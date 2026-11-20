@AGENTS.md

# Claude Code notes (the shared rules are in AGENTS.md above; the local model follows the same file)
- Claude and the local model both work in their own worktrees from `main`; Claude is also the one who ships, releases and resolves merge conflicts when the user asks.
- When the user says "ship it", "merge it" or "release it", that is the permission for `tools/ship.sh` / `tools/release.sh`. Anything else outward-facing: ask first.
- Check on the local model's branches with `git -C <main folder> branch --no-merged main`; an unmerged finished branch is a miss to report.
- Start and end every session with `bash tools/status.sh`; report its result in one or two lines. Everything finished is installed (finish.sh), merged, pushed, and released when the user says so; leave nothing half-done.
