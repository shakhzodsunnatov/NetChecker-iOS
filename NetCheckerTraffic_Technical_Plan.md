# 🔬 NetCheckerTraffic — Технический план модуля перехвата трафика

> **Встроенный HTTP/HTTPS инспектор для iOS-приложений**
> Аналог Charles Proxy / Proxyman / Pulse — прямо внутри приложения, подключается как SPM-модуль.

---

## 1. Обзор модуля

### Зачем это нужно

Разработчик подключает NetCheckerTraffic в свой проект и моментально видит **все сетевые запросы** приложения: свой бэкенд, third-party SDK, аналитику, рекламу — всё в красивом интерфейсе прямо на устройстве. Без прокси, без сертификатов, без Mac рядом.

### Ключевые возможности

- Перехват ВСЕХ HTTP/HTTPS запросов (URLSession, Alamofire, Moya, любые)
- Детальный просмотр request/response (headers, body, timing)
- JSON/XML подсветка и форматирование
- Фильтрация по хосту, методу, статус-коду, ключевым словам
- Waterfall timeline (как в Chrome DevTools → Network)
- Экспорт запроса как cURL / HAR / Share
- Mock-ответы для тестирования
- Breakpoints — пауза и модификация запроса перед отправкой
- Performance-метрики по каждому запросу
- Push-уведомление при ошибках (4xx/5xx)
- Работает в DEBUG, полностью отключается в RELEASE

---

## 2. Архитектура модуля

### Структура файлов

```
Sources/
├── NetCheckerTraffic/
│   ├── Core/
│   │   ├── TrafficInterceptor.swift          ← Главный класс, точка входа
│   │   ├── NetCheckerURLProtocol.swift       ← URLProtocol-перехватчик
│   │   ├── SessionSwizzler.swift             ← Swizzling URLSessionConfiguration
│   │   └── InterceptorConfiguration.swift    ← Настройки перехвата
│   │
│   ├── Models/
│   │   ├── TrafficRecord.swift               ← Полная запись запрос+ответ
│   │   ├── RequestData.swift                 ← Модель запроса
│   │   ├── ResponseData.swift                ← Модель ответа
│   │   ├── RequestTimings.swift              ← Тайминги по фазам
│   │   ├── SecurityInfo.swift                ← TLS/SSL информация
│   │   ├── TrafficError.swift                ← Модели ошибок
│   │   └── ContentType.swift                 ← Типы контента (JSON/XML/Image/etc)
│   │
│   ├── Storage/
│   │   ├── TrafficStore.swift                ← Центральное хранилище записей
│   │   ├── TrafficFilter.swift               ← Фильтрация и поиск
│   │   ├── TrafficStatistics.swift           ← Агрегированная статистика
│   │   └── TrafficExporter.swift             ← Экспорт (cURL/HAR/JSON/Share)
│   │
│   ├── Mocking/
│   │   ├── MockRule.swift                    ← Правило мока
│   │   ├── MockEngine.swift                  ← Движок подмены ответов
│   │   └── MockPresets.swift                 ← Готовые пресеты (error, slow, empty)
│   │
│   ├── Breakpoints/
│   │   ├── BreakpointRule.swift              ← Правило остановки
│   │   ├── BreakpointEngine.swift            ← Движок breakpoints
│   │   └── RequestModifier.swift             ← Модификация запроса на лету
│   │
│   ├── Formatters/
│   │   ├── JSONFormatter.swift               ← Pretty-print JSON с подсветкой
│   │   ├── XMLFormatter.swift                ← Pretty-print XML
│   │   ├── HeaderFormatter.swift             ← Форматирование заголовков
│   │   ├── BodySizeFormatter.swift           ← Человекочитаемый размер (1.2 KB)
│   │   ├── CURLFormatter.swift               ← Конвертация в cURL команду
│   │   └── HARFormatter.swift                ← Экспорт в HAR формат
│   │
│   ├── Protocols/
│   │   ├── TrafficRecording.swift            ← Протокол записи
│   │   ├── TrafficFiltering.swift            ← Протокол фильтрации
│   │   └── TrafficExporting.swift            ← Протокол экспорта
│   │
│   └── Extensions/
│       ├── URLRequest+Traffic.swift          ← Хелперы для URLRequest
│       ├── HTTPURLResponse+Traffic.swift     ← Хелперы для Response
│       ├── Data+PrettyPrint.swift            ← Форматирование Data
│       └── URLSessionTaskMetrics+Ext.swift   ← Парсинг метрик
│
└── NetCheckerTrafficUI/
    ├── Views/
    │   ├── TrafficListView.swift             ← Главный список запросов
    │   ├── TrafficDetailView.swift           ← Детали одного запроса
    │   ├── RequestDetailView.swift           ← Вкладка Request
    │   ├── ResponseDetailView.swift          ← Вкладка Response
    │   ├── TimingDetailView.swift            ← Вкладка Timing (waterfall)
    │   ├── SecurityDetailView.swift          ← Вкладка TLS/Certificate
    │   ├── TrafficStatisticsView.swift       ← Дашборд статистики
    │   ├── WaterfallChartView.swift          ← Timeline всех запросов
    │   ├── MockRulesView.swift               ← Управление моками
    │   ├── BreakpointRulesView.swift         ← Управление breakpoints
    │   ├── TrafficSearchBar.swift            ← Поиск и фильтры
    │   └── FloatingTrafficBadge.swift        ← Мини-оверлей (кол-во запросов)
    │
    ├── Components/
    │   ├── StatusCodeBadge.swift             ← Цветной бейдж: 200/401/500
    │   ├── MethodBadge.swift                 ← GET/POST/PUT/DELETE бейдж
    │   ├── JSONSyntaxView.swift              ← JSON с подсветкой синтаксиса
    │   ├── HeadersTableView.swift            ← Таблица заголовков key-value
    │   ├── TimingBarView.swift               ← Полоска тайминга одного запроса
    │   ├── SizeIndicator.swift               ← Индикатор размера данных
    │   ├── CopyButton.swift                  ← Кнопка копирования
    │   └── ShareSheet.swift                  ← Шаринг через UIActivityVC
    │
    └── Theme/
        └── TrafficTheme.swift                ← Цвета статус-кодов и методов
```

---

## 3. Механизм перехвата

