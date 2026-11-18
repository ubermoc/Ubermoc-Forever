#!/usr/bin/env bash
# Start a task in its OWN copy of the repo (a git worktree) on its own branch, so two workers (you, Claude, the local
# model) never edit the same folder. Usage: bash tools/work-start.sh <name> [claude|local]
# Makes ../Ubermoc-Forever-work/<who>-<name> on branch <who>/<name>, cut from main. Prints the folder to work in.
set -eu
name="${1:?usage: work-start.sh <name> [claude|local]}"; who="${2:-local}"
case "$who" in claude) prefix=claude ;; local) prefix=local-model ;; *) echo "second argument: claude or local"; exit 1 ;; esac
root=$(cd "$(dirname "$0")/.." && pwd)
dest="$(dirname "$root")/Ubermoc-Forever-work/$who-$name"
branch="$prefix/$name"
git -C "$root" rev-parse --verify -q main >/dev/null || { echo "no local main branch"; exit 1; }
[ -e "$dest" ] && { echo "$dest already exists"; exit 1; }
mkdir -p "$(dirname "$dest")"
git -C "$root" worktree add -b "$branch" "$dest" main
echo
echo "Work folder: $dest   (branch $branch, cut from main)"
echo "Run the worker there:  cd '$dest' && omp"
echo "When it is done, in the main folder: bash tools/merge-branch.sh $branch"
