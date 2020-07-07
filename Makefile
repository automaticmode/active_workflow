.PHONY: start
start:
	bundle exec foreman start

.PHONY: build-image
build-image:
	docker build -t local/active_workflow .

HEROKU_APP = $(shell heroku apps:info | grep 'Web URL' | awk -F'[/.]' '{print $$3}')
HEROKU_CONTAINER = registry.heroku.com/${HEROKU_APP}/web

.PHONY: test
test:
	bundle exec rspec spec
