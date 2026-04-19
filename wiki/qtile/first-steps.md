---
tags: [qtile, first-steps, guide]
---

# Первые шаги — для пользователей DE

← [qtile](README.md) | [Wiki Index](../README.md)

Гайд для тех, кто привык к GNOME / KDE / XFCE / Cinnamon и впервые видит
qtile. Фокус — минимум, достаточный чтобы **работать уже сегодня**.

## 1. Что такое qtile

**Не «рабочий стол».** qtile = tiling window manager:

| Привычный DE (KDE, GNOME) | qtile |
|---|---|
| Иконки на рабочем столе | Нет рабочего стола |
| Панель с часами, треем, меню «Пуск» | Минимальная top-bar без меню |
| Окна двигаются/ресайзятся мышью | Окна **автоматически замощают** экран |
| Виртуальные рабочие столы (4-6 шт) | **Groups** (9 по умолчанию), переключение клавишей |
| Alt+Tab | `Super+j/k` или клавиши-стрелки |
| Закрыть × в заголовке | `Super+w` |
| Конфиг в настройках GUI | Конфиг — **Python** в `~/.config/qtile/config.py` |
| «Перезайти в сессию» | `Super+Ctrl+r` перегружает qtile без logout |

**Почему это полезно:**
- Не нужно мышью таскать окна — WM сам раскладывает
- Клавиатурная навигация быстрее
- Минимум хлама на экране → фокус на работе

**Минусы (честно):**
- Крутая кривая обучения
- Без конфига выглядит бедно
- Для windowed-приложений (например GIMP с кучей окон) — менее удобно

## 2. Первый вход

Preseed настроил:
- **Autologin** пользователя `user` через lightdm
- **Сессия:** qtile

После boot'а вы видите **почти пустой экран** с тонкой полосой (bar)
сверху или снизу. Это нормально. Нет меню «Пуск», нет рабочего стола —
это дизайн.

## 3. Модификатор (Super-клавиша)

Большинство горячих клавиш qtile начинаются с `Super` — это **клавиша Windows**
(между Ctrl и Alt). На MacBook — это ⌘. На ThinkPad — обычно клавиша с логотипом Windows.

В конфиге qtile обозначается как `mod4`.

**Проверка:** нажмите `Super + Return`. Должен открыться терминал (kitty).
Если не открылся — возможно Mod привязан к Alt. Попробуйте `Alt + Return`.

## 4. Открыть терминал и запустить приложение

### Терминал (kitty)
```
Super + Return
```
Каждое нажатие открывает новый терминал. Первое окно займёт весь экран,
второе разделит экран пополам.

### Любое приложение — через prompt
```
Super + r
```
Появится prompt внизу экрана. Наберите имя и Enter:
- `firefox-esr` — Firefox
- `google-chrome` — Chrome
- `code` — VS Code (после `./bootstrap.sh ansible`)
- `obsidian` — Obsidian

Prompt поддерживает автодополнение через **Tab**.

