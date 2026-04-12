#!/usr/bin/env bash
set -euo pipefail

repo="/etc/nixos"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nixos-git-watch"
snooze_file="$state_dir/snooze_until"
lock_dir="$state_dir/lock"

mkdir -p "$state_dir"

now_epoch="$(date +%s)"

if [[ -f "$snooze_file" ]]; then
    snooze_until="$(cat "$snooze_file" 2>/dev/null || echo 0)"
    if [[ "$snooze_until" =~ ^[0-9]+$ ]] && (( now_epoch < snooze_until )); then
        exit 0
    fi
fi

if [[ ! -d "$repo/.git" ]]; then
    exit 0
fi

if ! mkdir "$lock_dir" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

export GIT_TERMINAL_PROMPT=0

current_branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
upstream_ref="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

remote_ahead=0
remote_behind=0
fetch_failed=0

if [[ -n "$upstream_ref" ]]; then
    remote_name="${upstream_ref%%/*}"

    if ! git -C "$repo" fetch --prune --quiet --no-tags "$remote_name"; then
        fetch_failed=1
    fi

    if read -r remote_behind remote_ahead < <(git -C "$repo" rev-list --left-right --count "HEAD...@{u}" 2>/dev/null); then
        remote_behind="${remote_behind:-0}"
        remote_ahead="${remote_ahead:-0}"
    fi
fi

status_lines="$(git -C "$repo" status --porcelain=v1 --untracked-files=normal 2>/dev/null || true)"
local_change_count=0
if [[ -n "$status_lines" ]]; then
    local_change_count="$(printf '%s\n' "$status_lines" | sed '/^$/d' | wc -l | tr -d ' ')"
fi

if (( local_change_count == 0 && remote_ahead == 0 && remote_behind == 0 && fetch_failed == 0 )); then
    exit 0
fi

message_lines=()
message_lines+=("<span size='x-large' weight='bold'>NixOS config needs attention</span>")

if (( local_change_count > 0 )); then
    message_lines+=("")
    message_lines+=("Local changes need review.")
fi

if (( remote_behind > 0 )); then
    message_lines+=("")
    message_lines+=("Remote changes are ready to pull.")
fi

if (( remote_ahead > 0 )); then
    message_lines+=("")
    message_lines+=("Local commits are ready to push.")
fi

if (( fetch_failed == 1 )); then
    message_lines+=("")
    message_lines+=("Remote status could not be refreshed.")
fi

message="$(printf '%s\n' "${message_lines[@]}")"

show_main_dialog() {
    set +e
    yad --title="NixOS configuration check" \
        --text="$message" \
        --text-align=center \
        --width=340 \
        --height=140 \
        --fixed \
        --borders=16 \
        --button="OK:0" \
        --button="Snooze:1"
    dialog_rc=$?
    set -e

    return "$dialog_rc"
}

show_snooze_dialog() {
    set +e
    yad --title="Snooze reminder" \
        --text="<span weight='bold'>Snooze this reminder?</span>" \
        --text-align=center \
        --width=300 \
        --height=120 \
        --fixed \
        --borders=16 \
        --button="1 hour:10" \
        --button="1 day:11" \
        --button="Back:12"
    dialog_rc=$?
    set -e

    return "$dialog_rc"
}

while true; do
    main_rc=0
    show_main_dialog || main_rc=$?
    case "$main_rc" in
        0)
            exit 0
            ;;
        1)
            snooze_rc=0
            show_snooze_dialog || snooze_rc=$?
            case "$snooze_rc" in
                10)
                    snooze_seconds=3600
                    break
                    ;;
                11)
                    snooze_seconds=86400
                    break
                    ;;
                12)
                    continue
                    ;;
                *)
                    exit 0
                    ;;
            esac
            ;;
        *)
            exit 0
            ;;
    esac
done

printf '%s\n' "$(( now_epoch + snooze_seconds ))" > "$snooze_file"
