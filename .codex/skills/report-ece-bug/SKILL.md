---
name: report-ece-bug
description: File detailed GitHub issues in the ECE project when an ECE bug, regression, hang, crash, failing build, failing test, browser/runtime deadlock, ece-serve problem, or vendored ECE integration failure is encountered while working on this project. Use when the user invokes /report-ece-bug, asks to report an ECE bug, or an investigation identifies a likely ECE-side defect that should be tracked upstream.
---

# Report ECE Bug

## Workflow

1. Confirm the problem is likely ECE-side.
   - Prefer evidence from the vendored `vendor/ece` submodule or the ECE repo itself.
   - If the failure may be application-side, state the uncertainty in the issue.
   - Do not open an issue for speculative concerns without reproducible evidence unless the user explicitly asks.

2. Gather enough evidence for another ECE session to reproduce it.
   - Exact repo and working directory used.
   - ECE commit, branch, or submodule pointer.
   - Parent app commit if the bug was found through this project.
   - Commands run, in order, from a clean or described state.
   - Expected behavior and actual behavior.
   - Full relevant error text, backtrace, hang description, CPU/process observations, browser console or DOM output, and generated artifact names/sizes.
   - Environment details that matter: OS, shell, runtime versions, browser/headless browser, ports, and whether sandbox/network approvals were involved.
   - Any workaround discovered.

3. Check for an existing matching issue before filing.
   - Use `gh issue list --repo anthonyf/ece --search "<keywords>"` when GitHub access is available.
   - If a matching open issue exists, comment there instead of creating a duplicate unless the new failure is clearly distinct.

4. Create the issue in `anthonyf/ece`.
   - Title must start with `BUG:`.
   - Keep the title specific and searchable, for example `BUG: ece-serve hangs after writing native-zone artifacts`.
   - Use `gh issue create --repo anthonyf/ece --title "BUG: ..." --body-file <temp-file>` for long reports.
   - If GitHub access is blocked, produce the exact title and body the user can file, and state that the issue was not created.

## Issue Body Template

Use this structure unless the situation calls for a small adjustment:

```markdown
## Summary
One or two sentences describing the bug and impact.

## Reproduction
1. `cd ...`
2. `...`

## Expected
What should have happened.

## Actual
What happened instead. Include exact errors, hangs, logs, backtraces, console output, status codes, or screenshots/DOM observations.

## Environment
- ECE commit:
- Parent repo/commit, if relevant:
- OS/shell:
- Runtime/browser/tool versions:

## Additional Notes
Workarounds, suspected area, artifacts generated, timing/CPU observations, and whether the issue reproduces after clean rebuilds.
```

## Quality Bar

- Be concrete: include exact commands and paths rather than summaries like "ran the tests".
- Preserve important output verbatim, but trim unrelated noise.
- Mention whether the failure reproduces from a clean retry.
- If a command hung, include how long it ran, whether files stopped growing, CPU usage if checked, and how it was interrupted.
- If browser behavior is involved, include URL, browser/headless command, visible DOM text, and relevant console errors.
- Never omit `BUG:` from the GitHub issue title.