### 3.1 URLProtocol — Основа перехвата

`URLProtocol` — это официальный Apple API, позволяющий вклиниться в цепочку обработки **любого** запроса через URLSession.

```
Приложение вызывает запрос
         │
         ▼
┌─────────────────────────────────────────────┐
│         URLSession Pipeline                  │
│                                              │
│  ┌───────────────────────────────────┐      │
│  │  NetCheckerURLProtocol            │      │
│  │                                    │      │
│  │  canInit(with: request) → true    │      │
│  │  ┌────────────────────────────┐   │      │
│  │  │ 1. LOG REQUEST             │   │      │
│  │  │    → headers, body, URL    │   │      │
│  │  ├────────────────────────────┤   │      │
│  │  │ 2. CHECK MOCK RULES       │   │      │
│  │  │    → если есть мок,        │   │      │
│  │  │      вернуть мок-ответ     │   │      │
│  │  ├────────────────────────────┤   │      │
│  │  │ 3. CHECK BREAKPOINTS      │   │      │
│  │  │    → если breakpoint,      │   │      │
│  │  │      ждать модификации     │   │      │
│  │  ├────────────────────────────┤   │      │
│  │  │ 4. FORWARD REQUEST         │   │      │
│  │  │    → отправить в сеть      │   │      │
│  │  ├────────────────────────────┤   │      │
│  │  │ 5. LOG RESPONSE            │   │      │
│  │  │    → status, body, timing  │   │      │
│  │  ├────────────────────────────┤   │      │
│  │  │ 6. RETURN TO APP           │   │      │
│  │  │    → приложение получает   │   │      │
│  │  │      оригинальный ответ    │   │      │
│  │  └────────────────────────────┘   │      │
│  └───────────────────────────────────┘      │
└─────────────────────────────────────────────┘
```

### 3.2 Три уровня перехвата

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                   │
│  Level 1: БАЗОВЫЙ (URLProtocol.registerClass)                    │
│  ──────────────────────────────────────────────                   │
│  Что ловит: только URLSession.shared                             │
│  Не ловит:  кастомные URLSession, background sessions            │
│  Подходит:  простые приложения без Alamofire/Moya                │
│  Активация: TrafficInterceptor.shared.start(level: .basic)      │
│                                                                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Level 2: РАСШИРЕННЫЙ (Swizzling URLSessionConfiguration)        │
│  ──────────────────────────────────────────────────────────       │
│  Что ловит: ВСЕ URLSession включая кастомные                    │
│  Не ловит:  background upload/download tasks                     │
│  Подходит:  большинство проектов (Alamofire, Moya, и т.д.)      │
│  Как работает:                                                    │
│    - Swizzle protocolClasses getter в URLSessionConfiguration    │
│    - Автоматически внедряет NetCheckerURLProtocol во все сессии  │
│  Активация: TrafficInterceptor.shared.start(level: .full)       │
│                                                                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Level 3: ИНЪЕКЦИЯ (Manual URLSession configuration)             │
│  ──────────────────────────────────────────────────────────       │
│  Что ловит: только явно подключённые URLSession                  │
│  Зачем:     когда swizzling нежелателен (production debugging)   │
│  Как работает:                                                    │
│    let config = URLSessionConfiguration.default                  │
│    config.protocolClasses = TrafficInterceptor.protocolClasses()  │
│    let session = URLSession(configuration: config)               │
│  Активация: ручная настройка разработчиком                       │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 3.3 Swizzling — детали механизма

```
Что происходит при TrafficInterceptor.start(level: .full):

1. Method Swizzling на URLSessionConfiguration:
   ┌──────────────────────────────────────────────────┐
   │  Оригинальный getter:                            │
   │  config.protocolClasses → [AnyClass]?            │
   │                                                   │
   │  После swizzle:                                  │
   │  config.protocolClasses → [NetCheckerURLProtocol] │
   │                          + оригинальные классы    │
   └──────────────────────────────────────────────────┘

2. Это затрагивает ВСЕ URLSession в приложении:
   ├── URLSession.shared
   ├── URLSession(configuration: .default)
   ├── URLSession(configuration: .ephemeral)
   ├── Alamofire.Session.default
   ├── Moya Provider
   ├── Kingfisher (загрузка картинок)
   ├── Firebase SDK
   ├── Analytics SDK
   └── Любой third-party SDK

3. Защита от двойного swizzle:
   ├── Проверка через objc_getAssociatedObject
   ├── Thread-safe через DispatchQueue.once аналог
   └── Восстановление оригинала при stop()
```

### 3.4 Предотвращение бесконечной рекурсии

**Проблема:** Наш URLProtocol перехватывает запрос → создаёт новый URLSession для отправки → этот запрос опять перехватывается → бесконечный цикл.

```
Решение: маркировка обработанных запросов

┌─────────────────────────────────────────────────────┐
│  canInit(with request: URLRequest) → Bool            │
│                                                      │
│  if request.value(forHTTPHeaderField:                │
│       "X-NetChecker-Intercepted") != nil {           │
│      return false  // уже обработан, пропускаем      │
│  }                                                   │
│  return true  // перехватываем                        │
│                                                      │
│  startLoading():                                     │
│  mutableRequest.setValue("true",                      │
│      forHTTPHeaderField: "X-NetChecker-Intercepted") │
│  // Отправляем помеченный запрос → он не будет       │
│  // перехвачен повторно                               │
└─────────────────────────────────────────────────────┘

Альтернативный метод (без модификации headers):

┌─────────────────────────────────────────────────────┐
│  URLProtocol.setProperty(true,                       │
│      forKey: "NetCheckerHandled",                    │
│      in: mutableRequest)                             │
│                                                      │
│  canInit: проверяем URLProtocol.property(            │
│      forKey: "NetCheckerHandled", in: request)       │
│                                                      │
│  ✅ Лучше! Не модифицирует headers запроса           │
└─────────────────────────────────────────────────────┘
```

---

## 4. Модели данных

### 4.1 TrafficRecord — Главная модель

