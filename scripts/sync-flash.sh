#!/usr/bin/env bash
# sync-flash — обновить Ventoy-флешку из репозитория.
#
# Что делает:
#   • Проверяет что флешка = ровно наш Transcend 32GB (по serial).
#   • Монтирует Ventoy-партицию (или использует уже смонтированную).
#   • rsync $REPO/preseed/ → /preseed/ на флешке (с --delete, без *.iso).
#   • Копирует ventoy.json → /ventoy/ventoy.json.
#   • Чистит old-layout файлы (если были).
#   • sync (flush буферов), НЕ отмонтирует — оставляет смонтированной для дописывания.
#
# Привязка к конкретной флешке (если возьмёте другую — поменять SERIAL ниже):
#   $ lsblk -d -o NAME,MODEL,SERIAL,TRAN | grep usb
#
# Запуск:
#   ./scripts/sync-flash.sh
#   ./scripts/sync-flash.sh -v      # verbose (показать каждый скопированный файл)
#   ./scripts/sync-flash.sh -n      # dry-run — что бы сделалось

set -euo pipefail

# ── конфиг ────────────────────────────────────────────────────────────────
SERIAL="${VENTOY_SERIAL:-182UFWBDLKB3TMM7}"          # Transcend Jet Flash 32GB
LABEL="Ventoy"                                       # exfat LABEL на p1
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── args ──────────────────────────────────────────────────────────────────
RSYNC_FLAGS="-rlt --delete --no-perms --no-owner --no-group --info=stats2"
DRY_RUN=""
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) RSYNC_FLAGS="$RSYNC_FLAGS -v" ;;
        -n|--dry-run) DRY_RUN="--dry-run"; RSYNC_FLAGS="$RSYNC_FLAGS -v" ;;
        -h|--help)
            sed -n '2,/^set -/p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "unknown arg: $arg"; exit 2 ;;
    esac
done

# ── pretty print ──────────────────────────────────────────────────────────
c_ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
c_info() { printf '\033[1;34m→\033[0m %s\n' "$*"; }
c_err()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }
die()    { c_err "$*"; exit 1; }

# ── шаг 1: найти устройство по serial ─────────────────────────────────────
DEV_BY_ID="/dev/disk/by-id/usb-JetFlash_Transcend_32GB_${SERIAL}-0:0"
PART_BY_ID="${DEV_BY_ID}-part1"

if [ ! -e "$DEV_BY_ID" ]; then
    c_err "Флешка с serial=$SERIAL не найдена."
    echo
    echo "Подключённые USB-устройства:"
    lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN | awk 'NR==1 || $NF=="usb"'
    echo
    echo "Если взяли другую флешку — найти serial и обновить:"
    echo "  SERIAL в начале скрипта, ИЛИ VENTOY_SERIAL=xxx ./scripts/sync-flash.sh"
    exit 1
fi
if [ ! -e "$PART_BY_ID" ]; then
    die "Флешка $DEV_BY_ID найдена, но partition1 отсутствует — возможно Ventoy не установлен"
fi

DEVICE=$(readlink -f "$DEV_BY_ID")
PART=$(readlink -f "$PART_BY_ID")
c_ok "Устройство: $DEV_BY_ID  ($DEVICE, partition $PART)"

# ── шаг 2: дополнительная проверка по LABEL на partition1 ────────────────
ACTUAL_LABEL=$(lsblk -no LABEL "$PART")
if [ "$ACTUAL_LABEL" != "$LABEL" ]; then
    die "Partition $PART имеет LABEL='$ACTUAL_LABEL', ожидалось '$LABEL'. Подозрительно — прекращаем."
fi
c_ok "LABEL=$LABEL подтверждён"

# ── шаг 3: монтирование (если ещё не смонтирована) ────────────────────────
MOUNT_POINT=$(lsblk -no MOUNTPOINT "$PART" | head -1)
if [ -n "$MOUNT_POINT" ]; then
    c_ok "Уже смонтирована: $MOUNT_POINT"
else
    c_info "Монтирую $PART ..."
    OUT=$(udisksctl mount -b "$PART")
    MOUNT_POINT=$(echo "$OUT" | sed -E 's/^Mounted .+ at //')
    [ -d "$MOUNT_POINT" ] || die "Монтирование не удалось: $OUT"
    c_ok "Смонтирована в $MOUNT_POINT"
fi

# ── шаг 4: cleanup old-layout (старые preseed/ventoy.json лежали иначе) ──
OLD_ROOT_FILES=(preseed.txt preseed-usb.txt)
removed_old=0
for f in "${OLD_ROOT_FILES[@]}"; do
    if [ -f "$MOUNT_POINT/$f" ]; then
        c_info "Удаляю old-layout файл: /$f"
        [ -z "$DRY_RUN" ] && rm -f "$MOUNT_POINT/$f"
        removed_old=$((removed_old+1))
    fi
done
[ $removed_old -gt 0 ] && c_ok "Cleanup: удалено $removed_old файлов"

# ── шаг 5: rsync repo/preseed → flash:/preseed (mirror, без ISO) ──────────
c_info "rsync preseed/ → $MOUNT_POINT/preseed/"
rsync $RSYNC_FLAGS $DRY_RUN \
    --exclude='*.iso' \
    --exclude='.vscode' \
    --exclude='.git*' \
    --exclude='*.swp' \
    --exclude='.DS_Store' \
    "$REPO/preseed/" \
    "$MOUNT_POINT/preseed/"

# ── шаг 6: ventoy.json → /ventoy/ventoy.json ──────────────────────────────
c_info "cp ventoy.json → $MOUNT_POINT/ventoy/ventoy.json"
if [ -z "$DRY_RUN" ]; then
    mkdir -p "$MOUNT_POINT/ventoy"
    cp "$REPO/preseed/ventoy.json" "$MOUNT_POINT/ventoy/ventoy.json"
fi

# ── шаг 7: sync (flush), НЕ отмонтировать ────────────────────────────────
if [ -z "$DRY_RUN" ]; then
    sync
    c_ok "sync сделан; флешка остаётся смонтированной: $MOUNT_POINT"
else
    c_ok "(dry-run — ничего не изменено)"
fi

# ── финальный листинг ─────────────────────────────────────────────────────
echo
echo "Текущее содержимое флешки:"
ls -la "$MOUNT_POINT" | head -20
echo
echo "Размонтировать вручную (когда готов):"
echo "  sync && udisksctl unmount -b $PART && udisksctl power-off -b $DEVICE"
