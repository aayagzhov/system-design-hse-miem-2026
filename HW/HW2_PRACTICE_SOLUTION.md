# Practice HW2 — Patroni PostgreSQL HA Cluster

---

## 🔴 КУДА ВСТАВЛЯТЬ РЕЗУЛЬТАТЫ И КУДА СДАВАТЬ

### Куда **вставить** результаты (внутри этого файла)

| Что вставить | Раздел | Как |
|--------------|--------|-----|
| Дата | **Строка 33** ниже | Замени красный текст |
| Скриншот `patronictl list` | **§ 2** | Картинка вместо красного блока |
| Скриншот HAProxy :7001 | **§ 3** | Картинка |
| Результат SQL (count на master/replica) | **§ 4.3** | Замени красные цифры |
| Наблюдения traffic-generator | **§ 5** | Красный текст |
| Скриншот после recovery реплики | **§ 6.1** | Картинка |
| Скриншот нового Leader | **§ 6.2** | Картинка |
| Твои наблюдения chaos-тестов | **§ 7** — таблица | Замени красные ячейки |
| Скриншоты Grafana | **§ 8** | 1–2 картинки |
| Инсайты Grafana | **§ 8** | Красный текст |

**Скриншоты сохрани в:** `HW\screenshots\`  
**Пример:** `![patronictl](screenshots/patronictl-list.png)`

### Куда **сдать** готовый файл

| Куда | Что отправить |
|------|---------------|
| **Telegram @nikolaysavelev** | Файл `HW\HW2_PRACTICE_SOLUTION.md` |
| **Telegram (опционально)** | Скриншоты из `HW\screenshots\` |

> <span style="color:red; font-weight:bold;">Все места с красным «ЗАПОЛНИ» / «ВСТАВЬ» — замени после запуска кластера на Windows.</span>

---

**Автор:** Аягжов  
**Проект:** `code\postgres-ha`  
**ОС:** Windows (PowerShell)  
**Дата:** <span style="color:red; font-weight:bold;">ЗАПОЛНИ: например 21.06.2026</span>

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

> <span style="color:red; font-weight:bold;">▼ ВСТАВЬ СКРИНШОТ И ДАННЫЕ ИЗ ТВОЕГО КЛАСТЕРА ▼</span>

> **Действие (Windows PowerShell):** `docker exec demo-patroni1 patronictl list`  
> (флаг `-it` на Windows иногда мешает — без него тоже ок)

**Твой вывод (заполни по факту):**

| Member | Host | Role | State | TL | Lag |
|--------|------|------|-------|----|-----|
| patroni1 | patroni1 | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |
| patroni2 | patroni2 | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |
| patroni3 | patroni3 | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |

**Скриншот — <span style="color:red; font-weight:bold;">ВСТАВЬ СЮДА (§ 2)</span>:**  
<span style="color:red; font-weight:bold;">ВСТАВЬ СКРИНШОТ: вывод patronictl list в PowerShell</span>
`![patronictl list](screenshots/patronictl-list.png)`

**Выводы:**
- Один **Leader** (primary) — единственный принимает write
- Два **Replica** в состоянии `streaming` — синхронная репликация WAL
- `Lag = 0` — реплики не отстают

---

## 3. HAProxy Dashboard

> <span style="color:red; font-weight:bold;">▼ ВСТАВЬ СКРИНШОТ HAProxy ▼</span>

> **Действие:** открой http://localhost:7001/

**Скриншот — <span style="color:red; font-weight:bold;">ВСТАВЬ СЮДА (§ 3)</span>:**  
<span style="color:red; font-weight:bold;">ВСТАВЬ СКРИНШОТ: страница HAProxy stats в браузере</span>
`![HAProxy stats](screenshots/haproxy-stats.png)`

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

**Проверка репликации — <span style="color:red; font-weight:bold;">ЗАПОЛНИ ЦИФРЫ (§ 4.3)</span>:**
```sql
-- На master (5001)
SELECT count(*) FROM events;  -- результат: <span style="color:red;">ЗАПОЛНИ</span>

-- На replica (5002)
SELECT count(*) FROM events;  -- результат: <span style="color:red;">ЗАПОЛНИ (должно совпасть)</span>
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

