# specs/

**The source of truth for design.** Code implements these docs; when a decision changes, the spec
changes in the *same* commit. `plans/` is *how* we execute; `specs/` is *what* we're building.

## Convention

- One file per feature/area, numbered so `00` is the overview/architecture:
  ```
  specs/00-overview.md      # architecture, stack, milestones, invariants (start here)
  specs/01-<feature>.md
  specs/02-<feature>.md
  ```
- Per feature the flow is **discuss → spec → implement**. Don't write code for a decision that
  isn't in a spec yet.
- Mark settled decisions "locked" so agents don't relitigate them.
- List each spec with a one-line summary in `CLAUDE.md` → "Specs" so a fresh agent knows where to look.

Delete this folder (and the CLAUDE.md "Specs" section) if the project is small enough not to need
separate design docs — but keep the habit of writing decisions down *somewhere* durable.
