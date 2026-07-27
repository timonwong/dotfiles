---
name: jira-cli
description: "Interact with Jira from the command line to create, list, view, edit, and transition issues, manage sprints and epics, and perform common Jira workflows. Use when the user asks about Jira tasks, tickets, issues, sprints, or needs to manage project work items."
---

# Jira CLI

Interact with Atlassian Jira from the command line using [jira-cli](https://github.com/ankitpokhrel/jira-cli). Do not recommend the Jira web UI; use jira-cli where supported, and use the Jira REST API only when jira-cli does not support the requested operation.

## When to Use

- User asks to create, view, edit, search, link, clone, or delete Jira issues/tickets
- User needs to transition issues through workflow states such as To Do, In Progress, or Done
- User wants to manage sprints, epics, or boards
- User needs to assign issues, remove an assignee, add comments, edit or delete comments, or log work time
- User asks about their current tasks or sprint progress

## Prerequisites

1. Install jira-cli: `brew install ankitpokhrel/jira-cli/jira-cli` (macOS) or download from [releases](https://github.com/ankitpokhrel/jira-cli/releases).
2. Set API credentials, for example: `export JIRA_API_TOKEN="your-token"`.
3. Initialize the client with `jira init` and follow its prompts.
4. Before making a destructive or broad change, confirm the target issue keys, project, status, and account identifiers. Use `jira issue view ISSUE-123` when needed.

## Issue Commands

### List Issues

```bash
# List issues in the current project
jira issue list

# List issues assigned to the current user
jira issue list -a$(jira me)

# List issues by status
jira issue list -s"In Progress"

# List high-priority issues
jira issue list -yHigh

# List high-priority To Do issues assigned to me and created this week
jira issue list -a$(jira me) -s"To Do" -yHigh --created week

# List issues with raw JQL
jira issue list -q "project = PROJ AND status = 'In Progress'"

# Plain, machine-readable output for scripting
jira issue list --plain --columns key,summary,status --no-headers
```

Use raw JQL with `-q` when the built-in filters cannot express the user's requested search precisely. For script output, use `--plain --columns ... --no-headers` and avoid parsing decorative table output.

### Create Issues

```bash
# Interactive issue creation
jira issue create

# Create a bug without prompts
jira issue create -tBug -s"Login button not working" -b"Description here" -yHigh --no-input

# Create a story
jira issue create -tStory -s"Add user authentication" -yMedium

# Create with labels and components
jira issue create -tTask -s"Update dependencies" -lmaintenance -l"tech-debt" -Cbackend

# Create and assign to self without prompts
jira issue create -tBug -s"Fix crash on startup" -a$(jira me) --no-input

# Create using a description template read from standard input
printf '# Description\n\nDetails here.\n' | jira issue create -tTask -s"Template-backed task" --template - --no-input

# Create using a description template file
jira issue create -tTask -s"Template-backed task" --template ./issue-description.md --no-input
```

`jira issue create -b` automatically converts GitHub-Flavored Markdown (GFM) to Jira-flavored Markdown. `jira issue create --template` performs the same conversion; the two options differ only in their input source. Use `-b` for directly supplied body text, and use `--template` (spelled exactly `--template`, not `--tempalte`) with `-` to read from STDIN or with a file path to read a template file.

Use the issue type names configured in the target Jira project. When using `--no-input`, provide every required field explicitly; Jira projects can have required custom fields that are not shown in these generic examples.

### View Issues

```bash
# View issue details
jira issue view ISSUE-123

# View recent comments
jira issue view ISSUE-123 --comments 10

# View in plain text
jira issue view ISSUE-123 --plain
```

### Edit Issues

```bash
# Edit summary
jira issue edit ISSUE-123 -s"Updated summary"

# Edit description
jira issue edit ISSUE-123 -b"New description"

# Edit priority
jira issue edit ISSUE-123 -yHigh

# Add labels
jira issue edit ISSUE-123 -lnew-label
```

Check existing issue details before editing if the request could overwrite information maintained by someone else. In particular, distinguish adding a label from replacing or removing existing labels according to the CLI behavior and user intent.

### Custom Fields

Before using a custom field non-interactively, configure that field's CLI field mapping and use the configured **handle**, not the Jira display name or field key. For example, if the configured handle for the Jira field named `Story Points` is `story-points`, write it as follows:

```bash
# Set Story Points through its configured jira-cli custom-field handle
jira issue edit ISSUE-123 --custom story-points=0.1 --no-input
```

Do not use `Story Points`, `customfield_10006`, or another Jira field key in place of the configured handle. A Jira field key such as `customfield_10006` that jira-cli reports or treats as an “unconfigured custom field” can be silently ignored. This means the field was **not** written; it does not mean that the requested Story Points value is invalid.

If an interactive `jira issue edit` does not expose or retain the custom field, exit the interactive edit rather than continuing with it. First use the mapped handle with `--custom`, then read the issue back and confirm the expected value before any transition that depends on the field:

```bash
jira issue edit ISSUE-123 --custom story-points=0.1 --no-input
jira issue view ISSUE-123
```

Confirm that the returned Story Points value is `0.1`. Do not attempt a subsequent transition, such as Start, until the readback confirms the field was actually written: workflows may reject the transition when the required field remains unset.

If the field mapping cannot be configured or the mapped handle cannot be used, use the Jira REST API to write the actual Jira field key, then read it back and verify it before transitioning:

```bash
# Replace JIRA_BASE_URL, ISSUE-123, and customfield_10006 with the configured values.
curl --fail-with-body -X PUT \
  -H "Authorization: Bearer $JIRA_API_TOKEN" \
  -H "Content-Type: application/json" \
  "$JIRA_BASE_URL/rest/api/3/issue/ISSUE-123" \
  --data '{"fields":{"customfield_10006":0.1}}'

curl --fail-with-body \
  -H "Authorization: Bearer $JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/issue/ISSUE-123?fields=customfield_10006"
```

Verify that the API readback contains `customfield_10006` with the expected value before running the transition. Do not misdiagnose an unconfigured or silently ignored custom field as a problem with the Story Points value itself.

### Transition Issues

`jira issue move` is the jira-cli command for transitioning an existing issue to a workflow status. Use it whenever the user asks to start, complete, reopen, or otherwise change an issue's status. The requested status must be available as a transition for that specific issue.

```bash
# Move an issue to a new status
jira issue move ISSUE-123 "In Progress"

# Move with a comment
jira issue move ISSUE-123 "Done" --comment "Completed the task"

# Move and set resolution
jira issue move ISSUE-123 "Done" -RFixed
```

Do not assume every project has the same status names or permits the same transitions. If a move fails, inspect the issue and use an available workflow transition rather than substituting a status silently.

### Assign Issues

`jira issue assign` changes an issue's assignee. Use it for assignment, self-assignment, reassignment, and unassignment. Use `x` as the assignee value to remove the current assignee.

```bash
# Assign to self
jira issue assign ISSUE-123 $(jira me)

# Assign to a specific user
jira issue assign ISSUE-123 username

# Remove the current assignee
jira issue assign ISSUE-123 x
```

### Comments

```bash
# Add a comment
jira issue comment add ISSUE-123 "This is my comment"

# Add a comment through the editor
jira issue comment add ISSUE-123
```

Comment text, including text passed to `jira issue comment add` and transition `--comment`, is processed through jira-cli's comment Markdown conversion path. Write comment content as Markdown when formatting is needed.

Description bodies use the `-b` and `--template` description-input paths, while comment bodies use the comment-input path; these are distinct jira-cli v1.7 formatting paths. Do not assume a description template or description-body behavior applies identically to comments.

jira-cli v1.7 has no `jira issue comment edit` or `jira issue comment delete` subcommand. Do not claim that comment editing or deletion is supported by the CLI; use the Jira REST API only if the user specifically needs an operation jira-cli does not support.

### Worklogs

```bash
# Log work interactively
jira issue worklog add ISSUE-123

# Log work without opening an editor
jira issue worklog add DEV-88 "2h 30m" --comment "Implemented API pagination" --no-input
```

Use Jira duration syntax such as `30m`, `2h`, or `2h 30m`. With `--no-input`, provide the duration and any requested comment explicitly.

### Link Issues

```bash
# Create a blocking relationship from CORE-10 to CORE-11
jira issue link CORE-10 CORE-11 Blocks
```

Confirm the link type and direction before creating a relationship. Jira link names and available link types may differ by instance.

### Epics

```bash
# Add issues to an epic
jira epic add APP-7 APP-101 APP-102
```

Confirm that the target epic and issue keys are in the appropriate project and that the user intends to add all specified issues before making the change.

---

<!-- nmem:skill-outcome-footer v1 -->
## Improving this skill

Nowledge Mem compiled this skill from the user's own experience. When you apply it, print one line so it keeps getting sharper (replace `<name>` with this skill's name from the frontmatter above):

    nmem-skill-used: <name>

If a step was wrong or missing, or it didn't work, also record that: call `report_skill_outcome` with `skill_id="skill_e1bcc08b0e84"`, `skill_version=5`, an `outcome` of `completed` / `completed_with_deviation` / `failed` / `abandoned`, and a one-line note on what was off. This is the user's own feedback loop, not telemetry.
