---
tags: [ansible, decisions, qa]
---

# Ansible — Decisions & Q&A

← [Ansible](README.md) | [Wiki Index](../README.md)

## Q: Почему ansible, а не bash для post-install установок?

**Обсудили:**
- **bash:** простой, никаких зависимостей, 50 строк. Минус: не идемпотентен, ошибки плохо сообщаются, плохо масштабируется.
- **ansible:** декларативный, идемпотентный, per-task status, легко добавлять новые apps.

Для 4 apps bash хватит, но план — **расширять** набор со временем.
Ansible от 9 apps уже окупает overhead.

**Решение: ansible.** Bootstrap.sh — тонкий оркестратор, внутри вызывает
ansible-playbook.

## Q: Native install или Flatpak для desktop apps?

**Контекст:** VS Code, DBeaver, Obsidian, Bruno и т.д. все есть как Flatpak.

Пользователь предпочёл **native** для:
- VS Code (MS apt-репо)
- DBeaver CE (.deb с dbeaver.io)
- Obsidian (.deb с GitHub)
- Bruno (.deb с GitHub)

**Почему:**
- Нативные пакеты обновляются через apt (единый workflow)
- Нет sandbox-ограничений Flatpak (некоторые apps глючат)
- Меньше дисковое потребление (нет дублирования runtime'ов)

Отказались от Kooha и Mattermost (из изначального списка Flatpak'ов) —
не нужны часто.

## Q: Tarball/AppImage для Postman и Redis Insight?

Оба **не имеют официального `.deb`**:
- Postman — только tarball (распаковка в `/opt/Postman`, symlink + .desktop)
- Redis Insight 2.x — AppImage (executable в `/opt/`, + .desktop)

Оба идемпотентны через ansible-модули `unarchive` и `get_url` с `mode: 0755`.

## Q: Почему по тегу на каждое приложение?

**Идемпотентность + тестируемость:**
```bash
sudo ansible-playbook -i inventory.ini site.yml --tags vscode  # только VS Code
```
- При добавлении нового приложения можно тестить только его
- Rollback при проблеме — выключить конкретный тег
- Dry-run (`--check`) селективный

## Q: `chezmoi` — почему в ansible, не в preseed?

`chezmoi` **не в Debian main** (ни в one of 30000+ packages trixie).
Пришлось выбрать способ установки:
- Go: нужен `go` → лишняя зависимость
- pip: `chezmoi` не python
- **`.deb` с GitHub** — официальный релиз, wget + dpkg
- Официальный installer script (`get.chezmoi.io`) — то же, но менее audit'uемо

**Решение:** `.deb` с GitHub releases `twpayne/chezmoi` через ansible (tag `chezmoi`).
Pattern такой же как для Bruno/Obsidian/Throne.

## Q: privoxy — почему настройка в ansible, а не в preseed?

**Preseed** — минимальная прослойка, устанавливает **пакеты**. Конфигурация
приложений — идемпотентная/меняется со временем — место для ansible.

`privoxy` ставится пакетом в preseed, но:
```
forward-socks5 / 127.0.0.1:2080 .
systemctl enable --now privoxy
```
→ в ansible (tag `privoxy`), потому что SOCKS5-порт может меняться,
и `lineinfile` идемпотентно (не дублирует строку на повторных запусках).

## Q: Почему бы не использовать `ansible-galaxy` роли?

Для 9 приложений оверкилл. Роли полезны когда:
- Множество apps с шаблонами
- Нужен переиспользуемый код
- Команда > 1 человека

У нас flat `site.yml` с тегами — достаточно. Рефакторить в роли можно
если станет 20+ apps.

## Q: Портирование fish-функции `capture` — скрипт в `~/.local/bin` vs bash-alias vs bash-функция?

**Контекст:** у пользователя в fish функция `capture` для записи экрана через `ffmpeg` (x11grab + pulse monitor). Нужно перенести на новую Debian систему.

**Обсудили варианты:**

| | alias в ~/.bashrc | function в ~/.bashrc | **script в ~/.local/bin** |
|---|---|---|---|
| Multiline code | ❌ (однострочный) | ✅ | ✅ |
| Dynamic `$(date ...)` | ⚠️ quoting hell | ✅ | ✅ |
| Из fish доступен | ❌ | ❌ | ✅ (бинарь в PATH) |
| Из zsh доступен | ❌ | ❌ | ✅ |
| Идёт через ansible | через lineinfile | через lineinfile | **простой `copy`-module** |
| Исходник в git (review, diff) | в `.bashrc` (смешано) | в `.bashrc` | **отдельный файл** |
| `which capture` видит | ❌ | ❌ | ✅ |

**Решение: script в `~/.local/bin/capture`.**
- Универсально (любой shell из PATH)
- Исходник `ansible/files/capture.sh` — версионируется отдельно
- Ansible deploy через `copy` module (tag `capture`) — идемпотентно
- `~/.local/bin` в PATH через дефолтный `~/.profile` в Debian

**Улучшения относительно оригинала:**
- Автоопределение разрешения (`xrandr`) вместо хардкода `1920x1080`
- Автоопределение audio source (default sink monitor вместо hardware-specific PCI пути)
- Fallback-значения если утилиты недоступны
- Banner печатает что записывается

**Зависимости добавлены в preseed:** `ffmpeg` (запись), `pulseaudio-utils` (`pactl` для default sink), `x11-utils` (`xrandr`).

## Ссылки

- [Ansible overview](README.md)
- [Applications](applications.md) — детали каждого приложения
- [Bootstrap](../post-install/README.md) — как ansible запускается
