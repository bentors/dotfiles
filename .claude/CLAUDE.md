# Global Claude Code Instructions

## Precedence
- This file overrides plugin/skill instructions (superpowers, ponytail, etc.) wherever they conflict.

## Models
- Always set the model explicitly when spawning a subagent (an omitted model inherits the session's Opus).
- Opus: orchestration, planning, design decisions, final review before push/PR.
- Sonnet: implementation and fixes.
- Haiku: code search/reading and mechanical edits (renames, formatting).
- Escalate a fix to Opus after 2 failed Sonnet rounds. Otherwise use the lowest-cost model that reliably completes the task.

## Plugins & skills
- Ponytail is the default for coding tasks: smallest complete change, no over-engineering.
- Superpowers process skills are vendored as personal skills in `dotfiles/.claude/skills` (plugin disabled to drop its SessionStart injection; refresh by re-copying from upstream). Use them only where they pay off, not the "1% rule":
  - `brainstorming` + `writing-plans` for new features or large changes;
  - `subagent-driven-development` to execute multi-task plans (see Delegation);
  - `systematic-debugging` for bugs and failing tests;
  - `test-driven-development` when changing behavior in a project with tests;
  - `verification-before-completion` before claiming anything is done.
  Trivial questions, small edits and config are done directly, without process skills.
- `run` to check UI/app changes in the real app; `claude-api` for LLM/Anthropic code.
- `code-review`: default level `medium`. Use `high` only for large or risky PRs (auth, migrations, payments, infra) or when I ask; never `max`/`ultra` unless I ask.
- Worktrees (EnterWorktree) only when I ask.

## Delegation
- Do trivial work directly.
- Use the custom agents in `~/.claude/agents` for delegated work; they pin model, tools, rules and report format:
  - `implementer` (Sonnet): implementation and fixes from a brief;
  - `test-runner` (Haiku): run tests/lint/build, return only failures;
  - `code-searcher` (Haiku): read-only lookups and flow tracing;
  - `reviewer` (Opus): read-only final review before push/PR and of delegated work.
  With these, a brief only needs the task, relevant files and acceptance criteria.
- `general-purpose` (or omitting `subagent_type`) is not allowed when one of the custom agents fits. Search/read → `code-searcher`; code change → `implementer`; tests/build → `test-runner`; review → `reviewer`. Other built-ins only for work no custom agent covers, always with an explicit model (Haiku or Sonnet; Opus only for planning/design).
- Never use `subagent_type: "fork"`: a fork inherits the whole conversation and always runs on Opus. Use a fresh custom agent with a short brief instead.
- Don't spawn a subagent for what takes a few tool calls inline; each spawn re-sends a large system prompt.
- Multi-task plans: execute with subagents, model per role (see Models). In `subagent-driven-development`: implementer role → `implementer`; per-task review → `general-purpose` on Sonnet (the one allowed exception); final whole-branch review → `reviewer`.
- Peer sessions (ListAgents + SendMessage) for parallel work outside the current plan (another repo or front); tell peers to do the work themselves, no subagents/workflows.
- "N agentes disponíveis" = already-running Claude sessions, not spawn capacity.
- When I am the peer receiving work: do it directly, never spawn subagents.
- Keep briefs concise and self-contained. For agents without those rules built in (built-ins, peers), include the Docker and Git rules below and ask back only status, commits, a one-line test summary and concerns (no full diffs).

## Context hygiene
- When I switch to a task unrelated to the current session, suggest `/clear` before starting.
- At the end of a milestone (plan step done, bug fixed, feature committed) in a long session, suggest `/compact <focus>` with a concrete focus line I can paste.
- Every turn re-reads the whole context, so long sessions are the main token cost. Once a session passes ~150k tokens of context, suggest `/compact <focus>` (or `/clear` plus a short handoff) at the next natural break, even mid-task.
- Don't re-read files or re-run commands whose output is already in context; read only the line ranges you need.
- Delegate large searches, log/test-output reading and wide codebase sweeps to a subagent (`test-runner` / `code-searcher`) so the raw output stays out of the main context; ask back only the conclusion.

## Compact instructions
When compacting, preserve: the current goal and plan step, files changed (with paths), commands used to build/test, decisions made and why, open issues and next steps, branch name and commit state. Drop long tool outputs, file dumps and resolved dead ends.

## Reviewing delegated work
- Review every delegated result: check requirements, inspect diffs, run tests.
- An agent saying "done/working" is not verification. I own the final result.

## Commands
- Run project commands (build, test, dev server, migrations) inside the project's Docker container, unless the project doesn't use Docker. Check docker-compose.yml/compose.yaml or ask.

## Git
- Commits (and staging) are allowed during the work without asking.
- Never push, open PRs, merge or deploy unless explicitly asked.
- New branch: `git fetch origin && git switch -c <name> --no-track origin/main`
  (never `git checkout -b <name> origin/main`). Verify with `git branch -vv` (no upstream).
- First push: `git push -u origin <name>`.
- Never add Co-Authored-By (Claude) or "Generated with Claude Code".
- Before any push, PR or merge (including options from superpowers' `finishing-a-development-branch` menu), run the `git-workflow` pre-push review (section 5) first.
- Never commit superpowers specs/plans (`docs/superpowers/`); they are ignored globally in `~/.config/git/ignore`.

## Caveman
- Caveman voice is on by default for chat replies (follow the `caveman` skill rules, including its "When to break the rules" list); no need for /caveman.
- Use normal prose for anything persisted or read by others: commits, PR titles/bodies, docs, reports, performance-review and LinkedIn/portfolio text, memory files, messages to third parties.
- Also use normal prose when asking me a question, confirming an irreversible action, giving a security warning, or when I ask for a detailed explanation.
- "stop caveman" / "normal mode" turns it off for the session.
- The caveman shrink-hook compresses Bash output. When output shows "elided (caveman)" or a `<<ccr:...>>` handle and the omitted part matters for a decision or edit, recover it with `caveman_retrieve` before acting.
- Read files I am about to edit with the Read tool, not `cat`/`sed` (Read is not compressed).
