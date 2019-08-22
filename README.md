# ActiveWorkflow

[![CircleCI](https://img.shields.io/circleci/project/github/automaticmode/active_workflow/master.svg)](https://circleci.com/gh/automaticmode/active_workflow)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

ActiveWorkflow is an intelligent process automation platform that uses
[software agents](https://en.wikipedia.org/wiki/Software_agent); autonomous
entities that act on schedule or react to external triggers. These unsupervised
agents connect to APIs, process information, perform routine tasks, and enable
you to automate internal or external workflows.

<img src="media/workflows_screenshot.png"
     srcset="media/workflows_screenshot@2x.png 2x"
     alt="Main view">

## Overview

The basic concepts in ActiveWorkflow are *agents* and *workflows*.

### Agents

Agents are of different types and each type typically knows how to
perform a simple task. For example, the HTTP Status Agent checks the status
returned from an HTTP request and emits a corresponding *message*, while the
Twilio Agent sends SMS messages or initiates phone calls.

Agents emit and receive messages (some only emit, or only receive). A structure
of agents designated as message sources and message targets forms a network. This
is what allows a group of agents to coordinate themselves and transform a
collection of simple tasks into sophisticated and complex behaviour.

Some agents are self contained, like the Trigger Agent, which watches for
specific values in the messages it receives. Others depend on complex third
party services, like the aforementioned Twilio Agent.

Agents perform actions either on schedule, or when they receive a message. There
are also agents that can be triggered by external events. Agents are generally
stateful and can have memory. For example, the IMAP Folder Agent remembers the
last email it retrieved.

Each instance of an agent is configured by giving it a name, setting its schedule,
selecting the sources of the messages it receives (other agents), and choosing
among other common options:

<img src="media/agent_edit_screenshot.png"
     srcset="media/agent_edit_screenshot@2x.png 2x"
     alt="Agent configuration">

Settings specific to a type of agent are often configured by editing
the agent's "options" presented as a JSON document:

<img src="media/agent_edit_json_screenshot.png"
     srcset="media/agent_edit_json_screenshot@2x.png 2x"
     alt="Agent configuration with JSON">

Each agent type has in-line documentation explaining its functionality and all
its configuration options.

### Workflows

A network of agents can quickly become crowded, making it hard to discern
the whole picture. This is where the other key ActiveWorkflow concept comes into
play. Agents sharing common goals can be organised into *workflows*.

Workflows allow you to view and control groups of agents all at once. They can
also be exported and imported, so you can share automation solutions as a unit.

<img src="media/workflow_diagram_screenshot.png"
     srcset="media/workflow_diagram_screenshot@2x.png 2x"
     alt="Workflow diagram">

## List of Built-in Agents

### Input/Output Agents

Agents that connect your workflows to the outside world. Some of them can be used to interface with third party services when a dedicated agent is not (yet) available.

- **Webhook Agent**: creates messages by receiving webhooks from any source.

- **Data Output Agent**: outputs received messages as either RSS or JSON. Use it to output a public or private stream of ActiveWorkflow data.

- **HTTP Status Agent**: will check a URL and emit the resulting HTTP status code with the time that it waited for a reply. Additionally, it will optionally emit the value of one or more specified headers.

- **FTP Site Agent**: checks an FTP site and creates messages based on newly uploaded files in a directory. When receiving messages it creates files on the configured FTP server.

- **Website Agent**: scrapes a website, XML document, or JSON feed and creates Messages based on the results.

- **RSS Agent**: consumes RSS feeds and emits messages when they change.

- **Email Agent**: sends any messages it receives via email immediately.

- **Email Digest Agent**: collects any messages sent to it and sends them all via email when scheduled.

- **IMAP Folder Agent**: checks an IMAP server in specified folders and creates messages based on new mails found since the last run.

### Workflow and Data Processing Agents

These are the agents that control the workflow and perform common and simple data processing operations.

- **Commander Agent**: gets invoked on schedule or an incoming message, and commands other agents to run, disable, configure, or enable themselves.

- **Buffer Agent**: stores received messages and emits copies of them on schedule. Use this as a buffer/queue of messages.

- **Post Agent**: receives messages from other agents (or runs periodically), merges those messages with the Liquid-interpolated contents of payload, and sends the results as POST (or GET) requests to a specified URL.

- **De-duplication Agent**: receives a stream of messages and reemits the message if it is not a duplicate.

- **Manual Message Agent**: is used to manually create Messages for testing or other purposes.

- **Liquid Output Agent**: outputs messages through a Liquid template you provide. Use it to create a HTML page, or a JSON feed, or anything else that can be rendered as a string from your stream of ActiveWorkflow data.

- **JavaScript Agent**: allows you to write JavaScript code that can create and receive messages. If other agents aren’t meeting your needs, try this one!

- **Scheduler Agent**: periodically takes an action on target agents according to a user-defined schedule.

- **Attribute Difference Agent**: receives messages and emits a new message with the difference or change of a specific attribute in comparison to the message received.

- **Change Detector Agent**: receives a stream of messages and emits a new message when a property of the received message changes.

- **CSV Agent**: parses or serializes CSV data. When parsing, messages can either be emitted for the entire CSV, or one per row.

- **Gap Detector Agent**: will watch for holes or gaps in a stream of incoming Messages and generate “no data alerts”.

- **Read File Agent**: takes messages from File Handling agents, reads the file, and emits the contents as a string.

- **Trigger Agent**: will watch for a specific value in an message payload.

- **Message Formatting Agent**: allows you to format incoming messages, adding new fields as needed.

- **Digest Agent**: collects any messages sent to it and emits them as a single message.

- **Peak Detector Agent**: will watch for peaks in a message stream.

- **JSON Parse Agent**: parses a JSON string and emits the data in a new message.

### Third Party Service Agents

These agents use third party services to provide functionality. They also require an account with these services.

- **Evernote Agent**: connects with a user’s Evernote note store.

- **Basecamp Agent**: checks a Basecamp project for new messages.

- **Human Task Agent**: is used to create Human Intelligence Tasks on Mechanical Turk.

- **S3Agent**: can watch a bucket for changes or emit an message for every file in that bucket. When receiving messages, it writes the data into a file on S3.

- **Jira Agent**: subscribes to Jira issue updates.

- **Twilio Agent**: receives and collects messages, and sends them via text message or calls when scheduled.

- **Twilio Receive Text Agent**: receives text messages from Twilio and emits them as messages.

- **Aftership Agent**: allows you to track your shipments from Aftership and emit tracking status into messages.

- **Google Calendar Publish Agent**: creates events on your Google Calendar.

- **Wunderlist Agent**: creates new Wunderlist tasks based on incoming messages.

- **Slack Agent**: lets you receive messages and send notifications to Slack.

## Acknowledgements

ActiveWorkflow started as a fork of [Huginn](https://github.com/huginn/huginn) with the
goal of solely targeting business use. ActiveWorkflow is incompatible with Huginn.

## Deployment

### One Click Heroku Deployment

The easiest way to start using ActiveWorkflow is by deploying it to
[Heroku](https://www.heroku.com/).

If you are reading this document in a browser all you need to do is click the
button bellow and fill in the environment variables for your seed user (admin):
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
Don't forget to set any configuration options you may require using the
`heroku config` command line tool.

The default ActiveWorkflow configuration uses the same single dyno to run both
the web server and workers.

### Deployment with Docker

If you want to deploy ActiveWorkflow to a platform that uses docker
containers, you could make an ActiveWorkflow image.

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

ActiveWorkflow is built using Ruby and is a Ruby on Rails app.

Install all dependencies with:

```sh
gem install bundler
bundle
```

Diagrams are rendered using the `dot` tool from `Graphviz`. On a Mac install
`Graphviz` with:

```sh
brew install graphviz
```

### Running Locally

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

This starts the ActiveWorkflow instance on a local address
[localhost:3000](http://localhost:3000) with default username "admin" and
password "password".

The local instance uses the configuration stored in a `.env` file. You could
tweak it or use it as guidance when configuring your deployment target.

Tests can be run with `make test`.

### Running Locally with Docker

You can test the docker container you just built locally. Run it (with
postgres database in a separate container):

```sh
docker-compose up
```

This starts ActiveWorkflow instance on a local address
[localhost:3000](http://localhost:3000) with default login "admin" and password
"password".

Stop containers with:

```sh
docker-compose down
```

## License

ActiveWorkflow is released under the [MIT License](LICENSE).
