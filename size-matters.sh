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

    _sm_print_commit_list() {
        local range="$1"
        local output
        output=$(git -C "$repo_root" log "$range" --format="%h %s" --shortstat 2>/dev/null)
        if [[ -z "$output" ]]; then
            echo "  No commits"
            return
        fi
        echo "$output" | awk '
            /^[a-f0-9]+ / {
                if (hash != "") {
                    printf "  %s %-50s %d files, +%d, -%d\n", hash, msg, files, adds, dels
                }
                hash = $1
                msg = substr($0, length($1) + 2)
                files = 0; adds = 0; dels = 0
                next
            }
            /file.*changed/ {
                for (i = 1; i <= NF; i++) {
                    if ($(i+1) ~ /file/) files = $i + 0
                    if ($i ~ /insertion/) adds = $(i-1) + 0
                    if ($i ~ /deletion/) dels = $(i-1) + 0
                }
            }
            END {
                if (hash != "") {
                    printf "  %s %-50s %d files, +%d, -%d\n", hash, msg, files, adds, dels
                }
            }
        '
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

    local merge_commit
    merge_commit=$(git -C "$repo_root" log --merges -1 --format=%H 2>/dev/null || true)

    echo ""
    echo "Commits since last merge:"
    if [[ -z "$merge_commit" ]]; then
        echo "  No merge commit found"
    else
        _sm_print_commit_list "$merge_commit..HEAD"
    fi

    echo ""
    echo "Changes since last merge commit:"
    if [[ -z "$merge_commit" ]]; then
        echo "  No merge commit found"
    else
        {
            git -C "$repo_root" diff "$merge_commit" --numstat
            _sm_get_untracked_numstat
        } | _sm_print_stats
    fi
}