```
TrafficRecord:
  ├── id: UUID
  ├── timestamp: Date
  ├── duration: TimeInterval                // Общее время запроса (ms)
  ├── state: TrafficRecordState             // .pending → .completed / .failed
  │
  ├── request: RequestData
  │     ├── url: URL
  │     ├── method: HTTPMethod              // .get, .post, .put, .delete, .patch, .head, .options
  │     ├── headers: [String: String]
  │     ├── body: Data?
  │     ├── bodyString: String?             // Декодированный body (UTF-8)
  │     ├── bodySize: Int64                 // Размер в байтах
  │     ├── contentType: ContentType?       // .json, .xml, .formData, .multipart, .image, .other
  │     ├── cachePolicy: URLRequest.CachePolicy
  │     ├── timeoutInterval: TimeInterval
  │     └── cookies: [HTTPCookie]
  │
  ├── response: ResponseData?
  │     ├── statusCode: Int                 // 200, 401, 500 и т.д.
  │     ├── statusCategory: StatusCategory  // .informational, .success, .redirect, .clientError, .serverError
  │     ├── headers: [String: String]
  │     ├── body: Data?
  │     ├── bodyString: String?
  │     ├── bodySize: Int64
  │     ├── contentType: ContentType?
  │     ├── mimeType: String?
  │     ├── isFromCache: Bool
  │     └── cookies: [HTTPCookie]           // Set-Cookie из ответа
  │
  ├── timings: RequestTimings?
  │     ├── dnsLookup: TimeInterval         // DNS Resolution
  │     ├── tcpConnect: TimeInterval        // TCP Handshake
  │     ├── tlsHandshake: TimeInterval?     // TLS Negotiation (HTTPS only)
  │     ├── requestSend: TimeInterval       // Time to send request
  │     ├── serverWait: TimeInterval        // TTFB (Time to First Byte)
  │     ├── responseReceive: TimeInterval   // Download time
  │     ├── total: TimeInterval             // Общее время
  │     │
  │     │   Визуально (Waterfall Bar):
  │     │   ├─DNS─┤├─TCP─┤├─TLS─┤├─Send─┤├──Wait──┤├──Receive──┤
  │     │   0ms                                              320ms
  │     │
  │     ├── connectionReused: Bool          // Keep-alive переиспользование
  │     ├── proxyConnection: Bool           // Через прокси
  │     └── protocolName: String?           // "h2", "http/1.1"
  │
  ├── security: SecurityInfo?
  │     ├── tlsVersion: String?             // "TLS 1.3", "TLS 1.2"
  │     ├── cipherSuite: String?
  │     ├── certificateChain: [CertificateInfo]
  │     │     ├── subject: String
  │     │     ├── issuer: String
  │     │     ├── validFrom: Date
  │     │     ├── validUntil: Date
  │     │     ├── serialNumber: String
  │     │     └── publicKeyBits: Int
  │     └── isPinned: Bool
  │
  ├── error: TrafficError?
  │     ├── code: Int                       // NSURLErrorDomain code
  │     ├── domain: String
  │     ├── localizedDescription: String
  │     ├── category: ErrorCategory
  │     │     (.timeout, .noConnection, .dnsFailure,
  │     │      .sslError, .cancelled, .serverUnreachable, .other)
  │     └── underlyingError: Error?
  │
  ├── metadata: TrafficMetadata
  │     ├── host: String                    // "api.mybackend.com"
  │     ├── path: String                    // "/v1/users/profile"
  │     ├── scheme: String                  // "https"
  │     ├── port: Int?
  │     ├── queryItems: [URLQueryItem]
  │     ├── isThirdParty: Bool              // Не наш бэкенд
  │     ├── sdkSource: String?              // "Alamofire", "Firebase", etc. (эвристика)
  │     └── tags: [String]                  // Пользовательские теги
  │
  └── redirects: [RedirectHop]
        ├── fromURL: URL
        ├── toURL: URL
        ├── statusCode: Int                 // 301, 302, 307, 308
        └── headers: [String: String]
```

### 4.2 Вспомогательные enum-ы

```
HTTPMethod:
  .get, .post, .put, .delete, .patch, .head, .options, .trace, .connect

StatusCategory:
  .informational (100-199)  → 🔵 синий
  .success       (200-299)  → 🟢 зелёный
  .redirect      (300-399)  → 🟡 жёлтый
  .clientError   (400-499)  → 🟠 оранжевый
  .serverError   (500-599)  → 🔴 красный

ContentType:
  .json
  .xml
  .html
  .formUrlEncoded      // application/x-www-form-urlencoded
  .multipartFormData   // multipart/form-data
  .plainText
  .image(ImageType)    // .png, .jpeg, .gif, .webp, .svg
  .pdf
  .protobuf
  .msgpack
  .graphql
  .binary
  .unknown(String)     // raw MIME type

TrafficRecordState:
  .pending             // Запрос отправлен, ждём ответ
  .completed           // Ответ получен
  .failed(Error)       // Ошибка
  .cancelled           // Отменён
  .mocked              // Подменён моком
```

---

## 5. Хранилище и фильтрация

### 5.1 TrafficStore — Центральное хранилище

```
TrafficStore:
  ├── Хранение: in-memory (Ring Buffer)
  │     ├── Макс. записей: 1000 (настраивается)
  │     ├── При переполнении: удаляются старейшие
  │     ├── Опционально: flush на диск (SQLite/SwiftData)
  │     └── Thread-safe: actor-based или DispatchQueue
  │
  ├── Публичный API:
  │     ├── records: [TrafficRecord]                  // Все записи
  │     ├── recordsPublisher: AnyPublisher            // Combine
  │     ├── recordsStream: AsyncStream                // async/await
  │     ├── add(_ record: TrafficRecord)
  │     ├── update(id: UUID, response: ResponseData)
  │     ├── clear()                                    // Очистить всё
  │     ├── remove(matching: TrafficFilter)            // Удалить по фильтру
  │     └── export(format: ExportFormat) → Data
  │
  ├── Реактивные уведомления:
  │     ├── onNewRecord: (TrafficRecord) → Void
  │     ├── onRecordUpdated: (TrafficRecord) → Void
  │     ├── onError: (TrafficRecord) → Void           // Автоуведомление об ошибках
  │     └── onChange: AnyPublisher<[TrafficRecord], Never>
  │
  └── Persistence (опционально):
        ├── SQLite через GRDB или SwiftData
        ├── Автоочистка: записи старше N часов/дней
        └── Экспорт истории за период
```

### 5.2 TrafficFilter — Система фильтрации

