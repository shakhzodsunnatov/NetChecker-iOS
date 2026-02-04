# 🔐 NetCheckerTraffic — SSL + Environment Switching

> Дополнение к основному техническому плану NetCheckerTraffic.
> Два новых блока: работа с SSL в debug/production и переключение окружений (prod/dev/staging/custom).

---

## Часть 1: SSL — Полная работа с сертификатами

### Проблема

При разработке iOS-приложения разработчик постоянно сталкивается с SSL-проблемами:

- На dev/staging сервере стоит **самоподписанный сертификат** — приложение отказывается подключаться
- Нужно **посмотреть трафик через Charles/Proxyman** — но SSL Pinning блокирует прокси
- Хочется **проверить цепочку сертификатов** бэкенда прямо из приложения
- Нужно убедиться что **SSL Pinning реально работает** — а не просто "вроде настроили"
- Сертификат на staging **истёк** — и непонятно почему приложение падает с ошибкой
- Перешли на новый домен — нужно **проверить TLS конфигурацию** до релиза

### Что делает наш модуль

Три подсистемы:

```
┌──────────────────────────────────────────────────────────────┐
│                      SSL Engine                               │
│                                                               │
│  ┌─────────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │  SSL Trust       │  │  SSL         │  │  SSL            │ │
│  │  Manager         │  │  Inspector   │  │  Pinning        │ │
│  │                  │  │              │  │  Validator      │ │
│  │ Управление       │  │ Просмотр     │  │ Тестирование    │ │
│  │ доверием к       │  │ сертификатов │  │ и валидация     │ │
│  │ сертификатам     │  │ в реальном   │  │ SSL Pinning     │ │
│  │ в debug          │  │ времени      │  │ конфигурации    │ │
│  └─────────────────┘  └──────────────┘  └─────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

### 1.1 SSL Trust Manager — Управление доверием

**Зачем:** В debug-режиме разработчику часто нужно работать с серверами у которых невалидные, самоподписанные или просроченные сертификаты. Вместо того чтобы лезть в код и добавлять `URLSessionDelegate` хаки, всё настраивается через конфигурацию NetChecker.

**Режимы доверия:**

```
SSLTrustMode:

  .strict (по умолчанию)
  ─────────────────────
  Стандартное поведение iOS.
  Доверяем только валидным сертификатам из системного хранилища.
  Самоподписанные, просроченные, с неправильным CN — отклоняются.
  Используется в production. Безопасно.

  .allowSelfSigned(hosts: Set<String>)
  ─────────────────────────────────────
  Разрешает самоподписанные сертификаты ТОЛЬКО для указанных хостов.
  Пример: .allowSelfSigned(hosts: ["dev-api.myapp.local", "192.168.1.100"])
  Остальные хосты проверяются строго.
  Используется при работе с локальным dev-сервером.

  .allowExpired(hosts: Set<String>)
  ──────────────────────────────────
  Разрешает просроченные сертификаты для указанных хостов.
  Пример: .allowExpired(hosts: ["staging-api.myapp.com"])
  Полезно когда на staging забыли обновить Let's Encrypt.

  .allowInvalidHost(hosts: Set<String>)
  ──────────────────────────────────────
  Разрешает несовпадение CN/SAN с hostname.
  Пример: сертификат выдан на *.myapp.com, а обращаемся к dev.internal.myapp.com.

  .allowAll
  ─────────
  ⚠️ Отключает ВСЮ проверку SSL для ВСЕХ хостов.
  Эквивалент NSAllowsArbitraryLoads, но на уровне URLSession.
  ТОЛЬКО для отладки. Показывает яркий warning-баннер в UI.
  Требует явного подтверждения: .allowAll(iUnderstandTheRisk: true)

  .allowProxy
  ────────────
  Специальный режим для работы через Charles/Proxyman/mitmproxy.
  Доверяет сертификатам прокси (корневой сертификат прокси добавляется
  в trust chain). При этом SSL Pinning временно отключается для
  указанных хостов, чтобы прокси мог расшифровать трафик.
  Пример: .allowProxy(proxyHosts: ["api.myapp.com"])

  .custom((SecTrust, String) -> Bool)
  ────────────────────────────────────
  Полный контроль. Разработчик сам решает доверять или нет.
  Получает SecTrust + hostname, возвращает Bool.
  Для продвинутых сценариев.
```

**Как это работает технически:**

```
Механизм: URLSessionDelegate внутри NetCheckerURLProtocol

Когда NetCheckerURLProtocol создаёт внутренний URLSession для
пересылки перехваченного запроса, он назначает себя delegate-ом
этого session. В методе:

