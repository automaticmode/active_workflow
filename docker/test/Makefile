.PHONY: rebuild
rebuild:
	docker-compose build

.PHONY: test
test:
	export UID && docker-compose run active_workflow_test

.PHONY: down
down:
	docker-compose down
