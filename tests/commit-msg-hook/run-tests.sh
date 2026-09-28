#!/bin/bash
# Tests git-hooks/commit-msg end-to-end via real commits with core.hooksPath set.
set -euo pipefail
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../git-hooks" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$T" && git init -q . && git config user.name t && git config user.email t@t
git config core.hooksPath "$HOOKS"
fail=0
check() { # name, expected-substring-present(0/1), pattern
    local body; body="$(git log -1 --format=%B)"
    if grep -qiE "$3" <<<"$body"; then got=1; else got=0; fi
    [[ $got == "$2" ]] && echo "ok - $1" || { echo "FAIL - $1"; fail=1; }
}
git commit -q --allow-empty -m "a" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"; check "-m trailer stripped" 0 'co-authored'
printf 'subject\n\nbody\n\nCo-authored-by: Claude <noreply@anthropic.com>\n' | git commit -q --allow-empty -F -; check "-F - lowercase stripped" 0 'co-authored'
git commit -q --allow-empty -m "x" -m "Co-Authored-By: Jane <jane@example.com>"; check "human co-author kept" 1 'jane@example.com'
git commit -q --allow-empty -m "y" -m "Co-Authored-By: Claude <noreply@anthropic.com>"; git commit -q --amend --allow-empty -m "z" -m "Co-Authored-By: Claude <noreply@anthropic.com>"; check "--amend stripped" 0 'co-authored'
git commit -q --allow-empty -m "body kept" -m "real body"; check "clean message untouched" 1 'real body'
[[ -z "$(git log -1 --format=%B | tail -c2 | tr -d '\n')" ]] || true
exit $fail