urlSession(_:didReceive challenge:completionHandler:)

Происходит следующее:

1. Получаем SecTrust из challenge.protectionSpace.serverTrust
2. Извлекаем hostname из challenge.protectionSpace.host
3. Проверяем текущий SSLTrustMode из конфигурации
4. Принимаем решение:
   - .strict → стандартная проверка через SecTrustEvaluateWithError
   - .allowSelfSigned → если host в списке, принимаем; иначе строго
   - .allowAll → принимаем всё (+ логируем warning)
   - .allowProxy → принимаем сертификат прокси
   - .custom → вызываем пользовательский handler
5. Вызываем completionHandler(.useCredential / .cancelAuthenticationChallenge)
6. Записываем результат в SecurityInfo модели TrafficRecord
```

**Конфигурация:**

```
TrafficInterceptor.shared.start(
    configuration: .init(
        ssl: SSLConfiguration(
            trustMode: .allowSelfSigned(hosts: ["dev-api.myapp.local"]),
            logCertificateDetails: true,
            showSSLWarningsInUI: true
        )
    )
)
```

**Safety guards:**

```
Защита от случайного использования в production:

1. Режимы .allowAll, .allowProxy и .allowSelfSigned
   работают ТОЛЬКО когда #if DEBUG == true.
   В Release build вызов игнорируется + console warning.

2. В UI показывается яркий красный баннер:
   "⚠️ SSL VERIFICATION DISABLED FOR: dev-api.myapp.local"
   Чтобы разработчик не забыл что работает в небезопасном режиме.

3. В логах пишется:
   "[NetChecker] ⚠️ SSL trust bypassed for dev-api.myapp.local (self-signed allowed)"

4. При попытке включить .allowAll без iUnderstandTheRisk: true
   — runtime fatalError с объяснением.
```

---

### 1.2 SSL Inspector — Просмотр сертификатов

**Зачем:** Видеть полную информацию о SSL-сертификате любого запроса прямо в приложении. Не нужно открывать Safari, Chrome DevTools или openssl s_client.

**Что показываем для каждого HTTPS-запроса:**

```
Информация о соединении:
├── TLS Version: TLS 1.3 / TLS 1.2 / TLS 1.1 (deprecated!)
├── Cipher Suite: TLS_AES_256_GCM_SHA384
├── ALPN Protocol: h2 (HTTP/2) / http/1.1
├── Session Reused: Yes/No (keep-alive)
├── OCSP Stapling: Yes/No
└── Certificate Transparency: Yes/No

Цепочка сертификатов (Certificate Chain):
│
├── 🔒 Leaf Certificate (серверный):
│     ├── Subject: CN=api.myapp.com
│     ├── Issuer: CN=Let's Encrypt Authority X3
│     ├── Serial Number: 04:E3:A1:...
│     ├── Valid From: 2025-01-15
│     ├── Valid Until: 2025-04-15
│     ├── Days Remaining: 42 дней ← (⚠️ если < 30 дней — warning)
│     ├── Public Key: RSA 2048-bit / ECDSA P-256
│     ├── Signature Algorithm: SHA256withRSA
│     ├── Key Usage: Digital Signature, Key Encipherment
│     ├── Extended Key Usage: Server Authentication
│     ├── Subject Alternative Names (SAN):
│     │     ├── api.myapp.com
│     │     ├── *.myapp.com
│     │     └── myapp.com
│     ├── SHA-256 Fingerprint: A1:B2:C3:...
│     └── Is Self-Signed: No
│
├── 🔗 Intermediate Certificate:
│     ├── Subject: CN=Let's Encrypt Authority X3
│     ├── Issuer: CN=DST Root CA X3
│     ├── Valid: 2024-03-13 → 2027-03-12
│     └── ...
│
└── 🏛 Root Certificate:
      ├── Subject: CN=DST Root CA X3
      ├── Self-Signed: Yes
      ├── In System Trust Store: Yes ✅
      └── ...


Визуальные индикаторы:

🟢 Всё OK: валидный сертификат, TLS 1.2+, сильный cipher
🟡 Warning: сертификат истекает < 30 дней, TLS 1.2 (не 1.3), слабый ключ
🟠 Problem: самоподписанный (разрешённый), CN mismatch (разрешённый)
🔴 Error: невалидный сертификат, TLS 1.0/1.1, отклонённый запрос
```

**Как получаем эти данные:**

```
Источник 1: URLSessionDelegate
──────────────────────────────
В urlSession(_:didReceive challenge:) получаем SecTrust,
из которого извлекаем:
- SecTrustGetCertificateCount → количество сертификатов в цепочке
- SecTrustCopyCertificateChain → массив SecCertificate (iOS 15+)
- SecCertificateCopySubjectSummary → CN (Common Name)
- SecCertificateCopyData → DER-encoded данные для парсинга

