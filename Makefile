COMPOSE_FILE = srcs/docker-compose.yml
DATA_PATH = /home/$(USER)/data

all:
	@mkdir -p $(DATA_PATH)/mariadb
	@mkdir -p $(DATA_PATH)/wordpress
	@docker compose -f $(COMPOSE_FILE) up --build -d

down:
	docker compose -f $(COMPOSE_FILE) down

stop:
	docker compose -f $(COMPOSE_FILE) stop

clean: down
	docker compose -f $(COMPOSE_FILE) down -v

fclean: clean
	docker system prune -af
	sudo rm -rf $(DATA_PATH)/mariadb
	sudo rm -rf $(DATA_PATH)/wordpress

re: fclean all

.PHONY: all down sop clean fclean re