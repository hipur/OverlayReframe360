# plans/

Active and completed **major-task** plans live here — one folder per task — using the
`planning-with-files` structure:

```
plans/<short-task-name>/
  task_plan.md   # the plan: phases + bite-sized steps (check them off as you go)
  findings.md    # what we learned while working (decisions, dead-ends, code locations)
  progress.md    # running log: done / in-progress / blockers (newest at top)
```

Copy `_template/` to start a new one:  `cp -r plans/_template plans/<short-task-name>`

## Conventions

- Start a major step by invoking the **planning-with-files** skill and keeping its files here —
  this is the **committed, team-visible** progress trail.
- **Design decisions go in the specs, not here.** `plans/` is *how we're executing*; specs are
  *what we're building*.
- Quick "where did we leave off" notes go in `.remember/` (local, gitignored), not here.
- Mark a task finished by putting `STATUS: complete` at the top of its `progress.md` (keep the
  folder for history).

See `CLAUDE.md` → "Working memory & continuity" for how this fits the overall workflow.
