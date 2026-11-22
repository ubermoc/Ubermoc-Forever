# Notes for the local model (and any agent) working on Ubermoc Forever

Short on purpose. The longer notes are `AGENTS.md` and `docs/LUA-WOW-GUIDE.md`; this file is what was learned the hard way
in November 2026, mostly from your own earlier runs. Read it before you touch code.

## 1. Do what was asked, no more, and how a finished task ends
- "Look into", "check", "find out", "report back before you do anything" means: report. No edits, commits, installs.
  A standing line in a project file does not override that. One run built, committed, pushed to `main` and installed a feature
  that was only supposed to be looked into.
- Never touch `main`: no merging into it, no pushing, no releasing. Those are the user's (or Ubermoc's, when asked).
- The ONE thing you do on your own when a feature or fix is finished and committed is install it for testing:
  `bash tools/finish.sh` in your own worker folder. It brings your branch up to date with main (renumbering your version when
  main moved on), runs the offline test and the Lua checker, and installs into the game from your folder. Then tell the user to
  type `/reload` in the game. This is a standing permission; you do not need to be asked and you must not ask the user how to install.
- The full routine, every time:
  1. `bash tools/work-start.sh <name> local` (your own folder `~/Downloads/Projects/Ubermoc-Forever/Project Support/Ubermoc-Forever - Worker Copies/local-<name>`, branch `local-model/<name>`, cut from main). `cd` there.
  2. `bash tools/status.sh` (start and end of every session) and `bash tools/doctor.sh` once: they list the state and anything missing.
  3. Do the one feature. Stage files by name (`git add path ...`), never `git add -A`. Commit with
     `git -c user.name=Ubermoc -c user.email=ubermoc@users.noreply.github.com commit -m "..."`.
  4. `bash tools/finish.sh`. If it prints FAILED, fix that, commit, run it again. If it says STOPPED on a merge, stop and report.
  5. Final message: what changed, the real test output line, what is untested in the game, how long it took, and this line:
     "Waiting to be merged: `bash tools/ship.sh local-model/<name>`".
- Work in your own copy. Ubermoc works in another copy at the same time. Never edit the main folder or another worker's folder.
- Leave other people's changes alone. Version numbers belong to main: do not pick one that is taken; finish.sh renumbers.

## 2. Facts about the game that cost hours (all verified in source or in the game)
- Many unit answers are SECRET values for addon code: `UnitHealth`, and `UnitName`/`UnitClass` on restricted units. Do not
  compare, concatenate or do arithmetic on them. `issecretvalue(v)` tells. `type()` of a secret string is still "string".
- A few calls accept secrets from addons (their documentation says `SecretArguments = "AllowedWhenTainted"`): FontString
  `SetText`/`SetFormattedText`, StatusBar `SetValue`/`SetMinMaxValues`, Region `SetVertexColor`. Others (`SetTextColor`,
  `SetFont`) take plain values only.
- `UnitHealthPercent(unit, usePredicted, curve)` with `CurveConstants.ScaleTo100` gives a percentage you may show.
- `GetFont` returns the font flags as TEXT ("OUTLINE", ""), not a number. Types in documentation are names (`TBFFlags`), not
  "number": find what the type really is (the documentation file, then the Enum/type definition) before faking it.
- Nameplates are built from parts (`HealthBarsContainer`, `name`, `ClassificationFrame`, `AurasFrame`, `RaidTargetFrame`,
  `WidgetContainer`, `LevelFrame`, `PlayerLevelDiffFrame`). Plate frames are REUSED for other units: set state both ways on every
  add, and remember the original alpha before changing it (the selection highlight starts at .25, not 1).
- The game's own name-only mode for friendly players (`nameplateShowOnlyNameForFriendlyPlayerUnits`) hides auras and the dragon
  icon; the raid icon stays. Enemy players never get raid icons (`NamePlateUnitFrameMixin:GetRaidTargetIndex`).
- CVars: write them out of combat, remember the player's old value, give it back when the option goes Off.
- Chat: each window's edit box is anchored once in the XML under the window; the tab dock is re-anchored by the game whenever
  tabs change. Moving the box is cheap; moving the tabs is not (see `ChatEdit.lua`).
- Blizzard's nameplate code has nothing about quest progress; do not assume a feature exists in the source, search first.