```
TrafficFilter:
  │
  ├── По содержимому:
  │     ├── searchText: String?              // Поиск по URL, headers, body
  │     ├── host: String?                    // "api.myapp.com"
  │     ├── path: String?                    // содержит "/users"
  │     └── bodyContains: String?            // Поиск в теле запроса/ответа
  │
  ├── По типу:
  │     ├── methods: Set<HTTPMethod>?        // [.post, .put]
  │     ├── statusCodes: Range<Int>?         // 400..<600
  │     ├── statusCategories: Set<StatusCategory>?
  │     └── contentTypes: Set<ContentType>?  // [.json, .xml]
  │
  ├── По состоянию:
  │     ├── states: Set<TrafficRecordState>? // [.failed, .pending]
  │     ├── onlyErrors: Bool                 // Только 4xx/5xx и network errors
  │     ├── onlySlowRequests: Bool           // Дольше threshold
  │     ├── slowThreshold: TimeInterval      // По умолчанию 3.0 сек
  │     └── onlyCached: Bool                 // Только из кэша
  │
  ├── По времени:
  │     ├── from: Date?
  │     ├── to: Date?
  │     └── lastMinutes: Int?               // Последние N минут
  │
  ├── По источнику:
  │     ├── onlyFirstParty: Bool            // Только наш бэкенд
  │     ├── onlyThirdParty: Bool            // Только сторонние
  │     ├── hosts: Set<String>?             // Конкретные хосты
  │     └── excludeHosts: Set<String>?      // Исключить хосты
  │
  ├── Сортировка:
  │     ├── sortBy: SortField (.timestamp, .duration, .size, .statusCode)
  │     └── sortOrder: SortOrder (.ascending, .descending)
  │
  └── Предустановленные фильтры:
        ├── .all                             // Все запросы
        ├── .errorsOnly                      // 4xx + 5xx + network errors
        ├── .slowRequests(threshold: 3.0)    // Медленные
        ├── .myBackend(hosts: ["api.myapp.com"])
        ├── .apiOnly                         // Исключает images, fonts, scripts
        └── .custom(TrafficFilter)
```

### 5.3 TrafficStatistics — Агрегированная аналитика

```
TrafficStatistics:
  │
  ├── Общие:
  │     ├── totalRequests: Int
  │     ├── successfulRequests: Int
  │     ├── failedRequests: Int
  │     ├── pendingRequests: Int
  │     ├── successRate: Double (%)
  │     ├── totalBytesReceived: Int64
  │     ├── totalBytesSent: Int64
  │     └── sessionDuration: TimeInterval
  │
  ├── Тайминги:
  │     ├── avgResponseTime: TimeInterval
  │     ├── medianResponseTime: TimeInterval
  │     ├── p95ResponseTime: TimeInterval       // 95-й перцентиль
  │     ├── p99ResponseTime: TimeInterval       // 99-й перцентиль
  │     ├── fastestRequest: TrafficRecord?
  │     ├── slowestRequest: TrafficRecord?
  │     └── avgDNSTime: TimeInterval
  │
  ├── По хостам:
  │     ├── requestsByHost: [String: Int]        // {"api.myapp.com": 45, ...}
  │     ├── errorsByHost: [String: Int]
  │     ├── avgTimeByHost: [String: TimeInterval]
  │     └── dataByHost: [String: Int64]          // Трафик по хосту
  │
  ├── По методам:
  │     └── requestsByMethod: [HTTPMethod: Int]  // {.get: 120, .post: 35, ...}
  │
  ├── По статус-кодам:
  │     ├── requestsByStatusCode: [Int: Int]     // {200: 100, 401: 5, ...}
  │     └── requestsByCategory: [StatusCategory: Int]
  │
  ├── По времени (для графика):
  │     ├── requestsPerMinute: [(Date, Int)]
  │     ├── errorsPerMinute: [(Date, Int)]
  │     └── avgResponseTimePerMinute: [(Date, TimeInterval)]
  │
  └── Топы:
        ├── top10Slowest: [TrafficRecord]
        ├── top10Largest: [TrafficRecord]         // По размеру ответа
        ├── top10MostFrequent: [(String, Int)]    // URL pattern → count
        └── recentErrors: [TrafficRecord]          // Последние 20 ошибок
```

---

## 6. Mocking Engine — Подмена ответов

### Зачем

Тестирование edge cases без изменения бэкенда: пустые списки, ошибки сервера, медленные ответы, специфические данные.

### Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                     MockEngine                           │
│                                                          │
│  Запрос приходит в URLProtocol                          │
│         │                                                │
│         ▼                                                │
│  ┌─────────────────┐                                    │
│  │ Match Rules      │  Проверяем все правила по порядку  │
│  │                   │                                    │
│  │  Rule 1: ❌ нет  │                                    │
│  │  Rule 2: ✅ да!  │  ← Совпадение найдено              │
│  │  Rule 3: —       │                                    │
│  └────────┬─────────┘                                    │
│           │                                              │
│           ▼                                              │
│  ┌───────────────────────────────┐                      │
│  │ Выбор действия:                │                      │
│  │                                │                      │
│  │  .respond(mockData)           │ → Вернуть мок        │
│  │  .delay(seconds) + respond    │ → Задержка + мок     │
│  │  .error(type)                 │ → Симулировать ошибку │
│  │  .passthrough                 │ → Пропустить в сеть  │
│  │  .modify(transform)          │ → Модифицировать      │
│  │                                │   реальный ответ      │
│  └───────────────────────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

### MockRule — Модель правила

```
MockRule:
  ├── id: UUID
  ├── name: String                    // "Empty user list"
  ├── isEnabled: Bool
  ├── priority: Int                   // Чем выше — тем раньше проверяется
  │
  ├── matching: MockMatching
  │     ├── urlPattern: String        // Regex или wildcard: "*/api/v1/users*"
  │     ├── method: HTTPMethod?       // nil = любой метод
  │     ├── headers: [String: String]?// Совпадение по заголовкам
  │     └── bodyContains: String?     // Содержимое body
  │
  ├── action: MockAction
  │     ├── .respond(MockResponse)
  │     │     ├── statusCode: Int
  │     │     ├── headers: [String: String]
  │     │     ├── body: Data
  │     │     └── delay: TimeInterval?
  │     │
  │     ├── .error(MockError)
  │     │     ├── .noConnection
  │     │     ├── .timeout
  │     │     ├── .dnsFailure
  │     │     ├── .sslError
  │     │     └── .custom(code: Int, domain: String)
  │     │
  │     ├── .delay(seconds: TimeInterval)    // Только задержка, ответ реальный
  │     │
  │     └── .modifyResponse((Data) → Data)   // Трансформация реального ответа
  │
  └── limits: MockLimits?
        ├── maxActivations: Int?      // Сработать N раз, потом отключиться
        ├── activationCount: Int      // Сколько раз уже сработало
        └── expiresAt: Date?          // Автоотключение по времени
```

