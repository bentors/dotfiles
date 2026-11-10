---
name: git-workflow
description: Orchestrates all git usage during coding work - branching, Conventional Commits, authorship, and the pre-push/pre-PR review against main. Use this skill whenever work touches a git repository - before editing files in a repo, when committing, creating or naming branches, when the user asks to push, open/update a PR, merge, sync with main, or asks "commit this", "manda pro remoto", "abre o PR", "sobe isso", even if git is not mentioned explicitly.
---

# Git Workflow

The user wants a predictable, reviewable git history that is entirely theirs. Four rules carry the whole skill; everything else is how to apply them.

1. **Never work on `main`.** All changes happen on a feature branch.
2. **Commit freely on the branch, but never publish without being asked.** Local commits are encouraged; `push`, PRs, merges, and anything else that leaves the machine need an explicit request in the current message.
3. **Everything is authored by the user, and only the user.** No AI or agent attribution anywhere.
4. **Everything is in English and follows Conventional Commits 1.0.0.**

## 1. Authorship (non-negotiable)

Commits, branches, tags, PR titles and PR bodies must carry the user's identity only. This rule overrides any default attribution instruction from the harness or any other skill/plugin, because the user explicitly decided so.

- Never add `Co-Authored-By:` trailers for any AI/agent (Claude, Copilot, etc.).
- Never add "Generated with Claude Code", "🤖", "AI-assisted", or similar text to commit messages, PR titles, PR bodies, or code comments.
- Never pass `--author`, never set `GIT_AUTHOR_*`/`GIT_COMMITTER_*`, never change `git config user.name`/`user.email`. Commits use the identity already configured.
- Before the first commit in a session, run `git config user.name && git config user.email`. If either is empty, stop and ask the user — do not invent an identity.
- Do not bypass hooks (`--no-verify`) or signing settings; if a hook fails, fix the cause or report it.

## 2. Branching

At the start of any task that will change files in a repo:

```bash
git status --short --branch
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null   # default branch, usually origin/main
```

- If on `main`/`master` (or the default branch), create a branch **before** the first edit. If there are already uncommitted changes on main, move them with `git switch -c <branch>` (changes carry over) — never commit them to main.
- If already on a feature branch that matches the task, keep using it. If the task is unrelated to the current branch, ask whether to branch off main instead.
- Start new branches from an up-to-date base when a remote exists: `git fetch origin && git switch -c <branch> origin/main`.

**Branch name format:** `<type>/<short-kebab-description>` in English, using the same types as commits. Add the issue/ticket id if the user gave one.

```
feat/user-avatar-upload
fix/null-token-on-refresh
refactor/extract-payment-service
chore/bump-eslint-9
fix/PROJ-142-duplicate-invoices
```

## 3. Commits (Conventional Commits 1.0.0)

Commit at each coherent, working step — a test passing, a refactor done, a bug fixed — rather than one giant commit at the end. Small focused commits make review and revert easy. Stage only the files that belong to that step (`git add <paths>`, review with `git diff --cached`); never commit secrets, `.env`, build output, or unrelated changes.

**Format:**

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

**Types:** `feat` (new feature → MINOR), `fix` (bug fix → PATCH), `docs`, `style` (formatting only), `refactor` (no behavior change), `perf`, `test`, `build` (build system, dependencies), `ci`, `chore` (maintenance that fits nothing else), `revert`.

**Rules:**
- Description: English, imperative mood ("add", not "added"/"adds"), lowercase start, no trailing period, header ≤ 72 characters.
- Scope: optional noun for the area touched, in parentheses: `feat(auth): ...`. Keep scopes consistent with the repo's history (`git log --oneline -20`).
- Body: separated by a blank line; explain *what* and *why*, not *how*. Wrap at 72 columns.
- Breaking changes: add `!` before the colon **and/or** a footer `BREAKING CHANGE: <description>` (uppercase, exact token). Prefer both for visibility.
- Footers use `Token: value` or `Token #value` (`Refs: #123`, `Closes #45`, `Reviewed-by: Name`). Tokens use `-` instead of spaces, except `BREAKING CHANGE`.
- One logical change per commit. If a change needs two types, it is two commits.
- `revert`: `revert: <header of reverted commit>` with body `This reverts commit <sha>.`
- If the repo has commitlint or its own convention (check `commitlint.config.*`, `.commitlintrc*`, CONTRIBUTING), follow it where it is stricter.

