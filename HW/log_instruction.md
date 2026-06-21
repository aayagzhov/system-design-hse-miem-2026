# Логи и сборка кластера (Windows)

## Одна команда (основная)

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha; .\fix-and-rebuild.ps1
```

Скрипт: `git pull` → LF → vendor → offline build → `compose up` → `patronictl list`.

---

## Если нет vendor (GitHub не качается)

Папка: `code\postgres-ha\patroni-master\vendor\`

| Сохранить как | Ссылка |
|---------------|--------|
| `etcd.tar.gz` | https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz |
| `confd` (без расширения) | https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64 |

Проверка:

```powershell
dir C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha\patroni-master\vendor
```

Потом снова одна команда выше.

**Сейчас у тебя:** etcd есть, нужен только `confd` → см. `HW/error`.

---

## Сбор логов для отладки

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha
.\collect-cluster-debug.ps1
```

```powershell
cd C:\Users\User\CppProjects\system-design-hse-miem-2026
git add HW/cluster-debug.txt
git commit -m "debug: patroni cluster logs"
git push
```

---

## Типичные ошибки

| Симптом | Причина | Решение |
|---------|---------|---------|
| `entrypoint.sh: Syntax error` | CRLF | `fix-and-rebuild.ps1` |
| `TLS connect error` при build | GitHub внутри Docker | offline + vendor |
| `vendor files missing` | нет confd/etcd | браузер → `vendor\` |
| `container is not running` | старый образ с CRLF | `fix-and-rebuild.ps1` |
