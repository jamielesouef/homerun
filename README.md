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
homerun --wip                               # scan, show plan, confirm, push
homerun --wip --yolo                        # skip the prompt, push immediately
homerun --wip --dry-run                     # show the plan and exit, never prompts
homerun --dry-run                           # same as --wip --dry-run
homerun --wip --repo "~/dev/foo"            # limit to one repo, repeatable
homerun --add "~/dev/foo" --main false      # or: homerun -a ~/dev/foo -m false
homerun --add .                             # "." resolves to the current folder
homerun --add ~/dev --recursive             # walk the tree, add every repo found, purge tracked repos whose path is gone, drop duplicates
homerun --ignore add node_modules           # skip any folder named node_modules during --add --recursive
homerun --ignore add ~/dev/scratch          # skip that specific folder during --add --recursive
homerun --ignore add .                      # ignore the current folder
homerun --ignore add .build .git .vscode    # add several in one call
homerun --ignore remove node_modules        # stop ignoring it
homerun --ignore remove .build .git         # remove several in one call
homerun --ignore list                       # show every ignored folder
homerun --main true                         # set main for the repo you are standing in
homerun --remove .                          # or by id: homerun --remove <uuid>
homerun --remove-all                        # asks to confirm; drop every tracked repo
homerun --remove-all --yolo                 # skip the confirm
homerun --purge                             # asks to confirm; drop tracked repos whose path no longer exists
homerun --purge --yolo                      # skip the confirm
homerun --dedupe                            # asks to confirm; collapse repos tracked more than once
homerun --dedupe --yolo                     # skip the confirm
homerun --list                              # show every tracked repo, with its id
homerun --default-wip-name "SAVE"           # set the config-wide default prefix
```

`--add-path`/`--remove-path` are accepted as aliases of `--add`/`--remove`, and `--sync` is accepted as an alias of `--wip`. Every flag also has a single-letter short form (`-s`, `-d`, `-y`, `-a`, `-r`, `-R`, `-l`, `-A`, `-u`, `-D`, `-p`, `-m`, `-w`, `-W`, `-i`) — see `homerun --help`.

`--main <true|false>` on its own updates the tracked repo whose path is the current folder — run it from the repo root. It fails with exit 1 if the current folder is not in the config. Passed alongside `--add`, it applies to the repo being added instead.

`--dedupe` reports `📭 No duplicate repos.` and exits 0 when there is nothing to collapse.

`--ignore add|remove|list [<name-or-path>...]` manages the folders skipped during `--add --recursive`: a bare name (e.g. `node_modules`) skips every folder with that name anywhere under the walked tree; a path (containing `/`, or `.` for the current folder) skips just that folder. `add`/`remove` take one or more names/paths, space-separated (a stray trailing comma on an item is stripped). An ignored folder is never walked into, even if it's itself a git repo. `--ignore add` fails with exit 1 if any of the folders are already ignored, after adding the rest; `--ignore remove` fails with exit 1 if any weren't ignored, after removing the rest; `--ignore list` (no further argument) prints every ignored entry. `--list` also shows the ignored folders alongside tracked repos.

`--add --recursive` also reads a `.gitignore` at the walked root, if there is one, and skips whatever it names for that walk only — it is never written to the config. Only plain name/path lines are honoured (same rules as `--ignore` above); comments, blank lines, wildcards (`*`), and negation (`!`) lines are skipped rather than translated.

`--yolo` and `--dry-run` together is an error. `--recursive` without `--add` is an error.

## How a WIP run works

1. Read the config listing tracked repos.
2. For each repo, decide whether it needs attention: uncommitted changes (staged, unstaged, or untracked), local commits ahead of upstream, or a current branch with no upstream.
3. Print the plan — every repo, its state, and the exact action to be taken.
4. Prompt `Continue? [y/N]`. Anything other than `y`/`yes` cancels, writes nothing, and exits 0.
5. For each repo needing attention: stage everything, create a WIP commit, and push (`git push -u origin <branch>` if there's no upstream yet).
6. Print the per-repo result and a one-line summary.

If nothing needs attention, homerun prints `Everything is pushed.` and exits without prompting. Nothing is ever written before you confirm — the plan phase is read-only.

### Progress

When stdout is a TTY, homerun narrates as it works — a line per repo as it's scanned, and a line per repo as it's pushed — so a long run over many repos never looks stalled. When stdout isn't a TTY (piped or redirected), the progress lines are suppressed and only the plan, results, and summary are printed, keeping scripted output clean.

### GitHub account switching

If you have more than one GitHub account authenticated with the [`gh` CLI](https://cli.github.com) and a push is rejected because the active account lacks access, homerun retries the push under each of your other `gh` accounts (via `gh auth switch`) until one works. The row then reports which account succeeded, e.g. `pushed → origin/main (as personal)`. Your original active account is always restored when the run finishes, regardless of outcome. This only applies to HTTPS remotes, where `gh` acts as git's credential helper; a non-fast-forward or merge rejection is never treated as an auth problem and never triggers a switch. If `gh` isn't installed or only one account is authenticated, a rejected push simply fails as before.

## Output

```
Scanning 6 repos...
  … tvos-app
  … homerun
  … dotfiles
  … ios-app
  … scratch

