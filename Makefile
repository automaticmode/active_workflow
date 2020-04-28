.PHONY: start
start:
	bundle exec foreman start

.PHONY: setup-heroku
setup-heroku:
	bundle exec bin/setup_heroku

.PHONY: build-image
build-image:
	docker build -t local/active_workflow .

HEROKU_APP = $(shell heroku apps:info | grep 'Web URL' | awk -F'[/.]' '{print $$3}')
HEROKU_CONTAINER = registry.heroku.com/${HEROKU_APP}/web

.PHONY: heroku-docker-push
heroku-docker-push:
	docker tag local/active_workflow ${HEROKU_CONTAINER}
	docker push ${HEROKU_CONTAINER}

.PHONY: heroku-docker-release
heroku-docker-release:
	heroku container:release web

.PHONY: test
test:
	bundle exec rspec spec
