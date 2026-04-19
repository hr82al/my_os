#!/usr/bin/env bash
# capture — запись экрана + системного звука через ffmpeg (X11).
#
# Автоопределяет:
#   • X11 DISPLAY ($DISPLAY, default :0.0)
#   • Разрешение первого активного монитора (xrandr)
#   • PulseAudio monitor-source (output.monitor) — что слышите, то и записывается
#
# Выход: $HOME/video/record_YYYY-MM-DD_HH-MM-SS.mp4
# Формат: H.264 (libx264, crf=25, veryfast) + AAC 96k, 12 fps (скринкаст)
#
# Остановить: Ctrl+C (ffmpeg корректно закроет файл с movflags +faststart).

set -eu

# -- Output file --
OUTDIR="${HOME}/video"
OUT="${OUTDIR}/record_$(date +%Y-%m-%d_%H-%M-%S).mp4"
mkdir -p "$OUTDIR"

# -- Display --
DISP="${DISPLAY:-:0.0}"

# -- Screen resolution — первый активный монитор --
if command -v xrandr >/dev/null; then
    RES=$(xrandr --query 2>/dev/null | awk '/ connected/{next} /\*/ {print $1; exit}')
fi
RES="${RES:-1920x1080}"

# -- Audio source: PulseAudio/PipeWire monitor of default sink --
if command -v pactl >/dev/null; then
    AUDIO=$(pactl get-default-sink 2>/dev/null).monitor
    # fallback: первый попавшийся .monitor source
    if ! pactl list sources short 2>/dev/null | awk '{print $2}' | grep -qx "$AUDIO"; then
        AUDIO=$(pactl list sources short 2>/dev/null | awk '/monitor/ {print $2; exit}')
    fi
fi
AUDIO="${AUDIO:-default}"

# -- Banner --
echo "==> capture → $OUT"
echo "    display=$DISP  res=$RES  audio=$AUDIO"
echo "    Ctrl+C — остановить"
echo

# -- Record --
exec ffmpeg \
    -f x11grab -framerate 12 -video_size "$RES" -i "$DISP" \
    -f pulse -i "$AUDIO" \
    -c:v libx264 -preset veryfast -tune zerolatency -crf 25 \
    -c:a aac -b:a 96k \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "$OUT"
