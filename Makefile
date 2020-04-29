DOCKER_COMPOSE = docker-compose
DOCKER_COMPOSE_INFRA = docker-compose -f docker-compose.infra.yml

stop:
	docker-compose down
	docker-compose -f docker-compose.infra.yml down
	docker network rm infra_postgres
	docker network rm infra_api
	docker network rm infra_rabbit

start:
	$(MAKE) create_networks
	-${DOCKER_COMPOSE_INFRA} up -d
	-${DOCKER_COMPOSE} up -d

create_networks:
	-docker network create infra_postgres
	-docker network create infra_api
	-docker network create infra_rabbit

setup:
	$(MAKE) setup_gitmodules
	$(MAKE) setup_config
	$(MAKE) setup_yarn

setup_config:
	if [ ! -e ./config/audit/config.json ] ; then cp config/audit/config.example.json config/audit/config.json ; fi
	if [ ! -e ./config/client/config.public.json ] ; then cp config/client/config.public.example.json config/client/config.public.json ; fi
	if [ ! -e ./config/client/config.infra.json ] ; then cp config/client/config.infra.example.json config/client/config.infra.json ; fi
	if [ ! -e ./config/continuum-adaptor/config.json ] ; then cp config/continuum-adaptor/config.example.json config/continuum-adaptor/config.json ; fi
	if [ ! -e ./config/reviewer-mocks/config.json ] ; then cp config/reviewer-mocks/config.example.json config/reviewer-mocks/config.json ; fi
	if [ ! -e ./config/submission/config.json ] ; then cp config/submission/config.example.json config/submission/config.json ; fi
	if [ ! -e ./config/submission/config.client.json ] ; then cp config/submission/config.client.example.json config/submission/config.client.json ; fi
	if [ ! -e ./config/submission/newrelic.js ] ; then cp config/submission/newrelic.example.js config/submission/newrelic.js ; fi

clean_config:
	rm config/audit/config.json
	rm config/client/config.public.json
	rm config/client/config.infra.json
	rm config/continuum-adaptor/config.json
	rm config/reviewer-mocks/config.json
	rm config/submission/config.json
	rm config/submission/newrelic.js

setup_gitmodules:
	git submodule update --init --recursive

setup_yarn:
	yarn install

clean_databases:
	$(MAKE) create_networks
	-${DOCKER_COMPOSE_INFRA} up -d postgres
	-${DOCKER_COMPOSE_INFRA} down -v

follow_logs:
	-docker-compose -f docker-compose.yml logs -f

wait_healthy_infra:
	./.scripts/docker/wait-healthy.sh reviewer_postgres_1 20
	./.scripts/docker/wait-healthy.sh reviewer_s3_1 30
	# no health -> ./.scripts/docker/wait-healthy.sh reviewer_rabbitmq_1 30

wait_healthy_apps:
	./.scripts/docker/wait-healthy.sh reviewer_reviewer-mocks_1 30
	./.scripts/docker/wait-healthy.sh reviewer_submission_1 20
	./.scripts/docker/wait-healthy.sh reviewer_client_1 60
	./.scripts/docker/wait-healthy.sh reviewer_audit_1 20
	./.scripts/docker/wait-healthy.sh reviewer_continuum-adaptor_1 20

test_integration: setup
	$(MAKE) create_networks
	-${DOCKER_COMPOSE_INFRA} up -d
	make wait_healthy_infra
	${DOCKER_COMPOSE} up -d
	make wait_healthy_apps
	yarn test:integration

test_integration_master: setup
	$(MAKE) create_networks
	-${DOCKER_COMPOSE_INFRA} up -d
	make wait_healthy_infra
	${DOCKER_COMPOSE} -f docker-compose.master.yml up -d
	make wait_healthy_apps
	yarn test:integration
