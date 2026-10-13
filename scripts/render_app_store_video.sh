#!/bin/sh
# Render genuine window recordings as a 27-second Mac App Preview.
set -eu
cd "$(dirname "$0")/.."
locale="${1:-en-US}"
case "$locale" in en-US|zh-Hans) ;; *) echo 'Expected en-US or zh-Hans.' >&2; exit 2 ;; esac
output="outputs/app-store-macos/0.4.0/$locale"
temporary="$output/raw-video/render"
mkdir -p "$temporary"
for scene in 01-library 02-run 03-step; do
    case "$scene" in 01-library) duration=3 ;; 02-run) duration=18 ;; 03-step) duration=6 ;; esac
    ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$output/raw-video/$scene/frames.ffconcat" \
        -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 \
        -t "$duration" -map 0:v:0 -map 1:a:0 \
        -vf 'scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p' \
        -c:v libx264 -profile:v high -level:v 4.0 -b:v 10M -maxrate 12M -bufsize 20M \
        -c:a aac -b:a 256k -ar 48000 -ac 2 -movflags +faststart "$temporary/$scene.mp4"
done
cat > "$temporary/concat.txt" <<'EOF'
file '01-library.mp4'
file '02-run.mp4'
file '03-step.mp4'
EOF
ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$temporary/concat.txt" \
    -c copy -movflags +faststart "$temporary/clean.mp4"
swift scripts/render_media_captions.swift "$locale" "$temporary"
ffmpeg -hide_banner -loglevel error -y -i "$temporary/clean.mp4" \
    -loop 1 -i "$temporary/caption-1.png" -loop 1 -i "$temporary/caption-2.png" -loop 1 -i "$temporary/caption-3.png" \
    -filter_complex "[0:v][1:v]overlay=0:0:enable='lt(t,3)'[a];[a][2:v]overlay=0:0:enable='gte(t,3)*lt(t,21)'[b];[b][3:v]overlay=0:0:enable='gte(t,21)',format=yuv420p[v]" \
    -map '[v]' -map 0:a:0 -t 27 -r 30 -c:v libx264 -profile:v high -level:v 4.0 \
    -b:v 10M -maxrate 12M -bufsize 20M -c:a copy -movflags +faststart "$output/herbot-bot-mac-preview.mp4"
ffmpeg -hide_banner -loglevel error -y -ss 5 -i "$output/herbot-bot-mac-preview.mp4" \
    -frames:v 1 -q:v 2 -update 1 "$output/preview-poster.jpg"
ffprobe -v error -show_entries stream=codec_name,profile,level,width,height,r_frame_rate,sample_rate,channels \
    -show_entries format=duration,size -of json "$output/herbot-bot-mac-preview.mp4" > "$output/video-specifications.json"
printf 'Saved %s\n' "$output/herbot-bot-mac-preview.mp4"
