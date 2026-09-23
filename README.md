# Homerun

Never leave work stranded on one Mac.

Homerun watches the git repositories you work in, commits whatever is still
uncommitted at the end of the day, pushes it, and tells you what would stop you
picking the work up somewhere else. It comes in two parts that share the idea
but not the code:

- **`cli/`** — `homerun`, a command line tool for the one-shot "commit and push
  everything before I close the lid" habit.
- **`desktop/`** — a macOS app that keeps an eye on the same repositories, shows
  what is outstanding, and helps set the next Mac up to continue.

## Contents

- [The command line tool](#the-command-line-tool)
- [The macOS app](#the-macos-app)
- [Repository layout](#repository-layout)
- [Building and testing](#building-and-testing)
- [Architecture](#architecture)
- [Known gaps](#known-gaps)
- [Licence](#licence)

## The command line tool

### Installing

Through Homebrew:

```sh
brew install jamielesouef/tap/homerun
```

Or from a checkout, which builds in release mode and copies the binary onto your
`PATH` (`/usr/local/bin` by default, override with `PREFIX`):

```sh
cd cli
./install.sh
```

Needs macOS 13 or newer and the `git` command line tool.

### Using it

Running `homerun` with no arguments syncs, which is the common case. It scans
every tracked repository, shows you the plan, and pushes what needs it.

```sh
homerun                     # scan, show the plan, ask, push
homerun --dry-run           # show the plan and exit, never prompts or writes
homerun --yes               # skip the prompt
homerun --repo my-app       # limit the scan to one repository, repeatable
```

Tracking repositories:

```sh
homerun add .                       # track the repository in this folder
homerun add ~/Developer --recursive # walk the tree, track every repository found
homerun list                        # show what is tracked
homerun rm .                        # stop tracking, by id, path, or "."
```

`add --recursive` also purges tracked repositories whose path has gone and drops
duplicate entries as it goes.

Per-repository options are set when adding, and re-adding a tracked repository
keeps what you already set unless you pass the flag again:

```sh
homerun add . --main true           # allow pushing main and master
homerun add . --wip-name PARKED     # prefix for this repository's WIP commits
```

Folders to skip while scanning:

```sh
homerun ignore add node_modules Pods
homerun ignore rm Pods
homerun ignore list
```

Config-wide settings and tidying up:

```sh
homerun config main true            # allow main and master for the current repository
homerun config wip-name PARKED      # default WIP commit prefix
homerun clean --missing             # forget repositories whose path has gone
homerun clean --duplicates          # keep one entry per repository
homerun clean --all --yes           # forget everything, no prompt
```

Configuration lives in `~/.config/homerun/config.json`.

## The macOS app

A SwiftUI app built around the same job, with the state the CLI cannot show you
between runs. It opens on **Today** and has **Repositories**, **GitHub
Accounts**, **Cleaner** and **Settings** beside it.

**Today** is the dashboard: what has work only on this Mac, what has a sync
problem, what is genuinely ready to resume, and what is not cloned here. You can
review and sync everything from one place.

**Repositories** lists what is tracked with each one's branch, local changes and
ahead/behind counts, filterable by dirty, clean, ahead, behind or failed. Add one
with the folder picker or by dropping it on the window; drop a folder that is not
itself a repository and it offers to search inside it. The detail pane shows the
working tree, recent commits, and per-repository settings.

**Syncing** makes a timestamped WIP commit from tracked changes, including
deletions, and pushes the current branch. Untracked files are listed but never
committed unless you tick them, and ignored files are never touched. It shows
the plan before it does anything, unless you turn confirmation off. A diverged
branch is reported, never force-pushed; other branches, unpushed tags and
submodule changes are reported rather than acted on.

**Readiness checks** separate "the current branch is pushed" from "this project
could actually be picked up elsewhere", and explain each thing in the way: local
only branches, unpushed tags, submodules needing attention, missing setup
instructions, missing configuration templates, and the environment variables the
other Mac will need. Variable names travel, values never do.

**Portable workspace** writes the shared parts — repository URLs, preferred
relative paths, setup requirements — to a versioned JSON manifest. Load it on
another Mac, preview what it would clone, and apply it. Each Mac keeps its own
workspace root, so the layout does not have to match.

**Resume** prepares a Mac to continue: clone what is missing, fast-forward what
is safe, check out the branch the previous Mac was left on, and flag anything
with local changes or divergence instead of touching it.

**GitHub Accounts** lists the accounts `gh` is signed in to, lets a repository
prefer one, and can retry a refused push with the others — always putting the
account that was active back afterwards, including when every retry failed. It
says so plainly when a repository pushes over SSH, where switching accounts
changes nothing.

**Cleaner** shows what simulator runtimes and Derived Data are costing you and
removes what you select. It refuses anything inside an Xcode installation, the
command line tools or the shared SDK folder.

A menu bar item carries the status, how many repositories have work only on this
Mac, and quick access to review, sync and resume.

`git` is required. `gh` is optional: without it ordinary git sync still works
through your existing git authentication, and only the account features are
withheld.

## Repository layout

```
cli/         the homerun command line tool, a Swift package
desktop/     the macOS app, an Xcode project
docs/        architecture templates and planning notes
impliment.yaml  the V1 specification the macOS app was built against
```

## Building and testing

The command line tool:

```sh
cd cli
swift build
swift test
```

The macOS app:

```sh
cd desktop
xcodebuild -project homerun-app.xcodeproj -scheme homerun-app -destination 'platform=macOS' build
xcodebuild -project homerun-app.xcodeproj -scheme homerun-app -destination 'platform=macOS' test
```

The app needs Xcode 26 or newer. There are no UI tests by design; the behaviour
lives in the domain, data and service layers and is tested there, including a
set of tests that drive real `git` against a repository and bare remote created
in a temporary folder.

## Architecture

[`docs/architecture.md`](docs/architecture.md) describes how the macOS app is put
together and why — the layers, the protocol seams, the two stores, and the
constraints that are deliberate.

Read [`docs/templates/README.md`](docs/templates/README.md) before adding to the
macOS app. It is the contract the code follows, not a suggestion: layers run
Domain ← Data ← Services ← Presentation, state lives in `@MainActor @Observable`
services rather than view models, each service exposes one derived `loadState`
the views switch on exhaustively, decisions a view makes are pure use cases that
can be tested without launching the app, and concurrency is Swift Concurrency
only.

Shared workspace membership and app preferences are held in SwiftData. Anything
specific to one machine — absolute paths, which repositories are cloned here,
tool locations, the workspace root, the menu bar preference — is kept in
`UserDefaults` so it never travels.

## Known gaps

A few things are deliberate, or known and not yet done:

- **iCloud sync is written but switched off.** The SwiftData models are
  CloudKit-safe and the container asks for a private database when the
  `HRCloudKitContainerIdentifier` Info.plist key is present. The key is unset,
  because turning it on needs a development team and a registered iCloud
  container. Until then the app uses a local store.
- **The app sandbox is off.** It shells out to `git`, `gh`, `osascript` and
  `xcrun`, and reads repositories anywhere on disk, which a sandboxed app cannot
  do.
- **CI does not currently run.** Both GitHub workflows call `swift build` and
  `swift test` from the repository root, where there is no `Package.swift` since
  the tool moved into `cli/`. They need a `working-directory: cli`.
- **The app loads repositories one at a time** when it starts. Adding and
  removing are immediate, but the initial read will get slower as the list
  grows.

## Licence

MIT. See [LICENSE](LICENSE).
