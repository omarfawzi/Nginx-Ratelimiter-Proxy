build:
	docker-compose build

start:
	docker-compose up -d

stop:
	docker-compose down

restart: stop start

tests:
	docker-compose up tests