Scanning 6 repos

  ↑  tvos-app         4 changed, 1 ahead      push → origin/feat-player
  ↑  homerun          2 changed, no upstream  push → origin/main (-u)
  ⊘  dotfiles         on main, main: false    skip
  ✓  ios-app          clean
  ✓  scratch          clean

2 to push · 1 skipped · 3 clean

Continue? [y/N]
```

```
  ✓  tvos-app         pushed → origin/feat-player
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
  "defaultWipName": "WIP",
  "ignoredFolders": ["node_modules", "~/dev/scratch"]
}
```

- `id` — a UUID assigned when the repo is added. Stable across re-adds of the same path; shown by `--list` and taken by `--remove <id>`.
- `repoPath` — absolute or tilde-expanded path, stored exactly as you typed it. Two entries are the same repo when their paths match after expanding `~` and resolving symlinks, so `~/dev/foo` and `/Volumes/Disk/dev/foo` — where one is a symlink to the other — are never both tracked.
- `wipName` — prefix for the WIP commit message: `"\(wipName): \(ISO8601 timestamp)"`.
- `main` — when `false`, skip the repo on `main`/`master` and report it as skipped. When `true`, treat it like any other branch.
- `defaultWipName` — top-level, optional, set with `--default-wip-name`. Falls back to `"WIP"`.
- `ignoredFolders` — top-level, folder names or paths skipped by `--add --recursive`, managed with `--ignore add`/`--ignore remove`. Falls back to an empty list.

## Rules

- Never force pushes.
- The plan phase is read-only — no staging, no commit, no push until you confirm.
- `--dry-run` never prompts and never writes.
- If stdin isn't a TTY and `--yolo` wasn't passed, homerun prints the plan and exits 1 rather than hang waiting on input.
- A failure in one repo doesn't abort the others.
- A repo is never tracked twice. `--add` updates the existing entry instead of adding a second one — keeping its id, `main` and `wipName` unless `--main`/`--wip-name` are passed — and `--add --recursive` drops any duplicate already in the config. `--dedupe` cleans up a config that already has duplicates: it keeps the first entry of each group, keeps its id, and keeps `main: true` if any entry in the group had it. A duplicate is only detected when the path exists on disk — symlinks can't be resolved otherwise; use `--purge` for entries whose path is gone.
- Exit code 0 if every repo succeeded, was clean, or you cancelled. Exit 1 if any repo failed, or on the non-TTY case above.

## Out of scope

Pull, merge, rebase, conflict resolution, credential setup, a daemon or file-watching mode, submodules.

## Requirements

macOS 13+, Swift 6. GitHub account switching is optional and needs the [`gh` CLI](https://cli.github.com) with more than one account authenticated; without it, homerun works exactly as before.

## Building from source

```
swift build -c release
```
