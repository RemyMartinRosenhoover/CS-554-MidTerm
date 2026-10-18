# agents/ — process tooling, not part of the submission

This folder holds the working material used to coordinate AI coding assistants (Codex on the Windows host, Claude in a cloud workspace, and possibly Grok for review and drafting) while the project was built. Graders can ignore it entirely; nothing the assignment requires lives here.

| Path | Contents |
|---|---|
| `assignment.md` | The assignment text, copied for agent reference |
| `briefs/` | Task briefs as they were handed to an agent, archived in order |
| `reports/` | Reports an agent produced (host verification, run logs) |
| `reviews/` | Review notes on pull requests before merge |

## Protocol in one paragraph

Standing rules live in the root `AGENTS.md`. Work arrives as GitHub Issues labeled `codex`, one task each, with acceptance criteria and the evidence files the task must produce. Codex works a single issue on a `codex/<n>-<slug>` branch and opens a pull request; CI is the machine-checkable definition of done; a reviewer merges. Anything an agent could not complete is reported in the issue rather than worked around.
