# homerun

A macOS terminal tool that makes sure in-progress work is never stranded on one
machine. It scans a configured list of repositories, shows you what it would do,
and on confirmation WIP-commits and pushes everything that needs it.

## Problem

Work sits uncommitted, or committed but unpushed, on whichever machine it was
started on. Switching machines loses access to it.

## Behaviour

Bare `homerun` (no flags) prints usage and exits 0. `homerun --sync` runs the
scan-plan-push flow described below; `--dry-run` chains onto it to show the
plan without prompting or writing.

1. Read the JSON config listing tracked repos.
2. For each repo, decide whether it needs attention:
   - uncommitted changes (staged, unstaged, or untracked)
   - local commits ahead of upstream
   - current branch has no upstream
3. Print the plan: every repo, its state, and the exact action to be taken.
4. Prompt `Continue? [y/N]`.
   - No, or anything other than `y`/`yes` — exit 0, write nothing, print
     `Cancelled. Nothing was changed.`
   - Yes — proceed.
5. For each repo needing attention:
   - stage everything
   - create a WIP commit using `wipName`
   - push; if no upstream is set, `git push -u origin <branch>`
6. Print the coloured per-repo result and a one-line summary.

If no repo needs attention, print `Everything is pushed.` and exit 0 without
prompting.

The scan runs once. Step 3 and step 6 render the same results, so the plan and
the outcome cannot disagree.

## Config

`~/.config/homerun/config.json`

```json
{
  "repos": [
    { "repoPath": "~/dev/foo", "wipName": "WIP", "main": false }
  ],
  "defaultWipName": "WIP"
}
```

- `repoPath` — absolute or tilde-expanded path. Accepts `~/...` or `/Users/...`.
- `wipName` — prefix for the WIP commit message. The message is
  `"\(wipName): \(ISO8601 timestamp)"`.
- `main` — when `false`, skip the repo if the current branch is `main` or
  `master`, and report it as skipped. When `true`, treat it like any other branch.
- `defaultWipName` — top-level, optional. Set with `--default-wip-name`. Falls
  back to `"WIP"` when unset. `--add` uses this when its own `--wip-name` is
  not given.

## Usage

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
homerun --remove .
homerun --remove-all                        # drop every tracked repo
homerun --list                              # show every tracked repo
homerun --default-wip-name "SAVE"           # set the config-wide default prefix
```

`--add-path`/`--remove-path` are accepted as aliases of `--add`/`--remove`.
Every flag also has a single-letter short form (`-s`, `-d`, `-y`, `-a`, `-r`,
`-R`, `-l`, `-A`, `-p`, `-m`, `-w`, `-W`) — see `homerun --help`.

`--yolo` and `--dry-run` together is an error. `--recursive` without `--add` is
an error.

`--add`, `--remove`, `--remove-all`, `--list`, and `--default-wip-name` mutate
the config (or just read it, for `--list`) and exit without scanning. Adding a
path that is not a git repo is an error, unless `--recursive` is set, in which
case every git repo found under that path is added and the path itself is not
required to be one. Adding a duplicate path updates the existing entry rather
than appending a second one.

## Output

Aligned columns, one line per repo, colour carrying the status. The user should
be able to tell what happened from a glance at the colour alone.

The plan:

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

The result, after confirmation:

```
  ✓  kick-tvos        pushed → origin/feat-player
  ✓  homerun          pushed → origin/main (-u)
  ⊘  dotfiles         skipped
  ✗  scratch          push rejected (non-fast-forward)

2 pushed · 1 skipped · 1 failed
```

- green — pushed
- dim — clean, nothing to do
- yellow — pending action in the plan, or skipped in the result
- red — failed, with the git error on the same line

Colour must degrade: no ANSI when stdout is not a TTY, when `NO_COLOR` is set,
or when `TERM=dumb`. Piping to a file must produce plain text.

## Architecture

- Swift 6 package, single executable target `homerun`
- Strict concurrency (`complete`), zero warnings
- Platform: macOS 13+
- Git via `Process` shelling out to `git`. No libgit2.
- `GitClient`, `ConfigStore`, and `Confirmer` are protocols, so the scan, plan,
  and push logic is testable without real repos or a TTY
- Rendering is a pure function from `[RepoPlan]` or `[RepoResult]` to lines.
  Styling is applied at the edge, so tests assert on plain strings.

### Dependencies

- `https://github.com/apple/swift-argument-parser` — the entire flag surface.
  One `ParsableCommand`, no subcommands.

Colour, column alignment, and the prompt are hand-written standard library
code (`Style.swift`, `Row.swift`, `Confirmer.swift`) — no dependency for any of
them. Config is read and written with `Foundation`'s `JSONEncoder`/`JSONDecoder`
— no YAML dependency.

## Rules

- Never force push.
- Nothing is written before the user confirms. The plan phase is read-only:
  no staging, no commit, no push.
- `--dry-run` never prompts and never writes.
- If stdin is not a TTY and `--yolo` was not passed, print the plan, then exit 1
  with `Not a TTY — pass --yes to run unattended.` Do not hang waiting on input.
- A failure in one repo must not abort the others. Report it and continue.
- Exit code 0 if every repo succeeded, was clean, or the user cancelled.
  Exit 1 if any repo failed, or on the non-TTY case above.
- Writing the config must preserve every existing entry.

## Out of scope

- pull, merge, rebase, conflict resolution
- credential setup
- daemon or file-watching mode
- submodules

## Done means

- `swift build -Xswiftc -strict-concurrency=complete` is warning-free
- Unit tests cover: needs-attention detection, `main: false` skip, no-upstream
  push path, one-repo-fails-others-continue, config add/remove round-trip,
  plan rendering with colour disabled, and — via a fake `Confirmer` — that
  declining performs zero writes
- Tests use a fake `GitClient` — no test creates or mutates a real repo

## Claude Code

- Before you start, say in a line what you're about to do; brief updates while
  you work help the user follow along. Close with a short recap that stands on
  its own — what you found, what you did, and what's next — so a reader who
  only sees the last message has the full picture.
- Keep the conversation history append-only
- Please remove all mannered prose.
- Use lists and bullet points when asked to, or when the content is
  multifaceted enough that they help with clarity. If the person explicitly
  requests minimal formatting, always format your responses without bullet
  points, headers, lists, or bold emphasis, as requested. In conversational,
  personal, or emotional exchanges, keep to plain prose.
- You are operating autonomously. The user is not watching in real time and
  cannot answer questions mid-task, so asking 'Want me to…?' or 'Shall I…?'
  will block the work. For reversible actions that follow from the original
  request, proceed without asking. Stop only for destructive actions or genuine
  scope changes the user must decide. Offering follow-ups after the task is
  done is fine; asking permission before doing the work is not.
