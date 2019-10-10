# REST API to the ActiveWorkflow

ActiveWorkflow provides a REST API to allow you to query and control your agents and workflows programatically. 

All responses returned by ActiveWorkflow's API are in JSON format.

Currently only a basic read-only API is implemented. Nevertheless, it is still helpful enough for implementing dashboards, or for reading results of computations (messages) and feeding them into existing systems.

## Versioning

This is **version 1** of ActiveWorkflow API which is indicated by the URL. This
API may change in the future in a backwards compatible way. New endpoints and
parameters (optional) can be added without invalidating existing functionality.
Documented response fields may not be exhaustive - an API client should always
expect that more fields can be returned.

If any incompatible changes were to be introduced, the API version would be
updated and the new API would be served with a different URL.

## Authorization

The ActiveWorkflow API uses a [JsonWebToken](https://jwt.io/introduction/) based
authorization mechanism. You can acquire an authorization token by connecting to
the usual ActiveWorkflow web UI with you user email and password. You can then find
it under `Account` in `Configure Services`.

Note: an authorization token is connected to the account of a specific user and therefore
can only provide access to the system only on behalf of that user.

Currently API authorization tokens do not expire and allow full use of the
API. Expiring and scoped APIs (like **read only**) may be introduced later. An API
client should treat an authorization token as an opaque string and should not assume
anything about its format or content.

To authorize a request a client should put the authorization token into
an HTTP `Authorization` header in the following format:

```
Authorization: Bearer :token:
```

Where `:token:` is the authorization token.

Example invocation using curl:

```sh
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxfQ.kG4Si_1WJyGrsvm9zTcubjpYKzCubgaGdyakGwuwaCs" http://localhost:3000/api/v1/workflows
```

## Endpoints

### `GET /api/v1/agents`

List all of a user's agents.

Parameters - none.

Response - array of hashes where each hash represents an agent. Each agent's
hash has the following key/value pairs:

- `id` - identifier of the agent;
- `name` - name of the agent;
- `type` - string indicating the type of the agent;
- `disabled` - true if agent is disabled, false otherwise;
- `messages_count` - number of messages emitted by this agent;
- `source` - array of the source agents, each entry is a hash with `id`
  property.

Example:

```
GET /api/v1/agents
```

```json
[
  {
    "id": 1,
    "name": "Rerieve",
    "type": "Agents::WebsiteAgent",
    "disabled": false,
    "messages_count": 2,
    "sources": []
  },
  {
    "id": 2,
    "name": "Email",
    "type": "Agents::EmailAgent",
    "disabled": false,
    "messages_count": 0,
    "sources": [ { "id": 1 } ]
  }
]
```

### `GET /api/v1/agents/:agent_id`

Get info on specific agent.

Parameters - none.

Response - a hash representing an agent that has the following key/value pairs:

- `id` - identifier of the agent;
- `name` - name of the agent;
- `type` - string indicating the type of the agent;
- `disabled` - true if agent is disabled, false otherwise;
- `messages_count` - number of messages emitted by this agent;
- `source` - array of the source agents, each entry is a hash with `id`
  property.

Example:

```
GET /api/v1/agents/1
```

```json
{
  "id": 1,
  "name": "Rerieve",
  "type": "Agents::WebsiteAgent",
  "disabled": false,
  "messages_count": 2,
  "sources": []
}
```

### `GET /api/v1/agents/:agent_id/messages`

Get the latest messages emitted by the agent.

Parameters:

`after` - datetime (iso8601 string), only return the messages that where created
          *after* the given time;

`limit` - integer, only return this number of the *latest* created messages. By
          default all the messages are returned.

Response - an array of hashes where each hash represents a message and has the
following key/value pairs:

- `id` - identifier of the message;
- `agent_id` - identifier of emitting agent;
- `created_at` - datetime (iso8601 string) of when the message was created;
- `expires_at` - datetime (iso8601 string) of when the message expires, never if
                 null.

Example:

```
GET /api/v1/agents/1/messages?limit=1&after=2019-10-20T01:10:10.256-8:00
```

```json
[
  {
    "id": 1,
    "agent_id": 1,
    "created_at": "2019-10-20T02:01:14.122-8:00",
    "expires_at": "2019-10-21T02:01:14.122-8:00"
  },
  {
    "id": 2,
    "agent_id": 1,
    "created_at": "2019-10-20T02:02:13.317-8:00",
    "expires_at": "2019-10-21T02:02:13.317-8:00"
  },
]
```

### `GET /api/v1/messages/:message_id`

Get the message with the payload.

Parameter - none.

Response - a hash representing a message with the following key/value pairs:

- `id` - identifier of a message;
- `agent_id` - identifier of emitting agent;
- `created_at` - datetime (iso8601 string) of when a message was created;
- `expires_at` - datetime (iso8601 string) of when a message expires, never if
                 null;
- `payload` - JSON document containing payload of the message.

Example:

```
GET /api/v1/messages/1
```

```json
{
  "id": 1,
  "agent_id": 1,
  "created_at": "2019-10-20T02:01:14.122-8:00",
  "expires_at": "2019-10-21T02:01:14.122-8:00",
  "payload": {
    "title": "Lates news",
    "author": "John Snow"
  }
}
```

### `GET /api/v1/workflows`

Get a list of workflows.

Parameters - none.

Response - an array of hashes where each hash represent a workflow and has the
following key/value pairs:

- `id` - identifier of the workflow;
- `name` - name of the workflow;
- `description` - description of the workflow.

Example:

```
GET /api/v1/workflows
```

```json
[
  {
    "id": 1,
    "name": "My Workflow",
    "description": "This workflow does stuff."
  }
]
```

### `GET /workflows/:workflow_id`

Get a workflow *with* a list of agents that participate in that workflow.

Parameters - none.

Response - a hash that represents the workflow with the following key/value
pairs:


- `id` - identifier of the workflow;
- `name` - name of the workflow;
- `description` - description of the workflow,
- `agents` - array of hashes that describe agents participating in this workflow,
             format matches response of the `/api/v1/agents` endpoint.

Example:

```
GET /api/v1/workflows
```

```json
{
  "id": 1,
  "name": "My Workflow",
  "description": "This workflow does stuff.",
  "agents": [
    {
      "id": 1,
      "name": "Rerieve",
      "type": "Agents::WebsiteAgent",
      "disabled": false,
      "messages_count": 2,
      "sources": []
    },
    {
      "id": 2,
      "name": "Email",
      "type": "Agents::EmailAgent",
      "disabled": false,
      "messages_count": 0,
      "sources": [ { "id": 1 } ]
    }
  ]
}
```

## Errors

The API responds to failures using standard HTTP status codes. Additionally with a JSON
document containing a single key `error` where its value is a short description of the
error.

For example:

```json
{
  "error": "401 Unauthorized"
}
```

Supported errors are:

- `401` - unauthorized, authorization header is missing or is invalid;
- `404` - record (agent, workflow of message) not found;
- `500` - other unclassified errors (for now it includes parameter validation
          errors).
