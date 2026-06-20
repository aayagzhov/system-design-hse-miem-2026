# Инструкция: практические домашки №1 и №2

Выполняй на компьютере с **Docker Desktop**.  
SD-отчёты (текст) уже готовы в этой папке — здесь только **практика**.

---

## Что тебе нужно сделать (кратко)

| # | Задача | Время | Результат |
|---|--------|-------|-----------|
| 1 | Practice HW1: запустить demo-app-1, прогнать 3 теста k6 | ~2 ч | Заполнить `HW_1_SOLUTION.md` + скриншоты |
| 2 | Practice HW2: запустить Patroni-кластер, chaos-тесты | ~2 ч | Заполнить `HW2_PRACTICE_SOLUTION.md` + скриншоты |
| 3 | Отправить оба файла в Telegram @nikolaysavelev | 5 мин | — |

---

## Подготовка (один раз)

### 1. Установи Docker Desktop

- Скачай: https://www.docker.com/products/docker-desktop/
- Установи, **запусти** (иконка в трее должна быть активна)
- Проверь в терминале:

```bash
docker --version
docker compose version
```

### 2. Склонируй / открой проект

```bash
cd /путь/к/system-design-hse-miem-2026
```

### 3. Python (только для Practice HW2)

```bash
pip3 install psycopg2-binary
```

---

# Practice HW1 — Нагрузочное тестирование

**Проект:** `code/demo-app-1`  
**Отчёт:** `HW/HW_1_SOLUTION.md` (текст готов — вставь свои цифры и скриншоты)

## Что это

Учебное приложение: API заказов + PostgreSQL + Nginx + Grafana.  
Ты имитируешь тысячи пользователей и смотришь, где система ломается.

## Шаг 1. Запуск

```bash
cd code/demo-app-1
docker compose up -d --build
```

Подожди 30 секунд. Проверка:

```bash
docker ps
curl http://localhost:8081/api/users
```

Браузер: http://localhost:8080 — должен открыться UI.

## Шаг 2. Создай пользователей для тестов

```bash
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"User1","email":"u1@test.com"}'

curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"User2","email":"u2@test.com"}'
```

## Шаг 3. Настрой Grafana

1. Открой http://localhost:3000 → логин `admin` / `admin`
2. **Connections → Data sources → Add → Prometheus**
3. URL: **`http://prometheus:9090`** (не localhost!)
4. Save & test
5. **Dashboards → Import** — загрузи JSON из `code/demo-app-1/dashboards/`:
   - Node Exporter
   - Postgres Overview
   - k6 Prometheus

## Шаг 4. Три сценария k6

Оставайся в `code/demo-app-1`. Между тестами жди **3 минуты**.

```bash
# Шторм: 1000 пользователей за 10 секунд (~2 мин)
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/storm.js

# Волна: 0 → 500 за 2 минуты (~5 мин)
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/wave.js

# Кастом: 95% чтение (~3 мин)
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/read-heavy.js
```

В конце каждого прогона в терминале будут цифры — **запиши** `p(95)` latency и `http_req_failed`.

## Шаг 5. Скриншоты Grafana

После тестов открой дашборды, выбери время прогона (Last 15 min), сделай скриншоты:

- k6: VUs и latency
- Postgres: connections
- Node/cAdvisor: CPU

Сохрани в `HW/screenshots/` (создай папку).

## Шаг 6. Заполни отчёт

Открой `HW/HW_1_SOLUTION.md`:

1. Таблица в разделе **4.1** — впиши RPS, p95, error rate
2. Вставь скриншоты вместо `_[ВСТАВЬ]_`
3. Допиши выводы в 4.2–4.4 своими словами (можно по шаблону в файле)

## Шаг 7. Остановка

```bash
docker compose down
```

---

# Practice HW2 — Patroni PostgreSQL HA

**Проект:** `code/postgres-ha`  
**Отчёт:** `HW/HW2_PRACTICE_SOLUTION.md`

## Что это

3 копии PostgreSQL + etcd + HAProxy. Если падает лидер — другая нода становится master автоматически.

