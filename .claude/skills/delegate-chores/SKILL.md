---
name: delegate-chores
description: Use on Roamio before pushing a branch, opening a PR, updating a PR branch, pulling data or logs, running a test suite, building a test APK, searching widely, taking screenshots, syncing docs or making a mechanical edit across files. Hands these chores to a cheaper model in a separate session, with guardrails that prove the chore finished.
---

# Delegate chores to a cheaper session

The main session keeps the thinking; chores go to a cheaper model in their own session (owner, 2026-10-31).

## What goes where

**Haiku** (`claude-haiku-5-5`, medium effort): mechanical, with a clear pass or fail.
- Push a committed branch; open a PR from a written title and body.
- `gh pr update-branch`, then report the new CI result.
- Pull logs, run lists or data into a file, with a summary.
- Run format, analyze, app tests, backend lint or backend tests.
- Run `tool/e2e.sh` and report which journeys failed, with each error.
- Read CI and nightly results and list what's red.
- Build a test APK and upload it to a private draft release, once the owner has asked for one.
- List merged branches, old worktrees and old draft releases. Deleting any of them needs the owner's OK and stays in the main session.

**Sonnet** (`claude-sonnet-5-5`, medium effort): routine, but needs some reading.
- Answer "where is this used?" across many files.
- Capture app screens with the existing script and flag obvious layout problems.
- Bring the handover, task list and device-check list in line with what was merged.
- Make a rename or wording change across files, from the exact change the main session decided.
- Read long CI logs and summarise the failure, without attempting a fix.

**Main session:**
- Deciding what to build, and how to design it.
- Code and commit contents, including the failing tests and fixes for split math, FX, security rules and consent.
- Security and privacy reviews, and working out why something failed.
- Resolving merge conflicts.
- Merging a PR the owner named by number: the permission check only accepts a merge in the session where the owner said it, so a delegated merge is refused (found on #67).
- Comparing design references with the app.
- A quick read needed for the very next decision (one `gh` or `git` command costs less here than a new session).

Deploys, releases and CI changes aren't chores. They need the owner's approval first, and then stay in the main session.

## Starting the session

Before starting, commit the work and note the exact commit SHA. Then call `start_session` with:

- `initiation: "user_asked"`, `context: "fresh"`, and the `model` and `effort` above
- `use_worktree`:
  - `false` for push, PR, merge, data and status chores, so it sees this checkout's branches
  - `true`, with `source_branch`, for test runs, builds, docs and edits, so they can't collide with work in this checkout
- `background`: the repo (`VarunParikh/Roamio`), the branch or PR, and the rules below
- `prompt`: exact commands, the expected SHA or PR number, and what to report

One chore per session. Reuse a finished session for the next chore with `SendMessage`, rather than starting another.

Only one journey run at a time: the emulators use fixed ports on the owner's Mac. Check nothing else is running it first.

If the start is refused, because this turn came from a background event rather than the owner, propose it with `initiation: "own_initiative"` so it shows as a card to tap. Do not quietly do the chore here unless the owner says so.

## Rules to paste into every brief

```
You do one mechanical chore. You don't decide, fix or improve anything.
- Run only the commands in this brief. Don't edit, stage or commit files, or switch branches.
- Never: force-push, rebase, reset, delete a branch or release, use --no-verify or --admin, enable auto-merge, or change settings.
- Before acting, check the expected state below. If it differs, stop and report.
- If a command fails, you may retry once only for a network error. Otherwise stop and report the exact error.
- Don't print or save secrets, tokens, `.env` contents or `google-services.json`.
- Finish with: what you ran, the proof asked for, and anything unexpected. Say plainly if it isn't done.
```

For a docs or mechanical-edit chore, replace the "Don't edit" rule with:

```
- Edit only the files named in this brief, and only as described. Commit on your own worktree branch. Don't push.
```

The main session reads that session's whole diff, and brings it into its own branch only if the diff matches the brief.

## Chore commands and proof

**Push**
- Check: `git rev-parse refs/heads/<branch>` equals the SHA.
- Run: `git push -u origin refs/heads/<branch>:refs/heads/<branch>`
- Proof: `git ls-remote origin refs/heads/<branch>` shows the same SHA.

**Open a PR**
- Pass title and body from a file, ending with the attribution line from the session reminder.
- Run: `gh pr create --repo VarunParikh/Roamio --base main --head <branch> --title "<title>" --body-file <file>`
- Proof: the PR URL, and `gh pr view <url> --json headRefOid` shows the SHA.

**Merge** (main session only, in the same session the owner named the number; one PR per request)
- Check: `gh pr view N --repo VarunParikh/Roamio --json state,mergeable,headRefOid,statusCheckRollup`. It must be open and mergeable, with the expected SHA and every check successful.
- If another PR is stacked on it, retarget that PR to `main` first.
- Run: `gh pr merge N --repo VarunParikh/Roamio --squash --match-head-commit <sha>`
- Proof: `gh pr view N --repo VarunParikh/Roamio --json state,mergeCommit` shows `MERGED`.
- If anything is red, pending or conflicted: don't merge. Report it.

**Update a PR branch**
- Run: `gh pr update-branch N --repo VarunParikh/Roamio`
- Proof: the new head SHA and each check's result. Don't poll in a loop; report what's there.

**Pull data**
- Read-only commands only. Save to the scratch path given in the brief.
- Proof: the file path, row or line count, and a sample with no personal data.

**Run checks** (commands from `CLAUDE.md`; run `fvm flutter pub get` or `npm ci` first in a new worktree)
- Check: `git rev-parse HEAD` equals the SHA.
- Proof: each command's exit code and final summary line (test counts included). For a failure, the failing test names and their error text.
- Never skip, delete or edit a test, and don't try to fix a failure. A journey that fails is reported as failed, even if a re-run passes.

**Build a test APK** (only when the owner asked; the brief quotes them)
- Run the build command in the brief, then `gh release create <tag> --repo VarunParikh/Roamio --draft --title "<title>" <apk>`.
- Proof: `gh release view <tag> --repo VarunParikh/Roamio --json isDraft,assets` shows `isDraft: true` and the APK's name and size. If it isn't a draft, report it at once.

**Status and clean-up lists**
- Read-only. Proof: the command used and the list, with dates.

**Search, screenshots and log summaries** (Sonnet)
- Read-only for project files. Screenshots stay in the git-excluded `screenshots/` folder.
- Proof: file and line references, image paths, or the exact log lines each claim rests on. Mark anything unsure as unsure.

**Docs and mechanical edits** (Sonnet)
- Proof: the commit SHA, `git diff --stat`, and format, analyze and tests still passing if code changed.

## After it reports

A session's report is a claim, not proof. Before telling the owner a chore is done, the main session re-runs the proof command itself, or reads the file. If the proof fails, the main session works out why. It doesn't send the same chore again unchanged.

Never start the next step that depends on a chore until its proof has passed.
