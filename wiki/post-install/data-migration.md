---
tags: [backup, migration, postgresql, data]
---

# 70 — Миграция данных

← [Wiki Index](../README.md)

Preseed + ansible + chezmoi восстанавливают **систему**. Данные (PG, docs,
/data) — отдельная задача.

## PostgreSQL (docker volumes)

Текущая установка (Fedora) — см. [01 — Hardware](../hardware.md#postgresqldocker-на-текущей-fedora).

Три контейнера:
- `mp-sw-pg` (112 MB)
- `mp-sl-0-pg` (65 MB)
- `mp-sl-1-pg` (38 GB) ← основной

### Перед установкой Variant A (NVMe стирается)

**Бэкап через `pg_dump`:**
```bash
mkdir -p ~/backup/pg
docker exec mp-sw-pg    pg_dumpall -U postgres > ~/backup/pg/mp-sw.sql
docker exec mp-sl-0-pg  pg_dumpall -U postgres > ~/backup/pg/mp-sl-0.sql
docker exec mp-sl-1-pg  pg_dumpall -U postgres > ~/backup/pg/mp-sl-1.sql

# скопировать на внешний носитель
cp -r ~/backup/pg /path/to/external/disk/
```

**Или целиком volume:** (требует остановить контейнеры)
```bash
docker compose down
sudo cp -a /var/lib/docker/volumes/mp-sl-1-pg-vol/_data/ /mnt/external/mp-sl-1-pg-vol/
sudo cp -a /var/lib/docker/volumes/mp-sl-0-pg-vol/_data/ /mnt/external/mp-sl-0-pg-vol/
sudo cp -a /var/lib/docker/volumes/mp-sw-pg-vol/_data/   /mnt/external/mp-sw-pg-vol/
```

Volume-подход быстрее (нет dump/restore overhead), но UID/GID должны
совпасть на новой системе (обычно 999:999 для postgres в alpine).

### Восстановление после установки

**Вариант 1 — через docker compose + sql-restore:**
```bash
cd ~/mp   # предполагая что docker-compose лежит там (клонировать из git)
docker compose up -d mp-sw-pg mp-sl-0-pg mp-sl-1-pg

# wait
for c in mp-sw-pg mp-sl-0-pg mp-sl-1-pg; do
    until docker exec "$c" pg_isready -U postgres; do sleep 1; done
done

# restore
cat /path/to/backup/mp-sw.sql    | docker exec -i mp-sw-pg    psql -U postgres
cat /path/to/backup/mp-sl-0.sql  | docker exec -i mp-sl-0-pg  psql -U postgres
cat /path/to/backup/mp-sl-1.sql  | docker exec -i mp-sl-1-pg  psql -U postgres
```

**Вариант 2 — копирование volumes (быстрее):**
```bash
docker compose down   # если уже запущены

# ВАЖНО: все контейнеры должны быть остановлены
sudo cp -a /path/to/backup/volumes/mp-sl-1-pg-vol/_data/. /var/lib/docker/volumes/mp-sl-1-pg-vol/_data/
# ... остальные

# UID должен совпасть — обычно postgres = 999:999 для alpine
sudo chown -R 999:999 /var/lib/docker/volumes/mp-sl-1-pg-vol/_data/

docker compose up -d
```

## Пользовательские данные

### `/home/user/mr/` — проекты, конфиги

Если рабочая папка с проектами (не docker volumes) — rsync на внешний:
```bash
rsync -avh --progress /home/user/mr/ /mnt/external/home-mr/
```

На новой системе:
```bash
rsync -avh /mnt/external/home-mr/ /home/user/mr/
```

### `/home/user/docs`, `/home/user/Downloads` и прочее

Аналогично `rsync`.

## Автоматизация через restic (рекомендуется)

Ручной `rsync` хрупок. [restic](https://restic.net) — incremental,
encrypted, deduplicated backups. Планы:
- `restic init` на external disk или cloud (S3/B2/rclone backend)
- Ежедневный snapshot через systemd-timer
- Retention policy (keep 7 daily, 4 weekly, 6 monthly)

TODO после первой успешной установки — настроить через ansible-роль.

## Variant B специфика

Если ставим на USB SSD — внутренний NVMe с Fedora **не трогается**.
Данные остаются доступны:
- Загрузиться обратно в Fedora (F12 → внутренний NVMe)
- Или смонтировать btrfs раздел Fedora из новой Debian

Это главный плюс fallback-сценария: данные не нужно «мигрировать», они
физически на месте.

## Ссылки

- [01 — Hardware](../hardware.md) — числа текущего docker/PG setup
- [11 — Variant A](../preseed/variant-a-nvme.md) — сценарий с затиранием NVMe
- [12 — Variant B](../preseed/variant-b-usb-ssd.md) — fallback-сценарий без миграции
- [60 — bootstrap.sh](README.md)
