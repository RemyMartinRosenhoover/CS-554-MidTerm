# Evidence log

Concise, labeled terminal output and screenshots for every observation the assignment requires. Each file lists, at the top, exactly what it must contain; those checklists are the acceptance criteria for the task that fills it.

| File | Covers |
|---|---|
| `00-host-vm.md` | VM facts, networking mode, tool versions, where Kubernetes runs |
| `01-compose.md` | Part 2: requests from VM and host, status, logs, restart and counter |
| `02-kubernetes.md` | Part 3: image loading, two ready replicas, access through the Service, Pod replacement |
| `03-selector-break.md` | Part 4: baseline, broken selector, symptom, observations, recovery |
| `04-readiness-554.md` | CS 554: resources, readiness probe, one replica NotReady, EndpointSlices, recovery |
| `screenshots/` | Images referenced from the files above, named by file number and topic |

Format rule (from `AGENTS.md`): heading, one line of context (host / VM / cluster, date and time), then a fenced block with the command on its own line and the unedited output. Scrub only the host's hostname and username.
