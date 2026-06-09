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
    Content-Type: application/json

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
     (вернёт JSON с полем claudeAiOauth.accessToken). Имя сервиса уточни — поищи в Keychain
     элемент, связанный с Claude Code.
  2) Фоллбэк-файл: ~/.claude/.credentials.json -> .claudeAiOauth.accessToken
Перечитывай токен каждый опрос (Claude Code сам его обновляет, когда работает).

=== ЛИМИТ ЧАСТОТЫ (критично) ===
Эндпоинт READ-ONLY и НЕ тратит лимит, НО он сам по себе rate-limited: при частых запросах
возвращает HTTP 429. Поэтому:
  - опрашивай НЕ чаще раза в 60 секунд;
  - при ошибке делай экспоненциальный бэкофф (на 429 старт ~90с, потолок ~10 мин), НЕ повторяй
    в тугом цикле;
  - при сбое НЕ гаси индикатор — показывай последнее хорошее значение, пометь как устаревшее.

=== ФОРМАТ И ПОВЕДЕНИЕ ===
- Место: строка меню macOS (NSStatusItem, верхний правый угол). Это лучше WidgetKit-виджета:
  realtime, без троттлинга обновлений.
- В строке меню: компактно "5h 24%  7d 10%" (или с цветными кружками). Цвет по утилизации:
  зелёный <40, жёлтый 40-69, оранжевый 70-89, красный >=90.
- Выпадающее меню по клику: 5h %, 7d %, 7d Sonnet %, время сброса каждого (в локальном времени),
  пункты "Обновить" и "Выход".
- Автозапуск при логине (LaunchAgent).

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

За reference-реализацию (бэкофф, формат, watchdog-логика) возьми Windows-версию из этого
репозитория: claude-usage-pill.ps1.

Сначала проверь, где реально лежит токен (Keychain vs файл), сделай один тестовый запрос
(ровно один, чтобы не словить 429) и покажи мне результат, потом собирай виджет.
```

See also: [usage-endpoint.md](usage-endpoint.md) for the endpoint reference.
