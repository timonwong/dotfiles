---
name: gitlab-cli
description: "Reference guide for GitLab CLI (`glab`) commands. Use when running `glab` commands for issues, merge requests, pipelines, releases, or CI/CD operations, or when the user asks about GitLab CLI syntax."
---

# GitLab CLI (glab) Assistant

Use this skill when running or explaining GitLab CLI (`glab`) commands for issues, merge requests, pipelines, releases, repository metadata, labels, milestones, or GitLab API access. Prefer exact, copyable command shapes and include repository targeting when the command may be run outside the intended checkout.

## When to use

Use this skill when the user asks to:

- Diagnose or fix `glab` authentication, hostname, token, or configuration problems.
- List, view, create, update, close, or comment on GitLab issues.
- List, view, create, update, checkout, review, comment on, approve, close, or merge GitLab merge requests.
- Inspect, retry, cancel, or trigger CI/CD pipelines and jobs.
- Create or inspect releases and tags.
- Query labels, milestones, repositories, commits, comparisons, or other GitLab data through `glab api`.
- Run a `glab` command against a repository other than the current local checkout.

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

### 2. Diagnose authentication before changing tokens or config

If a `glab` command fails with an authentication error, the first diagnostic command is:

```bash
glab auth status
```

Use this before regenerating tokens, editing config, or changing remotes. It shows whether `glab` is authenticated, which host is active, and often which token or account is being used. If multiple GitLab hosts are involved, check the intended host explicitly when supported by the installed version:

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
- `glab ci status` usually reports the current branch's pipeline status.
- `glab ci view` may be interactive, which is useful for humans but not ideal for scripts.
- Use `glab ci list -F json` when you need to locate a pipeline id programmatically.

### 6. Releases and tags

Common release commands:

```bash
glab release list
glab release view <tag>
glab release create <tag> --notes "Release notes"
```

Create a release for tag `v2.4.0` with release notes:

```bash
glab release create v2.4.0 --notes "Release notes here"
```

Notes:

- The tag should already exist unless your `glab` version and GitLab server support creating it through the release flow.
- Quote release notes. For longer notes:

```bash
glab release create v2.4.0 --notes "$(cat RELEASE_NOTES.md)"
```

### 7. Labels, milestones, and repository info

```bash
glab label list [-F json]
glab milestone list [--state active|closed] [-F json]
glab repo view
glab repo view -R parent-group/subgroup/project
```

For repository metadata in scripts, prefer JSON output if the installed command supports it. Otherwise use `glab api` against the project endpoint.

### 8. Raw API access

Use `glab api` when the high-level `glab` subcommand does not expose the data or filter needed.

General forms:

```bash
glab api <endpoint> --method GET|POST|PUT|DELETE
glab api graphql --field query='...'
```

Project-scoped REST endpoints can usually use `projects/:id/...` where `:id` means the current project when run inside a checkout. If targeting another project, either run with `-R full/namespace/project` when supported or use the URL-encoded project path in the endpoint.

Recent commits:

```bash
glab api projects/:id/repository/commits
```

Commit comparison for a release summary:

```bash
glab api "projects/:id/repository/compare?from=<previous-tag>&to=<new-tag>"
```

Example:

```bash
glab api "projects/:id/repository/compare?from=v2.3.0&to=v2.4.0"
```

Gotchas:

- Quote API endpoints containing `?`, `&`, or shell-sensitive characters.
- For nested project paths used directly in REST URLs, URL-encode slashes as `%2F`, for example `parent%2Fsubgroup%2Fproject`.
- Prefer high-level commands for standard actions, and `glab api` for custom filters or endpoints.

## Decision rules

### Output format and automation

- If the user asks for an exact command, provide the command first in a code block.
- If the user asks for a command pattern, keep placeholders such as `<id>`, `<branch>`, `<pipeline-id>`, and `<previous-tag>` instead of substituting unrelated examples.
- If the user mentions scripting, parsing, automation, or programmatic use, include `-F json` where the subcommand supports it.
- If the user names a specific id, branch, tag, or project, include it exactly.
- If the user might be outside the target repository, mention `-R full/namespace/project` or `--repo full/namespace/project`.

### Authentication

- For any authentication failure, first run or recommend `glab auth status`.
- Do not recommend changing tokens, remotes, or config before checking authentication status.
- If multiple hosts may be configured, include the relevant `--hostname` check.

