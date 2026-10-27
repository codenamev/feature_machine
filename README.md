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
