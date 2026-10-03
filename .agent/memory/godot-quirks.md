# GoKart / Godot quirks

- Godot ignores files whose name starts with `_` (e.g. `tools/_probe.gd` -> "File not found"). Name throwaway probes `tools/probe_x.gd` and delete them before committing.
- Sibling nodes given the same `name` are renamed `@Name@N` at runtime — give per-index names (`"Signal%d" % i`) when tests count them.
- `user_shell` may start in $HOME with AGENT_PROJECT_FOLDER unset: always `cd /Users/toddbruss/Documents/GitHub/GoKart` explicitly.
- Headless tools: `tools/*_check.gd` print PASS/FAIL lines and "<NAME> CHECK: OK"; `_process` runs more than once per physics frame, so one-off checks need a `checked` flag rather than `pf == N`.