### Предустановленные пресеты

```
MockPresets:
  ├── .serverError           → 500 Internal Server Error
  ├── .notFound              → 404 Not Found
  ├── .unauthorized          → 401 Unauthorized
  ├── .forbidden             → 403 Forbidden
  ├── .tooManyRequests       → 429 Too Many Requests
  ├── .serviceUnavailable    → 503 Service Unavailable
  ├── .noConnection          → NSURLErrorNotConnectedToInternet
  ├── .timeout               → NSURLErrorTimedOut
  ├── .slowResponse(5.0)     → Задержка 5 секунд
  ├── .emptyResponse         → 200 с пустым body
  ├── .emptyArray            → 200 с []
  └── .emptyObject           → 200 с {}
```

---

## 7. Breakpoints Engine — Остановка и модификация

### Зачем

Остановить запрос ДО отправки, посмотреть/изменить параметры, продолжить. Или перехватить ответ ДО доставки в приложение и модифицировать.

### Архитектура

```
Запрос из приложения
        │
        ▼
┌───────────────────┐     ┌──────────────────────┐
│ Check Breakpoint  │────▶│ Request Breakpoint    │
│ Rules             │     │                       │
│                   │     │ UI показывает запрос   │
│                   │     │ Разработчик может:     │
│                   │     │ ├── Изменить URL       │
│                   │     │ ├── Изменить headers   │
│                   │     │ ├── Изменить body      │
│                   │     │ ├── Продолжить ▶       │
│                   │     │ ├── Отменить ✕         │
│                   │     │ └── Мокнуть ответ 🔄   │
│                   │     └──────────┬─────────────┘
│                   │                │
└───────────────────┘                ▼
                              Отправка в сеть
                                     │
                                     ▼
                         ┌──────────────────────┐
                         │ Response Breakpoint   │
                         │                       │
                         │ UI показывает ответ    │
                         │ Разработчик может:     │
                         │ ├── Изменить status    │
                         │ ├── Изменить headers   │
                         │ ├── Изменить body      │
                         │ ├── Продолжить ▶       │
                         │ └── Подменить полностью│
                         └──────────┬─────────────┘
                                    │
                                    ▼
                           Доставка в приложение
```

### BreakpointRule — Модель

```
BreakpointRule:
  ├── id: UUID
  ├── name: String
  ├── isEnabled: Bool
  ├── matching: BreakpointMatching
  │     ├── urlPattern: String
  │     ├── method: HTTPMethod?
  │     └── direction: BreakpointDirection
  │           ├── .request          // Остановить перед отправкой
  │           ├── .response         // Остановить перед доставкой
  │           └── .both             // Оба направления
  └── autoResume: TimeInterval?     // Авто-продолжение через N сек (safety net)
```

---

## 8. Форматирование и экспорт

### 8.1 cURL Export

```
Пример вывода:

curl -X POST 'https://api.myapp.com/v1/users/login' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer eyJhbGciOi...' \
  -H 'Accept: application/json' \
  -H 'User-Agent: MyApp/1.0 iOS/17.0' \
  -d '{
    "email": "user@example.com",
    "password": "***REDACTED***"
  }'

Фичи cURL экспорта:
├── Автоматическая маскировка sensitive данных
│     ├── Authorization header → "Bearer ***"
│     ├── password поля → "***REDACTED***"
│     ├── api_key → "***"
│     └── Настраиваемый список полей для маскировки
├── Копирование в буфер обмена одной кнопкой
├── Share sheet для отправки коллегам
└── Multiline форматирование для читабельности
```

### 8.2 HAR Export (HTTP Archive)

```
HAR формат — стандарт для обмена HTTP-данными.
Открывается в Chrome DevTools, Charles, Proxyman, и т.д.

Экспорт:
├── Один запрос → .har файл
├── Все запросы за сессию → .har файл
├── Фильтрованные запросы → .har файл
└── Share через UIActivityViewController
```

### 8.3 JSON Export

```
Простой JSON-экспорт всех записей:
├── Для импорта в Postman
├── Для автоматизированного тестирования
├── Для отправки в баг-репорт
└── Формат: массив TrafficRecord в JSON
```

---

## 9. UI компоненты (NetCheckerTrafficUI)

### 9.1 Общая навигация

```
┌──────────────────────────────────────────────┐
│ Traffic Inspector                    🔍 ⚙️    │
├──────────────────────────────────────────────┤
│ [All] [Errors] [Slow] [API] [3rd Party]     │  ← Быстрые фильтры
├──────────────────────────────────────────────┤
│                                               │
│ ● POST /v1/auth/login           200  120ms   │  ← Зелёный = success
│ ● GET  /v1/users/profile        200   85ms   │
│ ● GET  /v1/feed                 200  340ms   │
│ ● POST /v1/analytics/event      200   45ms   │
│ ● GET  /v1/notifications        401  230ms   │  ← Оранжевый = client error
│ ● GET  /v1/feed?page=2          500 1200ms   │  ← Красный = server error
│ ● GET  /images/avatar.jpg       200  890ms   │  ← Серый = static
│ ● POST /v1/upload/photo         200 3400ms   │  ← Жёлтый = slow
│ ○ GET  /v1/settings             ...  ...     │  ← Пустой = pending
│                                               │
├──────────────────────────────────────────────┤
│ 47 requests │ 2 errors │ Avg: 234ms │ 1.2MB │  ← Суммарная статистика
└──────────────────────────────────────────────┘
```

### 9.2 Детали запроса (TrafficDetailView)

