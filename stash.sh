#!/bin/bash

# stash.sh - Improved Command Stashing Utility
# Stores recent shell commands for recall or reuse

STASH_FILE="$HOME/.command_stash"

show_help() {
    cat <<EOF
Command Stash Utility
Usage:
  stash                  - stash the last command
  stash head N           - stash last N commands
  stash tail N           - stash first N commands of session
  stash history N        - stash history line N
  stash find "text"      - search stashed commands
  stash recall N         - execute line N from stash file
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

    # Check for duplicates
    if [[ -f "$STASH_FILE" ]]; then
        # Extract just the command part from each line and compare
        if awk -F'] ' '{print $2}' "$STASH_FILE" | grep -Fxq "$cmd"; then
            echo "Command already stashed: $cmd"
            return 0
        fi
    fi

    mkdir -p "$(dirname "$STASH_FILE")"
    local entry=$(add_timestamp "$cmd")
    echo "$entry" >> "$STASH_FILE"
    
    # Get the line number of the newly added command
    local line_num=$(wc -l < "$STASH_FILE" 2>/dev/null || echo "0")
    echo "Stashed: $cmd (line $line_num)"
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

    [[ ! -f "$STASH_FILE" ]] && echo "No stash file." && return 1

    echo "Commands matching '$pattern':"
    grep -ni "$pattern" "$STASH_FILE" | while IFS=: read -r line_num content; do
        echo "$line_num) $content"
    done

    local count=$(grep -ic "$pattern" "$STASH_FILE")
    echo "Found $count matching commands"
}

recall_command() {
    local line_num="$1"
    
    [[ ! -f "$STASH_FILE" ]] && echo "No stash file." && return 1
    
    local cmd=$(sed -n "${line_num}p" "$STASH_FILE" | sed 's/^\[[^]]*\] //')
    [[ -z "$cmd" ]] && echo "Invalid line number: $line_num" && return 1
    
    echo "Executing line $line_num: $cmd"
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
        if [[ "$2" =~ ^[0-9]+$ ]]; then
            get_head_commands "$2" | while read -r c; do 
                [[ -n "$c" ]] && stash_command "$c"
            done
        else
            echo "Usage: stash head N (where N is a number)"
        fi
        ;;
    tail)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
            get_tail_commands "$2" | while read -r c; do 
                [[ -n "$c" ]] && stash_command "$c"
            done
        else
            echo "Usage: stash tail N (where N is a number)"
        fi
        ;;
    history)
        [[ "$2" =~ ^[0-9]+$ ]] && stash_command "$(get_history_line "$2")" || echo "Usage: stash history N"
        ;;
    find)
        [[ -n "$2" ]] && find_commands "$2" || echo "Usage: stash find \"pattern\""
        ;;
    recall)
        [[ "$2" =~ ^[0-9]+$ ]] && recall_command "$2" || echo "Usage: stash recall N (where N is the line number)"
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