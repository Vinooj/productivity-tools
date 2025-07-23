#!/bin/bash

# stash.sh - Improved Command Stashing Utility
# Stores recent shell commands for recall or reuse

STASH_FILE="$HOME/.command_stash"

show_help() {
    cat <<EOF
Command Stash Utility
Usage:
  stash                  - stash the last command
  stash head -N          - stash last N commands
  stash tail -N          - stash first N commands of session
  stash history N        - stash history line N
  stash find "text"      - search stashed commands
  stash recall N         - execute Nth command from last search
  stash list             - list stashed commands
  stash clear            - clear stash
  stash help             - show help
EOF
}

add_timestamp() {
    local cmd="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $cmd"
}

stash_command() {
    local cmd="$1"

    if [[ -z "$cmd" ]]; then
        echo "ERROR: No command to stash." >&2
        return 1
    fi

    if [[ "$cmd" =~ stash.sh || "$cmd" =~ ^[[:space:]]*stash([[:space:]]|$) ]]; then
        echo "ERROR: Not stashing stash commands." >&2
        return 1
    fi

    mkdir -p "$(dirname "$STASH_FILE")"
    local entry=$(add_timestamp "$cmd")
    echo "$entry" >> "$STASH_FILE"
    echo "Stashed: $cmd"
}

get_last_command() {
    local hist_file="${HISTFILE:-$HOME/.zsh_history}"
    local cmd=""

    if [[ -f "$hist_file" ]]; then
        # Read history file in reverse, skip the first line (which is the stash command itself),
        # then find the first command that is not 'gemini' and strip the zsh timestamp prefix.
        cmd=$(tail -r "$hist_file" | sed -n '2,$p' | grep -vE -m 1 '(^| )(gemini)( |$)' | sed 's/^: [0-9]*:[0-9]*;//')
    fi

    echo "$cmd"
}

get_head_commands() {
    local n=$1
    history -a
    fc -ln -$n -1 | sed 's/^ *//' | grep -vE '(^| )stash( |$)'
}

get_tail_commands() {
    local n=$1
    history -a
    local total=$(history | wc -l)
    history | head -$((n)) | sed 's/^ *[0-9]* *//' | grep -vE '(^| )stash( |$)'
}

get_history_line() {
    local line="$1"
    history -a
    history | awk -v n="$line" '$1 == n { $1=""; print substr($0,2) }'
}

find_commands() {
    local pattern="$1"
    local temp_results="/tmp/.stash_search_$$"

    [[ ! -f "$STASH_FILE" ]] && echo "No stash file." && return 1

    grep -i "$pattern" "$STASH_FILE" | tail -5 > "$temp_results"
    echo "$temp_results" > /tmp/.stash_last_search

    echo "Last 5 matching commands:"
    nl -w1 -s") " "$temp_results"

    local count=$(grep -ic "$pattern" "$STASH_FILE")
    [[ $count -gt 5 ]] && echo "... and $((count - 5)) more matches"
}

recall_command() {
    local num="$1"
    local file=$(cat /tmp/.stash_last_search 2>/dev/null)
    [[ ! -f "$file" ]] && echo "Run 'stash find' first." && return 1
    local cmd=$(sed -n "${num}p" "$file" | sed 's/^\[[^]]*\] //')
    [[ -z "$cmd" ]] && echo "Invalid selection." && return 1
    echo "Executing: $cmd"
    read -p "Press Enter to confirm..."
    eval "$cmd"
}

list_commands() {
    [[ ! -f "$STASH_FILE" ]] && echo "No stashed commands." && return
    nl -w1 -s") " "$STASH_FILE"
}

clear_commands() {
    rm -f "$STASH_FILE" && echo "Stash cleared."
}

# Main logic
case "$1" in
    "")
        cmd=$(get_last_command)
        stash_command "$cmd"
        ;;
    head)
        [[ "$2" =~ ^-[0-9]+$ ]] && get_head_commands ${2#-} | while read -r c; do stash_command "$c"; done || echo "Usage: stash head -N"
        ;;
    tail)
        [[ "$2" =~ ^-[0-9]+$ ]] && get_tail_commands ${2#-} | while read -r c; do stash_command "$c"; done || echo "Usage: stash tail -N"
        ;;
    history)
        [[ "$2" =~ ^[0-9]+$ ]] && stash_command "$(get_history_line "$2")" || echo "Usage: stash history N"
        ;;
    find)
        [[ -n "$2" ]] && find_commands "$2" || echo "Usage: stash find \"pattern\""
        ;;
    recall)
        [[ "$2" =~ ^[0-9]+$ ]] && recall_command "$2" || echo "Usage: stash recall N"
        ;;
    list)
        list_commands
        ;;
    clear)
        clear_commands
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        [[ -n "$1" ]] && stash_command "$*" || show_help
        ;;
esac