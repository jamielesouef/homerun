# homerun

Swift 6 CLI. Scans configured repos, plans WIP commit + push, confirms, executes.
User-facing spec (flags, config format, output examples) lives in `README.md` — it
is the source of truth for behaviour. Keep it in sync with any change here. This
file is for working on the codebase, not for describing it to a user.

## Behavioural contract

- Scan runs once. The plan (pre-confirm) and the result (post-confirm) render from
  the same scan data, so they can never disagree.
- Needs-attention = uncommitted changes, commits ahead of upstream, or no upstream
  set. `main: false` skips `main`/`master` instead.
- Nothing is written before the user confirms. Plan phase is read-only.
- `--dry-run` never prompts, never writes.
- Non-TTY stdin without `--yolo`: print the plan, exit 1, do not hang on input.
- One repo failing must not abort the others.
- Exit 0 on success/clean/cancel. Exit 1 on any failure or the non-TTY case.
- Config writes must preserve every existing entry, including ids.
- Progress narration (per-repo scan/push lines) is emitted only when stdout is a
  TTY, so piped/redirected output stays limited to plan, results, and summary.
- On an auth-failure push (permission denied / 403 / repo-not-found), retry under
  each other `gh` account and restore the original active account when done. A
  non-fast-forward or merge rejection is never an auth failure. No `gh`, or a
  single account, means the push just fails as before.

## Architecture

- Swift 6 package, single executable target `homerun`
- Strict concurrency (`complete`), zero warnings
- Platform: macOS 13+
- Git via `Process` shelling out to `git`. No libgit2.
- `gh` account switching shells out to the `gh` CLI, behind the `GitHubAuth`
  protocol so the retry path is tested with a fake, never a real `gh` login.
- `GitClient`, `ConfigStore`, `Confirmer`, and `GitHubAuth` are protocols, so
  scan/plan/push logic is testable without real repos, a TTY, or a GitHub account
- Rendering is a pure function from `[RepoPlan]`/`[RepoResult]` to lines. Styling is
  applied at the edge, so tests assert on plain strings.

### Dependencies

- `https://github.com/apple/swift-argument-parser` — the entire flag surface. One
  `ParsableCommand`, no subcommands.
- Colour, column alignment, and the prompt are hand-written stdlib code
  (`Style.swift`, `Row.swift`, `Confirmer.swift`) — no dependency for any of them.
- Config is read/written with Foundation's `JSONEncoder`/`JSONDecoder` — no YAML.

## Branching

- `feature/<name>` — new features
- `chore/<name>` — small updates
- `fix/<name>` — bug fixes

## Out of scope

- pull, merge, rebase, conflict resolution
- credential setup (switching between already-authenticated `gh` accounts is in
  scope; setting up or logging in those accounts is not)
- daemon or file-watching mode
- submodules

## Done means

- `swift build -Xswiftc -strict-concurrency=complete` is warning-free
- Unit tests cover: needs-attention detection, `main: false` skip, no-upstream
  push path, one-repo-fails-others-continue, config add/remove round-trip, plan
  rendering with colour disabled, and — via a fake `Confirmer` — that declining
  performs zero writes
- Tests use fake `GitClient`/`ConfigStore`/`GitHubAuth` — no test creates or
  mutates a real repo, config file, or `gh` login
- `gh`-switch coverage — via a fake `GitHubAuth`: auth-failure retries under
  another account and reports it, the original active account is restored, a
  non-auth failure never switches, and no handler / single account just fails

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
