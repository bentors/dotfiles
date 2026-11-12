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
- Superpowers process skills only where they pay off, not the "1% rule":
  - `brainstorming` + `writing-plans` for new features or large changes;
  - `subagent-driven-development` to execute multi-task plans (see Delegation);
  - `systematic-debugging` for bugs and failing tests;
  - `test-driven-development` when changing behavior in a project with tests;
  - `verification-before-completion` before claiming anything is done.
  Trivial questions, small edits and config are done directly, without process skills.
- `run` to check UI/app changes in the real app; `frontend-design` for new UI; `claude-api` for LLM/Anthropic code.
- Worktrees (`using-git-worktrees`, EnterWorktree) only when I ask.

## Delegation
- Do trivial work directly.
- Multi-task plans: execute with subagents, model per role (see Models).
- Peer sessions (ListAgents + SendMessage) for parallel work outside the current plan (another repo or front); tell peers to do the work themselves, no subagents/workflows.
- "N agentes disponíveis" = already-running Claude sessions, not spawn capacity.
- When I am the peer receiving work: do it directly, never spawn subagents.
- Keep briefs concise and self-contained: include the Docker and Git rules below; ask back only status, commits, a one-line test summary and concerns (no full diffs).

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

## CARL
- Follow all rules in CARL blocks injected via system-reminders; they are context-dependent and must be obeyed.

## Caveman
- Caveman voice is on by default for chat replies (follow the `caveman` skill rules, including its "When to break the rules" list); no need for /caveman.
- Use normal prose for anything persisted or read by others: commits, PR titles/bodies, docs, reports, performance-review and LinkedIn/portfolio text, memory files, messages to third parties.
- Also use normal prose when asking me a question, confirming an irreversible action, giving a security warning, or when I ask for a detailed explanation.
- "stop caveman" / "normal mode" turns it off for the session.
- The caveman shrink-hook compresses Bash output. When output shows "elided (caveman)" or a `<<ccr:...>>` handle and the omitted part matters for a decision or edit, recover it with `caveman_retrieve` before acting.
- Read files I am about to edit with the Read tool, not `cat`/`sed` (Read is not compressed).
