# lucos_agent

A GitHub App used by AI agents to interact with GitHub on the [lucos](https://github.com/lucas42/lucos) infrastructure.

Actions taken with these credentials appear as `lucos_agent[bot]` in the GitHub UI, keeping bot activity clearly distinct from human activity.

## Contents

- **`get-token`** — shell script that generates a short-lived GitHub installation access token (valid 1 hour), printed to stdout

## Usage

Pull credentials from lucos_creds, then run the script:

```bash
scp -P 2202 "creds.l42.eu:lucos_agent/development/.env" .
TOKEN=$(./get-token)
```

Use the token to make GitHub API calls, e.g. creating an issue:

```bash
gh api repos/lucas42/{repo}/issues \
    -H "Authorization: token $TOKEN" \
    --method POST \
    -f title="Issue title" \
    -f body="Issue body"
```

## How it works

`get-token` implements the [GitHub App authentication flow](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app):

1. Builds a short-lived JWT signed with the app's RSA private key (read from `APP_PEM` in `.env`)
2. Exchanges the JWT for an installation access token via the GitHub API

See `CLAUDE.md` for more technical detail, including notes on how the private key is stored in lucos_creds.
