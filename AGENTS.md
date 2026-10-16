# Agent Instructions

## Leading words

two-way door - a decision you can walk back through: code, branches, PRs, test data, dev infra.

one-way door - one you can't: prod data, deploys to users, force-pushing a shared branch, deleting what you didn't make, a message sent to another person.

rubber stamp - a question whose only sensible answer is yes. asking it costs me a round trip and teaches nothing.

## Two-way doors swing freely

Walk through two-way doors and show me after. Stop at one-way doors; If my answer would be a rubber stamp, don't ask. If running something could answer the question, run it instead. Save questions for taste and product calls only I can make, one at a time, with your recommendation & the built in question tool in your harness. No is an acceptable answer to me too.

Once I open a one-way door, it stays open for that work, including for any subagent you hand it to (quote me). Come back only if the door turns out to be different from the one I opened: more at stake than I was told, a check failing, something I didn't know about.

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