```
┌──────────────────────────────────────────────┐
│ ← Back     POST /v1/auth/login       📋 📤   │  ← Copy cURL / Share
├──────────────────────────────────────────────┤
│ [Overview] [Request] [Response] [Timing]     │  ← Табы
├──────────────────────────────────────────────┤
│                                               │
│  OVERVIEW TAB:                                │
│  ─────────────                                │
│  URL        https://api.myapp.com/v1/auth/..│
│  Method     POST                              │
│  Status     200 OK                    🟢      │
│  Duration   120ms                             │
│  Size       ↑ 156 B  ↓ 1.2 KB               │
│  Protocol   h2 (HTTP/2)                       │
│  TLS        TLS 1.3                           │
│  Cached     No                                │
│                                               │
│  REQUEST TAB:                                 │
│  ───────────                                  │
│  Headers:                                     │
│  ┌─────────────────┬────────────────────┐    │
│  │ Content-Type    │ application/json   │    │
│  │ Authorization   │ Bearer eyJhbG...   │    │
│  │ Accept          │ application/json   │    │
│  │ User-Agent      │ MyApp/1.0 iOS/17  │    │
│  └─────────────────┴────────────────────┘    │
│                                               │
│  Body:                                        │
│  ┌──────────────────────────────────────┐    │
│  │ {                                     │    │
│  │   "email": "user@example.com",       │    │
│  │   "password": "secret123"            │    │
│  │ }                                     │    │
│  └──────────────────────────────────────┘    │
│                                               │
│  TIMING TAB:                                  │
│  ──────────                                   │
│  ├─DNS──┤├─TCP─┤├─TLS─┤├─Wait──┤├Receive┤   │
│  │ 12ms ││ 15ms││ 25ms││  58ms ││ 10ms  │   │
│  Total: 120ms                                 │
│                                               │
└──────────────────────────────────────────────┘
```

### 9.3 Waterfall Chart (WaterfallChartView)

```
┌──────────────────────────────────────────────────────────────┐
│  Waterfall Timeline                                    ⏱ 2.4s│
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Time:  0    200ms   400ms   600ms   800ms   1s    1.2s      │
│         │      │       │       │       │      │      │       │
│  POST /login                                                  │
│         ▓▓▓▓▓▓░░░░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                       │
│         DNS  TCP TLS  Wait     Receive                        │
│                                                               │
│  GET /profile                                                 │
│              ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                                │
│              (connection reused)                               │
│                                                               │
│  GET /feed                                                    │
│              ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                │
│                                                               │
│  GET /avatar.jpg                                              │
│                   ▓▓░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒         │
│                   DNS TCP      Download (image)               │
│                                                               │
│  Legend:  ▓ DNS+TCP+TLS  ░ Waiting (TTFB)  ▒ Download        │
└──────────────────────────────────────────────────────────────┘
```

### 9.4 Statistics Dashboard (TrafficStatisticsView)

```
┌──────────────────────────────────────────────┐
│  Session Statistics                           │
├──────────────────────────────────────────────┤
│                                               │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐    │
│  │  47  │  │  43  │  │  2   │  │  2   │    │
│  │ Total│  │  OK  │  │Errors│  │ Slow │    │
│  │      │  │ 91.5%│  │ 4.3% │  │ 4.3% │    │
│  └──────┘  └──────┘  └──────┘  └──────┘    │
│                                               │
│  Response Time Distribution:                  │
│  ┌──────────────────────────────────────┐    │
│  │ ████████████████░░░░░ Avg: 234ms     │    │
│  │ ██████████░░░░░░░░░░░ P95: 890ms    │    │
│  │ ██████████████████████ P99: 3.4s    │    │
│  └──────────────────────────────────────┘    │
│                                               │
│  Top Hosts:                                   │
│  api.myapp.com         32 reqs   780 KB      │
│  cdn.myapp.com         10 reqs   2.1 MB      │
│  analytics.google.com   5 reqs    12 KB      │
│                                               │
│  Error Breakdown:                             │
│  401 Unauthorized       1                     │
│  500 Server Error        1                     │
│                                               │
│  Traffic:  ↑ 45 KB sent  ↓ 3.2 MB received   │
└──────────────────────────────────────────────┘
```

### 9.5 FloatingTrafficBadge — Мини-оверлей

```
Маленький плавающий бейдж поверх приложения:

  ┌─────────────────────┐
  │  🔵 47 │ 🔴 2 │ 234ms│   ← Перетаскивается по экрану
  └─────────────────────┘
  total  errors  avg time

  Тап → раскрывается полный TrafficListView
  Long press → быстрые действия (clear, pause, export)
  Свайп → скрыть временно
```

---

## 10. Конфигурация и API разработчика

### 10.1 Быстрый старт (одна строка)

```
// В AppDelegate или @main App:
TrafficInterceptor.shared.start()

// Готово! Все запросы перехватываются.
// Shake gesture → открывается TrafficListView
```

### 10.2 Продвинутая конфигурация

```
InterceptorConfiguration:
  │
  ├── Уровень перехвата:
  │     ├── level: .basic / .full / .manual
  │     └── enableInRelease: Bool (default: false ⚠️)
  │
  ├── Фильтрация перехвата (ЧТО ловить):
  │     ├── captureHosts: Set<String>?         // nil = все
  │     │     // ["api.myapp.com", "cdn.myapp.com"]
  │     ├── ignoreHosts: Set<String>           // Исключить
  │     │     // ["analytics.google.com", "crashlytics.com"]
  │     ├── captureMethods: Set<HTTPMethod>?   // nil = все
  │     ├── ignorePathPatterns: [String]       // Regex
  │     │     // [".*\\.(png|jpg|gif|svg)$"]   // Игнор картинок
  │     └── minBodySizeToCapture: Int          // Не логировать body > N bytes
  │
  ├── Хранение:
  │     ├── maxRecords: Int (default: 1000)
  │     ├── persistToDisk: Bool (default: false)
  │     ├── retentionPeriod: TimeInterval?     // Автоочистка
  │     └── captureResponseBody: Bool (default: true)
  │
  ├── Безопасность:
  │     ├── redactHeaders: Set<String>         // Маскировать значения
  │     │     // ["Authorization", "Cookie", "X-API-Key"]
  │     ├── redactBodyFields: Set<String>      // Маскировать JSON поля
  │     │     // ["password", "token", "secret", "ssn"]
  │     ├── redactQueryParams: Set<String>     // Маскировать query params
  │     │     // ["api_key", "access_token"]
  │     └── redactionString: String            // "***REDACTED***"
  │
  ├── UI:
  │     ├── enableShakeGesture: Bool (default: true)
  │     ├── showFloatingBadge: Bool (default: false)
  │     ├── badgePosition: BadgePosition (.topRight, .bottomRight, etc.)
  │     ├── enableNotificationOnError: Bool (default: true)
  │     └── theme: TrafficTheme?
  │
  └── Callbacks:
        ├── onRequest: ((URLRequest) → Void)?
        ├── onResponse: ((TrafficRecord) → Void)?
        ├── onError: ((TrafficRecord) → Void)?
        └── shouldIntercept: ((URLRequest) → Bool)?  // Динамическая фильтрация
```

