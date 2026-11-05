# Ubermoc Forever work process

Controller-first WoW addon for **Forever** (TOC 16001, build 1.60.1). Repo github.com/ubermoc/Ubermoc-Forever, CurseForge 1781086, license All Rights Reserved. Uses only Blizzard's own assets and public APIs.

## Rules
- Never drop Forever-only functionality. Forever loads Blizzard_Gamepad; Ubermoc must work alongside it without depending on it. Everything stays switchable in settings.
- Verify every API, CVar, template and atlas name against the `forever` branch of Gethe/wow-ui-source before using it. No in-game export exists.
- Never write a file with `open(p, "w")` before reading it (this once emptied tools/check.py).

## Every change
1. Make the change; add a CHANGELOG.md entry.
2. Run `tools/check.sh` (TOC/file list, Lua syntax, offline smoke test `tools/test.lua`, luacheck). It must pass; "luacheck not installed" is NOT a pass.
3. Build the zip (tagged release, or `tools/check.py build <version>` for dev builds).
4. ALWAYS install the build into the game folder without being asked: unzip to a temp dir, `cp -r` its `UbermocForever/.` over
   - `.../World of Warcraft/_forever_/Interface/AddOns/UbermocForever`
   then diff to confirm, and tell me I only need `/reload`.
5. Releases are tag-driven; see "Releasing: GitHub and CurseForge" below. Send me the zip + changelog.

## Testing loop
There is no desktop control. I run `/ubf selftest` (or another `/ubf` command) and `/reload`; you read
`.../_forever_/WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua` and `WTF/Config.wtf`.
Prefer `/reload` over logout: it re-fires ADDON_LOADED / PLAYER_LOGIN / PLAYER_ENTERING_WORLD.

## Releasing: GitHub and CurseForge
"Push" = the whole release (see `~/.claude/CLAUDE.md`). Everything needed is already set up:
- **GitHub:** repo `ubermoc/Ubermoc-Forever`, branch `main`, remote `git@github.com:ubermoc/Ubermoc-Forever.git` (SSH). The `gh` CLI is logged in as `ubermoc` (scopes: repo, read:org, gist). Use `gh` for releases, runs and secrets.
- **CurseForge:** project ID `1781086` (also `X-Curse-Project-ID` in `UbermocForever.toc`). Author page: https://authors.curseforge.com/#/projects/1781086
- **Release steps:**
  1. Bump nothing by hand in the TOC: `## Version: @project-version@` is filled in from the tag.
  2. Put the new entry at the TOP of `CHANGELOG.md` (it is the packager's `manual-changelog`, markdown). That text becomes both the GitHub release notes and the CurseForge changelog, so write it for players.
  3. Run `tools/check.sh` (must pass), commit as `vX.Y.Z: short summary`, push `main`.
  4. Tag `vX.Y.Z` and push the tag. `.github/workflows/release.yml` then runs the BigWigs packager, which builds `UbermocForever-X.Y.Z.zip` (per `.pkgmeta`, package-as `UbermocForever`), creates the GitHub release, and uploads the same zip to CurseForge with the repo secret `CF_API_TOKEN`. The packager gets the game version from the TOC `## Interface: 16001`.
  5. Verify, reporting each separately: `gh run list --limit 3` (workflow green), `gh release list --limit 3` (release is Latest, zip attached), then check the file appears on the CurseForge author page.
- If the CurseForge upload fails (token expired, game-version rejected), do not retry blindly: show me the workflow log (`gh run view --log-failed`). I enter or renew tokens myself (`gh secret set CF_API_TOKEN` is mine to run); you never type them.
- Manual CurseForge upload fallback: use Claude in Chrome at the author page above; I stay logged in myself. Never type my CurseForge or GitHub password.

## Related projects
This addon is one of four linked Ubermoc projects. How they fit together and where the others live is in `~/.claude/CLAUDE.md`; read it before changes that touch install paths, release assets, or the zip layout.