> **Важно:** по дефолту в Debian qtile может спросить `xterm` вместо `kitty`
> при `Super+Enter`. Если так — см. [Настроить default terminal](config.md#default-terminal).

## 5. Управление окнами

### Layout — способ раскладки

Окна раскладываются автоматически. Layout переключается:
```
Super + Space
```
Доступные по умолчанию:
- **Tile / Columns** — окна делят экран колонками
- **Stack** — одно большое + список справа
- **Max** — одно окно на весь экран (как «maximize»)
- **Floating** — свободное перемещение (как DE)

Попробуйте циклить `Super+Space` — увидите как раскладка меняется.

### Фокус между окнами

```
Super + j      вниз / следующее
Super + k      вверх / предыдущее
Super + h      влево
Super + l      вправо
```

Буквы `h j k l` — из vim (left/down/up/right). Если вы vim-пользователь,
это интуитивно.

### Переместить окно (порядок в layout)

```
Super + Shift + j/k/h/l
```

### Изменить размер

```
Super + Ctrl + j/k/h/l     grow вниз/вверх/влево/вправо
```

### Закрыть окно

```
Super + w
```
Не путать с «minimize» — **окно закрывается** (kill application).
Minimize в tiling-WM не нужен.

### Сделать floating

Иногда нужно окно «поверх» и свободно двигать (видео, калькулятор, диалог):
```
Super + (клавиша floating toggle) — зависит от конфига
# По умолчанию: Super + t в некоторых конфигах, но может отсутствовать
```
Если конфиг стандартный qtile — floating mostly automatic (диалоги открываются floating).

## 6. Groups (workspaces / virtual desktops)

Аналог рабочих столов KDE. По умолчанию 9 групп.

### Переключиться на группу
```
Super + 1    группа 1
Super + 2    группа 2
...
Super + 9    группа 9
```

### Перенести текущее окно в другую группу
```
Super + Shift + 1..9
```

### Типичная раскладка
- Группа 1 — Firefox / Chrome
- Группа 2 — VS Code
- Группа 3 — терминалы (kitty)
- Группа 4 — Obsidian
- Группа 5 — DBeaver
- и т.д.

## 7. Bar (статус-панель)

Узкая полоса по краю экрана. Обычно показывает:
- Список групп (подсвечена активная)
- Текущий layout
- Имя активного окна
- Часы
- (Опционально) CPU, память, сеть, звук, батарея

Кликать по группам можно мышью — переключится.

## 8. Выход / перезапуск

| Действие | Команда |
|---|---|
| Перезапустить qtile (после правки config.py) | `Super + Ctrl + r` |
| Выход из qtile (логаут) → lightdm | `Super + Ctrl + q` |
| Выключить систему | `shutdown now` в терминале, или `systemctl poweroff` |
| Перезагрузить | `systemctl reboot` |
| Suspend | `systemctl suspend` |

**Hibernation** — у нас swap только через zram (Variant B) или малый 16 GiB (Variant A) → hibernate **не работает**. Только suspend.

## 9. Recovery (когда всё сломалось)

### qtile зависла / config.py с ошибкой

1. Переключиться в TTY: `Ctrl + Alt + F2`
2. Логин как `user`
3. Проверить config: `qtile check` (покажет Python-ошибки)
4. Если ошибка — `vim ~/.config/qtile/config.py` → починить → сохранить
5. Вернуться: `Ctrl + Alt + F7` (или `F1`)
6. Перезапустить qtile: если живое — `Super+Ctrl+r`. Если нет — `pkill qtile` из TTY и lightdm его перезапустит.

### Экран полностью чёрный после boot

- `Ctrl + Alt + F2` → TTY
- `sudo systemctl status lightdm` — запущен ли
- `sudo systemctl restart lightdm`
- Если lightdm падает — `journalctl -u lightdm -n 50` посмотреть ошибку
- Часто причина: нет Xorg-драйвера видеокарты → `sudo apt install xserver-xorg-video-intel` (или amd/nvidia соответственно)

### Нет звука

- Проверить pipewire: `systemctl --user status pipewire pipewire-pulse wireplumber`
- Проверить вывод: `pactl list sinks short`
- Громкость: `pactl set-sink-volume @DEFAULT_SINK@ +5%`

### Нет интернета

- Wi-Fi: запустить `nm-applet` в фоне (добавить в autostart)
- Проверка: `nmcli device status`
- `nmcli device wifi connect <SSID> password <pass>`

## 10. Первые настройки (критичные)

Без этих правок qtile слегка спартанский:

1. **Терминал = kitty** (не xterm) — см. [config.md](config.md#default-terminal)
2. **Rofi** как запускатель приложений — богаче чем встроенный prompt
3. **Picom** — compositor для transparency / shadows (визуально приятнее)
4. **nm-applet, volume keys, brightness** — integration tray icons + функциональные клавиши
5. **Screenshot tool** — flameshot / grim / gnome-screenshot + keybinding

Всё это в [essentials.md](essentials.md).

## 11. Cheatsheet для первых дней

Распечатать / открыть на втором экране: [keybindings.md](keybindings.md).

## 12. Через месяц когда привыкнете

- Изучить `layout` модули qtile (`monadtall`, `bsp`, `ratiotile`)
- Добавить свои keybindings в config.py
- Настроить bar с CPU/battery/volume/network widgets
- Поставить **gtk-theme** через `lxappearance` для красивых диалоговых окон
- Подключить dotfiles через **chezmoi** (см. [post-install](../post-install/README.md))

## Ссылки

- [Keybindings cheatsheet](keybindings.md)
- [Config.py customization](config.md)
- [Essentials — rofi, picom и т.д.](essentials.md)
- [Decisions & Q&A](decisions.md)
- qtile official docs: [docs.qtile.org](https://docs.qtile.org)