### 10.3 Примеры использования

```
Сценарий 1: Минимальный (отладка):
─────────────────────────────────────────
TrafficInterceptor.shared.start()
// Shake → видишь все запросы


Сценарий 2: Только свой бэкенд:
─────────────────────────────────────────
TrafficInterceptor.shared.start(
    configuration: .init(
        captureHosts: ["api.myapp.com", "auth.myapp.com"],
        redactHeaders: ["Authorization"],
        redactBodyFields: ["password", "credit_card"]
    )
)


Сценарий 3: Корпоративное приложение:
─────────────────────────────────────────
TrafficInterceptor.shared.start(
    configuration: .init(
        level: .full,
        maxRecords: 5000,
        persistToDisk: true,
        onError: { record in
            BugReporter.attach(networkLog: record)
        }
    )
)


Сценарий 4: Автоматизированные тесты:
─────────────────────────────────────────
// В XCTestCase setUp():
TrafficInterceptor.shared.start(level: .basic)
TrafficInterceptor.shared.mockEngine.addRule(
    MockRule(
        matching: .url("*/api/v1/users*"),
        action: .respond(MockResponse(
            statusCode: 200,
            body: mockUsersJSON
        ))
    )
)

// В tearDown():
TrafficInterceptor.shared.stop()


Сценарий 5: SwiftUI интеграция:
─────────────────────────────────────────
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .trafficInspectorOverlay()     // Floating badge
                .trafficShakeGesture()         // Shake → open inspector
        }
    }
}

// Или открыть вручную:
NavigationLink("Network Inspector") {
    TrafficListView()
}
```

---

## 11. Обновлённый граф зависимостей Package.swift

```
┌──────────────────────────────────────────────────────────────────┐
│                      NetCheckerUI                                 │
│              (SwiftUI компоненты — ВСЁ)                          │
└────┬─────────┬────────────┬────────────┬─────────────────────────┘
     │         │            │            │
     │    ┌────▼────────────▼───┐   ┌────▼─────────────┐
     │    │ NetCheckerTrafficUI │   │ Speed/WiFi/Cell/ │
     │    │ (Traffic UI)        │   │ Security UI      │
     │    └────────┬────────────┘   └──────────────────┘
     │             │
     │    ┌────────▼────────────┐
     │    │ NetCheckerTraffic   │   ← НОВЫЙ МОДУЛЬ
     │    │ (Interceptor+Store) │
     │    └────────┬────────────┘
     │             │
┌────▼─────────────▼────────────────────────────────────────┐
│                    NetCheckerCore                           │
│            (NWPathMonitor, базовые типы)                    │
└────────────────────────┬──────────────────────────────────-┘
                         │
┌────────────────────────▼──────────────────────────────────┐
│                   NetCheckerLogger                         │
└───────────────────────────────────────────────────────────┘


Новые targets в Package.swift:

.target(
    name: "NetCheckerTraffic",
    dependencies: ["NetCheckerCore", "NetCheckerLogger"]
),
.target(
    name: "NetCheckerTrafficUI",
    dependencies: ["NetCheckerTraffic", "NetCheckerUI"]
),
.testTarget(
    name: "NetCheckerTrafficTests",
    dependencies: ["NetCheckerTraffic"]
),
```

---

## 12. Безопасность и Production Safety

### Критически важно

```
┌──────────────────────────────────────────────────────────┐
│  ⚠️  ЗАЩИТА ОТ ПОПАДАНИЯ В PRODUCTION                    │
│                                                           │
│  Проблема: URLProtocol swizzling в production может:     │
│  ├── Замедлить приложение                                │
│  ├── Потреблять память (хранение body)                   │
│  ├── Создавать security-уязвимости                       │
│  └── Нарушать App Store Review Guidelines                │
│                                                           │
│  Решения:                                                │
│                                                           │
│  1. Compile-time guard:                                  │
│     #if DEBUG                                            │
│     TrafficInterceptor.shared.start()                    │
│     #endif                                               │
│                                                           │
│  2. Runtime guard (внутри пакета):                       │
│     - По умолчанию НЕ работает в Release                 │
│     - Проверка: isDebugBuild() через _isDebugAssert      │
│     - Даже если вызвать start() в Release — ничего       │
│       не произойдёт без явного enableInRelease: true     │
│                                                           │
│  3. Stripping в Release:                                 │
│     - Весь UI-модуль обёрнут в #if DEBUG                 │
│     - Модели остаются (для логирования если нужно)       │
│     - URLProtocol registration — только в DEBUG          │
│                                                           │
│  4. App Store Safety:                                    │
│     - Swizzling разрешён Apple (Pulse, netfox делают)    │
│     - Но ТОЛЬКО для отладки, не для production           │
│     - Наш пакет безопасен "из коробки"                   │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

### Маскировка чувствительных данных

```
Авто-маскировка по умолчанию:

Headers (значения заменяются на "***"):
├── Authorization
├── Cookie / Set-Cookie
├── X-API-Key / X-Api-Key
├── X-Auth-Token
├── Proxy-Authorization
└── Пользовательский список

Body JSON fields (значения заменяются на "***REDACTED***"):
├── password / passwd / pass
├── token / access_token / refresh_token
├── secret / client_secret
├── ssn / social_security
├── credit_card / card_number / cvv
├── pin / pin_code
└── Пользовательский список

Query Parameters:
├── api_key / apikey
├── access_token
├── secret
├── key
└── Пользовательский список

