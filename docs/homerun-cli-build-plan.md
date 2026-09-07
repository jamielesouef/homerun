# homerun — build plan

## Context

Work-in-progress code gets stranded. You start something on one machine, leave it uncommitted or committed-but-unpushed, then sit down at a different machine and cannot reach it.

`homerun` is a macOS CLI that fixes this in one command. It reads a YAML list of repos, works out which ones hold unsaved work, shows you a coloured plan, asks once, then WIP-commits and pushes the ones that need it.

The repo is empty apart from `CLAUDE.md`, which is the specification. This plan turns that spec into a Swift 6 package. Nothing here invents behaviour the spec does not ask for.

Swift 6.4 is installed. Config path is `~/.config/homerun/config.yml` and does not exist yet.

## Facts confirmed

- `/Users/j.lesouef/Developer` is a symlink to `/Volumes/S990/Developer`. Both working directories are the same tree. Write only under `/Volumes/S990/Developer/personal/homerun`.
- `$OBSIDIAN_PLANS_DIR` resolves to `AI/plans` inside the vault.
- This document contains no literal backslash-n or backslash-t sequences, so it is safe to write through `obsidian create` with `content=`.
- No `.git` in the repo. No `git init`, no commit. Offer both as a follow-up.

## Deviations from the spec

`CLAUDE.md` names `CorvidLabs/swift-cli` for prompting, colour, and column alignment. **That dependency is dropped at your instruction.** Everything it was going to supply is a handful of lines of standard library code, and reading its source at tag `0.1.2` showed all three pieces were a poor fit anyway:

- `Prompt.confirm` does not exist. The real `Confirm` type puts the terminal in raw mode, reads a single key, and ignores anything that is not `y`/`n`/Enter — which breaks the spec's own rule that anything other than `y`/`yes` cancels. It also tears down raw mode in a detached `Task`, which can staircase the git output that prints next.
- `TerminalLayout.Table` measures raw string length, so a cell carrying ANSI escapes is measured wrong and the columns skew.
- `StyledText.render(colorMode:)` ignores its `colorMode` argument entirely — the body never reads the parameter, so asking it for plain text still returns escapes.

Replacements, all standard library:

- **Prompt** — `readLine()` behind the `Confirmer` protocol. Matches the spec's step 4 exactly, cannot hang the terminal, three lines.
- **Columns** — compute widths and pad with spaces in my own pure render function. About ten lines. This is what the spec's architecture section asks for anyway: "styling is applied at the edge, so tests assert on plain strings."
- **Colour** — about twelve lines of ANSI constants in `Style.swift` (`\u{1b}[32m` green, `[33m` yellow, `[31m` red, `[2m` dim, `[0m` reset), applied only when the colour gate is open.

`--yes` versus `--yolo`: the spec's usage block says `--yolo`, its non-TTY error message says `--yes`. **Decision: one flag, both spellings** — `@Flag(name: [.customLong("yolo"), .customLong("yes")])`. Both documents then tell the truth.

## Package layout

Single executable target, as the spec requires.

```
Package.swift
Sources/homerun/
  Homerun.swift          @main AsyncParsableCommand, flags, validate(), exit codes
  Config.swift           Config, RepoEntry, ConfigStore protocol, YamlConfigStore
  GitClient.swift        GitClient protocol, ProcessGitClient
  Scan.swift             RepoPlan, RepoStatus, scan()
  Execute.swift          RepoResult, execute()
  Render.swift           pure render(plans:) / render(results:) -> [Row]
  Style.swift            ANSI constants, colour gate, Row -> String at the edge
  Confirmer.swift        Confirmer protocol, ReadLineConfirmer
Tests/homerunTests/
  FakeGitClient.swift    fake + recorded calls
  ScanTests.swift
  ExecuteTests.swift
  ConfigTests.swift
  RenderTests.swift
```

Two dependencies, pinned:

- `apple/swift-argument-parser` `from: "1.5.0"` — the whole flag surface, one `ParsableCommand`, no subcommands
- `jpsim/Yams` `from: "6.0.0"` — YAML read and write