Из DER-данных парсим:
- Subject, Issuer (ASN.1 парсинг или через Security framework)
- Validity dates
- Public key info
- SAN (Subject Alternative Names)
- Key Usage, Extended Key Usage

Источник 2: URLSessionTaskMetrics
───────────────────────────────────
Из URLSessionTaskTransactionMetrics получаем:
- negotiatedTLSProtocolVersion → TLS version
- negotiatedTLSCipherSuite → cipher suite
- isReusedConnection → session reuse
- remoteAddress, remotePort

Источник 3: SecTrustEvaluateWithError
──────────────────────────────────────
Результат валидации:
- isValid: Bool
- error: если невалидный — причина отказа
```

**Доп. возможности SSL Inspector:**

```
Проверка конкретного хоста (без запроса):
──────────────────────────────────────────
SSLInspector.check(host: "api.myapp.com", port: 443) { result in
    // result.certificates — цепочка
    // result.tlsVersion — версия TLS
    // result.isValid — валидность
    // result.expiresIn — дней до истечения
}

Это создаёт NWConnection к хосту, выполняет TLS handshake,
извлекает информацию и закрывает соединение.
Полезно для:
- Проверки сертификата staging перед деплоем
- Мониторинга срока действия сертификатов
- Диагностики SSL ошибок
```

---

### 1.3 SSL Pinning Validator — Тестирование пиннинга

**Зачем:** Разработчик настроил SSL Pinning (через TrustKit, Alamofire, или вручную). Нужно убедиться что он реально работает и защищает от MITM.

**Что делает:**

```
Автоматическое тестирование SSL Pinning:

1. Обнаружение pinning:
   - Проверяет есть ли в приложении TrustKit
   - Проверяет Info.plist на TSKConfiguration
   - Проверяет ATS настройки (NSAppTransportSecurity)
   - Анализирует URLSessionDelegate методы (runtime)

2. Валидация пинов:
   - Извлекает текущий pin (SPKI hash) сервера
   - Сравнивает с настроенными пинами
   - Показывает: ✅ Pin Match / ❌ Pin Mismatch

3. Тестирование (в debug):
   - Симулирует подключение с "неправильным" сертификатом
   - Проверяет что приложение корректно отклоняет его
   - Результат: "SSL Pinning is working correctly ✅"

4. Мониторинг в реальном времени:
   - Для каждого HTTPS-запроса в TrafficRecord записывается:
     - isPinned: Bool — прошёл ли запрос через pinning
     - pinValidationResult: .success / .failure(reason)
   - В UI: иконка 📌 рядом с pinned-запросами
```

**Bypass SSL Pinning для отладки:**

```
⚠️ Только в DEBUG. Нужно для работы с Charles/Proxyman.

TrafficInterceptor.shared.start(
    configuration: .init(
        ssl: SSLConfiguration(
            trustMode: .allowProxy(proxyHosts: ["api.myapp.com"]),
            bypassPinning: .forHosts(["api.myapp.com"])
        )
    )
)

Как работает bypass:
1. Method swizzle на URLSession delegate methods
   (если используется кастомный delegate)
2. Перехват TrustKit callback-ов (если TrustKit есть)
3. Замена SecTrustEvaluate результата для указанных хостов
4. Оригинальный pinning остаётся для остальных хостов

Красный баннер в UI:
"🔓 SSL PINNING BYPASSED FOR: api.myapp.com"
```

---

### 1.4 UI для SSL

```
В TrafficDetailView добавляется вкладка [Security]:

┌──────────────────────────────────────────────┐
│ ← Back     GET /v1/users           📋 📤     │
├──────────────────────────────────────────────┤
│ [Overview] [Request] [Response] [Timing]     │
│ [Security] ← НОВАЯ ВКЛАДКА                  │
├──────────────────────────────────────────────┤
│                                               │
│  Connection Security               🟢 Secure │
│  ──────────────────                           │
│  TLS Version     TLS 1.3                     │
│  Cipher Suite    TLS_AES_256_GCM_SHA384      │
│  Protocol        h2 (HTTP/2)                 │
│  Pinned          📌 Yes                       │
│                                               │
│  Server Certificate                           │
│  ──────────────────                           │
│  Subject     api.myapp.com                   │
│  Issuer      Let's Encrypt Authority X3      │
│  Valid       2025-01-15 → 2025-04-15         │
│  Expires in  42 days                   🟢    │
│  Key         ECDSA P-256                     │
│  SAN         api.myapp.com, *.myapp.com      │
│                                               │
│  [View Full Chain ▶]                          │
│  [Copy Fingerprint]                           │
│  [Check Certificate ↻]                        │
│                                               │
│  Trust Status                                 │
│  ────────────                                 │
│  ✅ Certificate is valid                      │
│  ✅ Chain of trust verified                   │
│  ✅ Hostname matches SAN                      │
│  ✅ Certificate not expired                   │
│  ✅ SSL Pinning validated                     │
│                                               │
└──────────────────────────────────────────────┘

