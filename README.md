# homerun

WIP everything before you head home, so nothing gets stranded on one machine.

homerun scans a list of repos you tell it about, shows you exactly what it plans to do, and — once you say yes — commits and pushes every repo that has loose work sitting on it. Uncommitted changes, unpushed commits, branches with no upstream: all of it, gone from "only on this laptop" to "safe on the remote" in one command.

## Why

Work sits uncommitted, or committed but unpushed, on whichever machine it was started on. Switch machines, and that work is out of reach. homerun is the tool you run on your way out the door.

## Install

Via Homebrew (no Swift needed):

```
brew install jamielesouef/tap/homerun
```

From source:

```
./install.sh
```

Builds a release binary and copies it onto your `PATH` (`/usr/local/bin` by default, override with `PREFIX`).

## Commands

```
homerun                                     # no flags: print usage, exit 0
homerun --sync                              # scan, show plan, confirm, push
homerun --sync --yolo                       # skip the prompt, push immediately
homerun --sync --dry-run                    # show the plan and exit, never prompts
homerun --dry-run                           # same as --sync --dry-run
homerun --sync --repo "~/dev/foo"           # limit to one repo, repeatable
homerun --add "~/dev/foo" --main false      # or: homerun -a ~/dev/foo -m false
homerun --add .                             # "." resolves to the current folder
homerun --add ~/dev --recursive             # walk the tree, add every repo found
homerun --remove .                          # or by id: homerun --remove <uuid>
homerun --remove-all                        # asks to confirm; drop every tracked repo
homerun --remove-all --yolo                 # skip the confirm
homerun --list                              # show every tracked repo, with its id
homerun --default-wip-name "SAVE"           # set the config-wide default prefix
```

`--add-path`/`--remove-path` are accepted as aliases of `--add`/`--remove`. Every flag also has a single-letter short form (`-s`, `-d`, `-y`, `-a`, `-r`, `-R`, `-l`, `-A`, `-p`, `-m`, `-w`, `-W`) — see `homerun --help`.

`--yolo` and `--dry-run` together is an error. `--recursive` without `--add` is an error.

## How a sync works

1. Read the config listing tracked repos.
2. For each repo, decide whether it needs attention: uncommitted changes (staged, unstaged, or untracked), local commits ahead of upstream, or a current branch with no upstream.
3. Print the plan — every repo, its state, and the exact action to be taken.
4. Prompt `Continue? [y/N]`. Anything other than `y`/`yes` cancels, writes nothing, and exits 0.
5. For each repo needing attention: stage everything, create a WIP commit, and push (`git push -u origin <branch>` if there's no upstream yet).
6. Print the per-repo result and a one-line summary.

If nothing needs attention, homerun prints `Everything is pushed.` and exits without prompting. Nothing is ever written before you confirm — the plan phase is read-only.

## Output

```
Scanning 6 repos

  ↑  kick-tvos        4 changed, 1 ahead      push → origin/feat-player
  ↑  homerun          2 changed, no upstream  push → origin/main (-u)
  ⊘  dotfiles         on main, main: false    skip
  ✓  kick-ios         clean
  ✓  scratch          clean

2 to push · 1 skipped · 3 clean

Continue? [y/N]
```

```
  ✓  kick-tvos        pushed → origin/feat-player
  ✓  homerun          pushed → origin/main (-u)
  ⊘  dotfiles         skipped
  ✗  scratch          push rejected (non-fast-forward)

2 pushed · 1 skipped · 1 failed
```

Colour carries the status — green for pushed, dim for clean, yellow for pending/skipped, red for failed with the git error on the same line. Colour degrades to plain text when stdout isn't a TTY, `NO_COLOR` is set, or `TERM=dumb`.

## Config

`~/.config/homerun/config.json`

```json
{
  "repos": [
    { "id": "71E1185C-AFA1-4791-B0C3-AD2892F2C49D", "repoPath": "~/dev/foo", "wipName": "WIP", "main": false }
  ],
  "defaultWipName": "WIP"
}
```

- `id` — a UUID assigned when the repo is added. Stable across re-adds of the same path; shown by `--list` and taken by `--remove <id>`.
- `repoPath` — absolute or tilde-expanded path.
- `wipName` — prefix for the WIP commit message: `"\(wipName): \(ISO8601 timestamp)"`.
- `main` — when `false`, skip the repo on `main`/`master` and report it as skipped. When `true`, treat it like any other branch.
- `defaultWipName` — top-level, optional, set with `--default-wip-name`. Falls back to `"WIP"`.

## Rules

- Never force pushes.
- The plan phase is read-only — no staging, no commit, no push until you confirm.
- `--dry-run` never prompts and never writes.
- If stdin isn't a TTY and `--yolo` wasn't passed, homerun prints the plan and exits 1 rather than hang waiting on input.
- A failure in one repo doesn't abort the others.
- Exit code 0 if every repo succeeded, was clean, or you cancelled. Exit 1 if any repo failed, or on the non-TTY case above.

## Out of scope

Pull, merge, rebase, conflict resolution, credential setup, a daemon or file-watching mode, submodules.

## Requirements

macOS 13+, Swift 6.

## Building from source

```
swift build -c release
```
