# Practice HW2 — подробный план (Windows, только терминал)

**Цель:** поднять Patroni-кластер PostgreSQL, пролить SQL, погонять нагрузку, провести chaos-тесты, заполнить отчёт.  
**Отчёт:** `HW\HW2_PRACTICE_SOLUTION.md`  
**Сдача:** Telegram @nikolaysavelev  
**Время:** ~2–3 часа (первый build может занять 15–20 мин)

---

## Что понадобится

| Что | Зачем |
|-----|-------|
| Docker Desktop (Running) | Кластер в контейнерах |
| Python 3 + `pip install psycopg2-binary` | `traffic-generator.py` |
| 3 окна PowerShell | Основные команды / generator / chaos |
| `git pull` свежий репозиторий | Фиксы Dockerfile, скрипты |

**Не нужны:** DBeaver, браузер (опционально только для скриншотов Grafana).

---

## Схема: что поднимаем

```
traffic-generator / psql
         │
    HAProxy :5001 (write) / :5002 (read) / :7001 (stats)
         │
  patroni1 + patroni2 + patroni3  (PostgreSQL + Patroni)
         │
     etcd1 + etcd2 + etcd3  (DCS, кворум 2/3)
```

Порты на хосте:

| Порт | Назначение |
|------|------------|
| 5001 | Master (write) |
| 5002 | Replica (read) |
| 7001 | HAProxy stats |
| 3000 | Grafana |
| 9090 | Prometheus |
| 9187 | postgres-exporter |

Логин БД: `postgres` / `postgres`

---

## Окна PowerShell

| Окно | Роль | Когда открыть |
|------|------|---------------|
| **1** | build, compose, psql, patronictl | С самого начала |
| **2** | `traffic-generator.py` | После SQL, до chaos |
| **3** | `docker stop/start` chaos-тесты | Пока generator работает |

---

# Фаза 0. Подготовка Git (Windows, один раз)

Git на Windows может испортить `entrypoint.sh` (CRLF) → контейнеры падают с `Exited (2)`.

**Окно 1:**

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026

git config core.autocrlf false
git pull
```

Проверка Docker:

```powershell
docker --version
docker compose version
```

Рекомендуется Docker Desktop → Settings → Resources → Memory **4–6 GB**.

---

# Фаза 1. Сборка образа `patroni` (~15–20 мин)

### 1.1. Исправить переносы строк (обязательно на Windows)

```powershell
cd code\postgres-ha
.\fix-line-endings.ps1
```

Должно вывести: `Fixed: patroni-master\docker\entrypoint.sh`

### 1.2. Сборка

```powershell
cd patroni-master
docker build --build-arg PG_MAJOR=15 -t patroni .
```

`PG_MAJOR=15` — использует образ `postgres:15` из HW1, не качает `postgres:17`.

**Успех:** последняя строка `Successfully tagged patroni:latest`.

### 1.3. Если build падает — что делать

| Ошибка в логе | Причина | Решение |
|---------------|---------|---------|
| `TLS handshake timeout` на `postgres:17` | Docker Hub недоступен | `--build-arg PG_MAJOR=15` (см. выше) |
| `gzip: unexpected end of file` при etcd | GitHub оборвал скачивание | `git pull` и повторить обычный build; или офлайн (оба файла в `vendor\`) |
| `vendor/confd: not found` при offline build | confd не скачался (curl reset) | Скачай confd в браузере в `vendor\confd`, или **не используй offline** — обычный build |
| `entrypoint.sh: Syntax error` после `compose up` | CRLF в entrypoint.sh | Фаза 0 + `fix-line-endings.ps1` + **пересобрать** образ |

`download-deps.ps1` нужен **только** если обычный build не качает etcd. Если build уже прошёл — **не запускай**.

---

# Фаза 2. Запуск кластера

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha

docker compose down
docker compose up -d
```

Подожди **90–120 секунд** — etcd и patroni поднимаются не мгновенно.

### 2.1. Проверка: все контейнеры Up

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Должны быть Up (10 штук):**

- `demo-patroni1`, `demo-patroni2`, `demo-patroni3`
- `demo-etcd1`, `demo-etcd2`, `demo-etcd3`
- `demo-haproxy`
- `postgres-ha-prometheus-1`, `postgres-ha-grafana-1`, `postgres-ha-postgres_exporter-1`

### 2.2. Если видишь только grafana/prometheus — patroni Exited (2)

```powershell
docker ps -a --format "table {{.Names}}\t{{.Status}}"
docker logs demo-patroni1 2>&1 | Select-Object -Last 20
```

