# ActiveWorkflow

[![CircleCI](https://img.shields.io/circleci/project/github/automaticmode/active_workflow/master.svg)](https://circleci.com/gh/automaticmode/active_workflow)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

ActiveWorkflow is a business process automation platform that uses
[software agents](https://en.wikipedia.org/wiki/Software_agent), autonomous
entities that act on schedule or react to external triggers. These unsupervised
agents can connect to third party services, process information, perform
routine tasks, and automate internal or external workflows, allowing businesses
to direct precious human time towards things that really matter.

<img src="media/workflows_screenshot.png"
     srcset="media/workflows_screenshot@2x.png 2x"
     alt="Main view">

## Overview

The fundamental "building blocks" used in ActiveWorkflow to implement business
process automation are *agents*. Agents are of different types and each type only
performs simple tasks specific to it. For example, the HTTP Status Agent can
check the status returned to an HTTP request and can emit a corresponding
*message*. The Twilio Agent can send SMS messages or initiate phone calls.

Some agents are self contained (like the Trigger Agent, which watches for
specific values in the messages it receives), others depend on complex third
party services (like the aforementioned Twilio Agent).

Agents perform actions either on schedule, or when they receive a message. There
are also agents that can be triggered by external events. Agents are generally
stateful and can have memory. For example, the IMAP Folder Agent remembers the
last email it retrieved.

Each instance of an agent is configured by giving it a name, setting its schedule,
selecting the sources (other agents) of the messages it receives, and choosing
among other options common to all agents:

<img src="media/agent_edit_screenshot.png"
     srcset="media/agent_edit_screenshot@2x.png 2x"
     alt="Agent configuration">

Settings specific to a type of agent are often configured by editing
the agent's "options" presented as a JSON document:

<img src="media/agent_edit_json_screenshot.png"
     srcset="media/agent_edit_json_screenshot@2x.png 2x"
     alt="Agent configuration with JSON">

Each agent type has inline documentation explaining its functionality and all
its configuration options.

As mentioned previously, agents can emit and receive messages (some can only
emit or only receive). A structure of agents designated as message sources and
message targets forms a network. This is what allows a group of agents to coordinate
among themselves and elevate a collection of simple tasks into complex behaviour.

A big network of agents may become crowded, making it overwhelming to discern
the whole picture. This is where another key ActiveWorkflow element comes into
play: agents sharing common goals can be organised into *workflows*.

Workflows allow you to view and control groups of agents all at once. Workflows
can be exported and imported, so process automation solutions can be shared as
a unit.

## Acknowledgments

ActiveWorkflow started as a fork of [Huginn](https://github.com/huginn/huginn)
with the sole goal of targeting strictly business use, for business process
automation. In our view Huginn would be a better option for personal use;
ActiveWorkflow is less fit to act like a home automation or smart weather
notification system. ActiveWorkflow is incompatible with Huginn.

## Deployment

### One click Heroku deployment

The easiest way to start using ActiveWorkflow is by deploying it to
[Heroku](https://www.heroku.com/).

If you are reading this document in a browser all you need to do is click the
button bellow and fill in environment variables for your seed user (admin):
`SEED_USERNAME`, `SEED_PASSWORD` and `SEED_EMAIL`.

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/automaticmode/active_workflow)

A free Heroku plan could be used to try out ActiveWorkflow, but it wouldn't be
enough for real use. That's because the limited run time and automatic turning
off of unused workers inhibits ActiveWorkflow from running scheduled tasks.

### Deployment to Heroku

If you would like more control or intend to deploy ActiveWorkflow from a modified
source tree, you could do that using Heroku's command line interface.

Please install Heroku's command line interface tool from
[Heroku Toolbelt](https://toolbelt.heroku.com).

For your convenience there is a helper script that guides you through all the
steps necessary to deploy to Heroku. It helps with Heroku app creation, plugin
installation, initial configuration and repository synchronisation. Helper
script is run with:

```sh
make setup-heroku
```

For additional configuration options please take a look at the `.env` file.
Don't forget to set any configuration options you require using `heroku config`
command line tool.

The default ActiveWorkflow configuration uses the same single dyno to run both
web server and workers.


### Deployment with Docker

If you want to deploy ActiveWorkflow to the platform that uses docker
containers, you could make an ActiveWorkflow image yourself.

Note: currently there is no official ActiveWorkflow image.

#### Requirements

To build, use, or try out a docker image you would need the following tools:
`docker` and `docker-compose`. (`docker-compose` is required if you plan to
run docker images locally for testing).

On a Mac the recommended way to install docker is
[here](https://docs.docker.com/docker-for-mac/install/).

On Linux please use your package manager or follow this [docker installation
guide](https://docs.docker.com/install/overview/).


#### Building the Image

You can build a docker image for deployment with:

```sh
make build-image
```

This creates an image named `local/active_workflow`.


#### Deployment to Heroku with Docker

You may prefer to use Heroku in a container mode (instead of deploying via
GitHub). Please be sure to login to Heroku docker registry before doing that:

```sh
heroku container:login
```

Docker deployment to Heroku happens in two steps. Push:

```sh
make heroku-docker-push
```

And release:

```sh
make heroku-docker-release
```

If you no longer wish to use image based deployment to Heroku you will need to
reset Heroku stack to `heroku-18` like this:

```sh
heroku stack:set heroku-18
```


## Development

### Requirements

ActiveWorkflow is built using the Ruby programming language and is a Ruby on Rails
app. You can install and manage a Ruby installation using [rvm](https://rvm.io/)
(recommended).

Install all dependencies with:

```sh
gem install bundler
bundle
```

Diagrams are rendered using `dot` tool from `Graphviz`. On a Mac install
`Graphviz` with:

```sh
brew install graphviz
```

### Running locally

If you want to test out ActiveWorkflow locally you can start a demo instance
using a local sqlite database. First prepare the database with:

```sh
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:seed
```

You can start the instance by running:

```sh
make start
```

This starts ActiveWorkflow instance on a local address
[localhost:3000](http://localhost:3000) with default username "admin" and password
"password" for you to try.

The local instance uses the configuration stored in a `.env` file. You can tweak it or
use it as guidance when configuring your deployment target.

Tests can be run with `make test`.

### Running locally with docker

You can test the docker container you just built locally. Run it (with
postgres database in a separate container):

```sh
docker-compose up
```

This starts ActiveWorkflow instance on a local address
[localhost:3000](http://localhost:3000) with default login "admin" and password
"password" for you to try.

Stop containers with:

```sh
docker-compose down
```

## License

ActiveWorkflow is released under the [MIT License](LICENSE).
