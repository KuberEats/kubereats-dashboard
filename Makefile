.PHONY: up down logs ps restart validate

COMPOSE_FILE=deploy/gcp-vm/docker-compose.yml

up:
	docker compose --env-file .env -f $(COMPOSE_FILE) up -d

down:
	docker compose --env-file .env -f $(COMPOSE_FILE) down

logs:
	docker compose --env-file .env -f $(COMPOSE_FILE) logs -f

ps:
	docker compose --env-file .env -f $(COMPOSE_FILE) ps

restart:
	docker compose --env-file .env -f $(COMPOSE_FILE) restart

validate:
	bash scripts/validate.sh
