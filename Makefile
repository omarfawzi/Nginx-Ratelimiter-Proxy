build:
	docker-compose build

start:
	docker-compose up -d

restart:
	docker-compose down && docker-compose up -d