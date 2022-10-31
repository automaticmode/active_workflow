.PHONY: start
start:
	bundle exec foreman start

.PHONY: build-image
build-image:
	docker build -t local/active_workflow .

.PHONY: test
test:
	bundle exec rspec spec
