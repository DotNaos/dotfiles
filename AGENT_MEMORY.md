# Agent Memory in Codex

The shared startup rule lives in `context/base/codex/AGENTS.md` and applies to all
rendered Codex clients. It loads the versioned guide from the configured Agent
Memory service before context-dependent work. The full guide stays maintained
in Agent Memory, not duplicated here.

## Connection and scope

A ChatGPT-connected Agent Memory app can be available through Codex's app tools
without a `mcp_servers.agent-memory` entry in `config.toml`. Check the actual
client tools and a read request before adding another connection. `codex mcp list`
may omit app-provided tools, so an absent entry there alone does not show that
Agent Memory is disconnected. Codex's `features.memories` setting controls its
separate local memory feature.

Use the client's existing authorized connection. The private shared service and
a work-local service are separate scopes. Do not add a private endpoint to work
profiles, copy credentials between machines, expose a service publicly, or
create an isolated local store merely to make a connection check pass.

## Work-only isolation

`os-work` (including WSL) must not connect to `os-vps`, directly or indirectly
through a proxy, tunnel, relay, or another personal machine. Work-memory
processing, storage, indexes, and backups must stay local to the work
installation. Do not access it remotely without a new explicit user instruction.

`os-yoga` may be a private OS installation on the same physical device. Establish
its exact host identity and role independently before configuring it. Shared
hardware does not establish a shared network policy or memory scope. Do not
classify it as either a work-memory or personal-memory client merely from its
name or its relationship to `os-work`.

These are deployment and network requirements, not proof of technical
enforcement. Instruction files cannot establish firewall isolation. Verify
network restrictions and the work-local deployment only through an access path
that the user has expressly authorized.

A work machine needs its own memory system: service, data root, indexes, backups,
and access configuration. A project tag or filter inside the personal store is
not an isolation boundary. Do not register the personal memory connector in a
work profile or send work queries/context to it. If the work connection cannot
be verified, continue without memory.

Do not sync, mirror, import, or copy memories in either direction. Keep work
backup destinations and source-ingestion jobs separate from personal ones. This
includes local Codex memories and other automatic context publishers: they must
not publish work context into a personal store. Installing a bootstrap rule does
not establish that isolation; verify the actual work deployment and client
profile using an explicitly authorized access method. Do not attempt remote
access to a work machine when the user prohibits it.

## Verify each client

1. Load `memory_instructions` through that client's configured Agent Memory tool.
   Read the returned guide and keep its content version in session context.
2. Make a bounded read, such as `memory_recent` with `limit: 1`. A successful
   service health check alone does not verify a client connection.
3. If reads work but the guide tool is absent, compare the service tool catalogue
   with the client's. Refresh the connector using its normal client settings
   workflow, then reload/resume and repeat the check. Do not disconnect accounts
   or replace authentication merely to refresh a tool list.
4. If MCP is unavailable, an already-installed `agent-memory skill --json` can
   provide that installation's guide. It is not proof of a working remote
   connection or the remote guide version.
5. Report unavailable/offline clients separately. Do not infer that work-local
   installation is missing solely because remote login is unavailable.

Connection checks do not require writing memory entries or importing data.

On 2026-09-23, a fresh read-only Codex CLI session on personal `os-pc` successfully
called the app-provided `agent_memory.memory_instructions` and
`agent_memory.memory_recent` (`limit: 1`) tools. This verifies that client at that
time; it does not prove other machines or future sessions are connected. Keep the
app connection rather than adding a second local-store or guessed `os-vps` MCP
entry. To recheck in the target client, request those same two read-only calls
there and inspect their results. Do not publish returned memory contents in logs,
issues, or pull requests.

## Apply managed instructions

For a clean, reviewed checkout, the existing narrow Codex entry point is:

```sh
./scripts/link-home --only codex --dry-run
./scripts/link-home --only codex
```

This renders and links **both** `AGENTS.md` and `config.toml`. It is not an
instructions-only command. Preserve and review unrelated local changes first.

For an instructions-only update on a machine with unrelated settings changes:

1. Back up the source and resolved live `~/.codex/AGENTS.md`; compare them and
   investigate any existing difference before editing.
2. Add only the reviewed Agent Memory section to the managed source, preserving
   the machine's other instructions.
3. Render into a fresh scratch directory with the actual host context:

   ```sh
   ./scripts/render-configs --only codex --home "$HOME" --render-root /absolute/scratch/rendered
   ```

4. Verify the rendered `AGENTS.md`, then atomically replace only the resolved
   live instructions file. Keep its symlink and permissions intact. Check that
   source and live instructions agree, and that live `config.toml` is unchanged.
5. Reload/resume the client and run the connection checks above.

The render directory must be disposable: rendering recreates its `.codex`
subdirectory. Do not use the live render directory for this isolated check.
