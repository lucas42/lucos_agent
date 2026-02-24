# lucos_agent

This repo provides tooling for AI agents to interact with GitHub on the lucos infrastructure, authenticated as the **lucos_agent** GitHub App rather than as a personal user. Actions taken with these credentials appear as `lucos_agent[bot]` in the GitHub UI.

## GitHub App details

| Field | Value |
|---|---|
| App name | `lucos_agent` |
| App ID | `2943201` |
| Installation ID | `112266755` |
| Installed on | `lucas42` (all repos) |

The app has **Issues: Read & Write** permission. The private key is stored in lucos_creds (see below).

---

## get-token

The `get-token` script generates a short-lived GitHub installation access token (valid for 1 hour) and prints it to stdout.

### How it works

GitHub App authentication uses a two-step flow:

1. **Build a JWT** signed with the app's RSA private key, containing the App ID and an expiry 10 minutes from now.
2. **Exchange the JWT** for an installation access token by calling `POST /app/installations/{installation_id}/access_tokens`. This token can then be used like a normal GitHub API token.

The JWT is assembled manually in bash:
- Header and payload are base64url-encoded JSON
- The signature is produced by `openssl dgst -sha256 -sign` using the RSA private key
- The three parts are joined with `.`

### Usage

First ensure the `.env` file is present (see below), then:

```bash
TOKEN=$(./get-token)
```

Use the token with `gh api` by passing `-H "Authorization: token $TOKEN"`.

---

## APP_PEM and lucos_creds

The RSA private key is stored in lucos_creds as a variable called `APP_PEM`. Pull down the `.env` file with:

```bash
scp -P 2202 "creds.l42.eu:lucos_agent/development/.env" .
```

### Newline handling quirk

RSA PEM keys are multi-line, but lucos_creds flattens values to a single line, replacing newlines with spaces. This affects both the base64 body of the key and the spaces that are legitimately part of the `-----BEGIN RSA PRIVATE KEY-----` / `-----END RSA PRIVATE KEY-----` markers.

`get-token` handles this by parsing the header and footer markers out separately, then replacing spaces only in the base64 body before reassembling the key. A temporary file is used to pass the restored PEM to `openssl` (macOS's OpenSSL does not support `/dev/fd` process substitution).
