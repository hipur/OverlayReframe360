---
description: End-of-session wrap-up — sync progress, specs, ponytail review, handoff, commit + push, rename
argument-hint: (no args needed)
---

Run the **end-of-session routine** (see `CLAUDE.md` → "Session end routine"). Work through these
in order, and keep it concise:

1. **Reconcile:** run `git status` and `git log --oneline -5` to see what actually changed this
   session.
2. **Active task:** if a `plans/<task>/` is in flight, update its `progress.md` (done / decisions /
   blockers, newest at top) and tick off completed steps in `task_plan.md`.
3. **Specs:** if any design decision changed this session, update the relevant `specs/*.md` so the
   specs stay the source of truth.
4. **Ponytail review:** run `/ponytail-review` on the session diff and apply its delete-list before
   committing. Skip only if the diff is docs-only.
5. **Handoff:** invoke the `remember` skill to write `.remember/remember.md` with — current state,
   the single most important **next action**, open questions, and any gotchas. Keep it tight and
   actionable.
6. **Git hygiene + commit + push + rename — do not ask for confirmation:** review the `git status` from
   step 1 and sort each new/changed path:
   - **Commit** source, specs, docs, plans, and shared config with a conventional-prefix message.
   - **Gitignore** what shouldn't be tracked — build output, dependencies, secrets/`.env`,
     local/editor files, generated artifacts — by adding it to `.gitignore`.
   - **Clean up** stray temp files.
   Then, **only if there's something meaningful to record**, commit the right files **and push to
   `origin`** (the hipur fork — never `upstream`). If the tree is clean or only has gitignored/ephemeral
   changes, say so and skip.
   Finally, **rename the session to the feature that was implemented** — a short noun-phrase from
   what actually shipped, not the first prompt.

Finish with a 3-line summary: **Did / Where we are / Next action.**
