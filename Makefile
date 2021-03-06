BACKEND-SERVICE-CONTAINER=backend-service
MYSQL-CONTAINER=mysql

BACKEND-TEST-CONTAINER=test-backend
TEST-NETWORK=test-network

.PHONY : help
help :
	@echo "backend.lint			: Run static code analyis for backend"
	@echo "backend-proxy.lint	: Run static code analysis for the slack proxy backend service"
	@echo "backend.app			: Build and run backend service alongwith mysql server"
	@echo "backend.test			: Build and Run the tests for backend service"
	@echo "clean				: Remove docker containers."

build.images:
	docker-compose build --parallel

start.all: build.images
	docker-compose up -d

ui.install:
	cd ui/classroom-bot-ui && npm install

ui.build:
	cd ui/classroom-bot-ui && npm run-script build

ui.local.test:
	cd ui/classroom-bot-ui && npm test

ui.local.start:
	cd ui/classroom-bot-ui && npm start

ui.docker.lint:
	docker build --file='ui/lint.dockerfile' ui  --tag=node-lint:local
	docker run -it --name=node-lint node-lint:local
	docker rm node-lint

ui.docker.build:
	docker build --file='ui/deploy.dockerfile' ui --tag=bot-ui:local

ui.docker.run:
	docker-compose rm -f ui
	docker-compose up ui

ui.docker.test:
	docker build --file='ui/test.dockerfile' ui  --tag=node-test:local
	docker run -it --name=node-test node-test:local
	docker rm node-test

ui.docker.debug:
	docker build --file='ui/debug.dockerfile' ui  --tag=node-debug:local
	docker run -it --name=node-debug node-debug:local
	docker rm node-debug

ui.docker.run.all: ui.docker.build
	docker-compose rm -f ui
	docker-compose up ui

ui.docker.down:
	docker-compose stop ui


backend.down:
	docker-compose stop backend-service
	docker-compose rm backend-service

.PHONY : backend.lint
backend.lint:
	docker build -t backendlinter -f backend-service/lint.Dockerfile ./backend-service/
	docker run --rm backendlinter

.PHONY : backend-proxy.lint
backend-proxy.lint:
	docker build -t backendproxylinter -f backend-service/lint-bot-proxy.Dockerfile ./backend-service/
	docker run --rm backendproxylinter

.PHONY : backend.app
backend.app: build.images
	docker-compose up -d ${MYSQL-CONTAINER}
	docker-compose up -d ${BACKEND-SERVICE-CONTAINER}

.PHONY : restart.backend
restart.backend:
	- docker rm -f ${BACKEND-SERVICE-CONTAINER}
	- docker-compose up -d ${BACKEND-SERVICE-CONTAINER}

.PHONY : run-mysql
run-mysql:
	- docker run --name ${MYSQL-CONTAINER} --network ${TEST-NETWORK} -e MYSQL_ROOT_PASSWORD=group18 \
     -e MYSQL_DATABASE=classroom_db -e MYSQL_USER=user \
     -e MYSQL_PASSWORD=group18 -p 52000:3306 -d mysql:5.7
	- sleep 60

.PHONY : create-network
create-network:
	- docker network create ${TEST-NETWORK}

.PHONY : build-run-backend-test
build-run-backend-test:
	docker build -t backendtest -f backend-service/test.Dockerfile ./backend-service/
	docker run --rm --name ${BACKEND-TEST-CONTAINER} --network ${TEST-NETWORK} \
	 -p 8002:8002 --env-file backend-service/sample.env -e MYSQL_HOST=${MYSQL-CONTAINER} \
	 -e MYSQL_USER=root -e MYSQL_ROOT_PASSWORD=group18 backendtest

.PHONY : backend.test
backend.test: create-network run-mysql build-run-backend-test

.PHONY : clean
clean:
	- docker rm -f ${BACKEND-SERVICE-CONTAINER}
	- docker rm -f ${BACKEND-TEST-CONTAINER}
	- docker rm -f ${MYSQL-CONTAINER}
	- docker network rm ${TEST-NETWORK}
