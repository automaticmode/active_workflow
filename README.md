<a href="https://www.automaticmode.com"><img src="media/AML-logo.svg" width="125" height="125" align="right" /></a>

# ActiveWorkflow

[![CircleCI](https://circleci.com/gh/automaticmode/active_workflow.svg?style=shield)](https://circleci.com/gh/automaticmode/active_workflow)
[![Codecov](https://codecov.io/gh/automaticmode/active_workflow/branch/master/graph/badge.svg)](https://codecov.io/gh/automaticmode/active_workflow)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)


ActiveWorkflow helps you automate your business or product workflows with [software agents](https://en.wikipedia.org/wiki/Software_agent); autonomous
entities that act on schedule or react to external triggers. These unsupervised agents -which can be written in any programming language- connect to APIs, process information, perform routine tasks, and generally enable you to automate internal or external workflows.


<img src="media/workflows_screenshot.png"
     srcset="media/workflows_screenshot@2x.png 2x"
     alt="Main view">

## Getting Started

See the [Getting Started wiki page](https://github.com/automaticmode/active_workflow/wiki/Getting-Started) and follow the simple setup process. 

## Try it on Heroku!

A quick and easy way to check out ActiveWorkflow is by deploying it to
[Heroku](https://www.heroku.com/).

All you need to do is click the button bellow and fill in the environment variables for your seed user (admin):
`SEED_USERNAME`, `SEED_PASSWORD` (must be at least 8 characters long) and `SEED_EMAIL`.

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/automaticmode/active_workflow)

## Usage

Once you have ActiveWorkflow up and running you will want to configure some agents and most probably to arrange them in one or more workflows. You can use ActiveWorkflow via its web interface or its [REST API](https://github.com/automaticmode/active_workflow/wiki/REST-API) as illustrated in the diagram below, where a1-a6 are six agents and w1-w3 are three workflows these agents participate in.

<img src="media/AW_usage_diagram.svg" alt="ActiveWorkflow system overview diagram" />

### Creating Agents

There are currently three ways to create agents, listed below in order of ease:

1. You can create a new instance of a built-in agent and configure it via the web interface following the agent's configuration options and inline documentation. With [30+ built-in agents](https://github.com/automaticmode/active_workflow/wiki/List-of-Built-In-Agents) you have the ability to address many common business workflows.
2. If the functionality you wish to achieve isn't directly possible with any of the built-in agents then you can use the (built-in) JavaScript agent which let's you write custom JavaScript code that can send and receive messages.
3. Finally, if none of the above offers you the flexibility or the functionality you wish to achieve you can code and plug-in your own ActiveWorkflow agent. See [How to Create Your Own Custom Agents (with the Remote Agent API)](https://github.com/automaticmode/active_workflow/wiki/Remote-Agent-API) to learn how to do this.

## Documentation

You can find documentation at the [ActiveWorkflow Wiki](https://github.com/automaticmode/active_workflow/wiki).

## Acknowledgements

ActiveWorkflow started as a fork of [Huginn](https://github.com/huginn/huginn) with the
goal of solely targeting business use. ActiveWorkflow is incompatible with Huginn.


## License

ActiveWorkflow is released under the [MIT License](LICENSE).
