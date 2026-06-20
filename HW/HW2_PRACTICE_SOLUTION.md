# Practice HW2 — Patroni PostgreSQL HA Cluster

**Автор:** Аягжов  
**Проект:** `code\postgres-ha`  
**ОС:** Windows (PowerShell)  
**Дата:**

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

```powershell
docker exec demo-patroni1 patronictl list
```

| Member | Host | Role | State | TL | Lag |
|--------|------|------|-------|----|-----|
| patroni1 | patroni1 | | | | |
| patroni2 | patroni2 | | | | |
| patroni3 | patroni3 | | | | |

![patronictl list](screenshots/patronictl-list.png)

**Выводы:**
- Один **Leader** (primary) — единственный принимает write
- Два **Replica** в состоянии `streaming` — синхронная репликация WAL
- `Lag = 0` — реплики не отстают

---

## 3. HAProxy Dashboard

http://localhost:7001/

![HAProxy stats](screenshots/haproxy-stats.png)

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

Выполнил скрипт из `hw2_practice.md` (таблицы `owners`, `events`, индексы, INSERT).

```sql
-- На master (5001)
SELECT count(*) FROM events;

-- На replica (5002)
SELECT count(*) FROM events;
```

---

## 5. Traffic Generator

```powershell
pip install psycopg2-binary
cd code\postgres-ha
python traffic-generator.py
```

**Поведение:**
- Каждую 1s: INSERT в `events`
- Каждые 2s: SELECT последних 3 записей
- Подключается к `localhost:5002` (HAProxy read-write endpoint)

**Наблюдения:**

---

## 6. Chaos Engineering — тесты отказоустойчивости

Запускал `traffic-generator.py` и не останавливал во время тестов.

### 6.1. Выключить реплику (не лидера)

```powershell
docker stop demo-patroni2
```

**Наблюдения:**

```powershell
docker start demo-patroni2
```

![recovery replica](screenshots/patronictl-recovery.png)

---

### 6.2. Выключить лидера (failover)

```powershell
docker exec demo-patroni1 patronictl list
docker stop demo-patroni1
```

**Наблюдения:**

```powershell
docker start demo-patroni1
```

![failover leader](screenshots/patronictl-failover.png)

---

### 6.3. Выключить etcd ноду

```powershell
docker stop demo-etcd1
```

**Наблюдения:**

```powershell
docker stop demo-etcd2
```

**Наблюдения при потере кворума:**

```powershell
docker start demo-etcd1 demo-etcd2
```

---

### 6.4. Выключить HAProxy

```powershell
docker stop demo-haproxy
```

**Наблюдения:**

**Как избежать в продакшене:**
1. **2+ HAProxy** с Keepalived (VIP floating)
2. **DNS round-robin** на несколько HAProxy
3. **Patroni REST API** напрямую в приложении (сложнее)
4. **Yandex Managed PostgreSQL** — LB встроен

---

## 7. Сводная таблица chaos-тестов

| Тест | Downtime | Данные потеряны? | Автовосстановление? | Комментарий |
|------|----------|------------------|---------------------|-------------|
| Replica down | | | | |
| Leader down | | | | |
| 1 etcd down | | | | |
| 2 etcd down | | | | |
| HAProxy down | | | | |

---

## 8. Grafana

http://localhost:3000 (admin/admin)

Импорт дашбордов из `grafana_dashboards/` если не подтянулись автоматически.

![Grafana Patroni](screenshots/grafana-patroni.png)

**Инсайты:**
