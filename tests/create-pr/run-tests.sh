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
exit $fail