Маскировка настраивается:
├── Полная замена: "***REDACTED***"
├── Частичная: "eyJhb...***" (первые 5 символов + ***)
├── Отключение маскировки для разработки
└── Custom transformer: (String) → String
```

---

## 13. Performance бюджет

```
┌────────────────────────────────────────────────────────────┐
│  Требования к производительности:                          │
│                                                             │
│  Memory:                                                    │
│  ├── Overhead на запрос: < 50 KB (без body)                │
│  ├── Body хранение: lazy, не загружается пока не нужно     │
│  ├── 1000 записей без body: ~50 MB максимум                │
│  ├── Ring buffer: автоматическое вытеснение старых          │
│  └── Предупреждение при > 100 MB использования             │
│                                                             │
│  CPU:                                                       │
│  ├── Перехват: < 1ms overhead на запрос                     │
│  ├── Логирование: async, не блокирует main thread          │
│  ├── JSON formatting: lazy, только при открытии детали     │
│  └── Фильтрация: < 10ms для 1000 записей                  │
│                                                             │
│  Network:                                                   │
│  ├── Нулевой дополнительный сетевой трафик                 │
│  ├── Запросы НЕ дублируются                                │
│  └── Body копируется из оригинального ответа, не скачивает │
│                                                             │
│  Battery:                                                   │
│  ├── Минимальное влияние при обычном использовании          │
│  └── Idle mode: никаких background-операций                │
│                                                             │
│  Disk (при persistToDisk: true):                           │
│  ├── SQLite: < 100 MB лимит по умолчанию                   │
│  ├── Автоочистка по retention period                        │
│  └── Body > 1MB: хранится на диске, не в памяти           │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## 14. Разрешения

```
┌──────────────────────────────────────────────────────────┐
│                                                           │
│  NetCheckerTraffic:     НОЛЬ РАЗРЕШЕНИЙ ✅               │
│  NetCheckerTrafficUI:   НОЛЬ РАЗРЕШЕНИЙ ✅               │
│                                                           │
│  URLProtocol — стандартный Apple API                      │
│  Method swizzling — разрешён (Objective-C runtime)       │
│  Всё работает в sandbox приложения                       │
│  Нет entitlements, нет Info.plist ключей                 │
│                                                           │
│  Privacy Manifest (iOS 17+):                             │
│  ├── NSPrivacyAccessedAPICategoryUserDefaults             │
│  │   (хранение настроек InterceptorConfiguration)        │
│  └── Данные не покидают устройство                       │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 15. Roadmap реализации

```
Фаза 1 — Core Interceptor (1 неделя):
├── NetCheckerURLProtocol (перехват)
├── SessionSwizzler (полный перехват)
├── TrafficRecord + RequestData + ResponseData модели
├── TrafficStore (in-memory ring buffer)
├── InterceptorConfiguration
├── Базовые Unit-тесты
└── Защита от рекурсии

Фаза 2 — Форматирование и экспорт (3-4 дня):
├── JSONFormatter (pretty print)
├── CURLFormatter
├── HeaderFormatter
├── BodySizeFormatter
├── TrafficFilter (поиск и фильтрация)
└── TrafficStatistics

Фаза 3 — UI (1-1.5 недели):
├── TrafficListView (главный список)
├── TrafficDetailView (4 вкладки)
├── StatusCodeBadge + MethodBadge
├── JSONSyntaxView (подсветка)
├── TimingBarView (waterfall)
├── TrafficSearchBar
├── FloatingTrafficBadge
├── TrafficStatisticsView
└── WaterfallChartView

Фаза 4 — Mock Engine (3-4 дня):
├── MockRule + MockEngine
├── MockPresets
├── MockRulesView (UI управления)
└── Integration тесты

Фаза 5 — Breakpoints (3-4 дня):
├── BreakpointRule + BreakpointEngine
├── RequestModifier
├── BreakpointRulesView (UI)
└── Request/Response editor UI

Фаза 6 — Полировка (2-3 дня):
├── HARFormatter (экспорт)
├── Share Sheet интеграция
├── Performance оптимизация
├── Documentation (DocC)
├── Demo в NetCheckerDemo app
└── README обновление
```

---

## 16. Конкурентный анализ

```
┌──────────────┬──────────┬──────────┬──────────┬───────────────┐
│ Фича         │NetChecker│  Pulse   │  netfox  │  Wormholy     │
│              │ Traffic  │ (Kean)   │          │               │
├──────────────┼──────────┼──────────┼──────────┼───────────────┤
│ Перехват all │   ✅     │    ✅    │    ✅    │     ✅        │
│ JSON подсветка│  ✅     │    ✅    │    ✅    │     ✅        │
│ Timing break │  ✅     │    ✅    │    ❌    │     ❌        │
│ Waterfall    │   ✅     │    ✅    │    ❌    │     ❌        │
│ cURL export  │   ✅     │    ✅    │    ✅    │     ✅        │
│ HAR export   │   ✅     │    ✅    │    ❌    │     ❌        │
│ Mock Engine  │   ✅     │    ❌    │    ❌    │     ❌        │
│ Breakpoints  │   ✅     │    ❌    │    ❌    │     ❌        │
│ Статистика   │   ✅     │    ✅    │    ❌    │     ❌        │
│ Фильтры      │  ✅     │    ✅    │    ✅    │     ✅        │
│ SwiftUI      │   ✅     │    ✅    │    ❌    │     ❌        │
│ 0 зависим.   │  ✅     │    ✅    │    ✅    │     ✅        │
│ SPM          │   ✅     │    ✅    │    ✅    │     ✅        │
│ + Network    │   ✅     │    ❌    │    ❌    │     ❌        │
│   monitoring │         │          │          │               │
│ + Speed test │   ✅     │    ❌    │    ❌    │     ❌        │
│ + WiFi info  │   ✅     │    ❌    │    ❌    │     ❌        │
│ + Security   │   ✅     │    ❌    │    ❌    │     ❌        │
│              │          │          │          │               │
│ Цена        │   FREE   │ Freemium │   FREE   │    FREE       │
└──────────────┴──────────┴──────────┴──────────┴───────────────┘

Главное преимущество NetChecker:
Единственный пакет, объединяющий traffic inspection
+ network monitoring + diagnostics + speed test в одном SPM.
```

---

*Документ подготовлен: Февраль 2026*
*Версия плана: 1.0*
*Модуль: NetCheckerTraffic + NetCheckerTrafficUI*
