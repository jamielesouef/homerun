# Homerun MacOS app

# Architecture

- READ FIRST: docs/templates/README.md
- Storage: SwiftData over icloud
- Commit at each feature
- Unit test for each feature
- NO UI tests
# Screns

## Welcome screen

## Navigation Split View

### Menu
    - Today (default)
    - Repositories
    - Github Actions
    - Cleaner
    - Settings

# V1 Features


## Today Screen

### Dashboard
- Dashboard showing unfinished work, sync problems, and projects ready to resume.
- Highlight repos with work that exists only on this Mac.
- Show the last successful sync and any actions needed.
- Review and sync all repos from one place.

### Portable Workspace

- Store repository URLs, preferred relative paths, and setup metadata in a versioned manifest.
- Recreate a workspace from the manifest on another Mac.
- Keep machine-specific paths and preferences separate from shared configuration.
- Preview which repositories will be cloned or updated.
- Support a different workspace root on each Mac.

### Readiness Checks

- Distinguish successfully pushed code from a project that is fully ready to resume.
- Surface untracked files that may need to be included.
- Identify local-only branches and unpushed tags.
- Check for submodule changes that require attention.
- Flag missing setup instructions.
- Track required environment variables and local configuration templates without copying secrets.
- Explain anything that could prevent work from continuing on another Mac.

## Repositories Screen

### Repos
- List and manage all tracked repositories.
- Show each repo's branch, local changes, ahead/behind counts, and sync status.
- Filter repos by dirty, clean, ahead, behind, or failed.
- View changes and recent activity in a repository detail pane.
- Sync all repos or select specific repos.
- Preview the sync plan without making changes.
- Confirm the plan before syncing, with an optional skip-confirmation setting.
- Automatically create timestamped WIP commits for dirty repos before pushing.
- Show live progress and a summary of successful, skipped, and failed operations.

### Repository Discovery

- Add a repository using a folder picker, path, or drag and drop.
- Scan a folder recursively to discover Git repositories.
- Respect .gitignore rules and configurable ignored folder names during discovery.
- Remove missing repository entries and deduplicate the list.
- Preserve existing repository settings when adding a repo again.

### Repository Settings

- Allow or prevent syncing main and master branches per repository.
- Set a custom WIP commit prefix per repository.
- Set an app-wide default WIP commit prefix, falling back to WIP.
- Remove repositories from tracking without deleting their files.
- Manage folder names excluded from recursive discovery.
- Remove missing entries, remove duplicates, or clear all tracked repository configuration.
- Confirm destructive configuration changes before applying them.

### Resume

- Prepare another Mac to continue working.
- Identify and clone missing repositories.
- Fetch remote updates and show what changed.
- Safely fast-forward repositories when possible.
- Flag local changes and diverged branches for attention.
- Help locate and check out the branch used on the previous Mac.
- Offer to open a project after it is ready.

## GitHub Accounts

- Retry failed push authentication using other available GitHub accounts.
- Restore the previously active account after retries.
- Show account-switching progress and authentication failures.
- Associate repositories with a preferred GitHub account.
- Check account access before syncing.


## Cleaner Screen
- Show Size taken by Derived Data
- Show size taken by SDKs
- Delete Apple development SDKs
- Derived Data (from default, project or custom path)

## Settings Screen

### Settings — Today
- Choose the default repository status filter.
- Choose whether to show repositories that are clean and fully synced.

### Settings — Repos
- Require confirmation before syncing, with an option to skip confirmation.
- Set the app-wide WIP commit prefix, falling back to WIP.
- Set the default repository list sort order.

### Settings — Repository Discovery
- Manage folder names excluded from recursive discovery.
- Always respect .gitignore during recursive discovery.
- Preserve existing per-repository settings when rediscovering repositories.

### Settings — Repository Settings
- Allow or prevent syncing main and master branches per repository.
- Override the app-wide WIP commit prefix per repository.
- Remove individual repositories from tracking without deleting files.
- Provide maintenance actions to remove missing entries and duplicates.
- Provide an action to clear all tracked repository configuration.
- Always confirm destructive configuration changes.

### Settings — GitHub Accounts
- Choose a preferred GitHub account per repository.
- Enable or disable fallback to other available accounts after push authentication failures.
- Enable or disable account-access checks before syncing.
- Always restore the previously active account after fallback attempts.
- Show available accounts and their authentication status.

### Settings — Resume
- Choose whether safe fast-forward updates are preselected in the preparation plan.
- Choose whether to offer to open a project after preparation succeeds.
- Set the preferred application for opening projects.
- Always flag local changes and diverged branches before updating.

### Settings — Portable Workspace
- Select the versioned workspace manifest to use.
- Set this Mac's workspace root for cloning repositories.
- Configure preferred relative paths for repositories.
- Keep machine-specific paths and preferences local.
- Provide actions to load a manifest and preview workspace changes.

### Settings — Readiness Checks
- Configure required environment variable names per repository.
- Configure expected local configuration templates per repository.
- Set the location of setup instructions per repository.
- Always surface untracked files, local-only branches, unpushed tags, and submodule changes.
- Store requirements and template references without copying secrets.

### Settings — Cleaner
- Select Apple development SDK locations to inspect.
- Include or exclude the default Derived Data location.
- Manage project-specific and custom Derived Data paths.
- Choose the default cleanup categories shown in the review.
- Always show the exact items and estimated space recovered before deletion.
- Always require confirmation before deleting SDKs or Derived Data.

## Settings — Menu Bar
- Show or hide the menu bar item.
- Choose whether the menu bar displays a count of repositories with local-only work.
- Choose whether closing the main window keeps homerun running in the menu bar.


## Menu Bar
- Show an at-a-glance sync and readiness status.
- Display how many repositories have work only on this Mac.
- Provide quick access to review, sync, and resume.
- Surface sync failures and required actions.
- Open the full app for detailed review.
