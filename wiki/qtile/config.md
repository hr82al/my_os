---
tags: [qtile, config, customization]
---

# Настройка `config.py`

← [qtile](README.md) | [Wiki Index](../README.md)

Конфигурация qtile = **Python-скрипт** `~/.config/qtile/config.py`.
Если файла нет — qtile использует встроенный default config.

## 1. Скопировать default config для правки

```bash
mkdir -p ~/.config/qtile
cp /usr/share/doc/qtile/default_config.py ~/.config/qtile/config.py
```

Или скачать с GitHub:
```bash
curl -o ~/.config/qtile/config.py \
    https://raw.githubusercontent.com/qtile/qtile/master/libqtile/resources/default_config.py
```

Откроете — увидите Python со структурой:
```python
from libqtile import bar, layout, widget
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

mod = "mod4"               # Super key
terminal = "xterm"         # ← поменять на kitty!

keys = [ Key([mod], "h", lazy.layout.left()), ... ]
groups = [Group(i) for i in "123456789"]
layouts = [layout.Columns(...), layout.Max()]
screens = [Screen(top=bar.Bar([...]))]
```

## 2. Первая правка — default terminal

В default config:
```python
terminal = "xterm"
```
Меняем на:
```python
terminal = "kitty"
```
Сохранить → `Super + Ctrl + r` (перезапуск qtile) → `Super + Enter` теперь открывает kitty.

## 3. Проверка config перед перезапуском

**Ошибка в config.py** → qtile не запустится → чёрный экран. Превентивно:
```bash
qtile check    # статическая проверка Python + qtile-specific
```
Если всё ок — «OK». Если ошибка — покажет строку.

## 4. Типичные правки для DE-пользователя

### 4a. Apps открываются в определённой группе (workspace)

Правило: Firefox → группа 1, VS Code → группа 2, terminal → 3.

```python
from libqtile.config import Match

groups = [
    Group("1", label="web",     matches=[Match(wm_class="firefox"),
                                          Match(wm_class="Google-chrome")]),
    Group("2", label="code",    matches=[Match(wm_class="Code")]),
    Group("3", label="term",    matches=[Match(wm_class="kitty")]),
    Group("4", label="notes",   matches=[Match(wm_class="obsidian")]),
    Group("5", label="db",      matches=[Match(wm_class="DBeaver")]),
    Group("6", label="chat",    matches=[Match(wm_class="TelegramDesktop")]),
    Group("7"),
    Group("8"),
    Group("9"),
]
```

Узнать `wm_class` приложения: в терминале `xprop WM_CLASS` → кликнуть на окно.

### 4b. Volume / Brightness клавиши

Добавить в `keys = [ ... ]`:
```python
Key([], "XF86AudioRaiseVolume",
    lazy.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%")),
Key([], "XF86AudioLowerVolume",
    lazy.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%")),
Key([], "XF86AudioMute",
    lazy.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle")),
Key([], "XF86MonBrightnessUp",
    lazy.spawn("brightnessctl s +5%")),
Key([], "XF86MonBrightnessDown",
    lazy.spawn("brightnessctl s 5%-")),
```

`brightnessctl` ставится отдельно: `sudo apt install brightnessctl`.

### 4c. Скриншот по Print

```python
Key([], "Print", lazy.spawn("flameshot gui")),
```

`flameshot` ставим отдельно: `sudo apt install flameshot`.

### 4d. Rofi как launcher (вместо Super+r prompt)

```python
Key([mod], "r", lazy.spawn("rofi -show drun")),
```

Rofi ставим: `sudo apt install rofi`.

### 4e. Bar с полезными widget'ами

Минимальный полезный bar:
```python
screens = [
    Screen(
        top=bar.Bar([
            widget.CurrentLayout(),
            widget.GroupBox(),
            widget.Prompt(),
            widget.WindowName(),
            widget.Chord(chords_colors={'launch': ("#ff0000", "#ffffff")},
                         name_transform=lambda name: name.upper()),
            widget.Systray(),          # трей (nm-applet, volume icon)
            widget.Volume(),
            widget.Battery(format='{char} {percent:2.0%}'),
            widget.Clock(format='%Y-%m-%d %H:%M'),
            widget.QuickExit(),
        ], 24),
    ),
]
```

После правки: `qtile check && Super+Ctrl+r`.

### 4f. Autostart (запускать приложения при старте qtile)

Создать скрипт:
```bash
mkdir -p ~/.config/qtile
cat > ~/.config/qtile/autostart.sh <<'EOF'
#!/bin/sh
# Tray apps
nm-applet &
pactl --help >/dev/null 2>&1 && /usr/bin/pipewire &
picom -b &
EOF
chmod +x ~/.config/qtile/autostart.sh
```

И хук в config.py:
```python
import os
import subprocess
from libqtile import hook

@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser('~/.config/qtile/autostart.sh')
    subprocess.Popen([home])
```

Теперь при запуске qtile — скрипт запустит nm-applet, picom и т.д.

### 4g. Floating окон для диалогов

Default config уже делает float для диалогов, но если какое-то приложение
должно быть всегда floating — добавить в `floating_layout`:
```python
floating_layout = layout.Floating(float_rules=[
    *layout.Floating.default_float_rules,
    Match(wm_class='pavucontrol'),
    Match(wm_class='calculator'),
    Match(title='Picture-in-Picture'),
])
```

## 5. Полезные готовые конфиги

Начать не с нуля, а с хорошего базового:
- qtile official [arcticicestudio/qtile-config](https://github.com/qtile/qtile-examples) — примеры
- [Derek Taylor (DistroTube) qtile](https://gitlab.com/dwt1/dotfiles) — популярный
- [r/unixporn](https://reddit.com/r/unixporn) — скриншоты + dotfiles

## 6. Debug

### Логи qtile
```bash
# обычно в ~/.local/share/qtile/qtile.log
less ~/.local/share/qtile/qtile.log
# или
journalctl --user -u qtile 2>/dev/null
```

### Python error в config.py
`qtile check` статический анализ. Если прошёл — ошибка runtime, смотреть лог.

### Перезапуск без потери окон
`Super+Ctrl+r` перезагружает config без закрытия открытых программ. Если
новый config ломается — qtile откатится на старый и уведомит.

## 7. Когда всё удобно — dotfiles

Скопировать config.py в git-repo, управлять через chezmoi. См. [post-install/README.md](../post-install/README.md).

## Ссылки

- [qtile official docs — Configuration](https://docs.qtile.org/en/stable/manual/config/)
- [first-steps.md](first-steps.md)
- [essentials.md](essentials.md) — что рядом с config.py должно быть