Если есть проблемы:

┌──────────────────────────────────────────────┐
│  Trust Status                        🔴      │
│  ────────────                                 │
│  ✅ Chain of trust verified                   │
│  ❌ Hostname mismatch                         │
│     Expected: staging.myapp.com              │
│     Got: *.myapp.internal                    │
│  ⚠️ Certificate expires in 5 days            │
│  ⚠️ TLS 1.2 (consider upgrading to 1.3)     │
│  🔓 SSL Pinning BYPASSED (debug mode)        │
│                                               │
└──────────────────────────────────────────────┘
```

**Отдельный SSL Dashboard:**

```
Доступен из главного экрана TrafficListView → кнопка 🔐

┌──────────────────────────────────────────────┐
│  SSL Health Dashboard                         │
├──────────────────────────────────────────────┤
│                                               │
│  Hosts Connected This Session:                │
│                                               │
│  🟢 api.myapp.com                            │
│     TLS 1.3 │ ECDSA │ 📌 Pinned │ 42d left  │
│                                               │
│  🟢 cdn.myapp.com                            │
│     TLS 1.3 │ RSA   │ Not Pinned │ 89d left │
│                                               │
│  🟡 staging.myapp.com                        │
│     TLS 1.2 │ RSA   │ 📌 Pinned │ 5d left ⚠️│
│                                               │
│  🔴 dev.myapp.local                          │
│     Self-signed │ Trusted (debug) │ 🔓       │
│                                               │
│  🟢 analytics.google.com                     │
│     TLS 1.3 │ ECDSA │ Not Pinned │ 60d left │
│                                               │
│  ──────────────────────────────────────────── │
│  Quick Check:                                 │
│  [Enter hostname...]        [Check 🔍]       │
│                                               │
└──────────────────────────────────────────────┘
```

---

## Часть 2: Environment Switching — Переключение окружений

### Проблема

Во время разработки постоянно нужно переключаться между серверами:

- **Production** (api.myapp.com) — для проверки реальных данных
- **Staging** (staging-api.myapp.com) — для тестирования перед релизом
- **Development** (dev-api.myapp.com) — для разработки новых фич
- **Local** (localhost:8080 или 192.168.1.100) — для работы с локальным бэкендом
- **Custom** — QA прислал специальный URL для тестирования конкретного бага

Обычно для этого нужно менять переменные в коде, пересобирать приложение, иногда даже переключать схемы в Xcode. Это медленно и неудобно.

### Что делает наш модуль

Переключение окружения **на лету**, без пересборки, прямо из UI приложения. Модуль перехватывает запросы через URLProtocol и подменяет base URL.

---

### 2.1 Модель окружения

```
Environment:
  ├── id: UUID
  ├── name: String                    // "Production", "Staging", "Dev", "Local"
  ├── emoji: String                   // "🟢", "🟡", "🔧", "💻"
  ├── baseURL: URL                    // https://api.myapp.com
  ├── headers: [String: String]       // Доп. заголовки для этого окружения
  │     // Например: ["X-Debug": "true", "X-Environment": "staging"]
  ├── sslTrustMode: SSLTrustMode      // .strict для prod, .allowSelfSigned для local
  ├── isDefault: Bool                 // Одно окружение по умолчанию
  ├── variables: [String: String]     // Переменные окружения
  │     // {"API_VERSION": "v2", "FEATURE_FLAG": "new_feed"}
  └── notes: String?                  // "QA: Используй этот для тестирования бага #1234"
```

**EnvironmentGroup — Группа URL-ов с общей заменой:**

```
EnvironmentGroup:
  ├── name: String                    // "Main API"
  ├── sourcePattern: String           // Что ищем: "api.myapp.com"
  ├── environments:
  │     ├── Environment("Production", "https://api.myapp.com")
  │     ├── Environment("Staging", "https://staging-api.myapp.com")
  │     ├── Environment("Dev", "https://dev-api.myapp.com:8443")
  │     └── Environment("Local", "http://192.168.1.100:8080")
  └── activeEnvironmentId: UUID       // Какое окружение сейчас активно
