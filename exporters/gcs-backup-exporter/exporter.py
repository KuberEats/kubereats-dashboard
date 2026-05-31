from __future__ import annotations

import logging
import os
import time
from dataclasses import dataclass
from datetime import timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Iterable

from google.cloud import storage
from prometheus_client import Gauge, generate_latest
from prometheus_client.core import REGISTRY

LOGGER = logging.getLogger("gcs-backup-exporter")
PORT = int(os.getenv("PORT", "9817"))
CHECK_INTERVAL_SECONDS = int(os.getenv("CHECK_INTERVAL_SECONDS", "300"))
GCS_REQUEST_TIMEOUT_SECONDS = int(os.getenv("GCS_REQUEST_TIMEOUT_SECONDS", "10"))


@dataclass(frozen=True)
class Config:
    bucket: str
    prefix: str
    max_age_hours: float
    env: str
    cluster: str

    @property
    def max_age_seconds(self) -> float:
        return self.max_age_hours * 3600


def load_config() -> Config:
    return Config(
        bucket=os.getenv("GCS_BACKUP_BUCKET", ""),
        prefix=os.getenv("GCS_BACKUP_PREFIX", ""),
        max_age_hours=float(os.getenv("GCS_BACKUP_MAX_AGE_HOURS", "26")),
        env=os.getenv("KUBEREATS_ENV", "dev"),
        cluster=os.getenv("KUBEREATS_DB_CLUSTER", "kubereats-postgres"),
    )


LABELS = ("env", "cluster", "bucket", "prefix")
last_check_success = Gauge(
    "kubereats_gcs_backup_last_check_success",
    "Whether the last GCS backup freshness check succeeded: 1 success, 0 failure.",
    LABELS,
)
latest_object_timestamp = Gauge(
    "kubereats_gcs_backup_latest_object_timestamp_seconds",
    "Unix timestamp for the latest backup object updated time.",
    LABELS,
)
latest_object_age = Gauge(
    "kubereats_gcs_backup_latest_object_age_seconds",
    "Age in seconds of the latest observed backup object.",
    LABELS,
)
objects_total = Gauge(
    "kubereats_gcs_backup_objects_total",
    "Number of backup objects observed under the configured prefix.",
    LABELS,
)
max_age = Gauge(
    "kubereats_gcs_backup_max_age_seconds",
    "Configured maximum allowed backup age in seconds.",
    LABELS,
)


class BackupChecker:
    def __init__(self, config: Config, client: storage.Client | None = None) -> None:
        self.config = config
        self.client = client
        self.labels = {
            "env": config.env,
            "cluster": config.cluster,
            "bucket": config.bucket,
            "prefix": config.prefix,
        }

    def check_once(self) -> None:
        max_age.labels(**self.labels).set(self.config.max_age_seconds)

        if not self.config.bucket:
            LOGGER.error("GCS_BACKUP_BUCKET is required")
            last_check_success.labels(**self.labels).set(0)
            return

        try:
            blobs = list(self._list_blobs())
            newest = max((blob.updated for blob in blobs if blob.updated), default=None)
            objects_total.labels(**self.labels).set(len(blobs))

            if newest is None:
                latest_object_timestamp.labels(**self.labels).set(0)
                latest_object_age.labels(**self.labels).set(float("inf"))
            else:
                if newest.tzinfo is None:
                    newest = newest.replace(tzinfo=timezone.utc)
                timestamp = newest.timestamp()
                latest_object_timestamp.labels(**self.labels).set(timestamp)
                latest_object_age.labels(**self.labels).set(max(0, time.time() - timestamp))

            last_check_success.labels(**self.labels).set(1)
        except Exception:
            LOGGER.exception("GCS backup freshness check failed")
            last_check_success.labels(**self.labels).set(0)

    def _list_blobs(self) -> Iterable[storage.Blob]:
        if self.client is None:
            self.client = storage.Client()
        return self.client.list_blobs(
            self.config.bucket,
            prefix=self.config.prefix,
            timeout=GCS_REQUEST_TIMEOUT_SECONDS,
        )


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/healthz":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok\n")
            return

        if self.path == "/metrics":
            payload = generate_latest(REGISTRY)
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        LOGGER.info("%s - %s", self.address_string(), format % args)


def run_loop(checker: BackupChecker) -> None:
    while True:
        checker.check_once()
        time.sleep(CHECK_INTERVAL_SECONDS)


def main() -> None:
    logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
    config = load_config()
    checker = BackupChecker(config)

    import threading

    thread = threading.Thread(target=run_loop, args=(checker,), daemon=True)
    thread.start()

    server = ThreadingHTTPServer(("", PORT), Handler)
    LOGGER.info("Serving GCS backup exporter on port %s", PORT)
    server.serve_forever()


if __name__ == "__main__":
    main()
