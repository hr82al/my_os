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

### 4. При установке с полного DVD нужен явный `use_mirror boolean true`

Installer с DVD **по умолчанию отключает сетевой mirror** (`apt-setup/use_mirror` = `false`) — считается что пакетов на DVD достаточно. Но DVD-1 не содержит всё, что в main (например `qtile`, `ansible`, `snapper`, `rclone`). Без mirror они не найдутся → pkgsel валится с ложными «Unable to locate package X».

Обязательно:
```
d-i apt-setup/use_mirror boolean true
d-i apt-setup/services-select multiselect security, updates
d-i apt-setup/security_host string security.debian.org
```

Симптом в `/var/log/syslog` installer'а:
```
apt-setup: warning: /usr/lib/apt-setup/generators/50mirror returned error code 1; discarding output
```
«discarding output» = скрипт вышел с 1 потому что use_mirror=false — это **ожидаемое** поведение при отсутствии настройки, не реальная ошибка сети.

При обнаружении отсутствующего пакета: либо найти новое имя (часто `*-1` → `*d`,
или `lib…1` → `lib…1t64` и т.п.), либо вынести установку в `ansible/site.yml`
по паттерну Bruno/Obsidian: `uri` для latest release → `get_url` для `.deb` →
`apt: deb:`.

## Стиль коммуникации

- Русский язык, технические термины en — не переводить
- Честная аргументация плюсов/минусов, не «бери A»
- Перед архитектурным решением — проверять реальные числа через `lsblk`/`du`/`free`
- Коротко: пользователь часто говорит «продолжаем» — это не «подожди новых инструкций»
