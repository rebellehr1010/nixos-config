#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: download-criticalrole-episodes.sh [OPTIONS]

Download the Critical Role C1 playlist, skipping its first 24 entries.
Resume partial downloads and skip successfully archived videos on reruns.
Save original English subtitles as SRT sidecars and embedded MKV tracks.

Options:
  --playlist-url URL  Override the C1 playlist
  --playlist-items N  yt-dlp index selection (default: 25:)
  --batch-file PATH   Use a URL list instead; no index filtering by default
  --output-dir PATH   Default: /home/riley/Downloads/CriticalRole/C1
  --archive-file PATH Default: <output-dir>/.yt-dlp-download-archive.txt
  --cookies-from-browser BROWSER
                      Authentication source (default: brave)
  --no-cookies        Try downloading without browser authentication
  --dry-run           List selected entries without downloading or archiving
  --help              Show this help

Temporary network failures use capped exponential backoff. Failed playlist
passes are retried twice; permanent failures still produce a nonzero exit.
There is no overall download time limit. Ctrl-C stops the run; rerun to resume.

LosslessCut: keep the subtitle track selected and export as MKV. Extract an
SRT from the FINAL edited output for YouTube (the original sidecar is uncut):
  ffmpeg -i edited.mkv -map 0:s:0 -c:s srt edited.en.srt
Check caption sync at joins and cut boundaries before uploading.
HELP
}

playlist_url='https://www.youtube.com/playlist?list=PLqTT_VuffgDP0I6accl0jP5p3kxBRPVPa'
playlist_items='25:'
items_explicit=false
batch_file=''
output_dir='/home/riley/Downloads/CriticalRole/C1'
archive_file=''
browser='brave'
dry_run=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --playlist-url|--playlist-items|--batch-file|--output-dir|--archive-file|--cookies-from-browser)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || {
                echo "Error: $1 requires a value" >&2; exit 2;
            }
            case "$1" in
                --playlist-url) playlist_url="$2" ;;
                --playlist-items) playlist_items="$2"; items_explicit=true ;;
                --batch-file) batch_file="$2" ;;
                --output-dir) output_dir="$2" ;;
                --archive-file) archive_file="$2" ;;
                --cookies-from-browser) browser="$2" ;;
            esac
            shift 2
            ;;
        --no-cookies) browser=''; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Error: Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

for dependency in yt-dlp ffmpeg ffprobe flock; do
    command -v "$dependency" >/dev/null || {
        echo "Error: Required command not found: $dependency" >&2; exit 1;
    }
done

source_args=()
if [[ -n "$batch_file" ]]; then
    [[ -f "$batch_file" ]] || { echo "Error: Batch file not found: $batch_file" >&2; exit 1; }
    source_args+=(--batch-file "$batch_file")
    if "$items_explicit"; then source_args+=(--playlist-items "$playlist_items"); fi
else
    source_args+=(--playlist-items "$playlist_items" "$playlist_url")
fi

network_args=(
    --ignore-config
    --no-abort-on-error
    --socket-timeout 60
    --retries 20
    --fragment-retries 20
    --extractor-retries 5
    --file-access-retries 3
    --retry-sleep 'http:exp=2:60'
    --retry-sleep 'fragment:exp=2:60'
    --retry-sleep 'extractor:exp=2:60'
    --sleep-requests 1
    --sleep-interval 3
    --max-sleep-interval 8
)
if [[ -n "$browser" ]]; then network_args+=(--cookies-from-browser "$browser"); fi
# yt-dlp enables only Deno by default; this NixOS installation has Node.
if command -v node >/dev/null; then network_args+=(--js-runtimes node); fi

if "$dry_run"; then
    exec yt-dlp "${network_args[@]}" --flat-playlist --simulate \
        --print '%(playlist_index)s %(id)s %(title)s' "${source_args[@]}"
fi

mkdir -p "$output_dir"
archive_file="${archive_file:-$output_dir/.yt-dlp-download-archive.txt}"
mkdir -p "$(dirname "$archive_file")"
# Prevent simultaneous runs from writing the same video/partial/archive files.
exec 9>"$output_dir/.download.lock"
flock -n 9 || { echo "Error: Another download is using $output_dir" >&2; exit 1; }

echo "Output dir   : $output_dir"
echo "Archive file : $archive_file"
yt_dlp_args=(
    "${network_args[@]}"
    --download-archive "$archive_file"
    --continue
    --part
    --no-force-overwrites
    --abort-on-unavailable-fragments
    --concurrent-fragments 1
    --format 'bv*+ba/b'
    --format-sort 'res,vcodec:h264,acodec:aac'
    --merge-output-format mkv
    --remux-video mkv
    --write-subs
    --no-write-auto-subs
    --sub-langs 'en.*'
    --sub-format 'srt/vtt/best'
    --convert-subs srt
    --embed-subs
    --embed-metadata
    --embed-chapters
    --newline
    --progress-delta 30
    -P "$output_dir"
    -o '%(title)s [%(id)s].%(ext)s'
)

# Do not use --ignore-errors: postprocessing failures must not look successful.
# Each new pass re-extracts fresh media URLs; the archive skips completed videos.
trap 'exit 130' INT
trap 'exit 143' TERM
rc=1
for attempt in 1 2 3; do
    echo "Download pass $attempt/3"
    if yt-dlp "${yt_dlp_args[@]}" "${source_args[@]}"; then
        echo 'All selected, available downloads completed.'
        exit 0
    else
        rc=$?
    fi
    if [[ "$rc" -eq 130 || "$rc" -eq 143 ]]; then exit "$rc"; fi
    if [[ "$attempt" -lt 3 ]]; then
        echo 'Some downloads failed. Retrying unfinished videos in 60 seconds...'
        sleep 60
    fi
done
echo 'Some downloads failed. Rerun this script to resume; completed videos will be skipped.' >&2
exit "$rc"
