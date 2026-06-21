# Practice HW2 — команды и скриншоты

Пошаговый чеклист для Windows (PowerShell).  
Все команды из папки `code\postgres-ha`, если не указано иное.

Папка для скринов и выводов:

```powershell
New-Item -ItemType Directory -Force -Path ..\..\HW\screenshots
```

---

## 0. Поднять кластер

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha
.\fix-and-rebuild.ps1
```

Если образ уже собран:

```powershell
docker compose up -d
Start-Sleep -Seconds 90
docker ps
```

Все контейнеры должны быть `Up` (patroni1–3, etcd1–3, haproxy, grafana, prometheus).

---

## Скрин 1 — §2 patronictl list

**Команда:**

```powershell
docker exec demo-patroni1 python3 /patronictl.py list
```

**Сохранить текст:**

```powershell
docker exec demo-patroni1 python3 /patronictl.py list | Out-File ..\..\HW\screenshots\patronictl-list.txt -Encoding utf8
```

**Скриншот:** терминал с таблицей (1 Leader + 2 Replica, lag 0).

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\patronictl-list.png` | §2 |

---

## Скрин 2 — §3 HAProxy stats

**Команда (проверка):**

```powershell
Invoke-WebRequest -Uri http://localhost:7001/ -UseBasicParsing | Select-Object StatusCode
```

**Открыть в браузере:** http://localhost:7001/

**Скриншот:** страница stats — backends `primary` и `replicas`, кто UP/DOWN.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\staatic_report_ha_proxy.png` | §3 |

> Если файл уже есть — можно не переделывать, только проверь что кластер Up.

---

## §4 SQL — скрин опциональный

**Пролить схему (master):**

```powershell
Get-Content init-schema.sql | docker exec -i -e PGPASSWORD=postgres demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres
```

**Проверка репликации:**

```powershell
docker exec -e PGPASSWORD=postgres demo-patroni1 psql -U postgres -h haproxy -p 5000 -d postgres -c "SELECT count(*) FROM events;"
docker exec -e PGPASSWORD=postgres demo-patroni1 psql -U postgres -h haproxy -p 5001 -d postgres -c "SELECT count(*) FROM events;"
```

Оба `count(*)` должны совпасть (после init-schema — **2**).

**Скриншот (по желанию):** терминал с обоими count.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\sql-replication.png` | §4.3 |

---

## §5 Traffic generator — скрин опциональный

**Терминал 1** (оставить открытым):

```powershell
pip install psycopg2-binary
python traffic-generator.py
```

Должны идти строки `INSERT` и `READ check`.

**Скриншот (по желанию):** терминал с логами generator.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\traffic-generator.png` | §5 |

---

## §6 Chaos — скрины опциональные

Generator крутится в **терминале 1**. Команды — в **терминале 2**.

### 6.1 Replica down

```powershell
docker exec demo-patroni1 python3 /patronictl.py list
docker stop demo-patroni2
docker exec demo-patroni1 python3 /patronictl.py list
docker start demo-patroni2
Start-Sleep -Seconds 30
docker exec demo-patroni1 python3 /patronictl.py list
```

**Скрин:** patronictl где patroni2 = `stopped`.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\patronictl-replica-down.png` | §6.1 |

```powershell
docker exec demo-patroni1 python3 /patronictl.py list | Out-File ..\..\HW\screenshots\patronictl-recovery.txt -Encoding utf8
```

### 6.2 Leader down (failover)

Узнай кто Leader:

```powershell
docker exec demo-patroni1 python3 /patronictl.py list
```

Останови **Leader** (например patroni2 или patroni3):

```powershell
docker stop demo-patroni2
Start-Sleep -Seconds 15
docker exec demo-patroni1 python3 /patronictl.py list
```

Должен появиться **новый Leader**, TL вырастет (1 → 2).

**Скрин:** patronictl с новым Leader + generator с `CONNECTION LOST` → `CONNECTED`.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\patronictl-failover.png` | §6.2 |

```powershell
docker start demo-patroni2
docker exec demo-patroni1 python3 /patronictl.py list | Out-File ..\..\HW\screenshots\patronictl-failover.txt -Encoding utf8
```

### 6.3 etcd down

**1 нода (кворум есть):**

```powershell
docker stop demo-etcd1
docker exec demo-patroni1 python3 /patronictl.py list
docker start demo-etcd1
```

**2 ноды (кворум потерян):**

```powershell
docker stop demo-etcd1
docker stop demo-etcd2
docker exec demo-patroni1 python3 /patronictl.py list
```

Ожидается ошибка `Etcd is not responding properly`. В generator — `CONNECTION LOST`, `read-only`.

**Скрин:** терминал с ошибкой patronictl + generator.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\etcd-down.png` | §6.3 |

**Восстановить:**

```powershell
docker start demo-etcd1 demo-etcd2
Start-Sleep -Seconds 15
```

### 6.4 HAProxy down

```powershell
docker stop demo-haproxy
```

В generator: `Connection refused` на `localhost:5002`.

**Скрин:** терминал generator с ошибкой.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\haproxy-down.png` | §6.4 |

**Восстановить:**

```powershell
docker start demo-haproxy
```

---

## Скрин 3 — §8 Grafana

```powershell
Start-Process "http://localhost:3000"
```

Login: `admin` / `admin`  
Dashboard: **Postgres Overview** (General → Postgres Overview)

**Скриншот:** графики QPS, connections, rows inserted/returned.

| Сохранить как | Куда в отчёте |
|---------------|---------------|
| `HW\screenshots\postgres.png` | §8 |

> Если файл уже есть — можно не переделывать.

---

## Минимум для сдачи (2 обязательных скрина)

| # | Файл | Раздел |
|---|------|--------|
| 1 | `patronictl-list.png` **или** `patronictl-list.txt` | §2 |
| 2 | `staatic_report_ha_proxy.png` | §3 |
| 3 | `postgres.png` | §8 (рекомендуется) |

Остальные скрины — по желанию, отчёт уже заполнен текстом.

---

## После скринов

1. Если сделал новые png — напиши, вставлю их в `HW2_PRACTICE_SOLUTION.md`.
2. Отправь в Telegram @nikolaysavelev:
   - `HW\HW2_PRACTICE_SOLUTION.md`
   - `HW\screenshots\` (папка целиком)

---

## Порты (чтобы не перепутать)

| Куда | Host (Windows) | Внутри docker-сети |
|------|----------------|---------------------|
| **Write (master)** | `localhost:5002` | `haproxy:5000` |
| **Read (replica)** | `localhost:5001` | `haproxy:5001` |
| HAProxy stats | `localhost:7001` | — |
| Grafana | `localhost:3000` | — |

**Важно:** `CREATE TABLE` только через master (`5000` / `5002`). На `5001` будет `read-only transaction`.
