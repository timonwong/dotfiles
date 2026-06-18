---
name: confluence
description: "Use confluence-cli to read, search, create, update, move, delete, and convert Confluence pages and attachments from the terminal."
---

# confluence-cli Skill

Use `confluence-cli` to read, search, create, update, move, delete, and convert Confluence pages and attachments from the terminal. Prefer safe, auditable commands, use read-only mode unless a write is explicitly requested, and verify page identity before destructive or versioned operations. Prefer running the CLI directly with `npx confluence-cli` so scripts and agents do not have to assume a globally installed `confluence` binary.

## When to use

Use this skill when you need to interact with Atlassian Confluence from a shell or automation context, including:

- Searching spaces or pages.
- Reading a page by ID or URL.
- Creating or updating pages.
- Moving, deleting, or converting pages.
- Uploading, downloading, or listing attachments.
- Exporting Confluence content into markdown, storage XML, HTML, or text.
- Running Confluence operations non-interactively from an agent, CI job, or script.

Do not use this skill when:

- The user has not granted Confluence access or credentials are unavailable.
- A requested write, move, or delete operation is ambiguous.
- You only need to draft content and do not need to read or modify Confluence.

## Procedure

### 1. Confirm the task and choose the safest access mode

1. Identify whether the task is read-only or write-capable.
2. For reading, searching, exporting, or inspection, enable read-only mode whenever possible:

```sh
export CONFLUENCE_READ_ONLY=true
```

3. For create, update, move, delete, attachment upload, or other write operations:
   - Proceed only when the user explicitly requested the write.
   - Make sure `CONFLUENCE_READ_ONLY` is unset or set to `false`.
   - Verify the target page, space, parent, and title before running the write command.

### 2. Run and verify the CLI

Prefer direct execution with `npx confluence-cli` so the command works without assuming a globally installed binary:

```sh
npx confluence-cli --version
```

If you intentionally want a global install, install and verify the global binary:

```sh
npm install -g confluence-cli
confluence --version
```

If `confluence` is not found after a global install, check the global npm bin path:

```sh
npm bin -g
npm config get prefix
```

For the rest of this skill, prefer `npx confluence-cli <command>`. If the global binary is installed and intentionally used, `confluence <command>` is equivalent.

### 3. Configure authentication non-interactively

Prefer environment variables for agents and CI so no interactive prompt blocks execution.

#### Atlassian Cloud with site API token

```sh
export CONFLUENCE_DOMAIN="company.atlassian.net"
export CONFLUENCE_API_PATH="/wiki/rest/api"
export CONFLUENCE_AUTH_TYPE="basic"
export CONFLUENCE_EMAIL="user@company.com"
export CONFLUENCE_API_TOKEN="ATATT3x..."
```

#### Atlassian Cloud with scoped token, recommended for agents

Use this form for least-privilege scoped tokens:

```sh
export CONFLUENCE_DOMAIN="api.atlassian.com"
export CONFLUENCE_API_PATH="/ex/confluence/<your-cloud-id>/wiki/rest/api"
export CONFLUENCE_AUTH_TYPE="basic"
export CONFLUENCE_EMAIL="user@company.com"
export CONFLUENCE_API_TOKEN="your-scoped-token"
```

Find the Cloud ID at:

```text
https://<your-site>.atlassian.net/_edge/tenant_info
```

#### Atlassian Cloud with custom domain

For custom Cloud domains, force Cloud-style link handling:

```sh
export CONFLUENCE_FORCE_CLOUD=true
```

#### Self-hosted Confluence Server or Data Center

```sh
export CONFLUENCE_DOMAIN="confluence.example.com"
export CONFLUENCE_API_PATH="/rest/api"
export CONFLUENCE_AUTH_TYPE="bearer"
export CONFLUENCE_API_TOKEN="personal-access-token"
```

No email is needed for bearer authentication.

### 4. Understand config resolution

The CLI resolves configuration in this order:

1. Direct environment config, if both `CONFLUENCE_DOMAIN` and `CONFLUENCE_API_TOKEN` are set. In this case, config files and profiles are not consulted.
2. Otherwise, profile selection:
   1. Global `--profile <name>` flag.
   2. `CONFLUENCE_PROFILE` environment variable.
   3. `activeProfile` in `~/.confluence-cli/config.json`.
   4. `default` profile.

Use a profile when managing multiple Confluence instances:

```sh
npx confluence-cli --profile staging <command>
```

