# Measure and shorten agent runtime

Measure the complete task before optimizing individual requests. A fast host call
can still be surrounded by expensive setup, planning, scheduling or reporting.

## Measurement boundaries

Use the runtime's task-start and task-complete events for total wall time. If an
independent duration field differs slightly, report both boundaries explicitly
and choose one consistently for accounting. For a running task, mark the result
incomplete rather than inventing a completion time.

Match tool calls to results by call ID. Compute the union of their wall-clock
intervals so overlapping calls count once. Keep outer orchestration intervals
separate from underlying tool intervals; never add nested durations together.
Report unmatched, failed or incomplete spans rather than treating them as zero.

Record startup before the first call, gaps between completed calls and later
dispatches, and the last-call-to-final-report window. The remaining time is
**outside tools**. It can include generation, reasoning, scheduling and context
handling; timestamps alone do not separate those components.

For a finer breakdown, group each gap by the stages on either side: identity
setup, host guides and recall, preflight, report preparation, report verification,
and final completion. These are **phase contexts**, not proof of time spent in
the named activity. Report startup separately and do not add time to first token
again if it is already inside that window. Provider response-creation timestamps
and token counts may add observational sub-boundaries; they do not independently
measure queueing, scheduling or inference time. State when those fields are absent.

Export only durations, counts, validated statuses and tool names. Keep source
inspection local to the authorized installation. Do not copy raw session logs,
conversation or reasoning text, tool arguments, outputs, live configuration,
connection details or credentials into reports or external telemetry.

## Shorten the largest waits

1. Complete required identity setup, then run independent setup and inspections
   together where supported. Preserve guide, schema and authorization decisions.
2. Read required guides completely and reuse their verified versions until a
   prescribed refresh trigger occurs.
3. Once the plan, guides and schemas are known, use an existing orchestration
   call for predictable steps. Independent hosts may run together; dependent
   writes and checks remain sequential on the exact device and session.
4. Check each result. Stop on failure, an unexpected state or uncertain effects
   unless an explicit safe branch was planned. Never automatically replay writes.
5. Return compact evidence at meaningful decision boundaries. Avoid repeated
   rediscovery, large irrelevant payloads, internal sleep loops and writing a
   separate report after every stage.
6. Reuse a reviewed recipe and compact report template for repeated fixed checks
   when available. Revalidate current inputs, guides, schemas, identity and
   authorization before executing it; prepared code never substitutes for them.
7. Reduce setup dispatches without removing setup decisions: read the identity
   skill and its permitted inventory together, then validate and complete the
   selector/rename workflow in order. Collect independent local context, memory
   guide and host discovery only after identity setup. Once those results are
   read, combine independent host guides, applicable schemas and narrow recall.
   Retain the inventory in orchestration context instead of repeatedly listing it
   after a truncated display. Identify the current task through supported metadata,
   follow real pagination, and preserve best-effort identity fallback behavior.
   Emit each required guide once in a complete representation, with a sufficient
   bounded output budget; read missing portions if output was truncated.
8. Let a fixed workflow publish and immediately verify compact reports inside the
   same awaited orchestration. Verify the canonical task-owned directory and use
   exclusive no-follow creation for new files. Refuse occupied slots, verify
   saved bytes and outcomes, and surface failures without overwriting or replaying
   a partial publication. Do not spend an extra model round repeating that check.
9. Once prerequisites have been read and verified, set the recipe inputs and run
   it in the same awaited call. A dispatch that only stores already-decided inputs
   adds a handoff without adding evidence. Keep required decision boundaries.

Keep model settings and safety handling unchanged for an initial comparison.
Changing those settings requires a separate decision and makes the original
comparison unsuitable for attributing the benefit to workflow grouping.

## Verify the improvement

Repeat the same complete workload with the same model, client, connection,
authorization settings and correctness checks. Include startup and reporting in
both variants. Report total duration, observed tool union, outside-tool time,
dispatch count and failures. Preserve exact write readbacks and independently
verified cleanup.

Use several samples when practical and acknowledge ordering, warm-state and
model-run variability. A startup failure or missing tools is an invalid
performance sample, not a successful fast run. Do not weaken safeguards or
silently change a model or route to obtain a passing result.

Persistent cross-task telemetry, UI timing breakdowns and automatic performance
audits remain separate work owned by Project Space issue #882. This protocol and
the shared workflow rules do not claim that broader feature is delivered.
