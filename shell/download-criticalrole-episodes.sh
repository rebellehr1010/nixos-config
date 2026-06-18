#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: download-criticalrole-episodes.sh [OPTIONS]

Download YouTube episodes listed in a batch file with resume/skip support.
Already downloaded videos are tracked in an archive file and skipped on reruns.

Options:
  --batch-file PATH   File containing one YouTube URL per line
                      (default: /home/riley/Downloads/remaining-episodes.txt)
  --output-dir PATH   Download directory
                      (default: /home/riley/Downloads/CriticalRole)
  --archive-file PATH yt-dlp archive file used to skip completed videos
                      (default: <output-dir>/.yt-dlp-download-archive.txt)
  --help              Show this help

Examples:
  download-criticalrole-episodes.sh
  download-criticalrole-episodes.sh --batch-file /home/riley/Downloads/episode-list.txt
EOF
}

batch_file="/home/riley/Downloads/remaining-episodes.txt"
output_dir="/home/riley/Downloads/CriticalRole"
archive_file=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --batch-file)
            [[ $# -ge 2 ]] || { echo "Error: --batch-file requires a path" >&2; exit 2; }
            batch_file="$2"
            shift 2
            ;;
        --output-dir)
            [[ $# -ge 2 ]] || { echo "Error: --output-dir requires a path" >&2; exit 2; }
            output_dir="$2"
            shift 2
            ;;
        --archive-file)
            [[ $# -ge 2 ]] || { echo "Error: --archive-file requires a path" >&2; exit 2; }
            archive_file="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -f "$batch_file" ]]; then
    echo "Error: Batch file not found: $batch_file" >&2
    exit 1
fi

mkdir -p "$output_dir"

if [[ -z "$archive_file" ]]; then
    archive_file="$output_dir/.yt-dlp-download-archive.txt"
fi

echo "Batch file   : $batch_file"
echo "Output dir   : $output_dir"
echo "Archive file : $archive_file"

yt_dlp_args=(
    --ignore-errors
    --download-archive "$archive_file"
    --force-write-archive
    --continue
    --no-overwrites
    --retries 15
    --fragment-retries 15
    --retry-sleep 5
    --sleep-requests 1
    --sleep-interval 2
    --max-sleep-interval 8
    --cookies-from-browser brave
    -P "$output_dir"
)

download_one_url() {
    local url="$1"
    local attempt rc log_file

    for attempt in 1 2; do
        echo
        echo "Downloading: $url (attempt $attempt/2)"
        log_file="$(mktemp)"

        set +e
        yt-dlp "${yt_dlp_args[@]}" "$url" 2>&1 | tee "$log_file"
        rc=${PIPESTATUS[0]}
        set -e

        if [[ "$rc" -eq 0 ]]; then
            rm -f "$log_file"
            return 0
        fi

        # YouTube bot checks can appear mid-run; retry once so yt-dlp re-reads fresh Brave cookies.
        if grep -q "Sign in to confirm you.re not a bot" "$log_file" && [[ "$attempt" -lt 2 ]]; then
            echo "Detected YouTube bot challenge. Retrying with freshly read Brave cookies..."
            rm -f "$log_file"
            continue
        fi

        rm -f "$log_file"
        return "$rc"
    done
}

total=0
failed=0

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(printf '%s' "$raw_line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

    if [[ -z "$line" || "$line" == \#* ]]; then
        continue
    fi

    total=$((total + 1))
    if ! download_one_url "$line"; then
        failed=$((failed + 1))
    fi
done < "$batch_file"

echo
echo "Processed URLs : $total"
echo "Failed URLs    : $failed"

rc=0
if [[ "$failed" -ne 0 ]]; then
    rc=1
    echo "Some downloads failed this run (often temporary/rate-limit related)."
    echo "Re-run this script; completed episodes in the archive file will be skipped."
fi

test "$rc" -eq 0
