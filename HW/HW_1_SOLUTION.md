# Practice HW1 — Нагрузочное тестирование demo-app-1

**Автор:** Аягжов  
**Проект:** `code/demo-app-1`  
**Дата прогона:** _[заполни после запуска на другом компе]_

---

## 0. Чеклист перед сдачей

- [ ] Docker Desktop установлен и запущен
- [ ] `docker compose up -d --build` — все контейнеры `Up`
- [ ] Grafana: datasource Prometheus = `http://prometheus:9090`
- [ ] Импортированы дашборды из `dashboards/`
- [ ] Прогнаны 3 сценария k6
- [ ] Скриншоты Grafana вставлены в раздел 4
- [ ] Файл отправлен @nikolaysavelev в Telegram

---

## 1. Архитектура и роль компонентов

### 1.1. Схема

```
Browser → Nginx :8080 → Backend Go :8081 → PostgreSQL :5432
                              ↓
                    Prometheus :9090 ← exporters
                              ↓
                         Grafana :3000
                    k6 → remote_write → Prometheus
```

### 1.2. Зачем каждый компонент

| Компонент | Зачем | Что будет без него |
|-----------|-------|-------------------|
| **Nginx** | Reverse proxy: статика (`/`), проксирование API (`/api/`), единая точка входа :8080 | Клиент ходит напрямую в backend; нет разделения static/API |
| **Backend (Go)** | Бизнес-логика, REST API, Prometheus-метрики `/metrics` | Нет приложения |
| **PostgreSQL** | Персистентность users/orders | Нет данных |
| **Prometheus** | Сбор метрик (scrape 15s): backend, postgres, node, cAdvisor | Слепая зона — не видим деградацию |
| **Grafana** | Визуализация, корреляция метрик во времени | Метрики есть, но нечитаемы |
| **k6** | Генерация нагрузки + remote write в Prometheus | Нет воспроизводимого НТ |
| **postgres-exporter** | `pg_stat_activity`, locks, TPS, connections | Не видим состояние БД |
| **node-exporter** | CPU, RAM, disk, network хоста | Не отличим «упёрлись в железо» от «упёрлись в код» |
| **cAdvisor** | CPU/RAM per container | Не видим, какой контейнер жрёт ресурсы |

### 1.3. Поток запроса (POST /api/orders)

1. k6 → `localhost:8081/api/orders` (или через Nginx `8080`)
2. Backend: middleware → histogram `http_request_duration_seconds`
3. SQL INSERT → histogram `db_query_duration_seconds`
4. Counter `http_requests_total{method,path,status}`
5. postgres-exporter фиксирует active connections, locks

---

## 2. Этап №1 — Какие метрики отслеживать

### 2.1. RED-метрики (по сервису)

| Метрика | Источник | Зачем |
|---------|----------|-------|
| **Rate** — RPS | `http_requests_total` | Понять, выдерживает ли система целевую нагрузку |
| **Errors** — error rate | `http_requests_total{status=5xx}` | Деградация под нагрузкой |
| **Duration** — latency p50/p95/p99 | `http_request_duration_seconds` | SLA, UX |

### 2.2. Метрики БД (критично — write-heavy сценарий)

| Метрика | Источник | Зачем |
|---------|----------|-------|
| Active connections | `pg_stat_activity_count` | Connection pool exhaustion |
| Idle vs active | postgres-exporter | Утечка соединений |
| Transaction rate | `pg_stat_database_xact_commit` | Throughput БД |
| Lock waits | `pg_locks_count` | Конкуренция за INSERT |
| Query duration | `db_query_duration_seconds` (backend) | Bottleneck в SQL |

### 2.3. Метрики инфраструктуры

| Метрика | Источник | Зачем |
|---------|----------|-------|
| CPU % per container | cAdvisor | Backend vs DB — кто упёрся |
| Memory | cAdvisor + node | OOM risk |
| Network I/O | node-exporter | Сеть как bottleneck |
| Disk I/O | node-exporter | WAL, INSERT pressure |

### 2.4. Метрики k6

| Метрика | Зачем |
|---------|-------|
| `http_req_duration` p95 | End-to-end latency под нагрузкой |
| `http_req_failed` | % неуспешных запросов |
| `vus` | Текущие виртуальные пользователи |
| `iterations` | Сколько итераций завершено |

### 2.5. Гипотезы до прогона

1. **Шторм (1000 VU за 10s):** PostgreSQL станет bottleneck — connection pool Go `sql.DB` по умолчанию неограничен, но PG `max_connections=200`; ожидаем рост latency и 5xx.
2. **Волна (0→500 за 2min):** Система адаптируется плавно; метрики растут линейно, без резкого error spike.
3. **Read-heavy (95% GET):** Latency ниже, чем в write-heavy; Nginx кэширует мало, но GET дешевле INSERT.

---

## 3. Этап №2 — Сценарии нагрузки

### 3.1. Сценарий «Шторм»

**Скрипт:** `k6/scripts/storm.js`  
**Профиль:** 0 → 1000 VU за 10s, держим 1 min, сброс 30s  
**Распределение:** 80% POST `/api/orders`, 20% GET `/api/orders`

```bash
cd code/demo-app-1
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/storm.js
```

**Что проверяем:** резкий пик, восстановление после него.

### 3.2. Сценарий «Волна»

**Скрипт:** `k6/scripts/wave.js`  
**Профиль:** 0 → 500 VU за 2 min, плато 2 min, сброс 1 min

```bash
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/wave.js
```

**Что проверяем:** плавное нарастание, есть ли «полка» по RPS.

### 3.3. Сценарий «Read-heavy» (кастомный)

