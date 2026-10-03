# GoKart / Godot quirks

- Godot ignores files whose name starts with `_` (e.g. `tools/_probe.gd` -> "File not found"). Name throwaway probes `tools/probe_x.gd` and delete them before committing.
- Sibling nodes given the same `name` are renamed `@Name@N` at runtime — give per-index names (`"Signal%d" % i`) when tests count them.
- `user_shell` may start in $HOME with AGENT_PROJECT_FOLDER unset: always `cd /Users/toddbruss/Documents/GitHub/GoKart` explicitly.
- Never pipe `./run_tests.sh` through `perl alarm` + grep: the alarm kills zsh but leaves godot orphaned holding the pipe -> the shell call hangs to the 600 s limit. Run `godot --headless --path . -s tests/test_runner.gd > /tmp/log 2>&1 &` under perl alarm and poll the log instead. Whole suite takes ~2-3 min.
- A test file with a parse error makes the runner's `script.new()` fail and `_initialize` abort silently (no RESULT line, hangs until the alarm). Check the log for `Failed to load script` first.
- Another Agent! tab may work in this repo concurrently (menu/HUD restyle, auto-checkpoint commits that sweep ALL working-tree changes). Stage only your own files; check `git status` before committing.
- Headless tools: `tools/*_check.gd` print PASS/FAIL lines and "<NAME> CHECK: OK"; `_process` runs more than once per physics frame, so one-off checks need a `checked` flag rather than `pf == N`.
