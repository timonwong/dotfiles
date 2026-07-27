---
name: gitlab-cli
description: "Reference guide for GitLab CLI (`glab`) commands. Use when running `glab` commands for issues, merge requests, pipelines, releases, or CI/CD operations, or when the user asks about GitLab CLI syntax."
---

# GitLab CLI (glab) Assistant

Use this skill whenever the user mentions `glab`, GitLab CLI, or asks to run, write, debug, or explain any `glab` command. Use this skill when running or explaining GitLab CLI (`glab`) commands for issues, merge requests, pipelines, releases, repository metadata, labels, milestones, or GitLab API access. Prefer exact, copyable command shapes and include repository targeting when the command may be run outside the intended checkout.

## When to use

Use this skill when the user asks to:

- Diagnose or fix `glab` authentication, hostname, token, or configuration problems.
- List, view, create, update, close, or comment on GitLab issues.
- List, view, create, update, checkout, review, comment on, approve, close, or merge GitLab merge requests.
- Inspect, retry, cancel, or trigger CI/CD pipelines and jobs.
- Create or inspect releases and tags.
- Query labels, milestones, repositories, commits, comparisons, or other GitLab data through `glab api`.
- Run a `glab` command against a repository other than the current local checkout.
- Answer any request that includes the literal command name `glab` or asks about GitLab CLI syntax.

## Procedure

### 1. Establish target project and host before running commands

1. If the command should apply to the current checkout, run the command normally from inside that repository.
2. If the user names another project, or they are working from the wrong checkout, add the repository targeting flag:
   - `-R group/project`
   - `-R parent-group/subgroup/project`
   - `--repo parent-group/subgroup/project`
3. For self-managed GitLab instances, include the host when needed:
   - `--hostname gitlab.example.com`
4. For scripts, prefer stable machine-readable output:
   - `-F json` or `--output json`
5. Be careful with nested groups: use the full namespace path, not just the final project name.

Examples:

```bash
glab issue list -R platform/backend/api -F json
glab mr view 17 -R parent-group/subgroup/project --comments
glab pipeline run --branch release/2.1 -R parent-group/subgroup/project
```

When the user asks what repository-targeting flag to use for another project, especially under a nested group namespace, answer with `-R owner/repo` or `--repo GROUP/NAMESPACE/REPO`, using the full namespace path such as `-R GROUP/NAMESPACE/REPO`.

### 2. Diagnose authentication before changing tokens or config

If a `glab` command fails with an authentication error, the first diagnostic command is:

```bash
glab auth status
```

Use `glab auth status` before regenerating tokens, editing config, or changing remotes. It shows whether `glab` is authenticated, which host is active, and often which token or account is being used. If multiple GitLab hosts are involved, check the intended host explicitly when supported by the installed version:

```bash
glab auth status --hostname gitlab.example.com
```

### 3. Issues

Common issue commands:

```bash
glab issue list [--assignee=@me] [--label X] [--milestone X] [--closed|--all] [-F json]
glab issue view <id> --comments
glab issue create --title "Title" --description "Description" [--label X] [--assignee USER]
glab issue update <id> [--title "Title"] [--description "Description"] [--label X] [--assignee USER]
glab issue close <id>
glab issue note <id> --message "Message text"
```

When the user asks for a reusable comment command shape, preserve the placeholder:

```bash
glab issue note <id> --message "Your message here"
```

For issue 42 specifically:

```bash
glab issue note 42 --message "Your message here"
```

For issue 482 specifically, if the user asks for a command shape with a message placeholder, still show the reusable shape:

```bash
glab issue note <id> --message "Your message here"
```

Notes:

- Use `glab issue note`, not `glab issue comment`.
- Quote message text to avoid shell parsing problems.
- For long comments, consider command substitution from a file if appropriate:

```bash
glab issue note <id> --message "$(cat comment.md)"
```

### 4. Merge requests

Common merge request commands:

```bash
glab mr list [--assignee=@me] [--reviewer=@me] [--merged|--closed|--all] [--label X] [-F json]
glab mr view <id> --comments
glab mr diff <id>
glab mr create --title "Title" --description "Description" [--source-branch X] [--target-branch X] [--related-issue X]
glab mr update <id> [--title "Title"] [--description "Description"] [--label X] [--draft] [--ready]
glab mr checkout <id>
glab mr approve <id>
glab mr merge <id> [--squash] [--remove-source-branch]
glab mr close <id>
glab mr note <id> --message "Message text"
```

