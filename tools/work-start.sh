#!/usr/bin/env bash
# Start a task in its OWN copy of the repo (a git worktree) on its own branch, so two workers (you, Ubermoc, the local
# model) never edit the same folder. Usage: bash tools/work-start.sh <name> [ubermoc|local]
# Makes "Project Support/Ubermoc-Forever - Worker Copies/<who>-<name>" inside this project on branch <who>/<name>, cut from main. Prints the folder to work in.
set -eu
name="${1:?usage: work-start.sh <name> [ubermoc|local]}"; who="${2:-local}"
case "$who" in ubermoc) prefix=ubermoc ;; local) prefix=local-model ;; *) echo "second argument: ubermoc or local"; exit 1 ;; esac
root=$(cd "$(dirname "$0")/.." && pwd)
main_dir=$(cd "$(git -C "$root" rev-parse --git-common-dir)/.." && pwd)   # the real repo, also when run from a worker copy
dest="$main_dir/Project Support/Ubermoc-Forever - Worker Copies/$who-$name"
branch="$prefix/$name"
git -C "$main_dir" rev-parse --verify -q main >/dev/null || { echo "no local main branch"; exit 1; }
[ -e "$dest" ] && { echo "$dest already exists"; exit 1; }
mkdir -p "$(dirname "$dest")"
git -C "$main_dir" worktree add -b "$branch" "$dest" main
echo
echo "Work folder: $dest   (branch $branch, cut from main)"
echo "Run the worker there:  cd '$dest' && omp"
echo "When it is done, in the main folder: bash tools/merge-branch.sh $branch"
