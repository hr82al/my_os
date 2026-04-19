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

### 5. DVD-installer оставляет `deb cdrom:` запись — отключать

После DVD-install'а `/etc/apt/sources.list` содержит строку вида:
```
deb cdrom:[Debian GNU/Linux 13.4.0 _Trixie_...]/ trixie contrib main non-free-firmware
```
Если в `late_command` выполнить `apt-get update` (например при добавлении docker-ce upstream-репо), apt пытается прочитать DVD, **которого уже нет** — команда виснет бесконечно. В итоге «Finish installation» в конце инсталлятора не отвечает.

Обязательно:
```
d-i apt-setup/disable-cdrom-entries boolean true
```

И belt-and-suspenders в late_command перед первым `apt-get update`:
```sh
sed -i "/^deb cdrom:/d" /target/etc/apt/sources.list
```

Симптом в `/var/log/late-install.log` на установленной системе:
```
+ echo 'deb [...] > /target/etc/apt/sources.list.d/docker.list'
+ in-target apt-get update
<< лог обрывается здесь >>
```

При обнаружении отсутствующего пакета: либо найти новое имя (часто `*-1` → `*d`,
или `lib…1` → `lib…1t64` и т.п.), либо вынести установку в `ansible/site.yml`
по паттерну Bruno/Obsidian: `uri` для latest release → `get_url` для `.deb` →
`apt: deb:`.

## Документация — всё в `wiki/`

Структура wiki с вложенностью по секциям (preseed/, ansible/, ventoy/,
installation/, troubleshooting/, post-install/). Главный индекс —
[`wiki/README.md`](wiki/README.md).

**При редактировании кода (preseed, ansible, bootstrap.sh) — синхронно обновлять соответствующий файл в wiki.**

## Захват Q&A — правило

⚠️ **КАЖДЫЙ вопрос пользователя с архитектурным/дизайнерским смыслом и ответ на него** должен попасть в `wiki/<section>/decisions.md`.

### Что считать «вопросом для decisions»

Вопросы и ответы, которые стоит сохранять:

✅ **Сохранять:**
- «Почему X, а не Y?» (любой trade-off выбор)
- «Можно ли сделать X?» — и обсуждение альтернатив
- «Как это работает?» — объяснение механизма/поведения
- «А что если...» — what-if анализ
- Решения по размерам, путям, именам (`ESP 512 MiB потому что...`)
- Обнаруженные баги и их фиксы (в `troubleshooting/lessons-learned.md`)

❌ **Не сохранять (ephemeral):**
- «Обнови флешку» / «продолжай» / «комитить буду сам»
- Опечатки, уточнения вроде «я подключил, проверь»
- Шаг-за-шагом подтверждения
- Повторяющиеся команды, которые уже есть в документации

### Формат записи

Каждая Q&A в `decisions.md` — как секция:

```md
## Q: Почему X, а не Y?

**Контекст:** коротко в чём дилемма.

**Обсудили:** таблица или bullet list альтернатив с плюсами/минусами.

**Решение:** выбранный вариант + краткое почему.

Trade-off: [если есть]
```

### Куда писать

| Тема вопроса | Файл |
|---|---|
| Разметка диска, partman, late_command, mirror, packages | [`wiki/preseed/decisions.md`](wiki/preseed/decisions.md) |
| Playbook, apps install methods, privoxy | [`wiki/ansible/decisions.md`](wiki/ansible/decisions.md) |
| Ventoy setup, Fedora quirks | [`wiki/ventoy/decisions.md`](wiki/ventoy/decisions.md) |
| Процедура установки, variants, portable boot | [`wiki/installation/decisions.md`](wiki/installation/decisions.md) |
| Debug methodology, логи, валидация | [`wiki/troubleshooting/decisions.md`](wiki/troubleshooting/decisions.md) |
| bootstrap.sh, chezmoi, atuin, rustup | [`wiki/post-install/decisions.md`](wiki/post-install/decisions.md) |
| **Встреченные баги и фиксы** | [`wiki/troubleshooting/lessons-learned.md`](wiki/troubleshooting/lessons-learned.md) |

### Когда писать

- **Немедленно** после того как вопрос/ответ произошёл (не в конце сессии — забудется)
- Если решение сложное — короткую версию в `decisions.md`, длинную — в тематическом файле (например `preseed/late-command.md`) со ссылкой
- При повторном вопросе о том же — обновить существующую запись, не дублировать

## Стиль коммуникации

- Русский язык, технические термины en — не переводить
- Честная аргументация плюсов/минусов, не «бери A»
- Перед архитектурным решением — проверять реальные числа через `lsblk`/`du`/`free`
- Коротко: пользователь часто говорит «продолжаем» — это не «подожди новых инструкций»
