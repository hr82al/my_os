---
tags: [qtile, essentials, addons]
---

# Essentials — что ещё нужно поставить

← [qtile](README.md) | [Wiki Index](../README.md)

qtile голый из коробки — только WM. Чтобы получить «рабочий стол» уровня
KDE-lite, нужны 5-10 утилит. Все из Debian-main, ставятся одной командой.

## Минимум для повседневной работы

```bash
sudo apt install \
    rofi \
    picom \
    feh \
    flameshot \
    brightnessctl \
    playerctl \
    pavucontrol \
    lxappearance \
    arandr
```

Детали каждой:

### rofi — application launcher
Замена `Super+r` встроенному prompt. Красивее, быстрее, fuzzy-search.

```bash
rofi -show drun     # запуск приложений
rofi -show run      # команды
rofi -show window   # переключение между окнами
```

Биндинг в qtile `config.py`:
```python
Key([mod], "r", lazy.spawn("rofi -show drun")),
```

### picom — compositor
Даёт transparency, shadow, blur. Без него — плоские окна без эффектов.

Автостарт в `~/.config/qtile/autostart.sh`:
```sh
picom -b
```

### feh — wallpaper manager
Без picom/feh у вас просто чёрный фон. feh ставит картинку:
```bash
feh --bg-scale ~/Pictures/wallpaper.jpg
```

Добавить в autostart.sh чтобы каждый раз применялось.

### flameshot — screenshots
GUI с обрезкой, аннотациями, буфером обмена, загрузкой.

Биндинг `Print`:
```python
Key([], "Print", lazy.spawn("flameshot gui")),
```

### capture — запись экрана (ffmpeg)

**Уже деплоится через ansible** (tag `capture` в [site.yml](../../ansible/site.yml)).
Файл: `~/.local/bin/capture`. Требует `ffmpeg`, `pactl`, `xrandr` — все в preseed.

Что делает:
- `x11grab` весь экран (autodetect разрешение через xrandr)
- PulseAudio/PipeWire monitor default sink — записывает то что **слышите**
- H.264 veryfast + AAC → mp4 в `~/video/record_YYYY-MM-DD_HH-MM-SS.mp4`
- 12 fps (достаточно для скринкаста, без нагрузки)

Запуск:
```bash
capture           # Ctrl+C для остановки
```

Хоткей в qtile `config.py`:
```python
Key([mod, "shift"], "r", lazy.spawn("capture")),
```

Script источник: [`ansible/files/capture.sh`](../../ansible/files/capture.sh).

### brightnessctl — яркость экрана
Без `sudo` работает если добавить user в группу `video`:
```bash
sudo usermod -aG video user   # logout/login после этого
brightnessctl set +5%
brightnessctl set 5%-
```

### playerctl — управление плеером
MPRIS-совместимые плееры (Spotify, VLC, browsers).
```bash
playerctl play-pause
playerctl next
playerctl previous
```

Биндинги в config.py:
```python
Key([], "XF86AudioPlay",  lazy.spawn("playerctl play-pause")),
Key([], "XF86AudioNext",  lazy.spawn("playerctl next")),
Key([], "XF86AudioPrev",  lazy.spawn("playerctl previous")),
```

### pavucontrol — GUI для audio
Без него управление звуком — `pactl` в терминале. С pavucontrol — GUI
для выбора устройства, уровней каждого приложения.

Hotkey для открытия (в config.py):
```python
Key([mod], "F1", lazy.spawn("pavucontrol")),
```

### lxappearance — GTK theme switcher
Диалоги Firefox, DBeaver, Obsidian, GTK-apps используют GTK-тему.
Без настройки — белый Adwaita. С lxappearance — выбрать тему, иконки, курсор.

Скачать красивые темы:
```bash
# Adwaita-dark уже в системе
sudo apt install arc-theme materia-gtk-theme
lxappearance  # GUI выбора темы
```

### arandr — monitor configuration
GUI для `xrandr` — если несколько мониторов. Настроить позиции, resolution.
```bash
arandr
# → настроить → "Save as..." → сохранит шелл-скрипт
```
Потом запускать скрипт в autostart.sh.

## Следующий уровень

### dunst — notification daemon
Без dunst уведомления приложений (Firefox, Thunderbird, etc.) не видны.
```bash
sudo apt install dunst
```
Автозапуск:
```sh
dunst &
```

### redshift / f.lux — тёплая цветовая температура вечером
```bash
sudo apt install redshift
# в autostart.sh:
redshift -O 4500K        # или через geoclue
```

### xss-lock + i3lock — автоблокировка экрана
После N минут неактивности блокировать:
```bash
sudo apt install i3lock xss-lock
# autostart.sh:
xss-lock -- i3lock -c 1d1f21 &
```

Вручную заблокировать:
```python
Key([mod], "l", lazy.spawn("i3lock -c 1d1f21")),
# Note: конфликтует с Super+l для фокуса вправо — изменить одну из них
```

### rofimoji / xdotool — emoji picker
```bash
sudo apt install rofi
pip install --user rofimoji   # или downloads из GitHub
```
Hotkey на `Super+.`:
```python
Key([mod], "period", lazy.spawn("rofimoji")),
```

### `xcape` — дополнительные биндинги на модификаторы
Нажать Super коротко = открыть меню / rofi. Хорошо для mouse-only сценариев.

### Иконка трея
- `nm-applet` — NetworkManager (из `network-manager-gnome` — в preseed уже есть)
- `blueman-applet` — Bluetooth (`sudo apt install blueman`)
- `volumeicon` — если не хотите widget в bar

Все в autostart.sh:
```sh
nm-applet &
blueman-applet &
```

## Приложения (GUI) которые ожидаются

Из preseed уже установлены:
- **kitty** — терминал
- **firefox-esr** + **google-chrome** — браузеры
- **lightdm** — display manager (autologin)

Через ansible (`./bootstrap.sh ansible`):
- **VS Code**, **DBeaver**, **Obsidian**, **Bruno**, **Throne**, **Postman**, **Redis Insight**, **LibreOffice**, **Telegram**

## Сводный autostart.sh

После установки всего выше:
```sh
#!/bin/sh
# ~/.config/qtile/autostart.sh

# Tray
nm-applet &
blueman-applet &

# Compositor (transparency/shadows)
picom -b &

# Wallpaper
feh --bg-scale ~/Pictures/wallpaper.jpg &

# Notifications
dunst &

# Screen lock after idle
xss-lock -- i3lock -c 1d1f21 &

# Warm colors in evening
redshift -O 4500K &

# Multi-monitor (если сохранили через arandr)
# ~/.screenlayout/default.sh &
```

`chmod +x ~/.config/qtile/autostart.sh`, добавить хук в config.py (см. [config.md](config.md#4f-autostart)).

## Ссылки

- [config.md](config.md) — как биндить эти утилиты на клавиши
- [first-steps.md](first-steps.md)
- [decisions.md](decisions.md) — обсуждение альтернатив
