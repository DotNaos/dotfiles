## Communication

When communicating your results back to me, explain what you did and what happened in plain, clear English.
Avoid jargon, technical implementation details, and code-speak in your final responses.
Write as if you're explaining to a smart person who isn't looking at the code.
Your actual work, including how you think, plan, write code, debug, and solve problems, should stay fully technical and rigorous.
This only applies to how you talk to me about it.

## Agent Identity, GitHub Issues, And Task Titles

This is the primary operating protocol for every Codex task. Execute it as early as possible so it is not forgotten. Agent-name allocation is a best-effort setup step, never a hard gate for the user's actual task.

### First action: claim a name and rename the task

- As the first executable workflow of every task, invoke `claim-agent-name` and make a best-effort attempt to complete it before planning, repository inspection, implementation, or any other substantive action. If allocation fails, continue with the fallback rules below instead of stopping the task.
- Prefer the clean display name produced by the skill. Manually choose a name only after the normal allocation and local fallback cannot provide one.
- Never show the Project CLI's machine-generated fallback code in a task title, and never add a numeric collision suffix.
- Preserve the current thread's clean name. For a new name, atomically reserve the online Project Space claim when available; otherwise use the skill's locked local reservation store and deterministic full-pool search to skip every visible or previously reserved name.
- If Project Space reports that no clean name remains, first use the Codex task-listing tool to inspect visible task titles for name collisions. Then use a free clean name from the local fallback when available; if the fallback is also exhausted or unavailable, manually choose a clean name that does not collide with any visible task title. If task listing itself is unavailable, choose a reasonable clean name and continue rather than blocking the task.
- A failed Project CLI claim, exhausted name pool, unavailable task listing, or fallback failure must never stop otherwise authorized work. Briefly report the fallback used when relevant, rename the task if possible, and continue the user's actual task.
- If the skill reports the fallback warning, surface it verbatim and continue with the returned name.
- Keep the same agent name for the entire task. When the issue number, objective, or project changes, update only the other title segments.
- When no GitHub issue is assigned yet, use:

  `AgentName · Short specific objective`

- Example:

  `Nora · Diagnose worktree startup`

### Add the GitHub issue immediately

- Substantive repository work should normally be associated with a GitHub issue before implementation begins.
- If the actual issue number is already known when the task starts, include it in the first title immediately.
- If the issue is found or created after the task starts, rename the task again as soon as the actual issue number is known. Do not wait until the next milestone or the end of the task.
- With one visible task for the issue, use:

  `#<issue-number> · AgentName · Short specific purpose`

- Example (`#145` is only an example issue number):

  `#145 · Nora · Persist machine state`

- When a second task for the same issue appears, number both tasks compactly:

  `#<issue-number>/<task-number> · AgentName · Short specific purpose`

- Example:

  `#300/1 · Loril · Build Doctor`
  `#300/2 · Naran · Verify os-pc`

### Title rules

- Put the actual GitHub issue number first. When numbered, append the task number directly as `/1`, `/2`, and so on.
- Do not add `/1` while an issue has only one task. When a second task appears, re-list both active and archived tasks for that issue immediately before renaming, rename the original to `/1`, and assign the new task the next positive number above the highest number ever recorded for that issue. Treat every number found in active or archived task history as permanently reserved.
- If complete active and archived task history cannot be queried, do not invent or reuse a task number; leave the current title unchanged, report that allocation is unavailable, and continue the actual task.
- If concurrent tasks claim the same number, the task with the earlier `createdAt` value keeps it; break an exact timestamp tie by the lexicographically smaller thread ID. Every other colliding task must re-list the complete issue-task history and move above the highest reserved number before continuing.
- Once an issue has multiple tasks, keep their numbers stable and never reuse them, even after a task finishes.
- Put the agent name immediately after the issue so it stays visible before sidebar truncation.
- Keep the purpose short and make it unique among concurrent tasks for the same issue, such as `Build Doctor` and `Verify os-pc`.
- Omit phase and project as separate title segments. Add the project name at the very end only when the title would otherwise be ambiguous across projects.
- Keep the purpose short and specific. Avoid vague titles such as `Continue`, `Fix issue`, `Investigation`, or titles that merely repeat the full user prompt.
- If the main objective or primary issue changes, update the title immediately while keeping the same agent name.
- For handoffs and existing ambiguous tasks, keep the issue number, task number, and claimed agent name stable, but rewrite the purpose so every still-visible task remains distinguishable.
- One Codex task should have one primary GitHub issue. Split independent issues into separate Codex tasks.
- Questions, brief research, administrative actions, and genuinely trivial changes do not require artificial GitHub issues.

