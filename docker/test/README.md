Docker image for ActiveWorkflow testing
=================================================

This image allows the ActiveWorkflow test suite to be run in a container,
against multiple databases.

In Development Mode, the source code of the current project directory is
mounted as a volume overlaying the packaged `/app` directory.  Please export
your user ID so volume permissions are correct (this is not required on a Mac):

```sh
export UID
```

## Development Usage

Build a docker image that contains ActiveWorkflow, as well as ActiveWorkflow test dependencies using `docker-compose`:

    cd docker/test
    docker-compose build

or

    cd docker/test && make rebuild

Run all specs against using `docker-compose`:

    cd docker/test
    docker-compose run active_workflow_test
    docker-compose down

or

    cd docker/test && make test && make down

Run a specific spec using `docker-compose`:

    docker-compose run active_workflow_test rspec ./spec/helpers/dot_helper_spec.rb:82
    docker-compose down
