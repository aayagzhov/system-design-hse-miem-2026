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

**Важно:** после `--no-cache` обычный Dockerfile качает etcd с GitHub **внутри** Docker — у тебя это падает с `TLS connect error`. Используй offline-сборку.

### Шаг A — скачать etcd + confd на Windows (браузер или VPN)

Положить в `code\postgres-ha\patroni-master\vendor\`:

| Файл | URL |
|------|-----|
| `etcd.tar.gz` | https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz |
| `confd` (без расширения) | https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 |

Или:

```powershell
cd code\postgres-ha\patroni-master
.\download-deps.ps1
dir vendor
```

## Одна команда (Windows)

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha; .\fix-and-rebuild.ps1
```

Скрипт сам: `git pull` → LF → скачать vendor → offline build → `compose up` → `patronictl list`.

Если на шаге vendor curl упадёт — **один раз** скачай в браузере в `patroni-master\vendor\` (см. таблицу ниже) и запусти **ту же команду** снова.