## 3. Taint, short
- Write only on our own frames. Where a feature must move a game frame (the chat edit box), write only its own anchors, out of
  combat, inside `pcall`, and give the game's own values back on Off. Never hook or replace game functions.
- Do not store our values in game tables. Keep our state in our own tables (weak-keyed when keyed by a game frame).
- After a change that touches game frames, ask the user for the taint log before building on it.

## 4. Tests: how your earlier tests fooled you, and how to not do it again
- Your fake of an outside system must come from a cited source (`proof claim`, then a FAKE marker naming the claim on the
  fake, like `FAKE` followed by the claim id in parentheses). A fake that
  returns what you assumed (a number for font flags, a plain string for a secret) makes every test agree with the bug.
- Run the tests like this (own worktree): `"$HOME/Downloads/Projects/Ubermoc-Forever/Project Support/Ubermoc-Forever - WoW Research and Tools/.venv/bin/python" tools/smoke_test.py`
  must end `ALL TESTS PASSED`; `python3 tools/check_lua.py Ubermoc-Forever/<file>.lua` must end `PASSED` (the game is Lua 5.1, the
  test is Lua 5.5; only the checker catches 5.4 syntax and misspelt globals).
- A test that replaces a global (`InCombatLockdown`, `GENERAL_CHAT_DOCK`) must put the original back. One that set it to nil
  broke every later test and the failure pointed somewhere else.
- Prove the test can fail: change the code in two or three ways (an offset, a missing guard) and see the test go red, then undo.
  Use a search string that occurs ONCE, or no change is made and "it survived" means nothing.
- Pages in the options window have a row-count assertion. Adding a button changes it: update the number and say why.
- When a test fails after you changed nothing, someone else is editing the same folder. Stop and look at `git status`.

## 5. The proof tool (`proof`), mistakes seen
- Use single quotes around a claim with backticks: `proof claim '`Name` is ...' --source file:3-14 --quote '...'`. Inside double quotes
  the shell eats the backticks. Or write names in `[[double brackets]]`.
- One claim has one `--source` range (up to 40 lines); use several `--quote` lines inside it.
- Write each requirement before `proof run ... --proves R<n>`. Hand off ONCE, when everything is done: `proof handoff`.
- Cite the source file that defines the thing (the documentation or Blizzard file), not a community note, when both exist.

## 6. Version, docs and the usual checklist (per change)
Every new button in the options window needs a description in plain words: `UF.Describe.set(button, title, text)` (or `Describe.fn` when it depends on a selection). It shows in the bottom panel while the highlight is on it and in the mouse tooltip, and a smoke test fails when a button on the Chat, Bars, Quality of life or Fading page has none. Say what it does, and what A and X do on it. About 300 characters at most: the panel has four lines.
`Ubermoc-Forever.toc` version, `CHANGELOG.txt` entry on top, `HANDOFF.md` first-line note, `docs/DESCRIPTION.md` and `README.md`
if the behaviour is user-visible, a case in `tools/smoke_test.py`, research notes in `docs/RESEARCH-NAVIGATION.md` with file:line.
Everything not seen in the game is "untested in the game", in the changelog, the commit and your report.

## 7. Speed and reports
- Writing is the slow part (about 57 tokens a second here). Do not re-read files you just wrote, do not narrate, batch edits.
- Do not run a long command with no output; use `timeout`. If a hang-up kills the session, it is resumed from the log.
- Reports are short: what changed, what was run (with the real output line), what is NOT verified, what you need decided.

## 8. The user
Short answers. Believe a bug report and reproduce it. Do not change stated behaviour without asking. Only Blizzard's own art and
templates, no invented textures. One feature at a time. Ask before anything outward-facing (release, push, install on his machine).
Fish shell: one command per code block.

## 9. When something "does nothing" in the game (added 1.3.157)
- No error in the error addon does NOT mean no error: a bare `pcall(f)` throws the message away (the X-on-bags bug hid inside `pcall(G.update)` for a day). Use `UF.try("label", fn, ...)` for our own code that runs from a ticker, an event or a click; `/ubf errors` in the game prints what it caught. `tools/check_lua.py` refuses a file whose count of statement-level `pcall(` grows past `tools/silent-pcall-baseline.json`.
- Find which step fails before changing the approach: does the legend show it (`/ubf x`), does the action resolve, does the click fire. Ask the user for one answer per step.
- The stub frames in `tools/smoke_test.py` raise when a method is called without its frame (`f.GetName()` instead of `f:GetName()`), like the game. Do not loosen them; if a test fails on that, the addon has the bug.
- A fix is proven by a test that fails on the old code: `proof run ... --fails-on main --keep tools/smoke_test.py -- ...` (see the harness README). Three failed attempts at one thing: stop and write a blocked hand-off.

