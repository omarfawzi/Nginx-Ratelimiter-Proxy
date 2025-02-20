build:
	docker-compose build

start:
	docker-compose up -d

restart:
	docker-compose down && docker-compose up -d

tests:
	docker-compose up proxy -d
	docker-compose exec proxy busted --pattern=_test /usr/local/openresty/nginx/lua