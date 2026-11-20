#!/usr/bin/env python3
"""Bring a worker branch up to date with main, renumbering the version when main has moved on.

Run through tools/sync-main.sh, inside the worker's own folder (never main), with everything committed.

What it does:
  1. merges the local `main` into the current branch;
  2. if only Ubermoc-Forever.toc, CHANGELOG.txt and HANDOFF.md conflict (two workers each added an entry on top and a
     version number), it resolves them by itself: main's entries stay, the branch's entry goes on top, and the branch's
     version becomes main's version + 1 (in the .toc, in the top CHANGELOG heading, in the HANDOFF note);
  3. any other conflict: the merge is aborted, nothing changes, and the files are listed so a person can look.
Exit code 0 = up to date (or nothing to do), 1 = stopped, 2 = bad use.
"""
import re
import subprocess
import sys

GIT = ["git", "-c", "user.name=Ubermoc", "-c", "user.email=ubermoc@users.noreply.github.com"]
AUTO = {"Ubermoc-Forever/Ubermoc-Forever.toc", "CHANGELOG.txt", "HANDOFF.md"}
VER = re.compile(r"\d+\.\d+\.\d+")


def run(*args, check=True):
    r = subprocess.run(list(args), capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"command failed: {' '.join(args)}\n{r.stdout}{r.stderr}")
    return r


def toc_version(text):
    m = re.search(r"^## Version:\s*(\S+)", text, re.M)
    return m.group(1) if m else None


def bump(version):
    a, b, c = (int(x) for x in version.split("."))
    return f"{a}.{b}.{c + 1}"


def split_conflict(text):
    """Return (ours, theirs, before, after) for the first conflict block in text."""
    m = re.search(r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", text, re.S)
    if not m:
        return None
    return m.group(1), m.group(2), text[: m.start()], text[m.end():]


def main():
    branch = run("git", "branch", "--show-current").stdout.strip()
    if branch in ("", "main"):
        sys.exit("Run this in your own worker folder, on your own branch (not main).")
    if run("git", "status", "--porcelain").stdout.strip():
        sys.exit("Commit your work first (git add <files>; git commit); there are uncommitted changes.")
    behind = run("git", "rev-list", "--count", "HEAD..main").stdout.strip()
    if behind == "0":
        print("Already up to date with main.")
        return 0
    main_ver = toc_version(run("git", "show", "main:Ubermoc-Forever/Ubermoc-Forever.toc").stdout)
    mine_before = toc_version(open("Ubermoc-Forever/Ubermoc-Forever.toc").read())
    r = run(*GIT, "merge", "--no-ff", "--no-commit", "main", check=False)
    conflicted = run("git", "diff", "--name-only", "--diff-filter=U").stdout.split()
    if r.returncode == 0 and not conflicted:
        # clean merge; the version may still be behind main's
        toc_path = "Ubermoc-Forever/Ubermoc-Forever.toc"
        mine = toc_version(open(toc_path).read())
        if mine_before and main_ver and tuple(map(int, mine.split("."))) <= tuple(map(int, main_ver.split("."))):
            new = bump(main_ver)
            text = open(toc_path).read().replace(f"## Version: {mine}", f"## Version: {new}", 1)
            open(toc_path, "w").write(text)
            run("git", "add", toc_path)
            print(f"The version was {mine}, main is at {main_ver}: set to {new} in the .toc. Fix the top CHANGELOG heading by hand.")
        run(*GIT, "commit", "-q", "-m", f"Merge main into {branch}")
        print("Merged main. No conflicts.")
        return 0
    others = [f for f in conflicted if f not in AUTO]
    if others:
        run(*GIT, "merge", "--abort", check=False)
        print("STOPPED: main and this branch changed the same lines in:\n  " + "\n  ".join(others))
        print("Nothing was changed. Ask Ubermoc (or the user) to resolve it; do not guess.")
        return 1
    new = bump(main_ver)
    for f in conflicted:
        text = open(f).read()
        parts = split_conflict(text)
        while parts:
            ours, theirs, before, after = parts
            if f.endswith(".toc"):
                resolved = f"## Version: {new}\n"
            elif f == "CHANGELOG.txt":
                ours = re.sub(r"(Ubermoc-Forever )" + VER.pattern, r"\g<1>" + new, ours, count=1)
                resolved = ours.rstrip("\n") + "\n\n" + theirs
            else:  # HANDOFF.md: the branch's own note first, its version number renumbered
                if mine_before:
                    ours = ours.replace(mine_before, new, 1)
                resolved = ours + theirs
            text = before + resolved + after
            parts = split_conflict(text)
        open(f, "w").write(text)
        run("git", "add", f)
    run(*GIT, "commit", "-q", "-m", f"Merge main into {branch}; renumbered this branch to {new}")
    print(f"Merged main. Main is at {main_ver}, so this branch is now {new} (toc, CHANGELOG top heading, HANDOFF note).")
    print("Read the top of CHANGELOG.txt and HANDOFF.md once to check they read well.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
