# feature_machine

Feature requests, work items, and the judge pipeline, packaged as a Rails engine.

## Install

Add the gem, then:

```
bin/rails g feature_machine:install
bin/rails feature_machine:install:migrations
bin/rails db:migrate
```

The generator writes `config/initializers/feature_machine.rb` and draws the
engine's routes into `config/routes.rb`:

```ruby
feature_machine_routes :web        # /feature-requests, /bug-reports, /roadmap
namespace :admin do
  feature_machine_routes :admin    # /admin/triage, /admin/work_items
end
namespace :api, defaults: { format: :json } do
  feature_machine_routes :api      # /api/feature_requests, /api/bug_reports, /api/roadmap,
end                                # /api/work_items, /api/maintainer/feature_requests
feature_machine_routes :mcp        # POST /mcp, for agents
```

Then tell the engine three things about your app in the initializer:

```ruby
FeatureMachine.configure do |config|
  # Who is signed in. With Rails' authentication generator:
  config.current_user = ->(request) { Session.find_by(id: request.cookie_jar.signed[:session_id])&.user }
  # Who may triage. The work-items migration adds users.admin, so the default works.
  config.admin = ->(user) { user.admin? }
  # Bearer token -> credential: any object answering `user` and `allows?(scope)`
  # for "read", "write" and "maintainer". Without it, agents can't connect.
  config.authenticate_api = ->(token) { ApiToken.authenticate(token) }
end
```

## Upgrading an app that drew the routes by hand

The route macro now draws everything the engine ships: bug reports, the
roadmap, triage, attachments, and their APIs. If your `config/routes.rb` still
draws any of those next to `feature_machine_routes`, delete your copies, or
Rails stops at boot with "Invalid route name, already in use".

The engine's controllers no longer inherit `Admin::BaseController` or
`Api::BaseController` on their own. If yours add filters, a layout or headers
the engine's pages should keep, point the engine at them:

```ruby
config.admin_parent_controller = "Admin::BaseController"
config.api_parent_controller   = "Api::BaseController"
```

Your API base keeps its own `render_error`. The engine reads the signed-in API
user through its own `api_user`, so your `current_user` is left alone.

## Host contract

That is everything a fresh `rails new` app needs. The engine brings its own
admin and API base controllers, so the host doesn't need `current_user`,
`Admin::BaseController`, `Api::BaseController` or a `has_many` on its user
model.

- **Postgres with pgvector.** The migrations enable the `vector` extension.
- **A `users` table.** `feature_requests.user_id` references it, and the
  work-items migration adds `users.admin`. Name another model with
  `config.user_class`.
- **Pages inherit your `ApplicationController`**, so your layout and auth
  filters apply. Signed-out visitors go to `new_session_path` when you have one
  (`config.sign_in_path`) and get a 401 otherwise. To inherit something else,
  set `config.parent_controller`, `config.admin_parent_controller` or
  `config.api_parent_controller`. An API base of your own keeps its own
  `render_error` and error handling.
- **The engine ships markup, not CSS.** Its pages carry `cn-*` class hooks
  for your stylesheet, alongside Tailwind-style utility classes that only take
  effect if your app already builds Tailwind. They show their own flash notices,
  because a new app's layout doesn't; set `config.flash_in_pages = false` if
  yours does.
- **Your own roadmap or bug board** replaces the engine's by pointing
  `config.roadmap_path` (and friends) at it.
- **An MCP server of your own** can skip `feature_machine_routes :mcp` and add
  `FeatureMachine::Mcp.for(credential)` to its tool list instead. A browser
  session cookie is never an MCP credential; only bearer tokens are.

### Models

Embeddings, the spec drafter and the triage judge are each off until you name a
RubyLLM model (`config.embedding_model`, `config.drafter_model`,
`config.judgment_model`). If a model is named but its provider key is missing
or the call fails, the feature steps aside: requests are still filed, triage
shows unranked groups, and forming a work item writes a plain digest instead
of a spec.

The triage judge uses RubyLLM's structured judgments, which only some providers
implement: OpenAI, Ollama, and TypeSafe's Jev models in ruby_llm 2.1. Pick a
`judgment_model` one of them serves. A chat model named through OpenRouter
can't judge: triage logs a warning and stays unranked.