**Скрипт:** `k6/scripts/read-heavy.js`  
**Фишка:** 95% GET / 5% POST — противоположность дефолтному скрипту.  
Показывает, что bottleneck зависит от профиля: write → БД, read → backend/сеть.

```bash
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/read-heavy.js
```

### 3.4. Базовый сценарий (оригинал)

```bash
docker compose run --rm k6 run --out experimental-prometheus-rw /scripts/load-script.js
```

---

## 4. Этап №3 — Анализ результатов

> **Инструкция:** после каждого прогона открой Grafana (http://localhost:3000), выбери временной диапазон теста, сделай скриншоты и заполни таблицы ниже.

### 4.1. Сводная таблица (заполни)

| Сценарий | Peak VU | RPS (peak) | p95 latency | Error rate | Главный bottleneck |
|----------|---------|------------|-------------|------------|-------------------|
| Шторм | _1000_ | _[ ]_ | _[ ] ms_ | _[ ]%_ | _[ ]_ |
| Волна | _500_ | _[ ]_ | _[ ] ms_ | _[ ]%_ | _[ ]_ |
| Read-heavy | _400_ | _[ ]_ | _[ ] ms_ | _[ ]%_ | _[ ]_ |

### 4.2. Шторм — инсайты

**Ожидаемое поведение (сверь с графиками):**

- `http_req_duration` p95: скачок до 1–5s в первые 10–20s
- `pg_stat_activity`: active connections → к `max_connections` (200)
- `http_requests_total{status="500"}`: рост при исчерпании пула
- CPU backend container: 80–100%
- После сброса VU (30s ramp-down): latency возвращается к baseline за 1–2 min

**Скриншоты:**
- _[ВСТАВЬ: k6 Prometheus dashboard — latency + VUs]_
- _[ВСТАВЬ: Postgres Overview — connections + transactions]_
- _[ВСТАВЬ: cAdvisor — backend CPU]_

**Вывод:**  
_[Заполни: например «При 1000 VU за 10s PostgreSQL исчерпал connections, backend начал отдавать 500. Система восстановилась через ~90s после снижения нагрузки»]_

### 4.3. Волна — инсайты

**Ожидаемое поведение:**

- Метрики растут плавно, без резкого error spike
- RPS ≈ линейно с VU до «полки» (CPU или DB)
- p95 latency: постепенный рост, не обрыв

**Скриншоты:**
- _[ВСТАВЬ: Grafana — RPS over time]_

**Вывод:**  
_[Заполни]_

### 4.4. Read-heavy — инсайты

**Ожидаемое поведение:**

- p95 latency **ниже**, чем в write-heavy при том же VU
- PostgreSQL connections **ниже** (GET `SELECT ... LIMIT 100` дешевле INSERT)
- RPS **выше** — read не ждёт WAL flush

**Сравнение с write-heavy:**

| Метрика | Write-heavy (80% POST) | Read-heavy (95% GET) |
|---------|------------------------|----------------------|
| p95 latency | выше | ниже |
| DB connections | выше | ниже |
| Error rate при пике | выше | ниже |

**Вывод:**  
_[Заполни: «Подтвердил гипотезу — bottleneck смещается в зависимости от профиля нагрузки»]_

---

## 5. Этап №4 — Решения и рекомендации

### 5.1. Bottleneck: PostgreSQL connections

**Проблема:** Go `sql.Open` без `SetMaxOpenConns` → неограниченный пул → PG `max_connections=200` исчерпывается.

**Решения:**
1. `db.SetMaxOpenConns(50)` + `SetMaxIdleConns(10)` в backend
2. PgBouncer перед PostgreSQL (transaction pooling)
3. Увеличить `max_connections` (временная мера, не масштабируется)

### 5.2. Bottleneck: write-heavy INSERT

**Проблема:** 80% POST создают конкуренцию за INSERT в `orders`.

**Решения:**
1. Batch INSERT в k6 не поможет пользователям — нужна очередь (Kafka) для write path
2. Read replicas для GET (уже 20% трафика)
3. Горизонтальное масштабирование backend (`docker-compose-lb.yaml` + HAProxy)

### 5.3. Bottleneck: нет backpressure

**Проблема:** при шторме k6 продолжает слать запросы, система не отбрасывает нагрузку gracefully.

**Решения:**
1. Rate limiting в Nginx (`limit_req_zone`)
2. Circuit breaker в backend
3. Auto-scaling backend pods (K8s HPA по CPU)

### 5.4. Observability improvements (звёздочка)

Добавить метрики:
- `db_pool_open_connections` — gauge текущего пула
- `db_pool_wait_duration` — время ожидания свободного connection
- Alert: `pg_stat_activity > 180` → PagerDuty

### 5.5. HAProxy — горизонтальное масштабирование

```bash
docker compose -f docker-compose-lb.yaml up -d --build
```

3 инстанса backend за round-robin → RPS ×3, отказ одного инстанса не роняет систему.

---

## 6. Полезные PromQL-запросы

```promql
# RPS backend
rate(http_requests_total[1m])

# p95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[1m]))

# Error rate
rate(http_requests_total{status=~"5.."}[1m]) / rate(http_requests_total[1m])

# PostgreSQL active connections
pg_stat_activity_count{state="active"}

# DB query p95
histogram_quantile(0.95, rate(db_query_duration_seconds_bucket[1m]))
```

---

## 7. Итог

1. **Запустил** demo-app-1, прогнал 3 сценария k6.
2. **Спроектировал** набор метрик RED + DB + infra до прогона.
3. **Проанализировал** дашборды, связал с гипотезами.
4. **Предложил** решения: connection pool, PgBouncer, rate limiting, HAProxy, observability.

Связь с курсом: закон Литтла (`L = λ × W`), горизонтальное масштабирование, роль Nginx как reverse proxy, observability stack как основа НФТ.