Nothing else. Colour, column alignment, and the prompt are standard library.

`@main struct Homerun: AsyncParsableCommand` — not a `main.swift`, because that would stop the test target doing `@testable import homerun`. If the linker objects to testing an executable target, fall back to a `HomerunKit` library plus a thin executable, and flag that as a deviation from "single executable target".

## Types

`RepoEntry` — `repoPath: String`, `wipName: String`, `main: Bool`. `Codable`, `Sendable`.

`Config` — `repos: [RepoEntry]`.

`GitClient` protocol, all `Sendable`, one method per git question the spec asks:

```
isRepo(at:) -> Bool
currentBranch(at:) throws -> String?      // nil = detached HEAD
porcelainStatus(at:) throws -> [String]   // one line per change
upstream(at:) throws -> String?           // nil = no upstream
aheadCount(at:) throws -> Int             // only called when upstream exists
stageAll(at:) throws
commit(at:message:) throws
push(at:branch:setUpstream:) throws
```

`ProcessGitClient` shells out to `git`. Three things it must get right:

- `GIT_TERMINAL_PROMPT=0` in the environment of every call, so a push that wants credentials fails fast into a red row instead of hanging.
- Read both stdout and stderr pipes to EOF **before** `waitUntilExit()`, or a chatty git deadlocks the pipe buffer.
- Non-zero exit throws an error carrying the last line of stderr — that string is what the red row prints.

`RepoStatus` enum: `.clean`, `.needsPush(changed: Int, ahead: Int?, upstream: String?)`, `.skipped(reason: String)`, `.failed(String)`.

`RepoPlan` — the entry, its status, and the action line. `RepoResult` — a plan plus its outcome. Both `Sendable`.

## Flow

`Homerun.run()`, in this exact order:

1. `validate()` rejects `--yolo` with `--dry-run`.
2. `--add-path` / `--remove-path` mutate the config and return. No scan.
3. Load config. Missing file means an empty repo list — print a hint to use `--add-path` and exit 0.
4. Apply `--repo` filter. A path not in the config is an error, exit 1.
5. Scan every repo, once. Build `[RepoPlan]`.
6. If nothing needs attention, print `Everything is pushed.` and exit 0. No prompt, TTY or not.
7. Print the plan and the count summary.
8. `--dry-run` exits 0 here.
9. `--yolo` proceeds. Otherwise, if `isatty(STDIN_FILENO) == 0`, print `Not a TTY — pass --yes to run unattended.` and exit 1.
10. Prompt through `Confirmer`. Anything but `y`/`yes` prints `Cancelled. Nothing was changed.` and exits 0.
11. Execute each pending repo. A throw is caught, recorded as `.failed`, and the loop continues.
12. Print the result rows and summary. Exit 1 if any repo failed, else 0.

Note the two different file descriptors: the TTY check is on **stdin**, the colour check is on **stdout**.

Execution per repo:

- `stageAll`, then `commit` **only if `porcelainStatus` was non-empty**. A repo that is merely ahead, or merely lacks an upstream, must skip the commit or git fails with "nothing to commit".
- Commit message: `"\(wipName): \(ISO8601 timestamp)"`.
- `push(setUpstream: upstream == nil)`. Never `--force`.

Edge cases the spec does not name, decided here:

- **Detached HEAD** — skipped row, yellow, reason `detached HEAD`.
- **Path missing, or not a git repo, at scan time** — failed row, red, and the scan continues.
- **`main: false` and branch is `main` or `master`** — skipped row, reason `on main, main: false`.
- **Result view lists only repos that were acted on** (pushed, skipped, failed), matching the spec's example. The plan view lists every repo including clean ones.

## Rendering

`Render.swift` is pure and knows nothing about colour or terminals.

`func render(plans: [RepoPlan]) -> [Row]` where `Row` is `(text: String, kind: RowKind)`. `RowKind` is `.pushed`, `.clean`, `.pending`, `.failed`.

Column widths come from the longest name and longest detail in the set, padded with spaces. Tests assert on `row.text`, which is always plain.

`Style.swift` holds the gate and the edge:

