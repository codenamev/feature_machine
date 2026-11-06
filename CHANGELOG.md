# Changelog

## 0.1.0 (unreleased)

First public release.

- Mountable engine: feature requests and bug reports in, triage, work items out.
- Roadmap page and JSON API, maintainer API, and an MCP server for agents.
- `rails g feature_machine:install` initializer and `feature_machine:install:migrations`.
- Optional embeddings (pgvector via neighbor) for duplicate detection, and a
  RubyLLM drafter and judge behind `FeatureMachine.configure`.
- `feature_machine` executable for the agent hand-off loop.
