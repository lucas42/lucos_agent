#!/bin/bash
# Tests create-pr's footer stripping using stub gh-as-agent / check-unsupervised in a temp copy.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$SRC/create-pr" "$T/create-pr"
cat > "$T/gh-as-agent" <<'STUB'
#!/bin/bash
for a in "$@"; do
    if [[ "$a" == body=@* ]]; then cp "${a#body=@}" "$(dirname "$0")/sent-body"; echo '{"number":1,"html_url":"https://example.invalid/pr/1"}'; exit 0; fi
done
echo '{}'
STUB
# Reviewer-path stub: POST exit code from $T/post_rc; verify GET (--jq) succeeds from the Nth call on, N in $T/ok_on (0 = never).
cat > "$T/gh-reviewer" <<'STUB'
#!/bin/bash
D="$(dirname "$0")"
for a in "$@"; do
    if [[ "$a" == body=@* ]]; then echo '{"number":1,"html_url":"https://example.invalid/pr/1"}'; exit 0; fi
    if [[ "$a" == */requested_reviewers ]]; then echo post >> "$D/posts"; exit "$(cat "$D/post_rc")"; fi
    if [[ "$a" == --jq ]]; then
        echo get >> "$D/gets"; n=$(wc -l < "$D/gets"); ok=$(cat "$D/ok_on")
        [[ "$ok" -gt 0 && "$n" -ge "$ok" ]] && echo lucas42
        exit 0
    fi
done
STUB
printf '#!/bin/bash\nexit 0\n' > "$T/sleep"
printf '#!/bin/bash\nexit 0\n' > "$T/check-unsupervised"
chmod +x "$T"/*
fail=0
run() { # body content; leaves result in $T/sent-body, stderr in $T/err
    printf '%b' "$1" > "$T/body"
    "$T/create-pr" --app x --repo r --title t --body-file "$T/body" --head h --base main --draft > /dev/null 2> "$T/err"
}
check() { [[ "$2" == "$3" ]] && echo "ok - $1" || { echo "FAIL - $1 (expected '$2' got '$3')"; fail=1; }; }

run 'Closes #1\n\nDesc\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n'
check "footer stripped" "0" "$(grep -c 'Generated with' "$T/sent-body")"
check "body kept" "1" "$(grep -c '^Desc$' "$T/sent-body")"
check "no trailing blank line" "Desc" "$(tail -n1 "$T/sent-body")"
check "warns on stderr" "1" "$(grep -c 'stripped' "$T/err")"
run 'Desc\n\nGenerated with [Claude Code](https://claude.com/claude-code)'
check "footer without emoji stripped" "0" "$(grep -c 'Generated with' "$T/sent-body")"
run 'Desc\n\nGenerated with a hammer\n'
check "unrelated line kept" "1" "$(grep -c 'a hammer' "$T/sent-body")"
check "no warning when clean" "0" "$(grep -c 'stripped' "$T/err")"

# Reviewer request path (supervised repo, non-draft)
printf '#!/bin/bash\nexit 1\n' > "$T/check-unsupervised"
cp "$T/gh-as-agent" "$T/gh-plain"; cp "$T/gh-reviewer" "$T/gh-as-agent"; chmod +x "$T"/*
rev() { # post_rc ok_on ; sets $rc, counts in $T/posts, $T/gets
    rm -f "$T/posts" "$T/gets"; touch "$T/posts" "$T/gets"; echo "$1" > "$T/post_rc"; echo "$2" > "$T/ok_on"
    set +e; PATH="$T:$PATH" "$T/create-pr" --app x --repo r --title t --body-file "$T/body" --head h --base main > /dev/null 2> "$T/err"; rc=$?; set -e
}
rev 0 1
check "reviewer: first attempt ok -> exit 0" "0" "$rc"
check "reviewer: one POST" "1" "$(wc -l < "$T/posts")"
rev 1 2
check "reviewer: POST fails, retry verifies -> exit 0" "0" "$rc"
check "reviewer: two POSTs" "2" "$(wc -l < "$T/posts")"
rev 1 0
check "reviewer: never verifies -> exit 1" "1" "$rc"
check "reviewer: gives up after 3 attempts" "3" "$(wc -l < "$T/posts")"
check "reviewer: loud error on stderr" "1" "$(grep -c 'could NOT be added' "$T/err")"
rev 0 0
check "reviewer: POST ok but verify fails -> exit 1" "1" "$rc"
exit $fail
