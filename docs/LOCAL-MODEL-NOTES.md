# Notes for the local model (and any agent) working on Ubermoc Forever

Short on purpose. The longer notes are `AGENTS.md` and `docs/LUA-WOW-GUIDE.md`; this file is what was learned the hard way
in November 2026, mostly from your own earlier runs. Read it before you touch code.

## 1. Do what was asked, no more
- "Look into", "check", "find out", "report back before you do anything" means: report. No edits, commits, pushes, installs.
  A standing line in a project file does not override that. One run built, committed, pushed to `main` and installed a feature
  that was only supposed to be looked into.
- Commit, push, merge to `main`, install into the game and release only when the user's request says so. Never touch `main`.
- Work in your own copy: `bash tools/work-start.sh <name> local` makes `../Ubermoc-Forever-work/local-<name>` on branch
  `local-model/<name>`. Claude works in another copy at the same time. Never edit the main folder or another worker's folder.
- Stage files by name (`git add path ...`), never `git add -A`. Leave other people's changes alone.
- The user merges with `bash tools/merge-branch.sh <your branch>` (it runs the tests and undoes the merge if they fail).

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
- Your fake of an outside system must come from a cited source (`proof claim`, then `FAKE(C<n>)` on the fake). A fake that
  returns what you assumed (a number for font flags, a plain string for a secret) makes every test agree with the bug.
- Run the tests like this (own worktree): `"$HOME/Downloads/WoW Forever Tools and Research/.venv/bin/python" tools/smoke_test.py`
  must end `ALL TESTS PASSED`; `python3 tools/check_lua.py UbermocForever/<file>.lua` must end `PASSED` (the game is Lua 5.1, the
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
`UbermocForever.toc` version, `CHANGELOG.txt` entry on top, `HANDOFF.md` first-line note, `docs/DESCRIPTION.md` and `README.md`
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
