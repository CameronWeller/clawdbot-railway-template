# Unfinished Work Tracker

Use this file to track work that was started but not completed in the same session/PR.

## How to use

- Add new items at the top of **Active Items**.
- Keep entries short and concrete so someone else can pick up quickly.
- Move completed items to **Closed Items** with the close date.
- Link related PRs/issues where possible.

## Status values

- `blocked` - cannot proceed due to dependency/access/bug outside this repo.
- `deferred` - intentionally postponed to a later PR.
- `needs-verification` - code change done, but external validation still pending.

## Active Items

_No active unfinished items._

### Entry template

```md
### UW-YYYYMMDD-01 - Short title
- Status: blocked | deferred | needs-verification
- Owner: @name
- Area: file/path/or/system
- Started: YYYY-MM-DD
- Context: one-paragraph summary of what was attempted
- Why unfinished: exact blocker or reason for deferral
- Next step: first concrete action to resume
- Depends on: issue/PR/env access/person (or "none")
- Links: PR #123, Issue #456
```

## Closed Items

_Move finished items here with resolution details._
