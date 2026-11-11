---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

If the user passes a ticket reference, fetch it from the issue tracker and state its title before starting. If the reference is ambiguous, ask.

Call the Skill tool with "tdd" where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

After verification, update each tracked issue implemented in this run. Check off verified acceptance criteria. For each unchecked criterion, add a line `- Критерий N: …` under `## Comments` with the reason and the remaining verification. Number criteria in their listed order. Set `Status: closed` if all criteria are verified or `in-progress` if any remain.

Run `code-review` with the implementation diff, issue file and verification results. Resolve findings and update the issue as needed.

Stage the issue file. From the repo root, run `./docs/agents/check-issue.ps1 -IssuePath .scratch/<feature>/issues/<issue>.md` for each issue implemented in this run. Resolve failures before committing. Include the checked issue files in the commit.

Commit your work to the current branch.