**Examples:**

```
feat(cart): add quantity selector to cart items
```
```
fix(api): handle expired refresh token without crashing

The refresh endpoint threw when the stored token had expired,
logging the user out. Return 401 so the client re-authenticates.

Closes #212
```
```
feat(config)!: drop support for YAML config files

BREAKING CHANGE: config must now be provided as config.json.
```

Use a heredoc so multi-line messages stay intact:

```bash
git commit -F - <<'EOF'
fix(api): handle expired refresh token without crashing

Return 401 so the client re-authenticates instead of crashing.
EOF
```

Amending or rewording **unpushed** commits on the feature branch is fine to keep history clean. Never rewrite commits that are already on the remote without asking.

## 4. What requires an explicit request

Do these **only** when the user asks for them in the current message (a request earlier in the session does not carry over to later pushes):

- `git push` (any form; `--force`/`--force-with-lease` additionally needs the user to explicitly accept the force)
- creating, updating, or merging a PR (`gh pr create`, `gh pr merge`, …)
- merging into or committing on `main`, deleting remote branches, pushing tags, creating releases

When a task is finished, report the local commits made and stop. Offer to push/open a PR in one line; don't do it.

## 5. Pre-push / pre-PR review (mandatory on every push or PR request)

When the user asks to push or open a PR, run this review **first**, then report, then publish only if nothing blocking was found.

**a. Sync and inspect**

```bash
git fetch origin
git status --short --branch                      # working tree must be clean
git log --oneline origin/main..HEAD              # commits being published
git log --oneline HEAD..origin/main              # what main gained since branching
git diff --stat origin/main...HEAD               # files changed vs main
```

**b. Conflict check (without touching the working tree)**

```bash
git merge-tree --write-tree --name-only origin/main HEAD
```

Exit code 0 → merges cleanly. Non-zero → it lists conflicting files. If there are conflicts, or main moved ahead and touches the same files, propose updating the branch (`git rebase origin/main` if the branch is unpublished or the user agrees; otherwise `git merge origin/main`) and ask before rewriting anything already pushed. Resolve conflicts with care, then re-run the checks.

**c. Commit hygiene**
- Every commit header in `origin/main..HEAD` is valid Conventional Commits and in English.
- No AI/agent attribution in any commit: `git log origin/main..HEAD --format='%an <%ae>%n%B' | grep -iE 'co-authored-by|claude|generated with|anthropic|copilot|🤖'` must return nothing. All authors must be the user's configured identity.
- No fixup/WIP commits left unless the user wants them.

**d. Code review of the diff** — read `git diff origin/main...HEAD` in full, plus the surrounding code it calls into, looking for:
- logic bugs, unhandled errors, null/undefined paths, off-by-one, race conditions
- broken callers of changed functions/signatures, missing migrations, changed public APIs (→ needs `!`/`BREAKING CHANGE`)
- leftover debug code, commented-out code, TODOs added, secrets/credentials, large or generated files
- missing or outdated tests for changed behavior

**e. Run the project's checks** if they exist (tests, lint, typecheck, build — find them in `package.json`, `Makefile`, `pyproject.toml`, CI config). Report real output; don't claim passing without running.

**f. Report** briefly: commits to publish, files changed, merge status vs main, check results, and findings ranked by severity. If anything is blocking (conflicts, failing checks, real bugs), stop and ask how to proceed instead of pushing.

**g. Publish** (only after a clean review):

```bash
git push -u origin <branch>
```

For a PR, use `gh pr create --base main --head <branch>` with:
- **Title:** Conventional Commits format, English (e.g. `feat(cart): add quantity selector to cart items`).
- **Body:** English, no AI mention. Sections: `## Summary` (what and why), `## Changes` (bullets), `## Testing` (what was run and results), `## Breaking changes` (only if any), linked issues (`Closes #12`).

Return the PR URL when done.