Initialize a profile non-interactively:

```sh
npx confluence-cli --profile staging init \
  --domain "company.atlassian.net" \
  --api-path "/wiki/rest/api" \
  --auth-type basic \
  --email "user@company.com" \
  --token "ATATT3x..."
```

Create a read-only profile for agents:

```sh
npx confluence-cli --profile agent init \
  --domain "company.atlassian.net" \
  --api-path "/wiki/rest/api" \
  --auth-type basic \
  --email "user@company.com" \
  --token "ATATT3x..." \
  --read-only
```

### 5. Check token scopes before attempting commands

For scoped Cloud tokens, ensure the token has the minimum required scopes.

Read-only operations:

- `read:confluence-content.all`
- `read:confluence-content.summary`
- `read:confluence-space.summary`
- `search:confluence`

Write operations:

- `write:confluence-content`
- `write:confluence-space`, if modifying spaces or space-level metadata

Attachment operations:

- `readonly:content.attachment:confluence`, for download
- `write:confluence-file`, for upload

If a command returns `401`, `403`, or an authorization error, first confirm domain, API path, auth type, and scopes before retrying.

### 6. Resolve page identifiers reliably

Most page commands accept a numeric page ID or supported URL.

Supported page ID inputs:

| Format | Example | Reliability |
|---|---|---|
| Numeric ID | `123456789` | Best |
| `?pageId=` URL | `https://company.atlassian.net/wiki/viewpage.action?pageId=123456789` | Best |
| Pretty `/pages/<id>` URL | `https://company.atlassian.net/wiki/spaces/SPACE/pages/123456789/Page+Title` | Best |
| Display URL | `https://company.atlassian.net/wiki/display/SPACE/Page+Title` | Title lookup, less reliable |

Prefer numeric IDs or URLs containing the numeric page ID. Display-style URLs perform a title-based lookup, so title encoding, duplicate titles, moved pages, or renamed pages can cause mistakes.

Examples:

```sh
npx confluence-cli read 123456789
npx confluence-cli read "https://company.atlassian.net/wiki/viewpage.action?pageId=123456789"
npx confluence-cli read "https://company.atlassian.net/wiki/spaces/MYSPACE/pages/123456789/My+Page"
```

Before any update, move, or delete, read the page first and verify it.

## Decision rules

- Prefer `npx confluence-cli <command>` in examples and automation unless the user explicitly wants a global install.
- Use read-only mode for inspection tasks and show `export CONFLUENCE_READ_ONLY=true` when giving shell setup for CI or agents.
- Do not perform writes unless the user explicitly requested a create, update, move, delete, conversion, or attachment upload.
- For destructive or location-changing operations, do not rely on title alone. Resolve to a numeric page ID or numeric-ID URL, read the page, and verify the space, title, parent, and URL before acting.
- If both `CONFLUENCE_DOMAIN` and `CONFLUENCE_API_TOKEN` are exported, explain that direct environment config wins and config files and profiles are not consulted.
- If no direct environment config is present, choose profiles in this order: `--profile <name>`, then `CONFLUENCE_PROFILE`, then `activeProfile` in `~/.confluence-cli/config.json`, then `default` profile.
- For Atlassian Cloud scoped tokens, use `CONFLUENCE_DOMAIN="api.atlassian.com"` and `CONFLUENCE_API_PATH="/ex/confluence/<your-cloud-id>/wiki/rest/api"`.
- For self-hosted Confluence Server or Data Center with a personal access token, use bearer auth with `CONFLUENCE_API_PATH="/rest/api"`, `CONFLUENCE_AUTH_TYPE="bearer"`, and `CONFLUENCE_API_TOKEN="personal-access-token"`.
- For Atlassian Cloud custom domains, add `export CONFLUENCE_FORCE_CLOUD=true` when links are being treated like Server or Data Center links.

---

<!-- nmem:skill-outcome-footer v1 -->
## Improving this skill

Nowledge Mem compiled this skill from the user's own experience. When you apply it, print one line so it keeps getting sharper (replace `<name>` with this skill's name from the frontmatter above):

    nmem-skill-used: <name>

If a step was wrong or missing, or it didn't work, also record that: call `report_skill_outcome` with `skill_id="skill_24c15f36b80c"`, `skill_version=3`, an `outcome` of `completed` / `completed_with_deviation` / `failed` / `abandoned`, and a one-line note on what was off. This is the user's own feedback loop, not telemetry.
