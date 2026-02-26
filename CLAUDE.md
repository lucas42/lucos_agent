# lucos_agent

This repo provides tooling for AI agents to interact with GitHub on the lucos infrastructure, authenticated as a lucos GitHub App rather than as a personal user. Actions taken with these credentials appear as bot accounts in the GitHub UI (e.g. `lucos-agent[bot]`).

## GitHub App details

App names are the GitHub-normalised slugs (lowercase, spaces replaced with hyphens). Pass these to `--app` in `get-token` and `gh-as-agent`.

### lucos-agent (default)

| Field | Value |
|---|---|
| Display name | `lucOS Agent` |
| App ID | `2943201` |
| Installation ID | `112266755` |
| Installed on | `lucas42` (all repos) |

The app has **Issues: Read & Write** permission. Private key stored in lucos_creds as `LUCOS_AGENT_PEM`.

### lucos-issue-manager

| Field | Value |
|---|---|
| Display name | `lucOS Issue Manager` |
| App ID | `2952357` |
| Installation ID | `112520892` |
| Installed on | `lucas42` (all repos) |

Used by the lucos-issue-manager Claude persona. The app has **Issues: Read & Write** permission. Private key stored in lucos_creds as `LUCOS_ISSUE_MANAGER_PEM`.

### lucos-code-reviewer

| Field | Value |
|---|---|
| Display name | `lucOS Code Reviewer` |
| App ID | `2956131` |
| Installation ID | `112629982` |
| Installed on | `lucas42` (all repos) |

Used by the lucos-code-reviewer Claude persona. The app has **Pull requests: Read & Write** permission. Private key stored in lucos_creds as `LUCOS_CODE_REVIEWER_PEM`.

---

## gh-as-agent

The `gh-as-agent` script is a wrapper around `gh api` that handles token generation internally. **This is the recommended way to make GitHub API calls as a lucos bot.**

### Usage

When the request body contains text (e.g. issue bodies, comments), write the payload to a file first and pass it via `--input`. This avoids backticks in Markdown content being misinterpreted as shell command substitution, which would require manual approval in Claude Code.

```bash
# Step 1: write the payload to a file (use the Write tool, not a shell command)
# /tmp/gh-payload.json:
# {"title": "Issue title", "body": "Issue body with `code` and **markdown**"}

# Step 2: call gh-as-agent with --input (default: authenticates as lucos-agent)
./gh-as-agent repos/lucas42/{repo}/issues \
    --method POST \
    --input /tmp/gh-payload.json

# Authenticate as a specific app (use --app as the first argument)
./gh-as-agent --app lucos-issue-manager repos/lucas42/{repo}/issues \
    --method POST \
    --input /tmp/gh-payload.json
```

For requests with no body (e.g. label management), `-f` flags are fine as label names won't contain backticks:

```bash
./gh-as-agent repos/lucas42/{repo}/issues/{number}/labels \
    --method POST \
    -f labels[]="agent-approved"
```

All `gh api` flags and arguments are passed through directly. There is no need to generate or manage tokens manually.

---

## get-token

The `get-token` script generates a short-lived GitHub installation access token (valid for 1 hour) and prints it to stdout. Prefer using `gh-as-agent` over calling this directly.

### How it works

GitHub App authentication uses a two-step flow:

1. **Build a JWT** signed with the app's RSA private key, containing the App ID and an expiry 10 minutes from now.
2. **Exchange the JWT** for an installation access token by calling `POST /app/installations/{installation_id}/access_tokens`. This token can then be used like a normal GitHub API token.

The JWT is assembled manually in bash:
- Header and payload are base64url-encoded JSON
- The signature is produced by `openssl dgst -sha256 -sign` using the RSA private key
- The three parts are joined with `.`

---

## Private keys and lucos_creds

All apps' RSA private keys are stored in lucos_creds and pulled down in a single `.env` file:

| App | `.env` variable |
|---|---|
| `lucos-agent` | `LUCOS_AGENT_PEM` |
| `lucos-issue-manager` | `LUCOS_ISSUE_MANAGER_PEM` |
| `lucos-code-reviewer` | `LUCOS_CODE_REVIEWER_PEM` |

Pull down the `.env` file with:

```bash
scp -P 2202 "creds.l42.eu:lucos_agent/development/.env" .
```

### Newline handling quirk

RSA PEM keys are multi-line, but lucos_creds flattens values to a single line, replacing newlines with spaces. This affects both the base64 body of the key and the spaces that are legitimately part of the `-----BEGIN RSA PRIVATE KEY-----` / `-----END RSA PRIVATE KEY-----` markers.

`get-token` handles this by parsing the header and footer markers out separately, then replacing spaces only in the base64 body before reassembling the key. A temporary file is used to pass the restored PEM to `openssl` (macOS's OpenSSL does not support `/dev/fd` process substitution).
