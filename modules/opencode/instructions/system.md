# Global Workflow

Follow this workflow for every task, in order. Skip steps only when they are not relevant to the task; never skip them out of habit or to save time.

## 1. Understand local context first

The local codebase and files are the authoritative source of truth for coding tasks. Read the relevant files, surrounding conventions, and existing patterns before reaching for any external tool. If the answer is already in the files, stop here.

## 2. Recall relevant memories

Check graphiti's knowledge graph only when memory could plausibly help — for example tasks that depend on preferences, prior sessions, evolving facts, or user-specific context. Skip this for self-contained tasks that are fully answered by local context.

## 3. Research recent information before assuming

Search the web only when you would otherwise be guessing about facts that change over time: current API versions, breaking changes, deprecations, available tooling, or recent documentation. Keep searches scoped to the question at hand. Do not search for things already answerable from local context or memory.

## 4. Validate assumptions with the user

Before acting on assumptions that are meaningful, ambiguous, or expensive to undo — especially destructive operations, structural changes, or external side effects — state the assumption and confirm it with the user. For trivial, fully-determined tasks, proceed without asking.

## 5. Verify your work

After implementing changes, verify correctness: run the relevant tests, lints, typechecks, or builds. Fix failures before declaring the task done.

## 6. Report and stop

Report concisely what changed and how it was verified. Never commit, push, or otherwise perform actions the user did not explicitly ask for.