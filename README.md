# feature_machine

Feature requests, work items, and the judge pipeline, packaged as a Rails engine.

## Install

```
bin/rails g feature_machine:install
bin/rails db:migrate
```

The generator writes `config/initializers/feature_machine.rb` and draws
`feature_machine_routes :web`, `:admin` and `:api` into `config/routes.rb`.

## Host contract

A fresh-app smoke test boots and serves `/up` once these are in place. Without
them, the matching surface returns a 500.

- **Postgres with pgvector.** The migrations enable the `vector` extension.
- **A `users` table.** `feature_requests.user_id` references it, and the
  work-items migration adds `users.admin`. The table name is not configurable yet.
- **`ApplicationController`** for the public feature-request pages.
- **`Admin::BaseController`** for everything under `:admin`. It owns the admin
  auth check.
- **`Api::BaseController`** for everything under `:api`. It owns token auth and
  the 401/403 bodies.
- **Host-owned pages** such as the roadmap and bug reports. The engine links to
  them through the `*_path` lambdas in the initializer (`config.roadmap_path`
  and friends) and never draws those routes itself, so `/roadmap` 404s until
  the host does.

## The fulfilment agent

`feature_machine agent` runs on a developer's machine, inside a checkout of the
host app. It reads planned work items from the host's maintainer MCP endpoint,
writes code in that checkout, runs the host's test command, and opens a pull
request. The engine never loads it; `require "feature_machine/agent"` opts in.

```
FEATURE_MACHINE_APP_URL=https://app.example \
FEATURE_MACHINE_TOKEN=... \
bundle exec feature_machine agent
```

Settings come from flags, then ENV, then `.feature_machine.yml` in the
checkout. The token is read from flags or ENV only, never from the YAML file.

### What it can and can't do

- It sees three host tools: `list_work_items`, `get_work_item`,
  `update_work_item`. Every `update_work_item` call waits for you to approve it.
- File reads and writes are confined to the checkout, checked both by path and
  after resolving symlinks.
- Tests run as an argv list with no shell.
- `OpenPullRequest` waits for your approval, refuses `main` and `master`, and
  only pushes after a separate judge passes the full diff against the work
  item's acceptance criteria. The agent can't supply those criteria itself;
  they are fetched from the host. Red tests or an empty diff fail without a
  model call.
- It never deploys and never touches the running app beyond those three tools.

### The security concession

Version one runs with your own credentials on a machine that already holds
them: your git remote, your `gh` login, your model keys. That is the same trust
you already extend to any coding agent you run locally. The deployed app gets
no new attack surface, because all it ever sees is a maintainer token making
API calls.

What that does mean: the work item text is input to the model, and the test
command executes code the model wrote. The approval gates and the judge narrow
what reaches GitHub. They don't sandbox the test run. If that matters for your
app, run the agent in a disposable checkout or container. A sandboxed test
runner is the planned upgrade, not part of this version.
