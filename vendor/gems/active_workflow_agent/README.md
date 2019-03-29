## Installation

```shell
gem install active_workflow_agent
```

### Creating a new Agent Gem

Use the provided generator to create a skeleton of the new Agent Gem.

```shell
active_workflow_agent new active_workflow_awesome_agent
```

You can now start developing the new Agent in `./active_workflow_awesome_agent`. An example Agent class skeleton is located in `./active_workflow_awesome_agent/lib/active_workflow_awesome_agent/awesome_agent.rb`.

Every Agent and ruby source file needs to be "registered", so that the `active_workflow_agent` can load them during the startup of ActiveWorkflow. After creating new files add them in `lib/active_workflow_<your agent name>_agent.rb`:

```ruby
# use register to add more agents to ActiveWorkflow
ActiveWorkflowAgent.register 'path_to/<agent name>_agent'
# use load to require concern or other library classes
ActiveWorkflowAgent.load 'path_to/concerns/<file name>'
```

You can add your Agent Gem to your ActiveWorkflow instance for testing by adding it the to list of `ADDITIONAL_GEMS` in the ActiveWorkflow `.env` file:

```
ADDITIONAL_GEMS=active_workflow_awesome_agent(path: /local/path/to/active_workflow_awesome_agent)
```

### Running the specs for the Agent Gem

Running `rake` will clone and set up ActiveWorkflow in `spec/active_workflow` to run the specs of the Gem in ActiveWorkflow as if it were a builtin Agent. The desired ActiveWorkflow repository and branch can be modified in the `Rakefile`:

```ruby
ActiveWorkflowAgent.load_tasks(branch: '<your branch>', remote: 'https://github.com/<github user>/active_workflow.git')
```

Make sure to delete the `spec/active_workflow` directory and re-run `rake` after changing the `remote` to update the ActiveWorkflow source code.

After the setup is done, `rake spec` will only run the tests, without cloning ActiveWorkflow again. To get code
coverage reports set the `COVERAGE` environment variable: `COVERAGE=true rake spec`

