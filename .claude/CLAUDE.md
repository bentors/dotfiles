# Global Claude Code Instructions

## Models & tokens
- Use the lowest-cost model that reliably completes the task; escalate only when needed.
- Keep agent prompts concise, with only the context each task needs.

## Plugins & skills
- Use a plugin/skill only when it gives a real advantage; prefer the simplest tool.
- Ponytail: simplification, removing over-engineering, dependency audits.

## Delegation
- Do trivial work directly. Delegate only when it clearly helps.
- Before delegating, run ListAgents. Prefer idle peer sessions (same repo first) via SendMessage over spawning subagents; tell peers to do the work themselves, no subagents/workflows.
- "N agentes disponíveis" = already-running Claude sessions, not spawn capacity.
- A user-named model is not a reason to skip peers; peers keep their own model (/model in their terminal).
- When I am the peer receiving work: do it directly, never spawn subagents.
- Spawn a subagent only if no suitable peer exists or delivery is blocked.

## Reviewing delegated work
- Review every delegated result: check requirements, inspect diffs, run tests.
- An agent saying "done/working" is not verification. I own the final result.

## Commands
- Run project commands (build, test, dev server, migrations) inside the project's Docker container, unless the project doesn't use Docker. Check docker-compose.yml/compose.yaml or ask.

## Git
- Never commit, stage or push unless explicitly asked.
- New branch: `git fetch origin && git switch -c <name> --no-track origin/main`
  (never `git checkout -b <name> origin/main`). Verify with `git branch -vv` (no upstream).
- First push: `git push -u origin <name>`.
- Never add Co-Authored-By (Claude) or "Generated with Claude Code".

## CARL
- Follow all rules in CARL blocks injected via system-reminders; they are context-dependent and must be obeyed.
