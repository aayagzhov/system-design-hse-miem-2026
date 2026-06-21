# Сбор логов кластера (Windows → Mac)

Скрипт: `code/postgres-ha/collect-cluster-debug.ps1`  
Результат: `HW/cluster-debug.txt`

## 1. Подтянуть репозиторий (Windows)

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026
git pull
```

## 2. Собрать логи

```powershell
cd code\postgres-ha
.\collect-cluster-debug.ps1
```

Должно вывести: `OK: ...\HW\cluster-debug.txt`

## 3. Закоммить и отправить

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026
git add HW/cluster-debug.txt
git commit -m "debug: patroni cluster logs"
git push
```

## 4. На Mac

```bash
git pull
```

Прислать в чат: `@HW/cluster-debug.txt`

---

## Если контейнеров уже нет

Сначала поднять кластер, подождать, потом скрипт:

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha
docker compose up -d
Start-Sleep -Seconds 30
.\collect-cluster-debug.ps1
```

---

## Что попадает в cluster-debug.txt

- `docker ps -a` — все контейнеры и статусы
- логи `demo-patroni1/2/3`, `demo-etcd1/2/3`, `demo-haproxy`
- exit code patroni1
- hex-дамп `entrypoint.sh` (CRLF vs LF)
- образ `patroni`, `git core.autocrlf`

---

## Известная проблема (контекст)

- `docker build` — OK
- `docker compose up` — Started, но patroni/etcd/haproxy сразу падают
- в `docker ps` только grafana, prometheus, postgres_exporter
- `docker exec demo-patroni1 patronictl list` → `container is not running`

Частая причина на Windows: CRLF в `entrypoint.sh` → см. раздел **Исправление** ниже.

---

## Исправление CRLF (если в логах `entrypoint.sh: Syntax error`)

Один скрипт — всё сам:

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026
git pull

cd code\postgres-ha
.\fix-and-rebuild.ps1
```

Скрипт: `core.autocrlf false` → LF в entrypoint → `docker build --no-cache` → `compose up` → `patronictl list`.

Вручную (если нужно по шагам):

```powershell
git config core.autocrlf false
cd code\postgres-ha
.\fix-line-endings.ps1
cd patroni-master
docker build --no-cache --build-arg PG_MAJOR=15 -t patroni .
cd ..
docker compose down
docker compose up -d
Start-Sleep -Seconds 90
docker exec demo-patroni1 patronictl list
```
