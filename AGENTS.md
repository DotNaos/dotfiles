# Agent Instructions

## GitHub issue planning and milestones

<!-- dotnaos-issue-intake:v1 -->

Before creating an issue, inspect existing milestones, the roadmap, relevant issues, and native parent/subissue links.

- Every **new** issue must receive a milestone at creation. Use an agreed existing SemVer release milestone if the issue is planned for that release. Otherwise use an explicit `Backlog - Nicht terminiert` / `Backlog / Not scheduled` milestone. If missing, create a Backlog milestone only when authorized; if it cannot be created, report the blocker and do not file an issue without a milestone.
- Never invent release numbers, due dates or duplicate issues. Do not inherit a parent's milestone blindly: an initiative may span several releases.
- Add one existing issue type label where available: `initiative`, `feature`, `story`, `task` or `bug`. Write user stories for concrete user-facing scenarios with acceptance criteria; backend/technical work remains a task. Reuse parent/subissues and dependency links.
- Read back the created issue to verify its milestone, type and parent persisted. Repair missing metadata, otherwise report incomplete intake.
- Before implementing an unplanned issue, determine whether its target release has been agreed. Keep it in Backlog while unscheduled.
- Do not automatically bump app, CLI or package SemVer for issue creation, PRs or merges; normal development builds use commit identities, and releases are intentional.

This guidance does not authorize CI/CD changes or bypass required approvals.
