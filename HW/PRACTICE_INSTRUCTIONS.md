# Инструкция: практические домашки №1 и №2 (Windows)

Выполняй на **Windows** с **Docker Desktop**.  
Открой **PowerShell** или **Windows Terminal** (не обязательно WSL).

SD-отчёты уже готовы в папке `HW/` — здесь только **практика**.

---

## Что тебе нужно сделать (кратко)

| # | Задача | Время | Результат |
|---|--------|-------|-----------|
| 1 | Practice HW1: demo-app-1 + 3 теста k6 | ~2 ч | `HW1_PRACTICE_SOLUTION.md` + скриншоты |
| 2 | Practice HW2: Patroni-кластер + chaos-тесты | ~2 ч | `HW2_PRACTICE_SOLUTION.md` + скриншоты |
| 3 | Отправить файлы в Telegram @nikolaysavelev | 5 мин | — |

---

## Подготовка (один раз)

### 1. Docker Desktop для Windows

1. Скачай: https://www.docker.com/products/docker-desktop/
2. При установке включи **WSL 2** (если спросит)
3. Запусти Docker Desktop — в трее иконка кита, статус **Running**
4. Проверь в PowerShell:

```powershell
docker --version
docker compose version
```

### 2. Открой проект

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026
```

Подставь свой путь к папке репозитория.

### 3. Python (только для Practice HW2)

Скачай Python с https://www.python.org/downloads/ — при установке отметь **Add Python to PATH**.

```powershell
pip install psycopg2-binary
```

---

# Practice HW1 — Нагрузочное тестирование

**Проект:** `code\demo-app-1`  
**Отчёт:** `HW\HW1_PRACTICE_SOLUTION.md`

## Шаг 1. Запуск

```powershell
cd code\demo-app-1
docker compose up -d --build
```

Подожди 30–60 секунд. Проверка:

```powershell
docker ps
```

Открой в браузере: http://localhost:8081/api/users — должен быть `[]` или JSON.

UI: http://localhost:8080

**Проверка через PowerShell (альтернатива браузеру):**

```powershell
Invoke-RestMethod -Uri http://localhost:8081/api/users
```

## Шаг 2. Создай пользователей для тестов

```powershell
Invoke-RestMethod -Uri http://localhost:8081/api/users -Method Post -ContentType "application/json" -Body '{"name":"User1","email":"u1@test.com"}'

Invoke-RestMethod -Uri http://localhost:8081/api/users -Method Post -ContentType "application/json" -Body '{"name":"User2","email":"u2@test.com"}'
```

Если есть `curl.exe` (Windows 10+):

```powershell
curl.exe -X POST http://localhost:8081/api/users -H "Content-Type: application/json" -d "{\"name\":\"User1\",\"email\":\"u1@test.com\"}"

curl.exe -X POST http://localhost:8081/api/users -H "Content-Type: application/json" -d "{\"name\":\"User2\",\"email\":\"u2@test.com\"}"
```

## Шаг 3. Настрой Grafana

1. Браузер → http://localhost:3000 → логин `admin` / `admin`
2. **Connections → Data sources → Add → Prometheus**
3. URL: **`http://prometheus:9090`** (не `localhost`!)
4. **Save & test**
5. **Dashboards → Import** — загрузи JSON из `code\demo-app-1\dashboards\`:
   - Node Exporter
   - Postgres Overview
   - k6 Prometheus

## Шаг 4. Три сценария k6

Оставайся в `code\demo-app-1`. Между тестами жди **3 минуты**.

```powershell
# Шторм: 1000 пользователей за 10 секунд (~2 мин)
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/storm.js

# Подожди 3 минуты

# Волна: 0 → 500 за 2 минуты (~5 мин)
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/wave.js

# Подожди 3 минуты

