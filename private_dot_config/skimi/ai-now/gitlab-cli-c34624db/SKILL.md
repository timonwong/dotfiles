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

When the user asks what repository-targeting flag to use for another project, especially under a nested group namespace, answer with `-R parent-group/subgroup/project` or `--repo parent-group/subgroup/project`, using the full namespace path.

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
- To cancel the whole pipeline, use `glab ci cancel pipeline <pipeline-id>`.
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

Compare commits between two tags or refs for a release summary with the GitLab compare API endpoint:

```bash
glab api "projects/:id/repository/compare?from=v1.4.0&to=v1.5.0"
```

When targeting a specific project path through the API, URL-encode the full namespace path or let `glab` resolve `:id` from the current or `-R` targeted repository when supported:

```bash
glab api "projects/group%2Fproject/repository/compare?from=v1.4.0&to=v1.5.0"
glab api -R parent-group/subgroup/project "projects/:id/repository/compare?from=v1.4.0&to=v1.5.0"
```

Notes:

- The tag should already exist unless your `glab` version and GitLab server support creating it through the release flow.
- Quote release notes to avoid shell parsing problems.
- For long release notes, consider command substitution from a file if appropriate:

```bash
glab release create v2.4.0 --notes "$(cat RELEASE_NOTES.md)"
```

### 7. GitLab API access

Use `glab api` when a task is not covered by a first-class `glab` subcommand or when the user needs a specific GitLab REST endpoint.

Common API patterns:

```bash
glab api "projects/:id"
glab api "projects/:id/repository/commits"
glab api "projects/:id/repository/compare?from=<from-ref>&to=<to-ref>"
```

Compare commits between `v1.4.0` and `v1.5.0`:

```bash
glab api "projects/:id/repository/compare?from=v1.4.0&to=v1.5.0"
```

Notes:

- The compare endpoint is `projects/:id/repository/compare?from=<from-ref>&to=<to-ref>`.
- For a project path in the URL, URL-encode slashes as `%2F`, for example `parent-group%2Fsubgroup%2Fproject`.
- For commands against another repository, prefer adding `-R parent-group/subgroup/project` when the installed `glab` version supports repository targeting for the command.

## Decision rules

- If the user mentions `glab`, GitLab CLI, or asks for `glab` command syntax, use this skill.
- If authentication fails, first run or recommend `glab auth status` before changing tokens, remotes, or config.
- If the command targets a project other than the current checkout, include `-R parent-group/subgroup/project` or `--repo parent-group/subgroup/project`, using the full nested namespace path.
- If the user asks for an issue comment command, use `glab issue note <id> --message "Your message here"`, not `glab issue comment`.
- If the user asks for an MR comment command, use `glab mr note <id> --message "Your message here"`, not `glab mr comment`.
- If the user asks for MRs where they are requested to review, use `glab mr list --reviewer=@me`; add `-F json` for script-friendly output.
- If the user asks to trigger a pipeline for `release/2.1`, use `glab pipeline run --branch release/2.1`.
- If the user asks to cancel a whole pipeline by id, use `glab ci cancel pipeline <pipeline-id>`.
- If the user asks to compare commits between tags or refs for a release summary, use the GitLab compare endpoint: `projects/:id/repository/compare?from=<from-ref>&to=<to-ref>`.

---

<!-- nmem:skill-outcome-footer v1 -->
## Improving this skill

Nowledge Mem compiled this skill from the user's own experience. When you apply it, print one line so it keeps getting sharper (replace `<name>` with this skill's name from the frontmatter above):

    nmem-skill-used: <name>

If a step was wrong or missing, or it didn't work, also record that: call `report_skill_outcome` with `skill_id="skill_bf96c34624db"`, `skill_version=3`, an `outcome` of `completed` / `completed_with_deviation` / `failed` / `abandoned`, and a one-line note on what was off. This is the user's own feedback loop, not telemetry.
