# Инструкция: практические домашки №1 и №2 (Windows)

Выполняй на **Windows** с **Docker Desktop**.  
Открой **PowerShell** или **Windows Terminal** (не обязательно WSL).

SD-отчёты уже готовы в папке `HW/` — здесь только **практика**.

---

## Что тебе нужно сделать (кратко)

| # | Задача | Время | Результат |
|---|--------|-------|-----------|
| 1 | Practice HW1: demo-app-1 + 3 теста k6 | ~2 ч | `HW_1_SOLUTION.md` + скриншоты |
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
**Отчёт:** `HW\HW_1_SOLUTION.md`

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

Открой `HW\HW_1_SOLUTION.md` — таблица 4.1, скриншоты, выводы.

## Шаг 7. Остановка

```powershell
cd ..\..\code\demo-app-1
docker compose down
```

---

# Practice HW2 — Patroni PostgreSQL HA

**Проект:** `code\postgres-ha`  
**Отчёт:** `HW\HW2_PRACTICE_SOLUTION.md`

## Шаг 1. Собери образ (первый раз, 5–15 мин)

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha\patroni-master
docker build -t patroni .
```

Дождись `Successfully tagged patroni:latest`.

## Шаг 2. Запусти кластер

```powershell
cd ..
docker compose up -d
```

Подожди **60–90 секунд**.

```powershell
docker ps
docker exec -it demo-patroni1 patronictl list
```

**Скриншот** вывода → в отчёт. Ожидаешь: 1 Leader, 2 Replica.

> Если `docker exec` ругается на TTY — убери `-it`:
> `docker exec demo-patroni1 patronictl list`

## Шаг 3. HAProxy

Браузер: http://localhost:7001/ — скриншот в отчёт.

## Шаг 4. SQL в базу

**DBeaver** (рекомендуется на Windows): https://dbeaver.io/download/

| | Master | Replica |
|--|--------|---------|
| Host | localhost | localhost |
| Port | **5001** | **5002** |
| Database | postgres | postgres |
| User | postgres | postgres |
| Password | postgres | postgres |

SQL скопируй из `HWs\hw2_practice.md` (CREATE TABLE + INSERT).

Проверь на replica: `SELECT count(*) FROM events;`

## Шаг 5. Генератор нагрузки

**Второе окно PowerShell** (первое не закрывай):

```powershell
cd C:\Users\ТВОЙ_ЮЗЕР\Study\system-design-hse-miem-2026\code\postgres-ha
python traffic-generator.py
```

Если `python` не найден — попробуй `py traffic-generator.py`

## Шаг 6. Chaos-тесты

**Третье окно PowerShell.** `traffic-generator` не останавливай.

```powershell
# 1. Реплика (не лидер!)
docker stop demo-patroni2
# Смотри traffic-generator ~30 сек
docker start demo-patroni2

# 2. Лидер
docker exec demo-patroni1 patronictl list
docker stop demo-patroni1
# Ошибки 10–30 сек, потом снова INSERT
docker exec demo-patroni2 patronictl list
docker start demo-patroni1

# 3. Одна etcd
docker stop demo-etcd1
docker start demo-etcd1

# 4. Две etcd — нет кворума
docker stop demo-etcd2
docker start demo-etcd1 demo-etcd2

# 5. HAProxy — всё падает
docker stop demo-haproxy
docker start demo-haproxy
```

## Шаг 7. Остановка

```powershell
cd code\postgres-ha
docker compose down
```

---

# Сдача

Telegram **@nikolaysavelev**:

1. `HW\HW_1_SOLUTION.md` (+ скриншоты)
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
| Медленный первый build | Нормально, жди 10–15 мин |
| Путь с пробелами | Возьми путь в кавычки: `cd "C:\Users\Имя\My Projects\..."` |

---

# Чеклист

**Practice HW1:**
- [ ] `docker compose up` в `code\demo-app-1`
- [ ] 2 пользователя созданы
- [ ] Grafana настроена
- [ ] 3 прогона k6
- [ ] Скриншоты в `HW\screenshots\`
- [ ] `HW_1_SOLUTION.md` отправлен

**Practice HW2:**
- [ ] `docker build -t patroni .`
- [ ] `docker compose up` в `code\postgres-ha`
- [ ] Скриншот `patronictl list` и HAProxy
- [ ] SQL в DBeaver
- [ ] `python traffic-generator.py`
- [ ] Chaos-тесты
- [ ] `HW2_PRACTICE_SOLUTION.md` отправлен
