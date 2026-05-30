.PHONY: up down logs validate

COMPOSE_FILE := deploy/local/docker-compose.yml

up:
	docker compose --env-file .env -f $(COMPOSE_FILE) up -d --build

down:
	docker compose --env-file .env -f $(COMPOSE_FILE) down

logs:
	docker compose --env-file .env -f $(COMPOSE_FILE) logs -f

validate:
	./scripts/validate.sh