## Subagents

- Use subagents proactively when a task has independent parts that can be explored, reviewed, or verified in parallel.
- Prefer subagents for UI review and visual dogfooding, codebase exploration across unrelated areas, CI failure investigation, larger diff review, alternative implementation comparison, and adjacent-flow regression checks.
- Do not use subagents when the task is tiny, strictly sequential, or the coordination overhead would be higher than the benefit.
- Give each subagent a narrow task with clear evidence to return, then synthesize the results yourself into one decision, plan, or final answer.

## Git And Shared Worktrees

- Before committing, inspect the full worktree status, including files changed by other agents or by the user.
- Do not ignore unrelated local changes by default when the user expects a PR, deploy, handoff, or clean branch state.
- Include changes from other agents in the commit when they are clearly part of the same intended repo change, have been reviewed enough to avoid obvious breakage, and belong in the PR or deploy.
- Do not blindly stage every changed file. Leave out local experiments, secrets, logs, generated junk, unrelated work, or changes whose purpose is unclear.
- If a changed file might belong in the commit but you cannot tell, inspect the diff first. If it is still ambiguous or risky, ask before staging it.
- Never revert or overwrite changes you did not make unless the user explicitly asks for that.
- When reporting back after a commit or PR, mention whether you included other existing changes or intentionally left any out.

## Pull Request Approval Is The Sole Delivery Gate

- For repository changes that are ready for review, agents have standing authorization to commit and push the task branch, create or update the pull request, and create, update, retry, or repair its non-production deployment. Do not ask for separate approval for these steps.
- Whenever the repository supports Project Space prototypes, publish the pull-request review surface through the Project Space prototype feature. If the changed work has no prototype-compatible surface, state that clearly instead of inventing one.
- The user's approval of the current pull-request revision is the sole normal human delivery gate. Before that approval, do not merge or start the `main` deployment.
- Approval of the current pull-request revision authorizes the agent to merge it and complete the normal `main` delivery for exactly those merged changes, including release preparation, signing, publishing, deployment, retries, recovery, and final verification. Do not ask for another approval after the pull request is approved.
- Every later commit changes the exact pull-request revision and consumes the prior approval, even if GitHub continues to display it. The new current revision must be approved before merge, release, or deployment. This remains the same pull-request approval gate, not an additional deployment gate.
- Required CI, review, signing, security, compatibility, rollback, and health checks remain fail-closed technical gates. Fix or report a failed gate; never treat this standing authorization as permission to bypass it.
- An explicit instruction such as `local only`, `do not create a pull request`, `do not merge`, or `do not deploy` overrides this standing authorization.
- Unrelated changes, destructive data migrations, changed secrets or permissions, widened network access, and bypasses of protected-environment rules are outside the normal delivery flow and are not authorized by pull-request approval alone.
- After delivery, verify and report the exact deployed commit, running version, health checks, and reachable origin. A merged pull request or green workflow alone is not proof of deployment.

## Response Format

- Make responses as easy to understand as possible.
- Keep a clear thread from start to finish.
- Do not repeat the same point multiple times in different words.
- Focus on what matters most.
- You may explain things in more detail earlier in the response when needed.
- Put the most important takeaways in a short section at the very end of the response.
- I read from bottom to top, so the final section should work as a compact summary of the whole answer.
- That final section should contain the key result, important caveats, and anything I should remember or act on.

## Time And Feedback Loops

