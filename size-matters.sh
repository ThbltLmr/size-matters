# size-matters - Git diff statistics with per-extension breakdown
# Usage: size-matters (or sm via alias)
#
# Add to your .bashrc/.zshrc:
#   source /path/to/size-matters.sh

size-matters() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Error: not inside a git repository" >&2
        return 1
    fi

    local repo_root
    repo_root="$(git rev-parse --show-toplevel)"

    _sm_print_stats() {
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

    _sm_get_untracked_numstat() {
        git -C "$repo_root" ls-files --others --exclude-standard | while IFS= read -r file; do
            [[ -f "$repo_root/$file" ]] || continue
            lines=$(wc -l < "$repo_root/$file" | tr -d ' ')
            printf '%s\t0\t%s\n' "$lines" "$file"
        done
    }

    echo "Uncommitted changes:"
    {
        if git -C "$repo_root" rev-parse HEAD &>/dev/null 2>&1; then
            git -C "$repo_root" diff HEAD --numstat
        else
            git -C "$repo_root" diff --cached --numstat
        fi
        _sm_get_untracked_numstat
    } | _sm_print_stats

    echo ""
    echo "Changes since last merge commit:"
    local merge_commit
    merge_commit=$(git -C "$repo_root" log --merges -1 --format=%H 2>/dev/null || true)
    if [[ -z "$merge_commit" ]]; then
        echo "  No merge commit found"
    else
        {
            git -C "$repo_root" diff "$merge_commit" --numstat
            _sm_get_untracked_numstat
        } | _sm_print_stats
    fi
}