Reviewer versus assignee distinction:

- MRs assigned to you: `glab mr list --assignee=@me`
- MRs where you are requested as reviewer: `glab mr list --reviewer=@me`
- Script-friendly reviewer list:

```bash
glab mr list --reviewer=@me -F json
```

MR comments:

```bash
glab mr note 17 --message "Your message here"
```

#### Multiline MR descriptions

When creating or updating a merge request, pass the description as a real multiline string. Never pass the result of `JSON.stringify(description)` directly as a shell argument: shell double quotes do not turn literal `\n` into newline characters, so GitLab will display escaped newline sequences.

Prefer a heredoc, `--description-file`, or another argument-passing method that preserves actual newlines. Before submitting, verify that the description contains real line breaks, not a backslash followed by `n`.

For example, create an MR with a heredoc:

```bash
glab mr create --title "Title" --description "$(cat <<'EOF'
## Root cause

内容
EOF
)"
```

Or write the description to a temporary file and use `--description-file`:

```bash
cat > /tmp/mr-description.md <<'EOF'
## Root cause

内容
EOF
glab mr create --title "Title" --description-file /tmp/mr-description.md
```

Use the same real-multiline approach when updating an MR. Do not use:

```bash
glab mr create --description "$(JSON.stringify(description))"
```

Notes:

- Use `glab mr note`, not `glab mr comment`.
- `--reviewer=@me` is not the same as `--assignee=@me`.
- `glab mr checkout <id>` modifies the local working tree, so check for uncommitted changes first if needed.

### 5. CI/CD pipelines and jobs

Common CI/CD commands:

```bash
glab ci list [-F json]
glab ci status
glab ci view [branch]
glab ci trace <job-id>
glab pipeline run --branch <branch>
glab ci retry <job-id>
glab ci cancel pipeline <pipeline-id>
glab ci cancel job <job-id>
```

Trigger a pipeline for a branch:

```bash
glab pipeline run --branch release/2.1
```

Retrieve logs for job 98765:

```bash
glab ci trace 98765
```

Cancel a whole pipeline by id:

```bash
glab ci cancel pipeline <pipeline-id>
```

Cancel a single job by id:

```bash
glab ci cancel job <job-id>
```

Gotchas:

- Pipeline IDs and job IDs are different. Do not pass a job ID to `glab ci cancel pipeline`.
- To inspect failed-job output, use `glab ci trace <job-id>`.

### 6. Releases and tags

Common release commands:

```bash
glab release list
glab release view <tag>
glab release create <tag> --name "Release name" --notes "Release notes"
glab release delete <tag>
```

Use `glab api` when release or tag data requires an endpoint not exposed by the installed `glab` version.

### 7. GitLab API access

Use `glab api` for GitLab REST API endpoints, especially when there is no corresponding high-level command or when a precise API response is needed.

For a release summary comparing commits between two refs, use:

```bash
glab api 'projects/:id/repository/compare?from=<old>&to=<new>'
```

For example:

```bash
glab api 'projects/:id/repository/compare?from=v1.4.0&to=v1.5.0'
```

Replace `:id` with the URL-encoded project ID or project path when necessary. Keep `from=` and `to=` in the endpoint, and quote endpoints containing `&` so the shell does not interpret them as background operators.

### 8. Verify destructive or state-changing operations

Before commands that merge, close, delete, cancel, retry, or otherwise change remote state:

1. Confirm the target project, MR/issue/pipeline/job ID, and host.
2. Inspect the current state where practical.
3. Run the requested operation only after ensuring it applies to the intended resource.
4. If state may have changed in parallel, re-read live branches or resource state and complete only the remaining requested verification or action.

---

<!-- nmem:skill-outcome-footer v1 -->
## Improving this skill

Nowledge Mem compiled this skill from the user's own experience. When you apply it, print one line so it keeps getting sharper (replace `<name>` with this skill's name from the frontmatter above):

    nmem-skill-used: <name>

If a step was wrong or missing, or it didn't work, also record that: call `report_skill_outcome` with `skill_id="skill_bf96c34624db"`, `skill_version=4`, an `outcome` of `completed` / `completed_with_deviation` / `failed` / `abandoned`, and a one-line note on what was off. This is the user's own feedback loop, not telemetry.
