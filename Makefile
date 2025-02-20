build:
	docker-compose build

start:
	docker-compose up -d

stop:
	docker-compose down

restart: stop start

tests:
	docker-compose up proxy -d
	docker-compose exec proxy busted --pattern=_test /usr/local/openresty/nginx/lua