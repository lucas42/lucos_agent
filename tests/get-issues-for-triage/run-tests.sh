#!/bin/bash
# Tests get-issues-for-triage's Ready-issue criteria (5 and 5b) with stub gh / gh-projects / get-token in a temp copy.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$SRC/get-issues-for-triage" "$SRC/personas.json" "$T/"
printf '#!/bin/bash\necho stub-token\n' > "$T/get-token"
printf '#!/bin/bash\ncat "%s/board.json"\n' "$T" > "$T/gh-projects"
mkdir -p "$T/bin" "$T/comments"
cat > "$T/bin/gh" <<'STUB'
#!/bin/bash
path="${@: -1}"
if [[ "$path" =~ ^/repos/([^/]+/[^/]+)/issues/([0-9]+)/comments ]]; then
    f="$T_STUB_DIR/comments/${BASH_REMATCH[1]//\//_}_${BASH_REMATCH[2]}.jsonl"
    [[ -f "$f" ]] && cat "$f"
fi
exit 0
STUB
chmod +x "$T"/get-token "$T"/gh-projects "$T"/bin/gh "$T"/get-issues-for-triage

python3 - "$T" <<'PY'
import json, sys
T = sys.argv[1]
IM, A, S, X = "lucos-issue-manager[bot]", "lucos-architect[bot]", "lucos-site-reliability[bot]", "someone-external"
# number -> (owner, [(login, created_at)])
cases = {
    1: ("lucos-system-administrator", [(IM, "01"), (A, "02")]),          # other persona after IM
    2: ("lucos-site-reliability",     [(IM, "01"), (S, "02")]),          # owner's own comment after IM
    3: ("lucos-system-administrator", [(A, "01"), (IM, "02")]),          # IM replied last
    4: ("lucos-system-administrator", [(A, "01")]),                      # IM never commented
    5: ("lucos-system-administrator", [(IM, "01"), (X, "02")]),          # external login only
    6: ("lucos-system-administrator", [(IM, "01"), ("lucas42", "02")]),  # criterion 5 still works
    7: ("lucos-system-administrator", [("lucas42", "01"), (IM, "02")]),  # lucas42 before IM
    8: ("lucos-system-administrator", [(IM, "01")]),                     # only the IM
    9: ("lucos-system-administrator", [(IM, "01"), (S, "02"), (A, "03"), (IM, "04"), (S, "05")]),  # later persona after IM's latest
}
nodes = []
for n, (owner, cs) in cases.items():
    with open(f"{T}/comments/lucas42_r_{n}.jsonl", "w") as f:
        for login, t in cs:
            f.write(json.dumps({"id": 1, "user": {"login": login}, "created_at": f"2026-11-{t}T00:00:00Z", "reactions": {"total_count": 0}}) + "\n")
    nodes.append({
        "content": {"number": n, "title": f"t{n}", "url": f"https://github.com/lucas42/r/issues/{n}",
                    "repository": {"nameWithOwner": "lucas42/r"}, "labels": {"nodes": []},
                    "comments": {"totalCount": len(cs)}, "reactions": {"totalCount": 0}},
        "fieldValues": {"nodes": [{"name": "Ready", "field": {"name": "Status"}}, {"name": owner, "field": {"name": "Owner"}}]},
    })
json.dump({"data": {"node": {"items": {"pageInfo": {"hasNextPage": False, "endCursor": None}, "nodes": nodes}}}}, open(f"{T}/board.json", "w"))
PY

got=" $(T_STUB_DIR="$T" PATH="$T/bin:$PATH" "$T/get-issues-for-triage" | python3 -c 'import json,sys; print(" ".join(str(i["number"]) for i in json.load(sys.stdin)))') "
fail=0
check() { # name, issue number, expected (yes|no)
    [[ "$got" == *" $2 "* ]] && actual=yes || actual=no
    [[ "$actual" == "$3" ]] && echo "ok - $1" || { echo "FAIL - $1 (surfaced: expected $3, got $actual)"; fail=1; }
}
check "5b: other persona commented after the issue manager" 1 yes
check "5b: Owner's own comment after the issue manager" 2 no
check "5b: issue manager replied after the persona" 3 no
check "5b: issue manager never commented" 4 yes
check "5b: external login only" 5 no
check "5: lucas42 after the issue manager" 6 yes
check "5: lucas42 before the issue manager" 7 no
check "only the issue manager has commented" 8 no
check "5b: persona commented after the issue manager's latest" 9 yes
exit $fail
