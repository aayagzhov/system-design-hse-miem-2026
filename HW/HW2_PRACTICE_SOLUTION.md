# Practice HW2 — Patroni PostgreSQL HA Cluster

**Автор:** Аягжов  
**Проект:** `code/postgres-ha`  
**Дата:** _[заполни после запуска]_

---

## 0. Чеклист перед сдачей

- [ ] Docker установлен
- [ ] Образ Patroni собран: `docker build -t patroni .`
- [ ] Кластер поднят: `docker compose up -d` из `postgres-ha/`
- [ ] `patronictl list` — скриншот
- [ ] HAProxy stats http://localhost:7001/ — скриншот
- [ ] SQL-скрипт пролит в master (порт 5001)
- [ ] `traffic-generator.py` запущен
- [ ] Chaos-тесты: выключение leader, replica, etcd, haproxy
- [ ] Grafana дашборды просмотрены
- [ ] Файл отправлен @nikolaysavelev в Telegram

---

## 1. Архитектура кластера

### 1.1. Компоненты

```
                    ┌─────────────┐
                    │   Client    │
                    │ (psql/DBeaver│
                    │  traffic-gen)│
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  HAProxy    │ :5001 (write/master)
                    │  :7001 stats│ :5002 (read/replicas)
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
    │  patroni1   │ │  patroni2   │ │  patroni3   │
    │  PostgreSQL │ │  PostgreSQL │ │  PostgreSQL │
    │  + Patroni  │ │  + Patroni  │ │  + Patroni  │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
           └───────────────┼───────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼───┐ ┌──────▼───┐ ┌──────▼───┐
       │  etcd1   │ │  etcd2   │ │  etcd3   │
       │  (DCS)   │ │  (DCS)   │ │  (DCS)   │
       └──────────┘ └──────────┘ └──────────┘
```

### 1.2. Роли компонентов

| Компонент | Роль | Аналогия |
|-----------|------|----------|
| **etcd** | DCS (Distributed Configuration Store). Хранит leader key, состояние кластера. Raft-кворум 2/3 | «Мозг» — кто сейчас master |
| **Patroni** | Sidecar на каждой ноде PG. Борется за leader key в etcd. Держит ключ → primary; нет ключа → replica | «Выборы» лидера |
| **HAProxy** | Опрашивает Patroni REST API, маршрутизирует write на leader, read на replicas | «Диспетчер» для клиента |
| **PostgreSQL** | Данные. Streaming replication primary → standby | «Склад» |

### 1.3. Порты

| Порт | Назначение |
|------|------------|
| 5001 | Write (master) через HAProxy |
| 5002 | Read (replicas) через HAProxy |
| 7001 | HAProxy stats UI |
| 9090 | Prometheus |
| 3000 | Grafana |
| 9187 | postgres-exporter |

---

## 2. Состав кластера (`patronictl list`)

> **Действие:** `docker exec -it demo-patroni1 patronictl list`

**Ожидаемый вывод:**

| Member | Host | Role | State | TL | Lag |
|--------|------|------|-------|----|-----|
| patroni1 | patroni1 | Leader | running | _N_ | 0 |
| patroni2 | patroni2 | Replica | streaming | _N_ | 0 |
| patroni3 | patroni3 | Replica | streaming | _N_ | 0 |

**Скриншот:** _[ВСТАВЬ]_

**Выводы:**
- Один **Leader** (primary) — единственный принимает write
- Два **Replica** в состоянии `streaming` — синхронная репликация WAL
- `Lag = 0` — реплики не отстают

---

## 3. HAProxy Dashboard

> **Действие:** открой http://localhost:7001/

**Скриншот:** _[ВСТАВЬ]_

**Выводы:**
- Backend `patroni_write` — зелёный только у текущего leader
- Backend `patroni_read` — зелёные все replicas
- HAProxy автоматически переключает при failover

---

## 4. Подключение и SQL-скрипт

### 4.1. Master (write) — порт 5001

```
Host: localhost
Port: 5001
Database: postgres
User: postgres
Password: postgres
```

### 4.2. Replica (read) — порт 5002

```
Port: 5002
(остальное то же)
```

### 4.3. SQL

Выполни скрипт из `hw2_practice.md` (таблицы `owners`, `events`, индексы, INSERT).

**Проверка репликации:**
```sql
-- На master (5001)
SELECT count(*) FROM events;

-- На replica (5002) — то же число
SELECT count(*) FROM events;
```

---

## 5. Traffic Generator

```bash
pip3 install psycopg2-binary
cd code/postgres-ha
python3 traffic-generator.py
```

**Поведение:**
- Каждую 1s: INSERT в `events`
- Каждые 2s: SELECT последних 3 записей
- Подключается к `localhost:5002` (HAProxy read-write endpoint)

**Наблюдение:** _[заполни: пишется/читается? откуда?]_

