# lucos_agent

A GitHub App used by AI agents to interact with GitHub on the [lucos](https://github.com/lucas42/lucos) infrastructure.

Actions taken with these credentials appear as bot accounts in the GitHub UI (e.g. `lucos-agent[bot]`), keeping bot activity clearly distinct from human activity.

## Contents

- **`get-token`** — shell script that generates a short-lived GitHub installation access token (valid 1 hour), printed to stdout
- **`gh-as-agent`** — wrapper around `gh api` that handles token generation internally; use this instead of calling `gh api` directly

## Usage

Pull credentials from lucos_creds, then use `gh-as-agent` to make GitHub API calls:

```bash
scp -P 2202 "creds.l42.eu:lucos_agent/development/.env" .
./gh-as-agent repos/lucas42/{repo}/issues \
    --method POST \
    -f title="Issue title" \
    -f body="Issue body"
```

All `gh api` flags and arguments are passed through directly. There is no need to generate or manage tokens manually.

## How it works

`get-token` implements the [GitHub App authentication flow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app):

1. Builds a short-lived JWT signed with the app's RSA private key (read from `APP_PEM` in `.env`)
2. Exchanges the JWT for an installation access token via the GitHub API

See `CLAUDE.md` for more technical detail, including notes on how the private key is stored in lucos_creds.
