# CONTEXT — перенесено в wiki/

Этот файл раньше содержал весь проектный контекст. **Всё перенесено в [`wiki/`](../wiki/README.md)** со структурой и cross-references.

## Где что искать

| Раньше в CONTEXT.md | Теперь в wiki/ |
|---|---|
| Цель проекта, философия | [00 — Overview](../wiki/00-overview.md) |
| Целевое железо, PG/Docker текущей системы | [01 — Hardware](../wiki/01-hardware.md) |
| Общие решения preseed, варианты A/B | [10 — Preseed](../wiki/10-preseed.md) |
| Разметка NVMe, LVM, btrfs | [11 — Variant A](../wiki/11-preseed-variant-a.md) |
| USB SSD, ext4, оптимизации | [12 — Variant B](../wiki/12-preseed-variant-b.md) |
| Пакеты `pkgsel/include`, подводные камни | [13 — Packages](../wiki/13-preseed-packages.md) |
| late_command в деталях | [14 — late_command](../wiki/14-preseed-late-command.md) |
| Выбор mirror, бенчмарк | [15 — Mirror](../wiki/15-preseed-mirror.md) |
| Ventoy, Fedora-quirks, процедура обновления | [30 — Ventoy](../wiki/30-ventoy.md) |
| bootstrap.sh, ansible, chezmoi pipeline | [60 — bootstrap.sh](../wiki/60-bootstrap.md) |
| PG migration, restic | [70 — Data migration](../wiki/70-data-migration.md) |
| Встреченные баги и их фиксы | [51 — Lessons learned](../wiki/51-lessons-learned.md) |

## Для Claude в новой сессии

> «Продолжаем работу над preseed. Прочитай `wiki/README.md`».

Правила валидации: [`CLAUDE.md`](../CLAUDE.md) в корне репо.