---

## 6. Chaos Engineering — тесты отказоустойчивости

> Запускай `traffic-generator.py` и **не останавливай** во время тестов.

### 6.1. Выключить реплику (не лидера)

```bash
docker stop demo-patroni2
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Продолжает ли приложение работать? | **Да** — write идёт на leader |
| Что в `patronictl list`? | patroni2 — stopped/unavailable |
| Что в HAProxy? | patroni2 красный в read pool |

**Восстановление:**
```bash
docker start demo-patroni2
# Через ~30s: patroni2 снова Replica, streaming
```

**Скриншот patronictl после recovery:** _[ВСТАВЬ]_

---

### 6.2. Выключить лидера (failover)

```bash
# Узнай кто leader
docker exec demo-patroni1 patronictl list
# Останови leader (например patroni1)
docker stop demo-patroni1
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Продолжает ли приложение работать? | **Кратковременный сбой** 5–30s, затем **да** |
| Что происходит? | Patroni на patroni2/3 захватывает leader key в etcd |
| Новый leader? | Один из оставшихся (например patroni2) |
| traffic-generator? | Ошибки connection ~10–30s, затем восстановление |

**Восстановление старого лидера:**
```bash
docker start demo-patroni1
# patroni1 вернётся как Replica (не leader!)
```

**Вывод:** Автоматический failover работает. RTO ~10–30s без HA для HAProxy.

**Скриншот:** _[ВСТАВЬ patronictl с новым leader]_

---

### 6.3. Выключить etcd ноду

```bash
docker stop demo-etcd1
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Продолжает ли кластер работать? | **Да** — кворум 2/3 (etcd2 + etcd3) |
| Чтение/запись? | **Да** |
| Failover возможен? | **Да** |

```bash
# Выключи ещё одну — потеря кворума!
docker stop demo-etcd2
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Что происходит? | **Кластер теряет способность к failover**; текущий leader продолжает работать, но новый leader не выберется |
| Запись? | Может работать, пока leader жив |

**Восстановление:**
```bash
docker start demo-etcd1 demo-etcd2
```

**Вывод:** etcd требует кворум (N/2+1). Минимум 3 ноды, выдерживает падение 1.

---

### 6.4. Выключить HAProxy

```bash
docker stop demo-haproxy
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Продолжает ли приложение работать? | **Нет** — клиент не знает IP нод напрямую |
| Достаточная ли отказоустойчивость? | **Нет** — HAProxy = SPOF |

**Как избежать в продакшене:**
1. **2+ HAProxy** с Keepalived (VIP floating)
2. **DNS round-robin** на несколько HAProxy
3. **Patroni REST API** напрямую в приложении (сложнее)
4. **Yandex Managed PostgreSQL** — LB встроен

---

## 7. Сводная таблица chaos-тестов (заполни)

| Тест | Downtime | Данные потеряны? | Автовосстановление? |
|------|----------|------------------|---------------------|
| Replica down | 0 | Нет | Да (rejoin) |
| Leader down | 10–30s | Нет (async repl) | Да (failover) |
| 1 etcd down | 0 | Нет | — |
| 2 etcd down | Failover невозможен | — | Нет |
| HAProxy down | Полный | — | Нет (SPOF) |

---

## 8. Grafana

> http://localhost:3000 (admin/admin)

Импорт дашбордов из `grafana_dashboards/` если не подтянулись автоматически.

**Дашборды для анализа:**
1. PostgreSQL / Patroni — replication lag, role changes
2. etcd — leader elections, raft index
3. HAProxy — backend health

**Скриншоты:** _[ВСТАВЬ 1–2 скриншота]_

**Инсайты:** _[заполни: видел ли скачок lag при failover, смену leader в метриках]_

---

## 9. Связь с теорией курса

| Концепция курса | Как проявилась в практике |
|-----------------|---------------------------|
| **SPOF** | HAProxy — единая точка отказа без HA |
| **Кворум (Raft)** | etcd 3 ноды, выдерживает 1 падение |
| **RTO / RPO** | RTO failover ~10–30s; RPO ~0 при sync repl |
| **Single-Leader replication** | Один primary, N replicas |
| **DCS** | etcd хранит leader key |
| **Load Balancer** | HAProxy маршрутизирует read/write |
| **Observability** | Prometheus + Grafana для lag и role |

---

## 10. Итог

1. Развернул Patroni-кластер: 3 PG + 3 etcd + HAProxy.
2. Убедился в репликации данных master → replica.
3. Провёл chaos-тесты: failover leader работает, etcd требует кворум, HAProxy — SPOF.
4. Понял production-рекомендации: HA для HAProxy, минимум 3 etcd, мониторинг lag.

Для кейса Avito (HW2): PostgreSQL primary + 2 async replica в МСК/СПб — тот же паттерн, масштабированный.
