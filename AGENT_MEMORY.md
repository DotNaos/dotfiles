# Agent Memory in Codex

The shared startup rule lives in `context/base/codex/AGENTS.md` and applies to all
rendered Codex clients. It loads the versioned guide from the configured Agent
Memory service before context-dependent work. The full guide stays maintained
in Agent Memory, not duplicated here.

## Connection and scope

A ChatGPT-connected Agent Memory app can be available through Codex's app tools
without a `mcp_servers.agent-memory` entry in `config.toml`. Check the actual
client tools and a read request before adding another connection. Codex's
`features.memories` setting controls its separate local memory feature.

Use the client's existing authorized connection. The private shared service and
a work-local service are separate scopes. Do not add a private endpoint to work
profiles, copy credentials between machines, expose a service publicly, or
create an isolated local store merely to make a connection check pass.

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