### Issue and MR comments

- Issue comments use:

```bash
glab issue note <id> --message "Your message here"
```

- Merge request comments use:

```bash
glab mr note <id> --message "Your message here"
```

- Do not substitute non-existent or ambiguous `comment` subcommands for `note`.

### Merge request filters

- To list MRs assigned to the user, use `--assignee=@me`.
- To list MRs the user is requested to review, use `--reviewer=@me`.
- For script-readable reviewer results, use:

```bash
glab mr list --reviewer=@me -F json
```

### Pipelines

- To trigger a branch pipeline, use:

```bash
glab pipeline run --branch <branch>
```

- To cancel a whole pipeline, use:

```bash
glab ci cancel pipeline <pipeline-id>
```

- To cancel only one job, use:

```bash
glab ci cancel job <job-id>
```

- Confirm whether the identifier is a pipeline id or job id before canceling.

### Release summaries

To prepare a release summary:

1. Identify the previous tag and new tag:

```bash
glab release list
```

2. Compare commits between tags:

```bash
glab api "projects/:id/repository/compare?from=<previous-tag>&to=<new-tag>"
```

3. Find merged MRs since the previous release date if needed:

```bash
glab mr list --merged --updated-after <date> -F json
```

4. Find closed issues since the previous release date if needed:

```bash
glab issue list --closed --updated-after <date> -F json
```

### Safe operation

- Commands that create, update, comment, approve, merge, retry, cancel, or release are state-changing. If the user's intent or target is ambiguous, ask for the missing id, branch, tag, or project before executing.
- Viewing, listing, diffing, and status commands are safe to run directly.
- For destructive or irreversible actions such as merging, closing, canceling production pipelines, or creating releases, restate the target if there is any ambiguity.

## Workflow patterns

### Summarize feature or epic status

1. Find related issues:

```bash
glab issue list --label <feature-label> -F json
```

2. Find related MRs:

```bash
glab mr list --label <feature-label> -F json
```

3. For open MRs, inspect the source branch and pipeline status:

```bash
glab mr view <id> -F json
glab ci status
```

4. Review changes if needed:

```bash
glab mr diff <id>
```

### Review an MR thoroughly

1. Understand context and discussion:

```bash
glab mr view <id> --comments
```

2. Inspect changes:

```bash
glab mr diff <id>
```

3. Checkout locally if code execution or deeper inspection is needed:

```bash
glab mr checkout <id>
```

4. Check CI:

```bash
glab ci status
```

5. Add feedback:

```bash
glab mr note <id> --message "Feedback here"
```

### Debug a failed pipeline

1. List recent pipelines and locate the failed pipeline id:

```bash
glab ci list -F json
```

2. Inspect the pipeline or jobs:

```bash
glab ci view
```

3. Read failed job logs:

```bash
glab ci trace <job-id>
```

4. Retry a failed job only if appropriate:

```bash
glab ci retry <job-id>
```

5. Cancel the whole bad pipeline only when the user intends to stop the pipeline, not just one job:

```bash
glab ci cancel pipeline <pipeline-id>
```

### Triage my work

```bash
glab issue list --assignee=@me -F json
glab mr list --assignee=@me -F json
glab mr list --reviewer=@me -F json
```

### Review tickets against the codebase

1. List relevant issues:

```bash
glab issue list --assignee=@me -F json
```

2. Search git history for the issue reference:

```bash
git log --oneline --grep="<issue-id>"
```

3. Search merged MRs for the issue reference:

```bash
glab mr list --merged -F json
```

4. View likely matching MRs or issues before updating status:

```bash
glab mr view <id> --comments
glab issue view <id> --comments
```

5. Add a status comment only after confirming the correct issue:

```bash
glab issue note <id> --message "Status update here"
```

---

<!-- nmem:skill-outcome-footer v1 -->
## Improving this skill

Nowledge Mem compiled this skill from the user's own experience. When you apply it, print one line so it keeps getting sharper (replace `<name>` with this skill's name from the frontmatter above):

    nmem-skill-used: <name>

If a step was wrong or missing, or it didn't work, also record that: call `report_skill_outcome` with `skill_id="skill_bf96c34624db"`, `skill_version=2`, an `outcome` of `completed` / `completed_with_deviation` / `failed` / `abandoned`, and a one-line note on what was off. This is the user's own feedback loop, not telemetry.
