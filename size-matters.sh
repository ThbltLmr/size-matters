#!/usr/bin/env bash
#
# size-matters.sh - Git diff statistics with per-extension breakdown
#

set -euo pipefail

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Error: not inside a git repository" >&2
    exit 1
fi

cd "$(git rev-parse --show-toplevel)"

print_stats() {
    awk -F'\t' '
        $1 == "-" { next }
        NF < 3 { next }
        {
            added = $1 + 0
            removed = $2 + 0
            file = $3

            n = split(file, parts, "/")
            base = parts[n]
            ext = "(no ext)"
            if (match(base, /\.[^.]+$/))
                ext = substr(base, RSTART)

            ea[ext] += added
            er[ext] += removed
            ef[ext]++
            ta += added
            tr += removed
            tf++
        }
        END {
            if (tf == 0) {
                print "  No changes"
                exit
            }
            printf "  Total: %d files changed, %d additions, %d deletions\n", tf, ta, tr
            for (ext in ef)
                printf "  %s: %d files changed, %d additions, %d deletions\n", ext, ef[ext], ea[ext], er[ext]
        }
    ' | {
        IFS= read -r first_line
        echo "$first_line"
        if [[ "$first_line" != *"No changes"* ]]; then
            sort -t: -k2 -rn
        fi
    }
}

get_untracked_numstat() {
    git ls-files --others --exclude-standard | while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        lines=$(wc -l < "$file" | tr -d ' ')
        printf '%s\t0\t%s\n' "$lines" "$file"
    done
}

echo "Uncommitted changes:"
{
    if git rev-parse HEAD &>/dev/null 2>&1; then
        git diff HEAD --numstat
    else
        git diff --cached --numstat
    fi
    get_untracked_numstat
} | print_stats

echo ""
echo "Changes since last merge commit:"
merge_commit=$(git log --merges -1 --format=%H 2>/dev/null || true)
if [[ -z "$merge_commit" ]]; then
    echo "  No merge commit found"
else
    {
        git diff "$merge_commit" --numstat
        get_untracked_numstat
    } | print_stats
fi
