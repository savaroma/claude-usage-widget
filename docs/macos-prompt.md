# macOS port — starter prompt

Paste this into a Claude Code session **on the Mac** to build a menu-bar (top-right)
version of this widget. All the technical facts already discovered for the Windows
version are baked in, so the Mac agent doesn't have to rediscover them (and won't
trip the endpoint's rate limit).

> Note the key macOS difference: Claude Code typically stores the OAuth token in the
> **Keychain**, not in `~/.claude/.credentials.json`.

---

```text
Хочу виджет в строке меню macOS (верхний правый угол / menu bar), который в реальном
времени показывает, сколько процентов моих лимитов подписки Claude израсходовано:
скользящее 5-часовое окно и недельный лимит. Это аналог моего рабочего виджета под
Windows (он живёт в панели задач). Сделай маковую версию.

=== ИСТОЧНИК ДАННЫХ (уже разведан, не нужно искать заново) ===
Недокументированный OAuth-эндпоинт, тот же, что использует индикатор лимитов в Claude Code:
  GET https://api.anthropic.com/api/oauth/usage
  Заголовки:
    Authorization: Bearer <accessToken>
    anthropic-beta: oauth-2025-04-20
  (Content-Type не нужен — это GET без тела.)

Ответ (JSON; секции могут быть null; utilization — процент 0..100):
  {
    "five_hour":        { "utilization": 24.0, "resets_at": "ISO8601+offset" },
    "seven_day":        { "utilization": 10.0, "resets_at": "..." },
    "seven_day_sonnet": { "utilization": 0.0,  "resets_at": "..." },
    "extra_usage":      { "is_enabled": false, ... }
  }

ВАЖНО (отличие macOS от Windows): на маке Claude Code обычно хранит OAuth-токен НЕ в файле,
а в Keychain. Проверь оба места:
  1) Keychain: `security find-generic-password -s "Claude Code-credentials" -a "$USER" -w`
     Имя сервиса именно "Claude Code-credentials", аккаунт — твой логин ($USER). Вернёт JSON:
       claudeAiOauth.{ accessToken, refreshToken, expiresAt, scopes, subscriptionType, ... }
     Бери claudeAiOauth.accessToken. Если по этому имени пусто — найди элемент поиском:
       `security dump-keychain 2>/dev/null | grep -i claude`
  2) Фоллбэк-файл: ~/.claude/.credentials.json -> .claudeAiOauth.accessToken
Перечитывай токен каждый опрос (Claude Code сам его обновляет, когда работает).
Примечание: первый вызов `security` из нового скрипта/приложения может показать GUI-промпт
на доступ к Keychain — это нормально, разреши один раз ("Always Allow").
Подсказка: в токене есть claudeAiOauth.expiresAt — если он в прошлом, можно заранее пометить
данные устаревшими (серый) ещё до сетевого запроса.

=== ЛИМИТ ЧАСТОТЫ (критично) ===
Эндпоинт READ-ONLY и НЕ тратит лимит, НО он сам по себе rate-limited: при частых запросах
возвращает HTTP 429. Поэтому:
  - опрашивай НЕ чаще раза в 60 секунд;
  - при ошибке делай экспоненциальный бэкофф (на 429 старт ~90с, потолок ~10 мин), НЕ повторяй
    в тугом цикле;
  - 401 ≠ 429: 401 значит токен протух. НЕ уходи в длинный бэкофф — перечитай токен из Keychain
    один раз и повтори. Если снова 401 — покажи серый/устаревший и подсказку "запусти Claude Code"
    (он обновит токен), и вернись к обычному интервалу;
  - при сбое НЕ гаси индикатор — показывай последнее хорошее значение, пометь как устаревшее.

=== ФОРМАТ И ПОВЕДЕНИЕ ===
- Место: строка меню macOS (NSStatusItem, верхний правый угол). Это лучше WidgetKit-виджета:
  realtime, без троттлинга обновлений.
- В строке меню: компактно "5h 24% · 2h13m" — процент 5h-лимита И сколько осталось до его
  сброса, плюс "7d 10%". Цвет по утилизации: зелёный <40, жёлтый 40-69, оранжевый 70-89,
  красный >=90.
- Счётчик до сброса 5h: считай как (five_hour.resets_at − сейчас), формат "2h13m" (а под
  час — "47m", под минуту — "<1m"). Тикает локально каждую секунду/минуту между сетевыми
  опросами, не дёргая эндпоинт; обновляй значение resets_at при каждом успешном запросе.
  Когда дойдёт до нуля — покажи "resetting…" и подтяни свежие данные следующим опросом.
- Если секция приходит null или без resets_at — показывай "—" (НЕ 0% и НЕ "0m"), не считай
  таймер по отсутствующей дате.
- Выпадающее меню по клику: 5h % + время до сброса и абсолютное время сброса (локальное),
  7d %, 7d Sonnet %, их времена сброса, пункты "Обновить" и "Выход".
- Автозапуск при логине: для варианта B — LaunchAgent; для варианта A (SwiftBar/xbar)
  автозапуск делает сам хост-app, отдельный LaunchAgent не нужен.

=== СПОСОБ РЕАЛИЗАЦИИ ===
Предложи два пути и порекомендуй:
  A) Быстрый, без Xcode: плагин для SwiftBar или xbar — это shell/Python/Swift-скрипт, который
     печатает первую строку (текст в меню-баре) и строки после "---" (выпадающее меню),
     с интервалом обновления (напр. 60с). Делает ровно то, что нужно, за минуты.
  B) Нативный: маленькое Swift/SwiftUI приложение с NSStatusItem (MenuBarExtra), таймер 60с,
     бэкофф, LaunchAgent. Полированный вариант.
Начни с (A) для рабочего MVP, потом по желанию (B).

=== НЕ ДЕЛАТЬ ===
- НЕ реализуй авто-refresh токена через /v1/oauth/token: refresh-токен ротируется и это может
  разлогинить сам Claude Code. Полагайся на то, что Claude Code держит токен свежим.
- Помни, что эндпоинт недокументирован — обрабатывай ошибки мягко (показывай "—"/серый),
  не падай.
- НЕ выводи accessToken никуда — ни в логи, ни в stderr, ни в меню. Осторожно с `set -x`/
  отладочными echo в shell-скрипте: токен не должен попасть в вывод SwiftBar.

За reference-реализацию (бэкофф, формат, watchdog-логика) возьми Windows-версию из этого
репозитория: claude-usage-pill.ps1.

Сначала проверь, где реально лежит токен (Keychain vs файл), сделай один тестовый запрос
(ровно один, чтобы не словить 429) и покажи мне результат, потом собирай виджет.
```

See also: [usage-endpoint.md](usage-endpoint.md) for the endpoint reference.