# Кастом: 95% чтение (~3 мин)
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/read-heavy.js
```

В конце каждого прогона смотри в терминале: `http_req_duration`, `http_req_failed` — запиши в отчёт.

## Шаг 5. Скриншоты Grafana

1. Дашборд k6 → время **Last 15 minutes**
2. Postgres → connections
3. Node Exporter → CPU

Сохрани в папку:

```powershell
cd ..\..\HW
mkdir screenshots -ErrorAction SilentlyContinue
```

Скриншоты: `HW\screenshots\storm-k6.png` и т.д.

## Шаг 6. Заполни отчёт

Открой `HW\HW1_PRACTICE_SOLUTION.md` — таблица 4.1, скриншоты, выводы.

## Шаг 7. Остановка

```powershell
cd ..\..\code\demo-app-1
docker compose down
```

---

# Practice HW2 — Patroni PostgreSQL HA (только терминал)

**Подробный пошаговый план:** [HW2_PRACTICE_PLAN.md](./HW2_PRACTICE_PLAN.md) — читай его, если делаешь HW2 впервые или что-то падает.

**Проект:** `code\postgres-ha`  
**Отчёт:** `HW\HW2_PRACTICE_SOLUTION.md`

Нужны **3 окна PowerShell**:
- **Окно 1** — основные команды
- **Окно 2** — `traffic-generator.py` (не закрывать во время chaos-тестов)
- **Окно 3** — chaos-тесты

Браузер не обязателен: `patronictl`, SQL и HAProxy — через терминал. Скриншоты для отчёта можно сделать из вывода терминала или сохранённого HTML.

---

## Шаг 1. Собери образ Patroni (первый раз, 5–15 мин)

**Окно 1:**

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha\patroni-master
```

Если `docker build` падает с `TLS handshake timeout` на `postgres:17`, используй уже скачанный образ из HW1:

```powershell
docker build --build-arg PG_MAJOR=15 -t patroni .
```

Если падает на **etcd/confd** (`gzip: unexpected end of file` — GitHub оборвал скачивание):

**Вариант A — повторить build** (в Dockerfile добавлены retry, подтяни свежий код):

```powershell
git pull
docker build --build-arg PG_MAJOR=15 -t patroni .
```