Если в логах `entrypoint.sh: Syntax error` или `: not found`:

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha
.\fix-line-endings.ps1
cd patroni-master
docker build --build-arg PG_MAJOR=15 -t patroni .
cd ..
docker compose down
docker compose up -d
Start-Sleep -Seconds 90
```

---

# Фаза 3. Состояние кластера (`patronictl list`)

```powershell
docker exec demo-patroni1 patronictl list
```

**Ожидаешь:**

| Поле | Значение |
|------|----------|
| Role | 1 × **Leader**, 2 × **Replica** |
| State | `running` |
| Lag | `0` или пусто |

Сохрани вывод для отчёта §2:

```powershell
mkdir ..\HW\screenshots -ErrorAction SilentlyContinue
docker exec demo-patroni1 patronictl list | Out-File ..\HW\screenshots\patronictl-list.txt -Encoding utf8
```

Сделай скриншот терминала или вставь текст в `HW2_PRACTICE_SOLUTION.md` §2.

---

# Фаза 4. HAProxy (терминал)

```powershell
Invoke-WebRequest -Uri http://localhost:7001/ -UseBasicParsing | Select-Object StatusCode
```

Сохрани HTML для отчёта §3:

```powershell
Invoke-WebRequest -Uri http://localhost:7001/ -UseBasicParsing -OutFile ..\HW\screenshots\haproxy-stats.html
```

Кто UP/DOWN:

```powershell
(Invoke-WebRequest -Uri http://localhost:7001/ -UseBasicParsing).Content | Select-String "UP|DOWN"
```

**В отчёте напиши:** backend `patroni_write` — зелёный только у leader; `patroni_read` — у всех replicas.

---

# Фаза 5. SQL через терминал

Скрипт уже в репо: `code\postgres-ha\init-schema.sql`  
Создаёт таблицы `owners`, `events`, индексы, 3 владельца, 2 события.

Оставайся в `code\postgres-ha`.

### 5.1. Пролить на master (порт 5001 внутри сети)

```powershell
Get-Content init-schema.sql | docker exec -i demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres
```

**Успех:** в конце `CREATE TABLE`, `CREATE INDEX`, `INSERT 0 3`, `INSERT 0 2`. Без `ERROR`.

### 5.2. Проверка на master

```powershell
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT count(*) FROM events;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT * FROM owners;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT * FROM events ORDER BY id;"
```

Ожидаешь: **count = 2**, **3 owners**, **2 events**.

### 5.3. Проверка репликации на replica (порт 5000 внутри сети)

```powershell
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres -c "SELECT count(*) FROM events;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres -c "SELECT * FROM events ORDER BY id;"
```

**count на replica = count на master** → репликация работает.

Запиши оба числа в отчёт §4.3.

### 5.4. Подключение с хоста (если установлен psql)

```powershell
$env:PGPASSWORD = "postgres"
psql -h localhost -p 5001 -U postgres -d postgres -c "SELECT count(*) FROM events;"
psql -h localhost -p 5002 -U postgres -d postgres -c "SELECT count(*) FROM events;"
```

---

# Фаза 6. Генератор нагрузки (Окно 2)

**Окно 2** — не закрывай Окно 1:

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha
pip install psycopg2-binary
python traffic-generator.py
```

Если `python` не найден:

```powershell
py -m pip install psycopg2-binary
py traffic-generator.py
```

**Нормальные логи:**

```
CONNECTED to Master Node
INSERT: login by Иван Петров
READ check (Last 3 IDs): [1, 2, 3]
```

**В Окне 1** — count растёт:

```powershell
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT count(*) FROM events;"
```

Запиши в отчёт §5: пишется/читается? были ли ошибки?

---

# Фаза 7. Chaos-тесты (Окно 3)

`traffic-generator` в Окне 2 **не останавливай**.  
После каждого теста: смотри логи generator + `patronictl list`.

Заполняй таблицу в отчёте §7.

### 7.1. Выключить реплику (не лидера)

```powershell
docker exec demo-patroni1 patronictl list
docker stop demo-patroni2
Start-Sleep -Seconds 15
docker exec demo-patroni1 patronictl list
```

**Ожидание:** INSERT продолжается; patroni2 — stopped.

```powershell
docker start demo-patroni2
Start-Sleep -Seconds 30
docker exec demo-patroni1 patronictl list
```

Сохрани вывод:

```powershell
docker exec demo-patroni1 patronictl list | Out-File ..\HW\screenshots\patronictl-recovery.txt -Encoding utf8
```

### 7.2. Выключить лидера (failover)

```powershell
docker exec demo-patroni1 patronictl list
```

Запомни **Leader** (например `patroni1`). Останови его:

```powershell
docker stop demo-patroni1
```

Смотри generator: **ошибки connection 10–30 сек**, потом снова INSERT.

```powershell
docker exec demo-patroni2 patronictl list
```

Кто новый Leader — в отчёт §6.2.

```powershell
docker exec demo-patroni2 patronictl list | Out-File ..\HW\screenshots\patronictl-failover.txt -Encoding utf8
docker start demo-patroni1
Start-Sleep -Seconds 30
docker exec demo-patroni1 patronictl list
```

patroni1 вернётся как **Replica**, не Leader.

### 7.3. Одна etcd-нода

```powershell
docker stop demo-etcd1
docker exec demo-patroni1 patronictl list
```

**Ожидание:** кластер работает (кворум 2/3).

```powershell
docker start demo-etcd1
```

### 7.4. Две etcd-ноды (потеря кворума)

```powershell
docker stop demo-etcd1
docker stop demo-etcd2
docker exec demo-patroni1 patronictl list
```

**Ожидание:** failover невозможен; текущий leader может ещё писать.

```powershell
docker start demo-etcd1 demo-etcd2
Start-Sleep -Seconds 15
```

### 7.5. HAProxy

```powershell
docker stop demo-haproxy
```

**Ожидание:** generator падает — connection error.

```powershell
docker start demo-haproxy
Start-Sleep -Seconds 10
```

**В отчёте:** HAProxy = SPOF; в проде — 2+ HAProxy + Keepalived.

---

# Фаза 8. Grafana (опционально)

```powershell
Invoke-RestMethod -Uri http://localhost:9090/-/healthy
Start-Process "http://localhost:3000"
```

Логин: `admin` / `admin`.  
Импорт JSON из `code\postgres-ha\grafana_dashboards\`.  
Datasource Prometheus: `http://prometheus:9090`.

Скриншот в `HW\screenshots\` → отчёт §8.

---

# Фаза 9. Заполнить отчёт

Файл: `HW\HW2_PRACTICE_SOLUTION.md`

| Раздел отчёта | Что вставить | Откуда взять |
|---------------|--------------|--------------|
| §2 | Таблица + скрин `patronictl list` | Фаза 3 |
| §3 | Вывод HAProxy / скрин | Фаза 4 |
| §4.3 | count(*) master и replica | Фаза 5 |
| §5 | Наблюдения generator | Фаза 6 |
| §6 | Chaos: реплика, failover | Фаза 7.1–7.2 |
| §7 | Сводная таблица тестов | Фаза 7 |
| §8 | Grafana (если делал) | Фаза 8 |

Скриншоты и `.txt` выводы: `HW\screenshots\`

---

# Фаза 10. Остановка

Окно 2: `Ctrl+C` (остановить generator).

Окно 1:

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha
docker compose down
```

---

# Сдача

Telegram **@nikolaysavelev**:

- `HW\HW2_PRACTICE_SOLUTION.md`
- скриншоты из `HW\screenshots\` (по желанию, если вставлены в md — можно только файл)

---

# Шпаргалка: порядок команд с нуля

```powershell
# 0
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026
git config core.autocrlf false
git pull

# 1 build
cd code\postgres-ha
.\fix-line-endings.ps1
cd patroni-master
docker build --build-arg PG_MAJOR=15 -t patroni .

# 2 up
cd ..
docker compose up -d
Start-Sleep -Seconds 90
docker exec demo-patroni1 patronictl list

# 3 SQL
Get-Content init-schema.sql | docker exec -i demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT count(*) FROM events;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres -c "SELECT count(*) FROM events;"

# 4 generator (окно 2)
python traffic-generator.py

# 5 chaos (окно 3) — см. фазу 7

# 6 down
docker compose down
```

---

# Частые ошибки (кратко)

| Симптом | Решение |
|---------|---------|
| Build: `TLS handshake timeout` | `--build-arg PG_MAJOR=15` |
| Build: `gzip unexpected end of file` | `download-deps.ps1` + `Dockerfile.offline` |
| `Exited (2)`, `entrypoint.sh Syntax error` | `fix-line-endings.ps1` + rebuild + compose up |
| `container is not running` | `docker ps -a`, смотри логи, жди 90 сек |
| `download-deps.ps1` ParseError | Не нужен если build OK; `git pull` для фикса |
| SQL ERROR | Кластер не Up; проверь `-h haproxy -p 5001` |
| Generator connection failed | HAProxy down или failover — подожди 30 сек |
