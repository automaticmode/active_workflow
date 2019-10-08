# Custom Agent API

You can create your own custom agents using the custom agent API. Currently
this is only available in Ruby, but we are working on providing a custom agent
API for multiple languages, beginning with Python.

## Creating a Custom Agent

To create an agent you define a class that has the following methods:

### `self.register(config)`

It registers your agent in the system. Receives configuration object `config`
and must return it with modifications applied.

### `initialize(context)`

It is called when your agent instance has to be created and receives context
that can be used to communicate with the system.

### `receive(msg)`

It receives a message that has to be processed by an agent.

### `check()`

It's called on schedule and gives the opportunity to an agent to perform its functionality.

### `working?`

Used to indicate an agents' status.

### The `config` Parameter

The config parameter is a Ruby object that has the following properties:
  - `display_name`: set the name of the agent that you want to display.
  - `description`: the description of the agent (Markdown).
  - `default_options`: options that will be used by default. These are the options that a user edits in the UI.

### The `context` Object

The `context` Ruby object is received during object initialisation and is used
to communicate with the system. It has the following methods and properties:
  - `memory`: access the agent's persistent memory (property that returns and accepts a hash).
  - `log(msg)`: the log method writes a log entry.
  - `error(msg)`: writes an error entry.
  - `emit_message(payload)`: emits a message with the provided payload.
  - `credential(name)`: reads credential configured by a user.

## Deploying the Custom Agent

To use your custom agent it has to be packaged as a Ruby gem. Fork the
ActiveWorkflow repository and add your gem to the `Gemfile`. Register your
agent's class by adding the following to the
`config/initializers/custom_agents.rb`:

```
require 'my_agent'

CustomAgents.register(MyAgent)
```

Where `my_agent` is the gem of your agent and `MyAgent` is the class of your agent.