```
let colourEnabled = isatty(STDOUT_FILENO) != 0
  && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
  && ProcessInfo.processInfo.environment["TERM"] != "dumb"
```

When enabled, wrap `row.text` in the ANSI code for its kind: green pushed, dim clean, yellow pending or skipped, red failed. When disabled, print `row.text` untouched — no escapes anywhere in the output.

## Config writing

`YamlConfigStore` reads and writes with Yams. On save it creates `~/.config/homerun` if absent, and always writes the full decoded list back, so no existing entry is lost.

`--add-path` compares tilde-expanded, standardised paths to spot a duplicate, but stores the path string as the user typed it. A duplicate updates the existing entry in place. A path that is not a git repo is an error.

## Conventions

- Every `.swift` file carries the Xcode header: target `homerun`, `Created by Jamie Le Souëf on 07/09/2026.`, two spaces after `//` on that line.
- Australian spelling throughout identifiers and comments (`colourEnabled`).
- Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
- `main` is a reserved-ish name next to `@main`, so the flag is `@Option(name: .customLong("main")) var allowMain: Bool`.

## Gotchas to watch

- `@testable import homerun` on an executable target. Try it first. Fall back to a `HomerunKit` library only if `swift test` fails to link, and report that as a deviation.
- `allowMain` needs a default value or every invocation would require `--main`. `--add-path` and `--remove-path` are `String?`.
- `swift-tools-version: 6.0` puts the package in Swift 6 language mode, where concurrency violations are errors. The `-strict-concurrency=complete` flag is then redundant but is still passed, because the spec names it.
- Build the empty skeleton before any source, so a Yams-under-Swift-6 problem surfaces at step 1, not step 7.
- The TTY check is on stdin. The colour check is on stdout. Do not merge them.

## Tests

All seven cases from "Done means", every one through the fake `GitClient` — no test touches a real repo.

1. Needs-attention detection: dirty, ahead, no upstream, and clean all classify correctly.
2. `main: false` on branch `main` produces a skipped row; `main: true` does not.
3. No-upstream repo pushes with `setUpstream: true` and the branch name.
4. One repo throwing does not stop the others; its row is `.failed` and the exit code is 1.
5. Config add then remove round-trips, and unrelated entries survive both.
6. Plan rendering with colour disabled emits exactly the expected plain strings, columns aligned.
7. A `Confirmer` that returns `false` results in zero recorded calls on the fake `GitClient` — asserted against the fake's call log, not just the output.

Plus: a repo that is only ahead records no `commit` call.

## Verification

```
swift build -Xswiftc -strict-concurrency=complete 2>&1 | tee /tmp/build.log; grep -c warning /tmp/build.log
swift test
swift run homerun --dry-run
NO_COLOR=1 swift run homerun --dry-run | cat        # must be plain text
swift run homerun --dry-run | cat                   # piped, also plain
swift run homerun --yolo --dry-run                  # must error
```

The warning count must be 0. `-strict-concurrency=complete` also compiles the dependencies; if Yams emits warnings I cannot fix from here, I will report that as a blocker rather than quietly dropping the flag.

Smoke test against a real repo goes through `--dry-run` only, and against `myzsh` or another repo I did not create, so nothing is written.

## Steps

0. Save this plan to the vault: `obsidian create path="AI/plans/homerun-cli-build-plan.md" content="$(cat docs/homerun-cli-build-plan.md)" overwrite silent`. Check the output for a leading `Error:`, not the exit code.
1. `Package.swift` and the directory skeleton. Build it empty first to prove both dependencies resolve under strict concurrency.
2. `Config.swift` + `ConfigTests` — smallest self-contained slice.
3. `GitClient.swift` protocol and `ProcessGitClient`.
4. `Scan.swift` + `ScanTests`.
5. `Render.swift` + `RenderTests`.
6. `Execute.swift` + `ExecuteTests`, including the declined-write test.
7. `Style.swift`, `Confirmer.swift`, `Homerun.swift` — wire the flow and the exit codes.
8. Run the full verification block.

No `git init`, no commit. I will offer both as a follow-up.
