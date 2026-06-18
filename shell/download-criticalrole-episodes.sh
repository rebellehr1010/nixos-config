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
    --batch-file "$batch_file"
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
    -P "$output_dir"
)

set +e
yt-dlp "${yt_dlp_args[@]}"
rc=$?
set -e

printf 'yt-dlp exit code: %s\n' "$rc"

if [[ "$rc" -ne 0 ]]; then
    echo "Some downloads failed this run (often temporary/rate-limit related)."
    echo "Re-run this script; completed episodes in the archive file will be skipped."
fi

test "$rc" -eq 0