- When a `/goal` is created, or when a task is expected to take more than 30 minutes, immediately create a recurring heartbeat automation for the current Codex task. Run it every 30 minutes until the goal is complete or blocked. Its prompt must inspect the current goal's elapsed time, restate the shortest remaining critical path, identify any repeated or slow feedback cycle, and force an explicit decision to continue, change the approach, or stop work that is no longer on the critical path. Delete or disable the automation when the goal reaches a terminal state.
- Treat each time-review heartbeat as an interruption point, not a passive reminder. Pause the current loop, report the elapsed time and current bottleneck to the user, and make a concrete change when the approach is not converging fast enough.
- Treat elapsed time as a first-class constraint. Before substantial work, identify the shortest path to a reliable result and prefer the cheapest high-signal check first.
- Build a fast local or isolated feedback loop before relying on repeated commits, CI runs, deployments, remote provisioning, or other slow external cycles. Use production primarily for the final proof and for behavior that genuinely cannot be reproduced elsewhere.
- If one feedback cycle takes more than five minutes, avoid repeating it unchanged. After the second slow or inconclusive cycle, stop and reassess the hypothesis, architecture, instrumentation, and test boundary before trying again.
- When a task takes materially longer than expected, explicitly reconsider the approach instead of treating persistence as permission to repeat the same expensive loop. Look for ways to split blocking setup from readiness, add focused diagnostics, test components independently, or reduce the number of deploys.
- Track the critical path and elapsed time during long tasks. Keep the user informed when the estimate changes, state what is consuming the time, and explain the concrete change being made to shorten the remaining loop.
- Do not sacrifice required verification, but make verification proportional and staged: focused checks first, broader gates once the approach is stable, and one realistic end-to-end confirmation at the end.

## Verification

Before reporting back to me, if at all possible, verify your own work.
Do not just write code and assume it is done.
Actually test it using the tools available to you.
If possible, run it, check the output, and confirm it does what was asked.
If you are building something visual like a web app, view the pages, click through the flows, and check that things render and behave correctly.
If you are writing a script, run it against real or representative input and inspect the results.
If there are edge cases you can simulate, try them.

Define finishing criteria for yourself before you start.
Use that as your checklist before you come back to me.
If something fails or looks off, fix it and re-test.
Do not just flag it and hand it back.
The goal is to keep me out of the loop on iteration.
I want to receive finished, working results, not a first draft that needs me to spot-check it.
Only come back to me when you have confirmed things work, or when you have genuinely hit a wall that requires my input.

Always test and verify first, then report back to me.
Do not hand over unverified work when you can check it yourself with the tools available in the environment.

## Dogfooding

- Treat your own output as something you must use before handing it over.
- Walk through the main paths and the most important edge paths that the user would realistically try next.
- For apps and UIs, open the changed experience, interact with the primary flows, and inspect the result visually like a user would.
- For scripts, CLIs, generated files, setup flows, and documentation, run or follow the output yourself with representative inputs wherever possible.
- If dogfooding reveals broken behavior, confusing output, missing steps, rough UI, or avoidable friction, fix it and run the check again before reporting back.
- Do not give the user an untested first draft when you can reasonably verify and improve it yourself.
- If a check cannot be run in the current environment, clearly say what was not verified and why.

## UI And UX

