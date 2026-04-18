# CLAUDE.md — project rules

## Всегда валидировать изменения в install-pipeline

Перед коммитом правок в `preseed/*.txt` или `ansible/site.yml` — прогнать три проверки через Debian-13 docker (локально на Fedora `debconf-set-selections` и `ansible-playbook` недоступны).

### 1. Синтаксис preseed

```bash
for f in preseed.txt preseed-usb.txt; do
    echo -n "$f: "
    docker run --rm -v $PWD/preseed:/p debian:13 bash -c \
        "apt-get install -y debconf >/dev/null 2>&1 && debconf-set-selections --checkonly /p/$f" \
        && echo "✅" || echo "❌"
done
```

### 2. Синтаксис ansible

```bash
docker run --rm -v $PWD/ansible:/a debian:13 bash -c \
    'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ansible >/dev/null 2>&1 && cd /a && ansible-playbook -i inventory.ini site.yml --syntax-check'
```

### 3. Существование пакетов в Debian 13 (trixie)

⚠️ **Обязательно** перед добавлением любого пакета в preseed `pkgsel/include` или
ansible `apt:`. Apt-транзакция атомарная: один несуществующий пакет валит всю
установку и выдаёт **каскад фейковых** ошибок «unable to locate X» для
несвязанных пакетов.

```bash
docker run --rm debian:13 bash -c '
    apt-get update -qq
    for p in <пакет1> <пакет2> ...; do
        apt-cache show "$p" >/dev/null 2>&1 && echo "✅ $p" || echo "❌ $p MISSING"
    done'
```

**Известные подводные камни** (различия bookworm → trixie):

| Было в Debian 12 | В Debian 13 |
|---|---|
| `policykit-1` | **удалён** → `polkitd` |
| `chezmoi` | **нет в Debian main** → ставить из GitHub `.deb` через ansible |

При обнаружении отсутствующего пакета: либо найти новое имя (часто `*-1` → `*d`,
или `lib…1` → `lib…1t64` и т.п.), либо вынести установку в `ansible/site.yml`
по паттерну Bruno/Obsidian: `uri` для latest release → `get_url` для `.deb` →
`apt: deb:`.

## Стиль коммуникации

- Русский язык, технические термины en — не переводить
- Честная аргументация плюсов/минусов, не «бери A»
- Перед архитектурным решением — проверять реальные числа через `lsblk`/`du`/`free`
- Коротко: пользователь часто говорит «продолжаем» — это не «подожди новых инструкций»
