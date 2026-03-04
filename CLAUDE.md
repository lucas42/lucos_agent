# lucos_agent

This repo provides tooling for AI agents to interact with GitHub on the lucos infrastructure, authenticated as a lucos GitHub App rather than as a personal user. Actions taken with these credentials appear as bot accounts in the GitHub UI (e.g. `lucos-agent[bot]`).

## GitHub App details

App names are the GitHub-normalised slugs (lowercase, spaces replaced with hyphens). Pass these to `--app` in `get-token` and `gh-as-agent`.

**Canonical identity data** for all personas (App ID, Installation ID, bot user ID, bot name, display name, PEM variable) is stored in [`personas.json`](personas.json) in this repo. This is the single source of truth — do not duplicate these values elsewhere.

**Important:** The App ID and the bot user ID are different numbers. For commits to show the app's avatar in GitHub's UI, the git committer email must use the **bot user ID**, not the App ID. The user ID is the `bot_user_id` field in `personas.json`. Using the App ID produces a grey ghost avatar.

All apps are installed on `lucas42` (all repos). Private keys are stored in lucos_creds; the `.env` variable name for each persona is the `pem_var` field in `personas.json`.

---

## gh-as-agent

The `gh-as-agent` script is a wrapper around `gh api` that handles token generation internally. **This is the recommended way to make GitHub API calls as a lucos bot.**

### Usage

`--app` is required — there is no default app. Every call must specify which persona is making the request.

```bash
# --app must be the first argument
./gh-as-agent --app lucos-issue-manager repos/lucas42/{repo}/issues \
    --method POST \
    -f title="Issue title" \
    -f body="Issue body here"
```

For label management and other simple requests, use `-f` flags in the same way:

```bash
./gh-as-agent --app lucos-system-administrator repos/lucas42/{repo}/issues/{number}/labels \
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

All apps' RSA private keys are stored in lucos_creds and pulled down in a single `.env` file. The `.env` variable name for each persona's private key is the `pem_var` field in `personas.json`.

Pull down the `.env` file with:

```bash
scp -P 2202 "creds.l42.eu:lucos_agent/development/.env" .
```

### Newline handling quirk

RSA PEM keys are multi-line, but lucos_creds flattens values to a single line, replacing newlines with spaces. This affects both the base64 body of the key and the spaces that are legitimately part of the `-----BEGIN RSA PRIVATE KEY-----` / `-----END RSA PRIVATE KEY-----` markers.

`get-token` handles this by parsing the header and footer markers out separately, then replacing spaces only in the base64 body before reassembling the key. A temporary file is used to pass the restored PEM to `openssl` (macOS's OpenSSL does not support `/dev/fd` process substitution).