OpenRouter does serve Jev's judgment API, so an OpenRouter key is enough:

```ruby
RubyLLM.configure do |c|
  c.typesafe_api_base = "https://openrouter.ai/api"
  c.typesafe_api_key  = ENV["OPENROUTER_API_KEY"]
end
FeatureMachine.config.judgment_model = "jev-latest"
```

For a local
[Jev-compatible server](https://rubyllm.com/configuration-providers/#jev-compatible-apis),
point `typesafe_api_base` at it instead and set
`config.judgment_provider = :typesafe`, so the server's own model id resolves
without a registry entry. Embeddings and the drafter work on any provider RubyLLM
supports, including OpenRouter (set `config.drafter_provider = :openrouter`).

Requests filed before `embedding_model` was set never got an embedding, and
triage leaves them out of every group. Embed them once you switch it on:

```
bin/rails feature_machine:embed_requests
```

`bin/rails feature_machine:calibrate_judge` checks your `judgment_model`
against mutated cases: paraphrases mustn't move an answer, and changes that
alter the meaning must. It spends tokens, so it never runs in CI.
In November 2026, `jev-latest` held 18 of 18. Rerun it when you change models.

## The fulfilment agent

`feature_machine agent` runs on a developer's machine, inside a checkout of the
host app. It reads planned work items from the host's maintainer MCP endpoint,
writes code in that checkout, runs the host's test command, and opens a pull
request. The engine never loads it; `require "feature_machine/agent"` opts in.

```
export FEATURE_MACHINE_APP_URL=https://app.example
export FEATURE_MACHINE_TOKEN=...        # a maintainer token held by an admin
export OPENAI_API_KEY=...               # or the key for whichever provider you use

bundle exec feature_machine agent                                  # list planned work items
bundle exec feature_machine agent --work-item 7 --plan-model gpt-4.1
```

Pick a capable model, and check it with `bin/rails feature_machine:eval_agent`.
That task seeds four work items on your app and runs the agent against a
scratch clone of your checkout. It confirms the agent opens a pull request
for a small change, reports an item blocked when it has no criteria or would
break sign-in, and never commits to `main`. In November 2026 runs,
`~anthropic/claude-sonnet-latest` (through OpenRouter) passed 8 of 8 across
two runs, `gpt-4.1` passed about half, mostly by writing tests that couldn't
see what they checked, and `gpt-4.1-mini` spent its whole budget exploring.
Treat that as a starting point, not a benchmark: run the eval yourself.

`--max-steps` (default 120) caps the run. One step is one model turn or one
round of tool calls; a small item takes 15 to 75. Approvals don't count.
Every run ends in a pull request or a progress note starting "Blocked:"; if
the model stops without either, it is asked once more.

Every write back to the app and every pull request stops and asks you `[y/N]`
at the terminal first. Settings come from flags, then ENV, then
`.feature_machine.yml` in the checkout. The token is read from ENV only, never
from a flag or the YAML file. Provider keys come from their usual variables
(`OPENAI_API_KEY`, `ANTHROPIC_API_KEY` and so on).

### What it can and can't do

- It sees three host tools: `list_work_items`, `get_work_item`,
  `update_work_item`. Every `update_work_item` call waits for you to approve it.
- In the checkout it has `list_files` (tracked and new files, not ignored
  ones), `read_file`, `write_file`, `run_tests` and `open_pull_request`.
- File reads and writes are confined to the checkout, checked both by path and
  after resolving symlinks.
- Tests run as an argv list with no shell.
- `open_pull_request` waits for your approval. It never commits to `main` or
  `master`: work started there moves to `feature-machine/work-item-<id>`. It
  only pushes after a separate judge passes the full diff against the work
  item's acceptance criteria. The agent can't supply those criteria itself;
  they are fetched from the host. Red tests or an empty diff fail without a
  model call.
- It never deploys and never touches the running app beyond those three tools.
- It can't run migrations. A change that needs one leaves the test schema
  behind, so the suite fails and the agent reports the item blocked.

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