```

**Зачем группы:** В приложении может быть несколько бэкендов. Основной API, auth-сервер, CDN, WebSocket. Каждый переключается независимо.

```
Пример:

Группа "Main API":
├── prod: api.myapp.com → staging: staging-api.myapp.com

Группа "Auth":
├── prod: auth.myapp.com → staging: staging-auth.myapp.com

Группа "CDN":
├── prod: cdn.myapp.com → (не переключаем, всегда prod)

Можно переключить API на staging, а Auth оставить на prod.
```

---

### 2.2 Механизм подмены URL

```
Как работает переключение:

Приложение делает запрос:
  GET https://api.myapp.com/v1/users/profile

URLProtocol перехватывает:
  1. Проверяет active environment groups
  2. Находит совпадение: "api.myapp.com" → группа "Main API"
  3. Active environment = "Staging"
  4. Подменяет host:
     GET https://staging-api.myapp.com/v1/users/profile
  5. Добавляет доп. headers из Environment (если есть)
  6. Применяет SSLTrustMode из Environment
  7. Отправляет подменённый запрос
  8. Ответ возвращает приложению как есть

Приложение НЕ знает что запрос ушёл на другой сервер.
В TrafficRecord сохраняется оригинальный и подменённый URL.
```

**URL Rewriting — правила подмены:**

```
Типы подмены:

1. Host replacement (самый частый):
   api.myapp.com → staging-api.myapp.com
   Меняется ТОЛЬКО host, path/query остаются.

2. Base URL replacement:
   https://api.myapp.com/v1 → https://staging.myapp.com/api/v1
   Меняется host + может меняться prefix пути.

3. Scheme change:
   https://api.myapp.com → http://192.168.1.100:8080
   HTTPS → HTTP для локального сервера.

4. Port change:
   api.myapp.com:443 → api.myapp.com:8443
   Для разных инстансов на одном сервере.

5. Full URL rewrite:
   https://api.myapp.com/v1/* → http://localhost:3000/api/*
   Полная подмена с сохранением пути после паттерна.

6. Path prefix:
   /v1/users → /v2/users
   Подмена версии API.
```

---

### 2.3 Quick URL Override — Быстрая подмена

**Зачем:** QA присылает в чат "проверь этот эндпоинт: https://bugfix-branch.myapp.dev/v1/users". Нужно быстро ввести URL и проверить, не создавая полноценное окружение.

```
Quick Override:
  ├── Ввести URL вручную
  ├── Ввести только host (path берётся из оригинала)
  ├── Применить к одному запросу (one-shot)
  ├── Применить ко всем запросам на этот host (sticky)
  └── Таймер: авто-отключение через N минут

Как активировать:
  1. Из UI: TrafficListView → кнопка 🔄 → "Quick Override"
  2. Из кода: TrafficInterceptor.shared.override(host: "api.myapp.com",
                                                   with: "bugfix.myapp.dev")
  3. Из Detail View: долгий тап на URL → "Override this host"
```

---

### 2.4 Retry с другим URL

**Зачем:** Запрос на production вернул ошибку. Нужно проверить — это баг на проде или бэкенд-проблема? Берём тот же самый запрос и переотправляем на staging/dev.

```
Сценарий:

1. Разработчик видит в списке:
   ● GET /v1/users/profile    500  890ms  ← Ошибка!

2. Открывает детали → нажимает [Retry ↻]

3. Появляется выбор:
   ┌─────────────────────────────────────┐
   │  Retry Request                       │
   │                                      │
   │  [↻ Same URL]                        │
   │     https://api.myapp.com/v1/users  │
   │                                      │
   │  [🟡 Staging]                        │
   │     https://staging-api.myapp.com   │
   │                                      │
   │  [🔧 Dev]                            │
   │     https://dev-api.myapp.com       │
   │                                      │
   │  [✏️ Custom URL...]                  │
   │     (ввести вручную)                │
   │                                      │
   │  ☐ Keep original headers            │
   │  ☐ Keep original body               │
   │  ☐ Show diff with original response │
   │                                      │
   └─────────────────────────────────────┘

4. Разработчик выбирает "Staging"

5. Модуль:
   - Берёт оригинальный запрос (method, headers, body)
   - Подменяет host на staging
   - Отправляет
   - Показывает результат рядом с оригиналом