## Шаг 1. Собери образ (первый раз, 5–10 мин)

```bash
cd code/postgres-ha/patroni-master
docker build -t patroni .
```

## Шаг 2. Запусти кластер

```bash
cd ..
docker compose up -d
```

Подожди **60–90 секунд**.

```bash
docker ps
docker exec -it demo-patroni1 patronictl list
```

**Скриншот** вывода `patronictl list` → в отчёт.

Ожидаешь: 1 Leader, 2 Replica, Lag = 0.

## Шаг 3. HAProxy

Браузер: http://localhost:7001/ — **скриншот** в отчёт.

## Шаг 4. SQL в базу

Подключись (DBeaver или psql):

| | Master | Replica |
|--|--------|---------|
| Host | localhost | localhost |
| Port | **5001** | **5002** |
| DB | postgres | postgres |
| User | postgres | postgres |
| Password | postgres | postgres |

Выполни SQL из `HWs/hw2_practice.md` (CREATE TABLE owners, events, INSERT).

Проверь на replica: `SELECT count(*) FROM events;` — число как на master.

## Шаг 5. Генератор нагрузки

**Отдельный терминал**, не закрывай:

```bash
cd code/postgres-ha
python3 traffic-generator.py
```

Должны идти логи INSERT и READ.

## Шаг 6. Chaos-тесты (ломаем по очереди)

**Третий терминал.** traffic-generator **не останавливай**.

```bash
# 1. Реплика (не лидер!)
docker stop demo-patroni2
# Смотри traffic-generator ~30 сек — должен работать
docker start demo-patroni2

# 2. Лидер (узнай через patronictl list)
docker stop demo-patroni1
# Ошибки 10–30 сек, потом снова INSERT
docker exec demo-patroni2 patronictl list   # новый Leader — скриншот
docker start demo-patroni1

# 3. Одна etcd
docker stop demo-etcd1
# Кластер работает
docker start demo-etcd1

# 4. Две etcd — нет кворума
docker stop demo-etcd2
# Failover не сработает
docker start demo-etcd1 demo-etcd2

# 5. HAProxy — всё падает
docker stop demo-haproxy
# traffic-generator — ошибки
docker start demo-haproxy
```

Заполни таблицу в `HW2_PRACTICE_SOLUTION.md` раздел 7.

## Шаг 7. Grafana (опционально)

http://localhost:3000 — импорт из `code/postgres-ha/grafana_dashboards/` если пусто.

## Шаг 8. Остановка

```bash
cd code/postgres-ha
docker compose down
```

---

# Сдача

Отправь в Telegram **@nikolaysavelev**:

1. `HW/HW_1_SOLUTION.md` (+ скриншоты)
2. `HW/HW2_PRACTICE_SOLUTION.md` (+ скриншоты)

SD-часть (без Docker):

- `HW/HW2.md` — в Telegram
- `HW/HW1.md` — GitHub PR (перед PR: `cp HW/HW1.md 2/HW1.md`)

---

# Частые ошибки

| Проблема | Решение |
|----------|---------|
| Порт 5432 занят | Останови локальный PostgreSQL |
| Grafana пустая | Datasource URL = `http://prometheus:9090` |
| k6 connection refused | `docker compose up -d`, подожди 30 сек |
| patroni build долго | Нормально при первом билде |
| traffic-generator не коннектится | Подожди 60 сек после `docker compose up` |

---

# Чеклист перед отправкой

**Practice HW1:**
- [ ] 3 прогона k6 (storm, wave, read-heavy)
- [ ] Скриншоты Grafana
- [ ] Таблица 4.1 заполнена
- [ ] `HW_1_SOLUTION.md` отправлен

**Practice HW2:**
- [ ] `patronictl list` — скриншот
- [ ] HAProxy :7001 — скриншот
- [ ] SQL выполнен
- [ ] traffic-generator работал
- [ ] Chaos: leader, replica, etcd, haproxy
- [ ] `HW2_PRACTICE_SOLUTION.md` отправлен