**Вариант B — офлайн-сборка** (только если обычный build падает на etcd; нужны **оба** файла в `vendor\`):

```powershell
.\download-deps.ps1
# если curl падает — скачай в браузере (VPN) и положи в vendor\:
#   etcd-v3.3.13-linux-amd64.tar.gz  ->  vendor\etcd.tar.gz
#   confd-0.16.0-linux-amd64         ->  vendor\confd
dir vendor
docker build -f Dockerfile.offline --build-arg PG_MAJOR=15 -t patroni .
```

**Обычно офлайн не нужен** — если раньше `docker build --build-arg PG_MAJOR=15` уже прошёл, используй обычный Dockerfile + `fix-line-endings.ps1`.

Иначе:

```powershell
docker build -t patroni .
```

Дождись `Successfully tagged patroni:latest`.

---

## Шаг 2. Запусти кластер

```powershell
cd ..
docker compose up -d
```

Подожди **60–90 секунд**, проверь контейнеры:

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## Шаг 3. Состояние кластера (`patronictl list`)

```powershell
docker exec demo-patroni1 patronictl list
```

Ожидаешь: **1 Leader**, **2 Replica** в состоянии `running` / `streaming`.

Сохрани вывод в файл (удобно для отчёта):

```powershell
docker exec demo-patroni1 patronictl list | Out-File ..\..\..\HW\screenshots\patronictl-list.txt -Encoding utf8
```

Скриншот терминала или этот `.txt` — в отчёт §2.

Повторная проверка с любой ноды:

```powershell
docker exec demo-patroni2 patronictl list
docker exec demo-patroni3 patronictl list
```

---

## Шаг 4. HAProxy stats (без браузера)

```powershell
Invoke-WebRequest -Uri http://localhost:7001/ -UseBasicParsing | Select-Object StatusCode, Content
```

Сохранить страницу в файл:

```powershell
Invoke-WebRequest -Uri http://localhost:7001/ -UseBasicParsing -OutFile ..\..\..\HW\screenshots\haproxy-stats.html
```

Открой `haproxy-stats.html` в браузере только если нужен скриншот. В отчёт §3 — вывод или скрин.

Кратко посмотреть, кто UP:

```powershell
(Invoke-WebRequest -Uri http://localhost:7001/ -UseBasicParsing).Content | Select-String "UP|DOWN"
```

---

## Шаг 5. SQL — только через терминал

`psql` уже есть внутри контейнеров Patroni. Подключение идёт через **HAProxy** внутри docker-сети:

| Роль | Внутри сети | С хоста (Windows) |
|------|-------------|-------------------|
| **Master (write)** | `haproxy:5001` | `localhost:5001` |
| **Replica (read)** | `haproxy:5000` | `localhost:5002` |

Логин: `postgres` / `postgres`

### 5.1. Пролить скрипт на master

Оставайся в `code\postgres-ha`:

```powershell
Get-Content init-schema.sql | docker exec -i demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres
```

Должно пройти без ERROR. В конце — `CREATE TABLE`, `INSERT 0 3`, `INSERT 0 2`.

### 5.2. Проверить данные на master

```powershell
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT count(*) AS events_on_master FROM events;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT * FROM owners;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT * FROM events ORDER BY id;"
```

Ожидаешь: **2** события, **3** владельца.

### 5.3. Проверить репликацию на replica

```powershell
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres -c "SELECT count(*) AS events_on_replica FROM events;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres -c "SELECT * FROM events ORDER BY id;"
```

Число на replica должно **совпасть** с master (**2**).

### 5.4. Интерактивный psql (если нужно)

Master:

```powershell
docker exec -it demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres
```

Внутри psql:

```sql
\dt
SELECT count(*) FROM events;
\q
```

Replica:

```powershell
docker exec -it demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres
```

### 5.5. Альтернатива: psql с хоста (если установлен PostgreSQL client)

```powershell
$env:PGPASSWORD = "postgres"
psql -h localhost -p 5001 -U postgres -d postgres -c "SELECT count(*) FROM events;"
psql -h localhost -p 5002 -U postgres -d postgres -c "SELECT count(*) FROM events;"
```

### 5.6. Альтернатива: одноразовый контейнер-клиент

```powershell
docker run --rm -e PGPASSWORD=postgres postgres:15 psql -h host.docker.internal -p 5001 -U postgres -d postgres -c "SELECT count(*) FROM events;"
docker run --rm -e PGPASSWORD=postgres postgres:15 psql -h host.docker.internal -p 5002 -U postgres -d postgres -c "SELECT count(*) FROM events;"
```

Запиши цифры `count(*)` master и replica в отчёт §4.3.

---

## Шаг 6. Генератор нагрузки

**Окно 2** (не закрывай Окно 1):

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha
pip install psycopg2-binary
python traffic-generator.py
```

Если `python` не найден: `py -m pip install psycopg2-binary` и `py traffic-generator.py`

В логах каждую секунду `INSERT`, каждые 2 сек `READ check`. Наблюдения — в отчёт §5.

Проверить рост данных **Окно 1** (пока generator работает):

```powershell
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT count(*) FROM events;"
docker exec demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres -c "SELECT count(*) FROM events;"
```

---

## Шаг 7. Chaos-тесты (Окно 3)

`traffic-generator` в Окне 2 **не останавливай**. После каждого шага смотри логи generator и выполняй `patronictl list`.

### 7.1. Выключить реплику (не лидера)

```powershell
docker exec demo-patroni1 patronictl list
docker stop demo-patroni2
docker exec demo-patroni1 patronictl list
```

Подожди ~30 сек, смотри generator — INSERT должен продолжаться.

Восстановление:

```powershell
docker start demo-patroni2
Start-Sleep -Seconds 30
docker exec demo-patroni1 patronictl list
```

Сохрани вывод:

```powershell
docker exec demo-patroni1 patronictl list | Out-File ..\..\HW\screenshots\patronictl-recovery.txt -Encoding utf8
```

### 7.2. Выключить лидера (failover)

```powershell
docker exec demo-patroni1 patronictl list
```

Запомни, кто **Leader**. Останови его (пример — если leader `patroni1`):

```powershell
docker stop demo-patroni1
```

Смотри generator: ошибки connection **10–30 сек**, потом снова INSERT.

```powershell
docker exec demo-patroni2 patronictl list
```

Кто стал новым Leader — в отчёт. Сохрани:

```powershell
docker exec demo-patroni2 patronictl list | Out-File ..\..\HW\screenshots\patronictl-failover.txt -Encoding utf8
```

Верни старого лидера (вернётся как Replica):

```powershell
docker start demo-patroni1
Start-Sleep -Seconds 30
docker exec demo-patroni1 patronictl list
```

### 7.3. Выключить одну etcd-ноду

```powershell
docker stop demo-etcd1
docker exec demo-patroni1 patronictl list
```

Кластер должен работать (кворум 2/3). Generator пишет/читает.

```powershell
docker start demo-etcd1
```

### 7.4. Выключить две etcd-ноды (потеря кворума)

```powershell
docker stop demo-etcd1
docker stop demo-etcd2
docker exec demo-patroni1 patronictl list
```

Failover невозможен, но текущий leader может ещё принимать write. Смотри generator.

```powershell
docker start demo-etcd1 demo-etcd2
Start-Sleep -Seconds 15
docker exec demo-patroni1 patronictl list
```

### 7.5. Выключить HAProxy

```powershell
docker stop demo-haproxy
```

Generator должен упасть с connection error — клиент не видит ноды напрямую.

```powershell
docker start demo-haproxy
Start-Sleep -Seconds 10
```

---

## Шаг 8. Grafana (опционально, для скриншотов)

Если нужны графики в отчёт §8:

```powershell
Start-Process "http://localhost:3000"
```

Логин `admin` / `admin`. Дашборды — из `grafana_dashboards\` (Import JSON), datasource Prometheus: `http://prometheus:9090`.

Проверка, что Prometheus жив:

```powershell
Invoke-RestMethod -Uri http://localhost:9090/-/healthy
```

---

## Шаг 9. Остановка

Останови generator в Окне 2 (`Ctrl+C`), затем **Окно 1**:

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha
docker compose down
```

---

## Шаг 10. Заполни отчёт

`HW\HW2_PRACTICE_SOLUTION.md`:
- §2 — вывод `patronictl list`
- §3 — HAProxy (терминал или `haproxy-stats.html`)
- §4.3 — `count(*)` master и replica
- §5 — наблюдения traffic-generator
- §6–7 — chaos-тесты
- §8 — Grafana (если делал)

Скриншоты/выводы: `HW\screenshots\`

### Если контейнеры `Exited (2)` и в логах `entrypoint.sh: Syntax error`

Причина: Git на Windows подменил переносы строк в `entrypoint.sh` (CRLF вместо LF).

```powershell
cd code\postgres-ha
git config core.autocrlf false
git pull
.\fix-line-endings.ps1
cd patroni-master
docker build --build-arg PG_MAJOR=15 -t patroni .
cd ..
docker compose down
docker compose up -d
Start-Sleep -Seconds 90
docker exec demo-patroni1 patronictl list
```

---

# Сдача

Telegram **@nikolaysavelev**:

1. `HW\HW1_PRACTICE_SOLUTION.md` (+ скриншоты)
2. `HW\HW2_PRACTICE_SOLUTION.md` (+ скриншоты)

SD (без Docker):

- `HW\HW2.md` → Telegram
- `HW\HW1.md` → GitHub PR. Перед PR:

```powershell
Copy-Item HW\HW1.md 2\HW1.md
```

---

# Частые ошибки на Windows

| Проблема | Решение |
|----------|---------|
| Docker не запускается | Включи WSL 2: `wsl --install`, перезагрузка |
| `docker compose` не найден | Обнови Docker Desktop или попробуй `docker-compose` |
| Порт 5432 занят | Останови локальный PostgreSQL в «Службы» Windows |
| `curl` ведёт себя странно | В PowerShell `curl` — это алиас; используй `curl.exe` или `Invoke-RestMethod` |
| `python` не найден | Установи Python с галочкой PATH, или `py -m pip install psycopg2-binary` |
| Grafana пустая | Datasource = `http://prometheus:9090` |
| Порт 5001/5002 недоступен | `docker ps` — haproxy Up? Подожди 90 сек после `compose up` |
| `psql` connection refused | Подключайся через `haproxy`, не напрямую в patroni: `-h haproxy -p 5001` |
| `docker build` timeout | `docker build --build-arg PG_MAJOR=15 -t patroni .` |
| `gzip: unexpected end of file` при build | GitHub оборвал etcd: `.\download-deps.ps1` затем `docker build -f Dockerfile.offline --build-arg PG_MAJOR=15 -t patroni .` |
| `entrypoint.sh: Syntax error` / `Exited (2)` | CRLF на Windows: см. ниже |
| Путь с пробелами | Возьми путь в кавычки: `cd "C:\Users\Имя\My Projects\..."` |

---

# Чеклист

**Practice HW1:**
- [ ] `docker compose up` в `code\demo-app-1`
- [ ] 2 пользователя созданы
- [ ] Grafana настроена
- [ ] 3 прогона k6
- [ ] Скриншоты в `HW\screenshots\`
- [ ] `HW1_PRACTICE_SOLUTION.md` отправлен

**Practice HW2:**
- [ ] `docker build -t patroni .` (или `--build-arg PG_MAJOR=15`)
- [ ] `docker compose up` в `code\postgres-ha`
- [ ] `patronictl list` + HAProxy через терминал
- [ ] SQL через `docker exec ... psql` + `init-schema.sql`
- [ ] `python traffic-generator.py`
- [ ] Chaos-тесты
- [ ] `HW2_PRACTICE_SOLUTION.md` отправлен