6. В списке появляется:
   ● GET /v1/users/profile    500  890ms  [prod]
   ↳ GET /v1/users/profile    200  120ms  [staging]  ← Retry
```

**Response Diff:**

```
Если включён "Show diff with original response",
показывается сравнение двух ответов:

┌──────────────────────────────────────────────┐
│  Response Diff: prod vs staging               │
├──────────────────────────────────────────────┤
│                                               │
│  Status:  500 → 200 ✅                       │
│  Time:    890ms → 120ms (↓ 86%)              │
│  Size:    0 B → 1.2 KB                       │
│                                               │
│  Body diff:                                   │
│  - (empty response / error)                  │
│  + {                                          │
│  +   "id": 123,                              │
│  +   "name": "John Doe",                    │
│  +   "email": "john@example.com"            │
│  + }                                          │
│                                               │
│  Headers diff:                                │
│  ~ X-Server: prod-1 → staging-3             │
│  + X-Debug-Info: "request processed ok"      │
│                                               │
│  Вывод: Баг воспроизводится только на prod.  │
│  Вероятно проблема с prod-1 инстансом.       │
│                                               │
└──────────────────────────────────────────────┘
```

---

### 2.5 Переменные окружения (Environment Variables)

```
Помимо подмены URL, каждое окружение может хранить переменные:

Environment "Staging":
  variables:
    API_VERSION: "v2"
    FEATURE_FLAG_NEW_FEED: "true"
    LOG_LEVEL: "verbose"
    MOCK_PAYMENTS: "true"

Как использовать в приложении:

// Вместо:
let version = "v1"

// Пишем:
let version = TrafficInterceptor.shared.variable("API_VERSION") ?? "v1"

// Или через property wrapper:
@EnvironmentVariable("API_VERSION", default: "v1")
var apiVersion: String

Переменные переключаются вместе с окружением.
Не нужно пересобирать приложение.
```

---

### 2.6 UI для Environment Switching

**Главный переключатель (EnvironmentSwitcherView):**

```
Доступен из TrafficListView → кнопка 🌍

┌──────────────────────────────────────────────┐
│  Environments                         [+ Add]│
├──────────────────────────────────────────────┤
│                                               │
│  Main API (api.myapp.com)                    │
│  ──────────────────────────────              │
│  ● 🟢 Production   api.myapp.com       [✓]  │
│  ○ 🟡 Staging      staging-api.myapp.com     │
│  ○ 🔧 Development  dev-api.myapp.com         │
│  ○ 💻 Local        192.168.1.100:8080        │
│                                               │
│  Auth Service (auth.myapp.com)               │
│  ──────────────────────────────              │
│  ● 🟢 Production   auth.myapp.com      [✓]  │
│  ○ 🟡 Staging      staging-auth.myapp.com    │
│                                               │
│  ──────────────────────────────────────────  │
│  Quick Override:                              │
│  [Enter custom URL or host...]     [Apply]   │
│  ☐ Auto-disable after 10 min                 │
│                                               │
│  ──────────────────────────────────────────  │
│  Active overrides:                            │
│  api.myapp.com → staging  [Disable ✕]        │
│                                               │
│  ──────────────────────────────────────────  │
│  [Import from JSON...]                        │
│  [Export environments...]                     │
│  [Reset all to Production]                    │
│                                               │
└──────────────────────────────────────────────┘
```

**Индикатор текущего окружения:**

```
В TrafficListView всегда видно на каком окружении работаем:

┌──────────────────────────────────────────────┐
│ Traffic Inspector            🟡 STAGING  🔍 ⚙️│
│                              ^^^^^^^^^^^^     │
│                              Всегда видно!    │
├──────────────────────────────────────────────┤
│ ...                                           │

Цвета:
🟢 Production (зелёный — всё нормально)
🟡 Staging (жёлтый — тестовое окружение)
🔧 Development (оранжевый)
💻 Local (синий)
🔴 Custom Override (красный — ручная подмена!)
```

**В FloatingTrafficBadge:**

```
  ┌──────────────────────────────┐
  │ 🟡 STG │ 47 │ 🔴 2 │ 234ms │
  └──────────────────────────────┘
   env      total errors  avg
