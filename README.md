<h3 align="center">
    <br>
    <a href="https://www.activeworkflow.org"><img src="media/ActiveWorkflow-logo.svg" width="243" /></a>
</h3>

<h3 align="center">
    Automate your workflows with autonomous agents<br> in any programming language
</h3>

<br>

<p align="center">
    <img alt="GitHub" src="https://img.shields.io/circleci/build/github/automaticmode/active_workflow?style=for-the-badge">
    <img alt="GitHub" src="https://img.shields.io/codecov/c/github/automaticmode/active_workflow?style=for-the-badge">
    <img alt="GitHub release (latest by date)" src="https://img.shields.io/github/v/release/automaticmode/active_workflow?style=for-the-badge&color=287fe2">
    <img alt="GitHub release (latest by date)" src="https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge&color=27aace">
</p>

<h4 align="center">
  <a href="#getting-started">Getting Started</a> •
  <a href="#usage">Usage</a> •
  <a href="#documentation">Documentation</a>
</h4>



## About

ActiveWorkflow helps you to automate your workflows with [software agents](https://en.wikipedia.org/wiki/Software_agent), autonomous
entities that act on schedule or react to external triggers. These unsupervised agents –which can be written in any programming language– enable you to automate internal or external business, app and product workflows.

<h4 align="center">Connect to APIs • Process Data • Perform Routine Tasks • Send Notifications</h4>

<img src="media/workflows_screenshot.png"
     srcset="media/workflows_screenshot@2x.png 2x"
     alt="Main view">

## Getting Started

See the [Getting Started wiki page](https://github.com/automaticmode/active_workflow/wiki/Getting-Started) and follow the simple setup process.

## Try it on Heroku

A quick and easy way to check out ActiveWorkflow is by deploying it to
[Heroku](https://www.heroku.com/).

All you need to do is click the button bellow and fill in the environment variables for your seed user (admin):
`SEED_USERNAME`, `SEED_PASSWORD` (must be at least 8 characters long) and `SEED_EMAIL`.

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/automaticmode/active_workflow&env[SINGLE_DYNO]=1)

**!Note!**: The button above deploys ActiveWorkflow on a single dyno so it could be run using the free Heroku plan. This configuration is not recommended for production. Please see [Getting Started](https://github.com/automaticmode/active_workflow/wiki/Getting-Started#Running-On-Heroku) for more details.

## Usage

Once you have ActiveWorkflow up and running you will want to configure some agents and most probably to arrange them in one or more workflows. You can use ActiveWorkflow via its web interface or its [REST API](https://github.com/automaticmode/active_workflow/wiki/REST-API) as illustrated in the diagram below, where a1–a6 are six agents and w1–w3 are three workflows these agents participate in.

<img src="media/AW_usage_diagram.svg" alt="ActiveWorkflow system overview diagram" />

### Creating Agents

There are currently three ways to create agents, listed below in order of ease:

1. You can create a new instance of a built-in agent and configure it via the web interface following the agent's configuration options and inline documentation. With [30+ built-in agents](https://github.com/automaticmode/active_workflow/wiki/List-of-Built-In-Agents) you have the ability to address many common business workflows.
2. If the functionality you wish to achieve isn't directly possible with any of the built-in agents then you can use the (built-in) JavaScript agent which lets you write custom JavaScript code that can send and receive messages.
3. Finally, if none of the above offers you the flexibility or the functionality you wish to achieve, you can code and plug-in your own ActiveWorkflow agent. See [How to Create Your Own Custom Agents (with the Remote Agent API)](https://github.com/automaticmode/active_workflow/wiki/Remote-Agent-API) to learn how to do this.

## Documentation

You can find documentation at the [ActiveWorkflow Wiki](https://github.com/automaticmode/active_workflow/wiki).

## Acknowledgements

ActiveWorkflow started as a fork of [Huginn](https://github.com/huginn/huginn) with the
goal of solely targeting business use. ActiveWorkflow is incompatible with Huginn.


## License

ActiveWorkflow is released under the [MIT License](LICENSE).