## 10. State at 1.3.177 and what this session taught (read with HANDOFF.md, "WHERE THINGS STAND")
- The top of `HANDOFF.md` lists what exists, what is verified in the game and what is not, what was learned, and the open work in order. Start there.
- Lessons that cost days, in one line each:
  - A test stub more forgiving than the game hides the bug. Make the stub reject what the game rejects (`f.Method()` without the frame, a second argument to `math.atan`, a texture with no point, `SetAtlas` answering nothing). When a fix "works offline" and not in the game, the first suspect is a stub.
  - `x and f()` keeps only the first return value of `f`. `pcall(f)` as a statement throws the error away. The game's Lua is 5.1.
  - "No error shown" is not "no error": look for a bare `pcall`. Add `UF.try` and read `/ubf errors`.
  - When something does nothing, find WHICH step fails (does it start, resolve, fire) before changing the approach. Ask the user for one fact per step, or add a recorder that saves the facts to disk (`DB.*`, read with `tools/read_saved.py` after a `/reload`). That solved the arrow direction in one round once the numbers were on disk.
  - Do not guess what the game exposes: read `Blizzard_APIDocumentationGenerated` and the example addons (ForeverPlusPlus, ThePath), then scan the live game with the `/ubf` scan tools and read the result. The scans showed in one minute that docks and entrances are not available.
  - Do not fix a symptom you cannot reproduce. Record it (see `Diag.lua`), then fix what the record shows. A guessed stealth fix broke other things once.
  - The user's wording matters: "with the view", "breadcrumbs", "old arrow only", "no options". When they remove options, remove the button and the code path; when they bring them back to choose, restore the exact earlier version (it is in git history).
  - Licences: this addon is MIT. Read GPL addons for ideas, copy nothing. Ask before downloading anything; put downloads in the research folder in their own folder.
- Before a release: the offline test, the checker for every file, `bash tools/test_install.sh`, then the user's own test in the game. Release only when the user says (this one he did).
- The arrow's turn: Breadcrumbs (the only aim) turns by waypoint bearing minus facing; `Q.viewRotation` (the user's earlier choice, "with the view") applies only in the straight-line fallback. If the user asks for "with the view" again, ask whether Breadcrumbs should then point by the game's marker (it would ignore the learned waypoints).

## 11. The release browser (CurseForge upload and description), added 2026-11-21
- Why: the browser tools need a Chrome with a debugging port. Since Chrome 136 Chrome ignores `--remote-debugging-port` on the everyday profile (a malware protection, https://developer.chrome.com/blog/remote-debugging-port), so "quit Chrome and restart it with the flag" does nothing, and putting the flag in the launcher would not help either. The only supported way is a separate `--user-data-dir`.
- What exists: `Project Support/Ubermoc-Forever - Release Browser/release-browser` starts that Chrome (profile folder `profile/` next to it, port 9222, 127.0.0.1 only, no `--remote-allow-origins`). `status` shows the open tabs, `stop` closes it. The everyday Chrome is never touched.
- How the model uses it: just call the browser tools. `~/.pi/agent/pi-browser-release.json` (`script`, `port`) makes the extension attach to port 9222 and run `release-browser start` first when nothing answers. It never opens an anonymous browser. The patch is marked `LOCAL PATCH (Ubermoc)` in the extension's `index.ts`; re-apply it if the extension is updated (a copy of both files is in the backup set).
- The login: CurseForge is logged in only inside that profile (the user logs in there once; it stays). If the page shows a login or a captcha, stop and tell the user to do it in the window titled ReleaseBrowser. Do not try to log in, and do not read or copy cookies from the everyday Chrome.
- The steps for the upload itself are in `AGENTS.md`, "Releasing". The upload and the description edit are an outward-facing publish: only when the user says to release.