```

---

### 2.7 Добавление нового окружения (AddEnvironmentView)

```
┌──────────────────────────────────────────────┐
│  Add Environment                              │
├──────────────────────────────────────────────┤
│                                               │
│  Name:                                        │
│  [QA Branch #1234                       ]     │
│                                               │
│  Emoji:                                       │
│  [🔍] (tap to pick)                           │
│                                               │
│  Base URL:                                    │
│  [https://branch-1234.myapp.dev         ]     │
│                                               │
│  Group:                                       │
│  [Main API (api.myapp.com)           ▼ ]     │
│                                               │
│  Additional Headers:                          │
│  ┌───────────────┬──────────────────────┐    │
│  │ X-Branch      │ feature/new-feed     │    │
│  │ X-Debug       │ true                 │    │
│  │ [+ Add header]│                      │    │
│  └───────────────┴──────────────────────┘    │
│                                               │
│  SSL:                                         │
│  [Allow self-signed certificates     ▼ ]     │
│                                               │
│  Variables:                                   │
│  ┌───────────────┬──────────────────────┐    │
│  │ API_VERSION   │ v2-beta              │    │
│  │ [+ Add var]   │                      │    │
│  └───────────────┴──────────────────────┘    │
│                                               │
│  Notes:                                       │
│  [Для тестирования бага #1234, спросить  ]   │
│  [у Андрея если не работает              ]   │
│                                               │
│  [Test Connection 🔍]     [Save ✓]           │
│                                               │
└──────────────────────────────────────────────┘
```

**Test Connection** — перед сохранением проверяет:
- DNS резолвится
- TCP подключение работает
- SSL handshake проходит (с учётом выбранного trustMode)
- Базовый GET / возвращает ответ

---

### 2.8 Import/Export окружений

```
Формат: JSON файл, который можно расшарить команде.

environments.json:
{
  "version": 1,
  "groups": [
    {
      "name": "Main API",
      "sourcePattern": "api.myapp.com",
      "environments": [
        {
          "name": "Production",
          "emoji": "🟢",
          "baseURL": "https://api.myapp.com",
          "sslTrustMode": "strict"
        },
        {
          "name": "Staging",
          "emoji": "🟡",
          "baseURL": "https://staging-api.myapp.com",
          "headers": {"X-Debug": "true"},
          "sslTrustMode": "strict"
        },
        {
          "name": "Local Docker",
          "emoji": "🐳",
          "baseURL": "http://localhost:8080",
          "sslTrustMode": "allowAll"
        }
      ]
    }
  ]
}

Способы импорта:
├── Из файла (Files app / AirDrop)
├── Из буфера обмена (JSON)
├── Из URL (скачать конфиг с сервера команды)
├── QR-код (отсканировать с другого устройства)
└── Из кода при инициализации
```

---

### 2.9 Конфигурация из кода

```
// Минимальная настройка:
TrafficInterceptor.shared.addEnvironment(
    group: "Main API",
    source: "api.myapp.com",
    environments: [
        .init(name: "Prod", url: "https://api.myapp.com"),
        .init(name: "Staging", url: "https://staging-api.myapp.com"),
        .init(name: "Dev", url: "https://dev-api.myapp.com"),
    ]
)


// С SSL и переменными:
TrafficInterceptor.shared.addEnvironment(
    group: "Main API",
    source: "api.myapp.com",
    environments: [
        Environment(
            name: "Production",
            emoji: "🟢",
            baseURL: URL(string: "https://api.myapp.com")!,
            sslTrustMode: .strict,
            isDefault: true
        ),
        Environment(
            name: "Local",
            emoji: "💻",
            baseURL: URL(string: "http://192.168.1.100:8080")!,
            sslTrustMode: .allowSelfSigned(hosts: ["192.168.1.100"]),
            headers: ["X-Debug": "true"],
            variables: ["LOG_LEVEL": "verbose"]
        ),
    ]
)


// Переключение:
TrafficInterceptor.shared.switchEnvironment(group: "Main API", to: "Staging")


// Quick override:
TrafficInterceptor.shared.override(
    host: "api.myapp.com",
    with: "bugfix-branch.myapp.dev",
    autoDisableAfter: .minutes(10)
)


// Получение текущего:
let current = TrafficInterceptor.shared.activeEnvironment(for: "Main API")
print(current.name) // "Staging"
```

---

## 3. Обновлённая структура файлов

```
Новые файлы к существующей структуре:

Sources/NetCheckerTraffic/
├── Core/
│   ├── ... (существующие)
│   └── URLRewriter.swift                     ← Подмена URL
│
├── SSL/
│   ├── SSLConfiguration.swift                ← Конфиг SSL
│   ├── SSLTrustManager.swift                 ← Управление доверием
│   ├── SSLInspector.swift                    ← Инспекция сертификатов
│   ├── SSLPinningValidator.swift             ← Тестирование pinning
│   ├── CertificateParser.swift               ← Парсинг DER/X.509
│   └── CertificateInfo.swift                 ← Модель сертификата
│
├── Environment/
│   ├── Environment.swift                     ← Модель окружения
│   ├── EnvironmentGroup.swift                ← Группа окружений
│   ├── EnvironmentStore.swift                ← Хранение и переключение
│   ├── EnvironmentVariable.swift             ← Property wrapper
│   └── EnvironmentImportExport.swift         ← JSON import/export
│
├── Retry/
│   ├── RequestRetrier.swift                  ← Повторная отправка запроса
│   └── ResponseDiffer.swift                  ← Сравнение ответов
│
└── Models/
    ├── ... (существующие)
    └── SecurityInfo.swift                    ← Расширяется SSL-данными

Sources/NetCheckerTrafficUI/
├── Views/
│   ├── ... (существующие)
│   ├── SSLDetailView.swift                   ← Вкладка Security
│   ├── SSLDashboardView.swift                ← SSL Health Dashboard
│   ├── CertificateChainView.swift            ← Визуализация цепочки
│   ├── EnvironmentSwitcherView.swift         ← Переключатель окружений
│   ├── AddEnvironmentView.swift              ← Добавление окружения
│   ├── QuickOverrideView.swift               ← Быстрая подмена URL
│   ├── RetryView.swift                       ← UI повторной отправки
│   └── ResponseDiffView.swift                ← UI сравнения ответов
│
└── Components/
    ├── ... (существующие)
    ├── EnvironmentBadge.swift                ← Бейдж текущего окружения
    ├── SSLStatusBadge.swift                  ← Иконка SSL-статуса
    └── CertificateRow.swift                  ← Строка сертификата в списке
```

---

## 4. Обновлённый Roadmap

```
К существующим фазам добавляются:

Фаза 2.5 — SSL Engine (4-5 дней):
├── SSLTrustManager (все режимы доверия)
├── SSLInspector (извлечение данных сертификата)
├── CertificateParser (парсинг DER)
├── Интеграция с URLProtocol delegate
├── SSLPinningValidator (обнаружение и тест)
├── SSLConfiguration
└── Unit-тесты SSL

Фаза 2.7 — Environment Switching (4-5 дней):
├── Environment + EnvironmentGroup модели
├── EnvironmentStore (хранение, переключение)
├── URLRewriter (механизм подмены)
├── Интеграция с URLProtocol
├── EnvironmentVariable property wrapper
├── Import/Export JSON
├── Persistence (UserDefaults)
└── Unit-тесты

Фаза 3.5 — SSL + Environment UI (3-4 дня):
├── SSLDetailView (вкладка Security)
├── SSLDashboardView
├── CertificateChainView
├── EnvironmentSwitcherView
├── AddEnvironmentView
├── QuickOverrideView
├── EnvironmentBadge
└── SSLStatusBadge

Фаза 5.5 — Retry & Diff (2-3 дня):
├── RequestRetrier
├── ResponseDiffer
├── RetryView (UI)
├── ResponseDiffView (UI)
└── Интеграция в TrafficDetailView

ИТОГО дополнительно: ~2-2.5 недели
ОБЩИЙ СРОК: ~5-6 недель (было ~3.5-4)
```

---

## 5. Итоговая карта функций модуля

```
NetCheckerTraffic — Полная карта:

🔬 Traffic Interception
├── URLProtocol перехват (3 уровня)
├── Полный request/response logging
├── Timing breakdown (DNS/TCP/TLS/TTFB/Download)
├── Фильтрация и поиск
├── Статистика и аналитика
├── cURL / HAR / JSON экспорт
└── Waterfall timeline

🎭 Mock Engine
├── Правила подмены ответов
├── Готовые пресеты ошибок
├── Задержки, таймауты
└── Модификация реальных ответов

⏸ Breakpoints
├── Остановка request/response
├── Модификация на лету
└── Авто-resume по таймеру

🔐 SSL Engine                          ← НОВОЕ
├── Trust Manager (6 режимов)
├── Certificate Inspector
├── Pinning Validator
├── Proxy mode (Charles/Proxyman)
└── SSL Health Dashboard

🌍 Environment Switching                ← НОВОЕ
├── Prod/Staging/Dev/Local/Custom
├── Quick URL Override
├── Retry с другим URL
├── Response Diff
├── Environment Variables
├── Import/Export JSON
└── Индикатор текущего окружения

🛡 Security
├── Auto-redaction sensitive данных
├── DEBUG-only guards
└── Production safety
```

---

*Дополнение к основному плану NetCheckerTraffic*
*Версия: 1.1*
*Февраль 2026*