**Наблюдение — <span style="color:red; font-weight:bold;">ЗАПОЛНИ (§ 5)</span>:**  
<span style="color:red;">ЗАПОЛНИ: пишется/читается? Были ли ошибки? Что видел в консоли traffic-generator?</span>

---

## 6. Chaos Engineering — тесты отказоустойчивости

> Запускай `traffic-generator.py` и **не останавливай** во время тестов.

### 6.1. Выключить реплику (не лидера)

```powershell
docker stop demo-patroni2
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Продолжает ли приложение работать? | **Да** — write идёт на leader |
| Что в `patronictl list`? | patroni2 — stopped/unavailable |
| Что в HAProxy? | patroni2 красный в read pool |

**Восстановление:**
```powershell
docker start demo-patroni2
# Через ~30s: patroni2 снова Replica, streaming
```

**Скриншот patronictl после recovery — <span style="color:red; font-weight:bold;">ВСТАВЬ (§ 6.1)</span>:**  
<span style="color:red; font-weight:bold;">ВСТАВЬ СКРИНШОТ: patronictl после docker start demo-patroni2</span>
`![recovery replica](screenshots/patronictl-recovery.png)`

---

### 6.2. Выключить лидера (failover)

```powershell
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
```powershell
docker start demo-patroni1
# patroni1 вернётся как Replica (не leader!)
```

**Скриншот — <span style="color:red; font-weight:bold;">ВСТАВЬ НОВОГО LEADER (§ 6.2)</span>:**  
<span style="color:red; font-weight:bold;">ВСТАВЬ СКРИНШОТ: patronictl после failover (кто стал Leader)</span>
`![failover leader](screenshots/patronictl-failover.png)`

**Твои наблюдения при падении лидера — <span style="color:red; font-weight:bold;">ЗАПОЛНИ</span>:**  
<span style="color:red;">ЗАПОЛНИ: сколько секунд были ошибки в traffic-generator? Кто стал новым Leader?</span>

---

### 6.3. Выключить etcd ноду

```powershell
docker stop demo-etcd1
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Продолжает ли кластер работать? | **Да** — кворум 2/3 (etcd2 + etcd3) |
| Чтение/запись? | **Да** |
| Failover возможен? | **Да** |

```powershell
# Выключи ещё одну — потеря кворума!
docker stop demo-etcd2
```

| Вопрос | Ожидаемый ответ |
|--------|-----------------|
| Что происходит? | **Кластер теряет способность к failover**; текущий leader продолжает работать, но новый leader не выберется |
| Запись? | Может работать, пока leader жив |

**Восстановление:**
```powershell
docker start demo-etcd1 demo-etcd2
```

**Вывод:** etcd требует кворум (N/2+1). Минимум 3 ноды, выдерживает падение 1.

---

### 6.4. Выключить HAProxy

```powershell
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

## 7. Сводная таблица chaos-тестов — <span style="color:red; font-weight:bold;">ЗАПОЛНИ ПО ФАКТУ (§ 7)</span>

| Тест | Downtime | Данные потеряны? | Автовосстановление? | Твой комментарий |
|------|----------|------------------|---------------------|------------------|
| Replica down | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |
| Leader down | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |
| 1 etcd down | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |
| 2 etcd down | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |
| HAProxy down | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> | <span style="color:red;">ЗАПОЛНИ</span> |

---

## 8. Grafana

> http://localhost:3000 (admin/admin)

Импорт дашбордов из `grafana_dashboards/` если не подтянулись автоматически.

**Дашборды для анализа:**
1. PostgreSQL / Patroni — replication lag, role changes
2. etcd — leader elections, raft index
3. HAProxy — backend health

**Скриншоты — <span style="color:red; font-weight:bold;">ВСТАВЬ 1–2 ШТУКИ (§ 8)</span>:**  
<span style="color:red; font-weight:bold;">ВСТАВЬ СКРИНШОТ: Grafana — replication lag / Patroni</span>
`![Grafana Patroni](screenshots/grafana-patroni.png)`

**Инсайты — <span style="color:red; font-weight:bold;">ЗАПОЛНИ (§ 8)</span>:**  
<span style="color:red;">ЗАПОЛНИ: видел ли скачок lag при failover? Смену leader на графиках?</span>

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
