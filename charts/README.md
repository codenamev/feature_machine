# Landing page charts

Interactive statecharts for the GitHub Pages site (`docs/`), drawn with the
Tinycharts Pro skill. Each folder holds the sheet (`.js`), its statechart
(`.mmd`) and a check (`.check.mjs`) that walks every reachable state.

| Chart | Type | Shows |
|---|---|---|
| `lifecycle/` | flowchart | one request from filed to shipped; tags from draft on are `WorkItem` statuses |
| `handoff/` | sequence diagram | who calls which MCP tool, from a user's agent to your merge |

Rebuild after editing (needs the tinycharts-pro skill, and `pele` from npm
somewhere above the folder for the logic panel's flow chart):

```sh
SK=~/.claude/skills/tinycharts-pro/assets
cd charts/lifecycle && node lifecycle.check.mjs && python3 $SK/build.py lifecycle.js -o ../../docs/charts/lifecycle.html --logic
cd ../handoff && node handoff.check.mjs && python3 $SK/build.py handoff.js -o ../../docs/charts/handoff.html --logic
```

If a status or transition changes in `WorkItem`, update the `.mmd`, the
drawing and the check together.
