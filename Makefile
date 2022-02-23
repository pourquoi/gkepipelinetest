.DEFAULT_GOAL      := help

DOCKER_COMPOSE      = docker compose

EXEC                = $(DOCKER_COMPOSE) exec
EXEC_API            = $(EXEC) api
EXEC_PHP            = $(EXEC) php
EXEC_CLIENT         = $(EXEC) client
RUN                 = $(DOCKER_COMPOSE) run --rm
RUN_PHP             = $(RUN) php
RUN_PHP_TEST_ENV    = $(RUN) -e APP_ENV=test php
RUN_PHP_NO_DEPS     = $(RUN) --no-deps php
RUN_CLIENT          = $(RUN) client
COMPOSER_INSTALL    = composer install --prefer-dist --no-progress --no-suggest --no-interaction
QA_PHP              = docker run --rm -v `pwd`/api:/project mykiwi/phaudit:7.4
STAGING_KUBECTL     = kubectl
STAGING_API_POD     = $(shell $(STAGING_KUBECTL) get pods | egrep '^api\-[a-z0-9]{10}-[a-z0-9]{5}' | cut -f 1 -d ' ')
STAGING_API         = $(STAGING_KUBECTL) exec -c app-api-backend $(STAGING_API_POD) -it --
STAGING_CLIENT_POD  = $(shell $(STAGING_KUBECTL) get pods | egrep '^client\-[a-z0-9]{10}-[a-z0-9]{5}' | cut -f 1 -d ' ')
STAGING_CLIENT      = $(STAGING_KUBECTL) exec -c app-client $(STAGING_CLIENT_POD) -it --

##
## Project
## -------
##

start: ## Start the project
	$(DOCKER_COMPOSE) up -d --build --remove-orphans --force-recreate

stop: ## Stop the project
	$(DOCKER_COMPOSE) stop

restart: stop start

down:
	$(DOCKER_COMPOSE) down --rmi all -v --remove-orphans

ps:
	$(DOCKER_COMPOSE) ps

db-shell: ## Connect to DB CLI
	$(DOCKER_COMPOSE) exec db psql -U api-platform -d api

db-diff: ## Generate migration file based on diff between entities and db schema
	$(EXEC_PHP) bin/console d:m:diff -n

db-migrate: ## Execute migrations
	$(EXEC_PHP) bin/console d:m:m -n

db-fixtures: ## Load fixtures
	$(EXEC_PHP) bin/console h:f:l -n

db-reset: ## Reset db
	$(EXEC_PHP) bin/console d:d:d --if-exists --force -n
	$(EXEC_PHP) bin/console d:d:c -n
	$(EXEC_PHP) bin/console d:m:m -n

api-shell: ## Run sh in api container with your own uid and gid
	$(EXEC_API) sh

php-shell: ## Run sh in php container with your own uid and gid
	$(EXEC_PHP) sh

client-shell: ## Run sh in client container
	$(EXEC_CLIENT) sh

##
## Vendors
## -------
##
vendors: vendor-php vendor-client vendor-admin

vendor-php:
	$(RUN_PHP_NO_DEPS) $(COMPOSER_INSTALL)

vendor-client:
	$(RUN_CLIENT) yarn install

vendor-admin:
	$(RUN_ADMIN) yarn install

##
## Tests
## -----
##

test: test-db test-php test-client test-admin ## Run tests

test-db: vendor-php
	$(RUN_PHP) sh -c "php bin/console d:d:c --if-not-exists && php bin/console d:m:m -n && php bin/console d:s:v"

test-php: test-php-phpunit test-php-behat ## Run API tests

test-php-phpunit: vendor-php ## Run PHPUnit tests
	$(RUN_PHP) sh -c "php vendor/bin/simple-phpunit"

test-php-behat: ## Run Behat tests
	$(RUN_PHP_TEST_ENV) php vendor/bin/behat

test-client: vendor-client ## Run client tests
	$(RUN_CLIENT) sh -c "CI=true yarn test --colors"

test-admin: vendor-admin ## Run admin tests
	$(RUN_ADMIN) sh -c "CI=true yarn test --colors"

##
## Lint
## --
##

lint: lint-php lint-twig lint-yaml lint-client lint-admin ## Run the linters

lint-fix: lint-php-fix lint-twig lint-yaml lint-client-fix lint-admin-fix ## Run the linters with fix option

lint-php: ## php-cs-fixer (http://cs.sensiolabs.org)
	$(QA_PHP) php-cs-fixer fix --dry-run --verbose --diff

lint-php-fix: ## apply php-cs-fixer fixes
	$(QA_PHP) php-cs-fixer fix --verbose --diff

lint-twig: vendor-php ## Check templates syntax
	$(RUN_PHP_NO_DEPS) sh -c "bin/console --ansi lint:twig templates"

lint-yaml: vendor-php ## Check configs syntax
	$(RUN_PHP_NO_DEPS) sh -c "bin/console --ansi lint:yaml config --parse-tags"

lint-client: vendor-client ## Run eslint on client
	$(RUN_CLIENT) sh -c "yarn run eslint --color src"

lint-client-fix: vendor-client ## Fix eslint on client
	$(RUN_CLIENT) sh -c "yarn run eslint --fix --color src"

lint-admin: vendor-admin ## Run eslint on admin
	$(RUN_ADMIN) sh -c "yarn run eslint --color src"

lint-admin-fix: vendor-admin ## Fix eslint on admin
	$(RUN_ADMIN) sh -c "yarn run eslint --fix --color src"

##
## QA
## --
##

qa: phploc phpmd php_codesnifer phpcpd

phploc: ## PHPLoc (https://github.com/sebastianbergmann/phploc)
	$(QA_PHP) phploc src

phpmd: ## PHP Mess Detector (https://phpmd.org)
	$(QA_PHP) phpmd src text .phpmd.xml

php_codesnifer: ## PHP_CodeSnifer (https://github.com/squizlabs/PHP_CodeSniffer)
	$(QA_PHP) phpcs -v --standard=.phpcs.xml src

phpcpd: ## PHP Copy/Paste Detector (https://github.com/sebastianbergmann/phpcpd)
	$(QA_PHP) phpcpd src

##
## Staging environment
## ----------------
##

staging-k8s-cluster-connect:
	gcloud container clusters get-credentials cluster-2 --zone europe-west1-d --project cataclop

staging-api-shell: staging-k8s-cluster-connect ## Log into a shell to the staging API environment
	$(STAGING_API) sh

staging-deploy: staging-k8s-cluster-connect ## Upgrades Helm staging config
	helm upgrade -f helm/app/values.yaml -f helm/app/staging/values.yaml app helm/app

##
## Help
## ----
##

help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m## /[33m/'
.PHONY: help
