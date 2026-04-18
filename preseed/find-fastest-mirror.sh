#!/usr/bin/env bash
# find-fastest-mirror.sh
# Загружает официальный список зеркал Debian, проверяет ping и скорость
# скачивания тестового файла, и выводит топ.
#
# Зависимости: curl, ping, awk, sort, sed
#
# Usage:
#   ./find-fastest-mirror.sh [-n COUNT] [-c COUNTRY] [-s SUITE] [-t TIMEOUT]
#   COUNT   - сколько лучших зеркал показать (по умолчанию 10)
#   COUNTRY - двухбуквенный код страны для фильтрации (напр. RU, DE, US)
#   SUITE   - проверяемый файл по этому релизу (по умолчанию trixie)
#   TIMEOUT - таймаут на загрузку в секундах (по умолчанию 8)

set -u
set -o pipefail

COUNT=10
COUNTRY=""
SUITE="trixie"
TIMEOUT=8

while getopts ":n:c:s:t:h" opt; do
    case "$opt" in
        n) COUNT="$OPTARG" ;;
        c) COUNTRY="${OPTARG^^}" ;;
        s) SUITE="$OPTARG" ;;
        t) TIMEOUT="$OPTARG" ;;
        h)
            sed -n '2,15p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: -$OPTARG" >&2
            exit 2
            ;;
    esac
done

MIRROR_LIST_URL="https://www.debian.org/mirror/list"
TEST_PATH="dists/${SUITE}/Release"

need() {
    command -v "$1" >/dev/null 2>&1 || { echo "Need '$1' installed." >&2; exit 1; }
}
need curl
need ping
need awk
need sort
need sed

tmp_html="$(mktemp)"
tmp_results="$(mktemp)"
trap 'rm -f "$tmp_html" "$tmp_results"' EXIT

echo "==> Загружаю список зеркал с ${MIRROR_LIST_URL}" >&2
if ! curl -fsSL --max-time 30 "$MIRROR_LIST_URL" -o "$tmp_html"; then
    echo "Не удалось получить список зеркал." >&2
    exit 1
fi

# Парсим http(s) ссылки на зеркала с /debian/ в конце.
# Также фиксируем код страны из заголовков формата <h3 id="XX">Country</h3>
mapfile -t MIRRORS < <(awk '
    /<h3 id="[A-Z]{2}"/ {
        match($0, /id="[A-Z]{2}"/)
        country = substr($0, RSTART+4, 2)
    }
    {
        while (match($0, /https?:\/\/[A-Za-z0-9._\/-]+\/debian\/?/)) {
            url = substr($0, RSTART, RLENGTH)
            sub(/\/?$/, "/", url)
            print country "|" url
            $0 = substr($0, RSTART+RLENGTH)
        }
    }
' "$tmp_html" | sort -u)

if [[ -n "$COUNTRY" ]]; then
    FILTERED=()
    for entry in "${MIRRORS[@]}"; do
        [[ "${entry%%|*}" == "$COUNTRY" ]] && FILTERED+=("$entry")
    done
    MIRRORS=("${FILTERED[@]}")
fi

total="${#MIRRORS[@]}"
if (( total == 0 )); then
    echo "Не найдено зеркал (фильтр COUNTRY=$COUNTRY)." >&2
    exit 1
fi
echo "==> Найдено зеркал: $total. Тестирую (это займёт пару минут)..." >&2

i=0
for entry in "${MIRRORS[@]}"; do
    i=$((i+1))
    country="${entry%%|*}"
    url="${entry#*|}"
    host="$(echo "$url" | awk -F/ '{print $3}')"

    printf '  [%d/%d] %s ... ' "$i" "$total" "$host" >&2

    # ping (1 пакет, 2-сек таймаут)
    ping_ms="$(ping -n -c 1 -W 2 "$host" 2>/dev/null \
        | awk -F'time=' '/time=/{print $2}' \
        | awk '{print $1; exit}')"
    if [[ -z "$ping_ms" ]]; then
        echo "ping fail" >&2
        continue
    fi

    # Загрузка тестового файла, измерение скорости
    speed_bps="$(curl -o /dev/null -fsS \
        --max-time "$TIMEOUT" \
        --connect-timeout 5 \
        -w '%{speed_download}' \
        "${url}${TEST_PATH}" 2>/dev/null)" || speed_bps=""
    if [[ -z "$speed_bps" || "$speed_bps" == "0.000" || "$speed_bps" == "0" ]]; then
        echo "dl fail" >&2
        continue
    fi

    # Скорость в KB/s (целое)
    speed_kbs="$(awk -v b="$speed_bps" 'BEGIN{printf "%.0f", b/1024}')"
    echo "ping=${ping_ms}ms speed=${speed_kbs}KB/s" >&2
    echo -e "${speed_kbs}\t${ping_ms}\t${country}\t${url}" >> "$tmp_results"
done

if [[ ! -s "$tmp_results" ]]; then
    echo "Ни одно зеркало не отозвалось." >&2
    exit 1
fi

echo
echo "===== TOP $COUNT зеркал по скорости ====="
printf '%-10s %-10s %-4s %s\n' "KB/s" "ping(ms)" "CC" "URL"
printf '%-10s %-10s %-4s %s\n' "----" "--------" "--" "---"
sort -k1,1 -nr "$tmp_results" | head -n "$COUNT" | \
    awk -F'\t' '{printf "%-10s %-10s %-4s %s\n", $1, $2, $3, $4}'

echo
echo "Чтобы прописать лучшее зеркало в preseed.txt, замените:"
echo "  d-i mirror/http/hostname string <hostname-без-https://-и-/debian/>"
echo "  d-i mirror/http/directory string /debian"