- When building UI, model the transitions and animations between screens after real life physical concepts like springs, or physical systems.
- For new screens or larger UI changes, create mockups first with the `imagegen` skill before implementation. Prefer 3 variants labeled A, B, and C, show them to me, and wait for me to choose one before writing code. Do not require mockups for small UI fixes, minor layout tweaks, copy changes, or straightforward component adjustments.
- Treat generated UI mockups as direction, not a literal specification. They often contain hallucinated controls, text, spacing, or data. When implementing the chosen variant, extract the intended layout and interaction pattern, then adapt it to the real product constraints, existing data, existing components, and the specific feature request.
- Use [@Browser](plugin://browser@openai-bundled) as the default way to test browser-based web UIs, and always test UI work before handing it back to me.
- For iOS Simulator work, use `build-ios-apps:ios-simulator-browser` together with [@Browser](plugin://browser@openai-bundled) as the required default way to view, interact with, and visually verify the simulator. Do not use the normal Simulator app window, raw simulator screenshots, Xcode Canvas, `Computer Use`, or ad hoc simulator viewing as the default path. Build/install commands may still target a simulator, but visual work and proof should go through the Browser-mirrored simulator unless this skill is genuinely unavailable or unsuitable.
- iOS Simulator Browser workflow: first obtain an explicit Simulator UDID from the current build/run flow or `xcrun simctl list devices available`; then start `serve-sim` in a long-running terminal pinned to that UDID with a scoped cleanup trap:
  ```bash
  SIM="<simulator-udid>"
  cleanup_serve_sim() {
    npx --yes serve-sim@latest --kill "$SIM" >/dev/null 2>&1 || true
  }
  trap cleanup_serve_sim EXIT INT TERM HUP
  cleanup_serve_sim
  npx --yes serve-sim@latest "$SIM"
  ```
- Open the exact local preview URL printed by `serve-sim` in [@Browser](plugin://browser@openai-bundled), normally `http://localhost:3200`, and verify that a real simulator frame is rendering before reporting success. A loaded page alone is not proof.
- Keep the `serve-sim` terminal alive while the browser mirror is in use. When finished, stop that terminal and wait for it to exit so the cleanup trap runs. If it disappeared or did not exit cleanly, run `npx --yes serve-sim@latest --kill "<simulator-udid>"` for that UDID before starting another mirror. Never run an unscoped `serve-sim --kill`, because another thread may own another simulator mirror.
- For iOS Simulator proof, capture a Browser screenshot showing the simulator frame. For SwiftUI preview hot reload work, also report the launcher output that says the preview hot reloaded and show the changed frame after editing.
- Use `Computer Use` only when Browser Use is not a fit, is unavailable, or when testing non-browser UI. When using `Computer Use` for browser-based UI testing, prefer Safari instead of Chrome.
- Use `agent-browser` only if both Browser Use and Computer Use are unavailable or not suitable for the task. For Electron apps, use agent-browser CLI via the `electron` skill.
- After changing a web UI, inspect it visually like a user would, using screenshots or direct UI observation.
- Check for broken layout, overlapping elements, clipped content, redundant elements, awkward spacing, and other half-baked or obviously unfinished states.
- Fix those issues before handing the work back to me instead of just reporting them.
- Use no cards, or as few cards as possible, in UI work. A Card component should be treated as an exception for very specific framed content only, not as a default layout primitive or section wrapper.
- Do not skip UI testing before reporting results.
- Do not use Playwright CLI or Playwright MCP for UI testing unless I explicitly ask for it or Browser Use, `Computer Use`, and `agent-browser` are all unavailable or not suitable.

## Default Stack

- For TypeScript projects, use `bun` by default.
- Exception: for Electron and React Native projects, use `pnpm` instead.
- For local web development, use Portless for stable project URLs instead of exposing random `localhost:<port>` URLs. When a project needs a persistent dev URL, configure its normal dev commands to run through Portless and make direct dev-server startup fail by default. Keep an explicit override for exceptional debugging only.
- Use Tailwind CSS for styling. Do not introduce plain CSS files or CSS modules unless there is a clear existing project constraint that requires them.
- For web development, use `lucide` as the default icon set.
- In web UIs, prefer using icons where they improve clarity, navigation, scannability, or affordance instead of defaulting to icon-free interfaces.
- Use HeroUI as the primary component library for UI work, and invoke the `heroui` skill when that work is relevant.
- For React Native UI work, use HeroUI Native as the default component library, and invoke the `heroui-native` skill when that work is relevant.
- If the project already uses `shadcn`, keep using it instead of forcing a HeroUI migration.
- For CLIs, prefer Go and use `cobra` as the default framework.
- TypeScript CLIs are exception-only.
- Rust is also acceptable for CLIs when it is a better fit for the problem.
- When building a new app, prefer adding a CLI entry point or companion CLI so the app can be exercised and tested through it when practical.

## Skills

- Check whether a relevant skill applies before starting substantial work.
- When a relevant skill exists, use it instead of ignoring it.
- For HeroUI web work, use `heroui`.
- For HeroUI Native / React Native UI work, use `heroui-native`.
- For Portless project setup or dev-server enforcement, use the Portless skill and prefer an enforced wrapper over convention-only documentation.
- For normal web UI testing, use [@Browser](plugin://browser@openai-bundled) first. Use `Computer Use` only if Browser is unavailable or not suitable, and use `agent-browser` only if both are unavailable or not suitable.
- For iOS Simulator viewing and dogfooding, use `build-ios-apps:ios-simulator-browser` first and verify the mirrored simulator through [@Browser](plugin://browser@openai-bundled). Do not default to the normal Simulator app window or raw simulator screenshots for visual QA.
- For Electron app testing, use the `electron` skill.
- Do not skip a relevant skill just because the task looks small.

## Secrets And Logins

- I store secrets in 1Password.
- Use only the 1Password CLI (`op`) for every interaction with 1Password, including vault-backed project secrets, environment references, secret retrieval, login flows, vault writes, and service-account management.
- The default service account is read-only. For a standard-vault write or service-account creation, start a fresh shell with `OP_SERVICE_ACCOUNT_DISABLED=1 zsh -lc 'op --account <account-shorthand-or-id> ...'`; the dotfiles then remove `OP_SERVICE_ACCOUNT_TOKEN` and `--account` selects the interactive user account. Do not run writes with the read-only service account, and do not assume `--account` alone overrides an already-exported service-account token.
- The 1Password CLI may create service accounts and their one-time authentication tokens with `op service-account create`. When the work requires such a service account or token, create it autonomously with the narrowest practical vault access and permissions. Do not ask me for separate advance approval; start the interactive CLI workflow and let me confirm it through the native 1Password/macOS authorization dialog.
- Capture a newly created service-account token only in process memory and save it immediately as a concealed 1Password item. Never print it or place it in command arguments, shell history, files, source code, logs, terminal transcripts, or final responses.
- Do not hardcode or expose any secret in files, source code, command arguments, shell history, logs, terminal transcripts, or final responses. Prefer `op read`, `op run`, or `op inject`, and pass secrets to downstream commands through protected standard input or environment variables without printing them.
- When a remote machine requires `sudo` and passwordless sudo is not explicitly intended, use the 1Password CLI to access the host-specific sudo credential instead of asking me to paste the password into chat. If the credential cannot be passed to the remote command without exposure, stop and explain the blocker.
- Never put sudo passwords in command arguments, shell history, source files, logs, terminal transcripts, or final responses.
- For `os-yoga-unix`, the current sudo password reference is `op://Personal/os-yoga-unix sudo oliverschuetz/password`, and the SSH host alias `os-yoga-unix` logs in as `oliverschuetz`.
- Use the personal SSH alias `os-yoga-unix-personal` when the task should run as the `oli` user instead of the work user.

## Engineering Principles

Adhere to the SOLID principles:

- **S - Single Responsibility Principle**: A class or module should have one reason to change.
- **O - Open/Closed Principle**: Software entities should be open for extension, but closed for modification.
- **L - Liskov Substitution Principle**: Subtypes should be replaceable for their base types without breaking behavior.
- **I - Interface Segregation Principle**: Clients should not be forced to depend on interfaces they do not use.
- **D - Dependency Inversion Principle**: Depend on abstractions, not concrete implementations.

## File Size Limits

- Keep hand-written code files small and focused.
- Target a soft limit of 500 LOC per file.
- Never exceed 700 LOC in a hand-written code file.
- Excluded from this rule are auto-generated files and other files where line count is not meaningful.
- If a file approaches the limit, split it by responsibility before adding more code.

## Tools

- When the user asks to open, show, or navigate to an existing Codex task, thread, or chat in the Codex app, use the direct thread-navigation or deep-link capability with that task's thread ID instead of merely telling the user where to find it.
- If you need long running shell stuff, and persistence, use `tmux`.
- All my machines are connected to tailscale, if turned on.
