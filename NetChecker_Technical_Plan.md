# 🔍 NetChecker — Технический план SPM-пакета для iOS

> **Универсальный сетевой чекер для iOS** — Swift Package Manager библиотека для мониторинга, диагностики и анализа сетевых подключений.

---

## 1. Обзор продукта

### Концепция

**NetChecker** — это модульный SPM-пакет, который предоставляет полный набор инструментов для мониторинга и диагностики сети на iOS. Подключается одной строкой в любой Xcode-проект и предоставляет как программный API, так и готовые SwiftUI-компоненты для визуализации.

### Ключевые принципы

- **Plug & Play** — подключение через SPM за 10 секунд, работа «из коробки»
- **Модульность** — импортируй только нужные модули, не тяни лишнее
- **SwiftUI-first** — готовые UI-компоненты с полной кастомизацией
- **Privacy-safe** — минимум разрешений, никакого сбора данных
- **Offline-capable** — вся логика работает локально на устройстве

---

## 2. Архитектура пакета

### Структура модулей SPM

```
NetChecker/
├── Package.swift
├── Sources/
│   ├── NetCheckerCore/            ← Ядро: мониторинг состояния сети
│   ├── NetCheckerDiagnostics/     ← Диагностика: ping, traceroute, DNS
│   ├── NetCheckerSpeed/           ← Тест скорости: upload/download
│   ├── NetCheckerWiFi/            ← WiFi: SSID, BSSID, сигнал, безопасность
│   ├── NetCheckerCellular/        ← Сотовая: оператор, технология, роуминг
│   ├── NetCheckerSecurity/        ← Безопасность: VPN, proxy, DNS-leak
│   ├── NetCheckerLogger/          ← Логгер: история событий и метрик
│   └── NetCheckerUI/              ← UI: готовые SwiftUI-компоненты
├── Tests/
│   ├── NetCheckerCoreTests/
│   ├── NetCheckerDiagnosticsTests/
│   ├── NetCheckerSpeedTests/
│   └── ...
└── README.md
```

### Package.swift — граф зависимостей

```
┌─────────────────────────────────────────────────────────────────┐
│                        NetCheckerUI                             │
│                  (SwiftUI-компоненты)                           │
│         зависит от ВСЕХ нижележащих модулей                     │
└──────────┬──────────┬──────────┬──────────┬─────────────────────┘
           │          │          │          │
     ┌─────▼───┐ ┌────▼────┐ ┌──▼───┐ ┌───▼──────┐
     │  Speed  │ │  WiFi   │ │Cell. │ │ Security │
     │  Test   │ │  Info   │ │ Info │ │ Analysis │
     └────┬────┘ └────┬────┘ └──┬───┘ └───┬──────┘
          │           │         │          │
     ┌────▼───────────▼─────────▼──────────▼──────┐
     │           NetCheckerDiagnostics             │
     │       (Ping, Traceroute, DNS Lookup)        │
     └─────────────────┬──────────────────────────-┘
                       │
     ┌─────────────────▼──────────────────────────┐
     │            NetCheckerCore                   │
     │  (NWPathMonitor, базовые типы, протоколы)   │
     └─────────────────┬──────────────────────────-┘
                       │
     ┌─────────────────▼──────────────────────────┐
     │           NetCheckerLogger                  │
     │     (Логирование, история, экспорт)         │
     └─────────────────────────────────────────────┘
```

### Подключение разработчиком

```swift
// Минимальное — только мониторинг
import NetCheckerCore

// Полный набор с UI
import NetCheckerUI

// Выборочно — только диагностика и скорость
import NetCheckerDiagnostics
import NetCheckerSpeed
```

---

## 3. Детальное описание модулей

---

### 3.1 NetCheckerCore — Ядро

**Роль:** Центральный модуль. Мониторинг состояния сети в реальном времени, базовые типы данных, общие протоколы.

**Используемые фреймворки Apple:**
- `Network.framework` — `NWPathMonitor`, `NWPath`, `NWInterface`
- `SystemConfiguration` — `SCNetworkReachability` (фолбек)
- `Combine` — реактивные потоки данных
- `os.log` — нативное логирование

**Основные компоненты:**

| Компонент | Описание |
|-----------|----------|
| `NetworkMonitor` | Синглтон/инстанс обёртка над `NWPathMonitor`. Отслеживает тип подключения (WiFi/Cellular/Ethernet/None), статус (satisfied/unsatisfied/requiresConnection) |
| `NetworkStatus` | Enum-модель текущего состояния: `.connected(type)`, `.disconnected`, `.restricted` |
| `ConnectionType` | Enum: `.wifi`, `.cellular`, `.wiredEthernet`, `.loopback`, `.other` |
| `NetworkEvent` | Модель события: timestamp, oldStatus, newStatus, duration |
| `NetCheckerConfiguration` | Глобальные настройки: интервалы, таймауты, уровень логирования |
| `NetworkQuality` | Оценка качества: `.excellent`, `.good`, `.fair`, `.poor`, `.none` |

**Публичный API (ключевые интерфейсы):**

```
protocol NetworkMonitoring {
    var currentStatus: NetworkStatus { get }
    var statusPublisher: AnyPublisher<NetworkStatus, Never> { get }
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
    func startMonitoring()
    func stopMonitoring()
}

protocol NetworkEventDelegate: AnyObject {
    func networkStatusDidChange(from: NetworkStatus, to: NetworkStatus)
    func networkQualityDidChange(quality: NetworkQuality)
}
```

**Поддержка async/await:**

```
// Современный API
func observeStatus() -> AsyncStream<NetworkStatus>
func waitForConnection() async -> ConnectionType
```

---

### 3.2 NetCheckerDiagnostics — Диагностика

**Роль:** Активные диагностические инструменты для проверки сетевых проблем.

**Используемые фреймворки:**
- `Network.framework` — `NWConnection` (TCP/UDP)
- `CFNetwork` — low-level socket ops
- `dnssd` — DNS-резолвинг (Darwin API)

**Основные компоненты:**

| Компонент | Описание |
|-----------|----------|
| `PingService` | ICMP Ping через `NWConnection`. RTT, jitter, packet loss, min/avg/max |
| `TracerouteService` | Трассировка маршрута через TTL-инкремент с UDP/ICMP |
| `DNSLookupService` | DNS-резолвинг: A, AAAA, CNAME, MX, TXT записи. Поддержка кастомных DNS-серверов |
| `PortScanner` | Проверка доступности портов (TCP connect). Сканирование популярных портов или кастомного диапазона |
| `HTTPProbe` | HTTP(S) проверка: status code, response time, SSL certificate info, redirect chain |
| `LatencyMeter` | Непрерывный замер латентности к заданному хосту |

**Модели данных:**

```
PingResult:
  ├── host: String
  ├── ipAddress: String
  ├── roundTripTime: TimeInterval
  ├── ttl: Int
  ├── sequenceNumber: Int
  ├── packetSize: Int
  └── timestamp: Date

PingSummary:
  ├── packetsTransmitted: Int
  ├── packetsReceived: Int
  ├── packetLoss: Double (%)
  ├── minRTT / avgRTT / maxRTT: TimeInterval
  └── jitter: TimeInterval

TracerouteHop:
  ├── hopNumber: Int
  ├── address: String?
  ├── hostname: String?
  ├── rtt1 / rtt2 / rtt3: TimeInterval?
  └── isTimeout: Bool

DNSRecord:
  ├── type: DNSRecordType (.A, .AAAA, .CNAME, .MX, .TXT)
  ├── name: String
  ├── value: String
  ├── ttl: Int
  └── resolverUsed: String

PortScanResult:
  ├── port: UInt16
  ├── status: PortStatus (.open, .closed, .filtered, .timeout)
  ├── serviceName: String?      // "HTTP", "HTTPS", "SSH" и т.д.
  ├── responseTime: TimeInterval
  └── banner: String?           // Ответ сервиса, если есть
```

**Предустановленные профили сканирования портов:**

```
PortProfile.webServer     → [80, 443, 8080, 8443]
PortProfile.mail          → [25, 110, 143, 465, 587, 993, 995]
PortProfile.database      → [3306, 5432, 27017, 6379, 1433]
PortProfile.common        → [21, 22, 23, 25, 53, 80, 110, 143, 443, 993, 995, 3389, 8080]
PortProfile.gaming        → [3478, 3479, 3480, 27015-27030]
PortProfile.custom([...]) → произвольный набор
```

---

### 3.3 NetCheckerSpeed — Тест скорости

**Роль:** Измерение скорости загрузки/отдачи и задержки. Аналог Speedtest/Fast.com.

**Используемые фреймворки:**
- `URLSession` — HTTP-транспорт с метриками (`URLSessionTaskMetrics`)
- `Network.framework` — TCP throughput estimation
- `CFNetwork` — low-level для точных замеров

**Основные компоненты:**

| Компонент | Описание |
|-----------|----------|
| `SpeedTestEngine` | Оркестратор: запуск теста, управление фазами (latency → download → upload) |
| `DownloadMeasurer` | Многопоточная загрузка тестовых файлов, замер throughput |
| `UploadMeasurer` | Многопоточная отправка данных, замер throughput |
| `SpeedTestServer` | Модель тестового сервера с выбором ближайшего |
| `BandwidthEstimator` | Алгоритм оценки реальной пропускной способности |

**Алгоритм тестирования:**

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  Phase 1:    │     │    Phase 2:      │     │  Phase 3:    │
│  Latency     │────▶│   Download       │────▶│   Upload     │
│  (10 pings)  │     │ (multi-stream)   │     │(multi-stream)│
│  ~2 сек      │     │   ~10 сек        │     │  ~10 сек     │
└──────────────┘     └──────────────────┘     └──────────────┘

Download/Upload алгоритм:
1. Начать с малого файла (100KB) для калибровки
2. Увеличивать размер и количество потоков адаптивно
3. Использовать 4-8 параллельных TCP-потоков
4. Отбрасывать первые 10% и последние 10% замеров (warm-up/cool-down)
5. Медиана оставшихся = финальный результат
```

**Модели данных:**

```
SpeedTestResult:
  ├── downloadSpeed: Measurement<UnitInformationStorage> (Mbps)
  ├── uploadSpeed: Measurement<UnitInformationStorage> (Mbps)
  ├── latency: TimeInterval (ms)
  ├── jitter: TimeInterval (ms)
  ├── serverInfo: SpeedTestServer
  ├── connectionType: ConnectionType
  ├── timestamp: Date
  └── testDuration: TimeInterval

SpeedTestProgress:
  ├── phase: TestPhase (.latency, .download, .upload)
  ├── progress: Double (0.0 - 1.0)
  ├── currentSpeed: Double (Mbps, мгновенная)
  └── elapsedTime: TimeInterval
```

**Тестовые серверы (стратегия):**

```
Варианты бэкенда:
├── Публичные серверы (Netflix Fast.com CDN, LibreSpeed, Cloudflare)
├── Self-hosted endpoint (для корпоративных клиентов)
└── Configurable URL — разработчик задаёт свой endpoint

По умолчанию: использовать Cloudflare Speed Test API
(speed.cloudflare.com — бесплатный, надёжный, глобальный)
```

---

### 3.4 NetCheckerWiFi — WiFi информация

**Роль:** Детальная информация о текущем WiFi-подключении.

**Используемые фреймворки:**
- `NetworkExtension` — `NEHotspotHelper`, `NEHotspotNetwork`
- `CoreLocation` — требуется для доступа к SSID (iOS 13+)
- `SystemConfiguration.CaptiveNetwork` — `CNCopyCurrentNetworkInfo`

**⚠️ Ограничения iOS:**

```
ВАЖНО: Apple ограничивает доступ к WiFi-информации!

Для получения SSID/BSSID требуется:
├── iOS 12: Entitlement "com.apple.developer.networking.wifi-info"
├── iOS 13+: + разрешение CoreLocation (whenInUse минимум)
├── iOS 14+: + пользователь должен быть подключён к WiFi
└── iOS 16+: можно использовать NEHotspotNetwork.fetchCurrent()

Entitlements необходимые в проекте-потребителе:
├── Access WiFi Information
└── Location When In Use (для SSID)
```

**Основные компоненты:**

| Компонент | Описание |
|-----------|----------|
| `WiFiInfoProvider` | Текущая сеть: SSID, BSSID, security type |
| `WiFiQualityAnalyzer` | Анализ качества: RSSI → уровень сигнала, шум, SNR |
| `WiFiSecurityChecker` | Определение типа защиты: Open/WEP/WPA/WPA2/WPA3 |
| `WiFiHistory` | История подключений к WiFi-сетям (локальная БД) |

**Модели данных:**

```
WiFiNetworkInfo:
  ├── ssid: String?
  ├── bssid: String?
  ├── signalStrength: Int (dBm, -30...-90)
  ├── signalQuality: SignalQuality (.excellent, .good, .fair, .weak)
  ├── securityType: WiFiSecurity (.open, .wep, .wpa, .wpa2, .wpa3, .enterprise)
  ├── frequency: WiFiFrequency? (.band2_4GHz, .band5GHz, .band6GHz)
  ├── channel: Int?
  ├── ipAddress: String
  ├── subnetMask: String
  ├── routerAddress: String
  ├── dnsServers: [String]
  └── isHotspot: Bool
```

---

### 3.5 NetCheckerCellular — Сотовая сеть

**Роль:** Информация о сотовом подключении.

**Используемые фреймворки:**
- `CoreTelephony` — `CTTelephonyNetworkInfo`, `CTCarrier`
- `Network.framework` — определение cellular path

**Основные компоненты:**

| Компонент | Описание |
|-----------|----------|
| `CellularInfoProvider` | Оператор, технология, MCC/MNC |
| `CellularTechnologyDetector` | Определение поколения: 2G/3G/4G/5G с подтипами |
| `DualSIMHandler` | Поддержка Dual SIM: информация по обеим SIM |
| `RoamingDetector` | Определение роуминга |

**Модели данных:**

```
CellularNetworkInfo:
  ├── carrierName: String?
  ├── technology: CellularTechnology
  │     (.gprs, .edge, .wcdma, .hsdpa, .hsupa, .lte, .lteAdvanced, .nr, .nrNSA)
  ├── generation: CellularGeneration (.2g, .3g, .4g, .5g)
  ├── mobileCountryCode: String?
  ├── mobileNetworkCode: String?
  ├── isoCountryCode: String?
  ├── isRoaming: Bool
  ├── allowsVOIP: Bool
  ├── simSlot: SIMSlot (.primary, .secondary)
  └── dataServiceIdentifier: String?
```

---

### 3.6 NetCheckerSecurity — Безопасность

**Роль:** Анализ безопасности текущего сетевого подключения.

**Используемые фреймворки:**
- `Network.framework` — proxy detection
- `NetworkExtension` — VPN status
- `Security.framework` — certificate evaluation
- `dnssd` — DNS leak detection

**Основные компоненты:**

| Компонент | Описание |
|-----------|----------|
| `VPNDetector` | Обнаружение активного VPN-соединения (любого типа) |
| `ProxyDetector` | Обнаружение HTTP/SOCKS proxy |
| `DNSLeakChecker` | Проверка утечки DNS (запрос к известным leak-test серверам) |
| `SSLCertificateInspector` | Проверка SSL-сертификата хоста: chain, expiry, pinning |
| `NetworkThreatAnalyzer` | Комплексная оценка безопасности сети |
| `CaptivePortalDetector` | Обнаружение captive portal (отельный/аэропортный WiFi) |

**Модели данных:**

```
NetworkSecurityReport:
  ├── overallScore: Int (0-100)
  ├── riskLevel: SecurityRiskLevel (.safe, .low, .medium, .high, .critical)
  ├── vpnStatus: VPNStatus (.active(protocol), .inactive)
  ├── proxyStatus: ProxyStatus (.none, .http(host, port), .socks(host, port))
  ├── dnsLeakDetected: Bool
  ├── dnsServers: [DNSServerInfo]
  ├── isCaptivePortal: Bool
  ├── encryptionType: WiFiSecurity
  ├── threats: [NetworkThreat]
  └── recommendations: [SecurityRecommendation]

SSLCertificateInfo:
  ├── subject: String
  ├── issuer: String
  ├── validFrom: Date
  ├── validUntil: Date
  ├── isExpired: Bool
  ├── serialNumber: String
  ├── signatureAlgorithm: String
  ├── publicKeyBits: Int
  ├── chain: [CertificateInfo]
  └── trustResult: SecTrustResultType
```

---

### 3.7 NetCheckerLogger — Логирование

**Роль:** Запись, хранение и экспорт сетевых событий и метрик.

**Используемые технологии:**
- `SwiftData` / `CoreData` — персистентное хранение (опционально)
- `os.log` / `OSLog` — системное логирование
- `Combine` — реактивная подписка на лог-поток

**Основные компоненты:**

| Компонент | Описание |
|-----------|----------|
| `NetworkLogger` | Центральный логгер: фильтрация, уровни, вывод |
| `EventStore` | Хранилище событий: in-memory + опциональный диск |
| `MetricsAggregator` | Агрегация метрик: uptime %, avg latency, total data, аналитика |
| `LogExporter` | Экспорт в JSON / CSV / отправка на сервер |

**Модели данных:**

```
NetworkLogEntry:
  ├── id: UUID
  ├── timestamp: Date
  ├── level: LogLevel (.debug, .info, .warning, .error)
  ├── category: LogCategory (.connectivity, .speed, .dns, .security, .wifi, .cellular)
  ├── message: String
  ├── metadata: [String: Any]
  └── sessionId: UUID

NetworkSessionSummary:
  ├── sessionStart: Date
  ├── sessionEnd: Date
  ├── uptimePercentage: Double
  ├── disconnections: Int
  ├── avgLatency: TimeInterval
  ├── connectionTypes: [ConnectionType: TimeInterval]   // время на каждом типе
  ├── dataTransferred: (rx: Int64, tx: Int64)
  └── events: [NetworkLogEntry]
```

---

### 3.8 NetCheckerUI — SwiftUI компоненты

**Роль:** Готовые, стилизуемые SwiftUI-виджеты для отображения сетевой информации.

**Ключевой принцип:** Каждый компонент работает автономно — просто вставь в View, данные подтянутся автоматически.

**Компоненты:**

| Компонент | Описание | Визуал |
|-----------|----------|--------|
| `NetworkStatusBadge` | Компактный бейдж: иконка + статус + тип подключения | 🟢 WiFi Connected |
| `NetworkStatusBanner` | Баннер с подробным статусом (для верха экрана) | Полоса с анимацией |
| `SpeedTestView` | Полноэкранный тест скорости с анимированным спидометром | Как Speedtest.net |
| `SpeedGaugeView` | Отдельный анимированный спидометр (download/upload) | Стрелочный/круговой gauge |
| `PingView` | Визуализация ping: график RTT в реальном времени | Line chart с точками |
| `TracerouteView` | Визуализация хопов трассировки | Список с timeline |
| `WiFiDetailCard` | Карточка WiFi: SSID, сигнал, безопасность, IP | Card с иконками |
| `CellularDetailCard` | Карточка сотовой: оператор, технология, роуминг | Card с иконками |
| `SecurityDashboard` | Дашборд безопасности со скором и рекомендациями | Score circle + list |
| `NetworkHistoryChart` | График истории: uptime, скорость, тип подключения за период | Charts framework |
| `DNSLookupView` | Интерфейс DNS-запросов с результатами | Input + Table |
| `PortScanView` | Интерфейс сканирования портов | Progress + Results grid |
| `FullDashboardView` | Полный дашборд: все метрики на одном экране | Tab-based layout |
| `MiniOverlayView` | Мини-оверлей для отладки (как в FLEX/Pulse) | Floating badge |

**Система стилизации:**

```
Каждый компонент поддерживает:
├── .netCheckerStyle(.compact / .regular / .expanded)
├── .netCheckerTheme(NetCheckerTheme(...))
│     ├── accentColor: Color
│     ├── backgroundColor: Color
│     ├── textStyle: Font
│     ├── cornerRadius: CGFloat
│     └── animationsEnabled: Bool
├── .netCheckerColorScheme(.auto / .light / .dark)
└── Custom ViewModifier для полной кастомизации
```

**Пример использования разработчиком:**

```
// Одна строка — и у вас полный сетевой дашборд
FullDashboardView()

// Или выборочно
VStack {
    NetworkStatusBanner()
    WiFiDetailCard()
    SpeedTestView()
        .netCheckerStyle(.compact)
}
```

---

## 4. Системные требования и зависимости

### Минимальные требования

| Параметр | Значение |
|----------|----------|
| iOS | 16.0+ (основной), iOS 15.0 (ограниченная поддержка) |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| Архитектуры | arm64 (device), x86_64 + arm64 (simulator) |
| macOS Catalyst | Поддерживается |
| visionOS | Базовая поддержка (без WiFi-специфики) |
| watchOS | Только NetCheckerCore (мониторинг) |

### Entitlements (требуются в проекте-потребителе)

```
┌─────────────────────────────────────────────────────────────┐
│ Entitlement                          │ Модуль    │ Обязат. │
├─────────────────────────────────────────────────────────────┤
│ Access WiFi Information              │ WiFi      │   Да    │
│ Hotspot Helper (если NEHotspot)      │ WiFi      │   Нет   │
│ Network Extensions (если VPN check)  │ Security  │   Нет   │
│ Location When In Use                 │ WiFi      │   Да*   │
│ Local Network (Bonjour)              │ Diagn.    │   Нет   │
└─────────────────────────────────────────────────────────────┘
* Для получения SSID на iOS 13-15. На iOS 16+ NEHotspotNetwork.fetchCurrent()
```

### Зависимости (минимальные, только при необходимости)

```
Основные модули: НОЛЬ внешних зависимостей (только Apple frameworks)

Опциональные (для UI):
├── Swift Charts (Apple, iOS 16+) — графики в NetCheckerUI
└── Нет third-party зависимостей — принципиальная позиция
```

---

## 5. Потоки данных

### Реактивная архитектура

```
┌─────────────┐    ┌──────────────┐    ┌────────────────┐
│ NWPathMonitor│───▶│ NetworkMonitor│───▶│   @Published   │
│ (System)     │    │  (Core)       │    │   properties   │
└─────────────┘    └──────┬───────┘    └───────┬────────┘
                          │                     │
                    ┌─────▼─────┐         ┌─────▼──────┐
                    │  Logger   │         │  SwiftUI   │
                    │  Events   │         │  Views     │
                    └───────────┘         └────────────┘

Три способа получения данных:
├── 1. Combine Publisher: monitor.statusPublisher.sink { ... }
├── 2. Async/Await:      for await status in monitor.statusStream { ... }
└── 3. Delegate:         monitor.delegate = self
```

### Жизненный цикл тестирования (Speed Test)

```
┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌─────────┐
│  Idle   │───▶│ Preparing│───▶│ Testing  │───▶│ Processing│──▶│ Complete│
│         │    │ (server  │    │ (3 phases│    │ (calculate│   │ (result │
│         │    │  select) │    │  running)│    │  medians) │   │  ready) │
└─────────┘    └──────────┘    └──────────┘    └──────────┘    └─────────┘
     ▲                              │
     │         ┌──────────┐         │
     └─────────│ Cancelled│◀────────┘
               └──────────┘
```

---

## 6. Безопасность и Privacy

### Privacy Manifest (PrivacyInfo.xcprivacy)

```
Обязательно для iOS 17+:

Required Reason APIs:
├── NSPrivacyAccessedAPICategorySystemBootTime → Для замера uptime
├── NSPrivacyAccessedAPICategoryDiskSpace → Нет (не используем)
└── NSPrivacyAccessedAPICategoryUserDefaults → Хранение настроек

Data Collection:
├── Данные НЕ покидают устройство
├── Нет analytics/tracking
├── Нет fingerprinting
└── Полное соответствие App Store Review Guidelines
```

### Info.plist строки для потребителя

```
NSLocationWhenInUseUsageDescription:
  "Для определения имени WiFi-сети (SSID) требуется доступ к геолокации"

NSLocalNetworkUsageDescription:
  "Для диагностики локальной сети (обнаружение устройств и сервисов)"
```

---

## 7. Стратегия тестирования

```
┌────────────────────────────────────────────────────────────┐
│                    Пирамида тестов                          │
│                                                             │
│                    ┌─────────┐                              │
│                    │  UI     │  ← XCUITest: 5-10 тестов     │
│                  ┌─┴─────────┴─┐                            │
│                  │ Integration │  ← 30-50 тестов             │
│                ┌─┴─────────────┴─┐                          │
│                │   Unit Tests    │  ← 200+ тестов            │
│              ┌─┴─────────────────┴─┐                        │
│              │    Mock/Protocol     │  ← Все сетевые         │
│              │    based testing     │    вызовы мокаются     │
│              └─────────────────────┘                        │
└────────────────────────────────────────────────────────────┘

Ключевые принципы:
├── Все сетевые операции за протоколами → легко мокать
├── Mock-сервер для SpeedTest (localhost)
├── Тесты не требуют реальной сети
├── CI/CD через GitHub Actions или Xcode Cloud
└── Code coverage target: 80%+
```

---

## 8. Примеры интеграции (Developer Experience)

### Сценарий 1: Быстрый мониторинг в приложении

```
// 1. File > Add Package > URL репозитория
// 2. Выбрать модуль "NetCheckerCore"
// 3. import NetCheckerCore
// 4. Использовать:

let monitor = NetworkMonitor.shared
monitor.startMonitoring()
// Готово! Статус доступен через monitor.currentStatus
```

### Сценарий 2: Отладочный оверлей

```
// Добавить плавающий бейдж с информацией о сети
// поверх любого View:

ContentView()
    .overlay { MiniOverlayView() }
```

### Сценарий 3: Корпоративное приложение

```
// Полный дашборд для IT-отдела:

NavigationStack {
    FullDashboardView()
        .netCheckerTheme(companyTheme)
        .onSecurityThreat { threat in
            sendAlertToIT(threat)
        }
}
```

---

## 9. Roadmap по фазам разработки

### Фаза 1 — MVP (2-3 недели)

```
✅ NetCheckerCore (мониторинг, статус, типы)
✅ NetCheckerDiagnostics (ping, DNS lookup)
✅ NetCheckerUI (StatusBadge, StatusBanner, PingView)
✅ Unit тесты для Core и Diagnostics
✅ README + Quick Start Guide
✅ Package.swift с модульной структурой
```

### Фаза 2 — Расширение (2-3 недели)

```
✅ NetCheckerWiFi (SSID, сигнал, безопасность)
✅ NetCheckerCellular (оператор, технология)
✅ NetCheckerSpeed (download/upload test)
✅ NetCheckerUI (WiFiCard, CellularCard, SpeedTestView)
✅ Integration тесты
✅ Пример Demo App
```

### Фаза 3 — Продвинутое (2-3 недели)

```
✅ NetCheckerSecurity (VPN, proxy, DNS leak, SSL)
✅ NetCheckerLogger (события, метрики, экспорт)
✅ Traceroute, Port Scanner
✅ FullDashboardView, SecurityDashboard
✅ NetworkHistoryChart
✅ Performance оптимизация
```

### Фаза 4 — Полировка (1-2 недели)

```
✅ Privacy Manifest
✅ Documentation (DocC)
✅ Примеры кода на каждый модуль
✅ CI/CD pipeline
✅ watchOS / macOS Catalyst поддержка
✅ Публикация v1.0
```

---

## 10. Структура файлов финального пакета

```
NetChecker/
├── Package.swift
├── LICENSE
├── README.md
├── CHANGELOG.md
├── Documentation.docc/
│   ├── NetChecker.md
│   ├── GettingStarted.md
│   ├── Tutorials/
│   └── Resources/
├── Sources/
│   ├── NetCheckerCore/
│   │   ├── NetworkMonitor.swift
│   │   ├── Models/
│   │   │   ├── NetworkStatus.swift
│   │   │   ├── ConnectionType.swift
│   │   │   ├── NetworkQuality.swift
│   │   │   └── NetworkEvent.swift
│   │   ├── Protocols/
│   │   │   ├── NetworkMonitoring.swift
│   │   │   └── NetworkEventDelegate.swift
│   │   ├── Configuration/
│   │   │   └── NetCheckerConfiguration.swift
│   │   └── Extensions/
│   │       └── NWPath+Extensions.swift
│   ├── NetCheckerDiagnostics/
│   │   ├── Ping/
│   │   │   ├── PingService.swift
│   │   │   └── PingResult.swift
│   │   ├── Traceroute/
│   │   │   ├── TracerouteService.swift
│   │   │   └── TracerouteHop.swift
│   │   ├── DNS/
│   │   │   ├── DNSLookupService.swift
│   │   │   └── DNSRecord.swift
│   │   ├── PortScan/
│   │   │   ├── PortScanner.swift
│   │   │   ├── PortScanResult.swift
│   │   │   └── PortProfile.swift
│   │   └── HTTP/
│   │       ├── HTTPProbe.swift
│   │       └── HTTPProbeResult.swift
│   ├── NetCheckerSpeed/
│   │   ├── SpeedTestEngine.swift
│   │   ├── DownloadMeasurer.swift
│   │   ├── UploadMeasurer.swift
│   │   ├── BandwidthEstimator.swift
│   │   └── Models/
│   │       ├── SpeedTestResult.swift
│   │       ├── SpeedTestProgress.swift
│   │       └── SpeedTestServer.swift
│   ├── NetCheckerWiFi/
│   │   ├── WiFiInfoProvider.swift
│   │   ├── WiFiQualityAnalyzer.swift
│   │   ├── WiFiSecurityChecker.swift
│   │   └── Models/
│   │       └── WiFiNetworkInfo.swift
│   ├── NetCheckerCellular/
│   │   ├── CellularInfoProvider.swift
│   │   ├── CellularTechnologyDetector.swift
│   │   ├── DualSIMHandler.swift
│   │   └── Models/
│   │       └── CellularNetworkInfo.swift
│   ├── NetCheckerSecurity/
│   │   ├── VPNDetector.swift
│   │   ├── ProxyDetector.swift
│   │   ├── DNSLeakChecker.swift
│   │   ├── SSLCertificateInspector.swift
│   │   ├── CaptivePortalDetector.swift
│   │   ├── NetworkThreatAnalyzer.swift
│   │   └── Models/
│   │       ├── NetworkSecurityReport.swift
│   │       └── SSLCertificateInfo.swift
│   ├── NetCheckerLogger/
│   │   ├── NetworkLogger.swift
│   │   ├── EventStore.swift
│   │   ├── MetricsAggregator.swift
│   │   ├── LogExporter.swift
│   │   └── Models/
│   │       ├── NetworkLogEntry.swift
│   │       └── NetworkSessionSummary.swift
│   └── NetCheckerUI/
│       ├── Components/
│       │   ├── NetworkStatusBadge.swift
│       │   ├── NetworkStatusBanner.swift
│       │   ├── SpeedTestView.swift
│       │   ├── SpeedGaugeView.swift
│       │   ├── PingView.swift
│       │   ├── TracerouteView.swift
│       │   ├── WiFiDetailCard.swift
│       │   ├── CellularDetailCard.swift
│       │   ├── SecurityDashboard.swift
│       │   ├── NetworkHistoryChart.swift
│       │   ├── DNSLookupView.swift
│       │   ├── PortScanView.swift
│       │   ├── FullDashboardView.swift
│       │   └── MiniOverlayView.swift
│       ├── Theme/
│       │   ├── NetCheckerTheme.swift
│       │   └── NetCheckerStyle.swift
│       ├── ViewModifiers/
│       │   └── NetCheckerModifiers.swift
│       └── Helpers/
│           ├── SpeedFormatter.swift
│           └── SignalStrengthIcon.swift
├── Tests/
│   ├── NetCheckerCoreTests/
│   ├── NetCheckerDiagnosticsTests/
│   ├── NetCheckerSpeedTests/
│   ├── NetCheckerWiFiTests/
│   ├── NetCheckerCellularTests/
│   ├── NetCheckerSecurityTests/
│   ├── NetCheckerLoggerTests/
│   └── Mocks/
│       ├── MockNetworkMonitor.swift
│       ├── MockPingService.swift
│       └── MockSpeedTestEngine.swift
└── Example/
    └── NetCheckerDemo/
        ├── NetCheckerDemo.xcodeproj
        └── NetCheckerDemo/
            ├── App.swift
            ├── ContentView.swift
            └── Tabs/
                ├── DashboardTab.swift
                ├── DiagnosticsTab.swift
                ├── SpeedTestTab.swift
                └── SecurityTab.swift
```

---

## 11. Конкурентный анализ и отличия

| Фича | NetChecker | Pulse (Kean) | Reachability.swift | Alamofire NetworkMonitor |
|-------|-----------|-------------|-------------------|------------------------|
| Мониторинг сети | ✅ | ✅ | ✅ | ✅ |
| Ping / Traceroute | ✅ | ❌ | ❌ | ❌ |
| Speed Test | ✅ | ❌ | ❌ | ❌ |
| Port Scanner | ✅ | ❌ | ❌ | ❌ |
| DNS Lookup | ✅ | ❌ | ❌ | ❌ |
| WiFi Details | ✅ | ❌ | ❌ | ❌ |
| Cellular Info | ✅ | ❌ | ❌ | ❌ |
| Security Analysis | ✅ | ❌ | ❌ | ❌ |
| Готовый UI | ✅ SwiftUI | ✅ SwiftUI | ❌ | ❌ |
| Модульный SPM | ✅ | ✅ | ✅ | Часть Alamofire |
| 0 зависимостей | ✅ | ✅ | ✅ | ❌ |
| async/await | ✅ | ✅ | ❌ | ✅ |
| Логирование | ✅ | ✅ (основное) | ❌ | ❌ |

**Главное отличие NetChecker:** комплексное решение "всё в одном" с модульной архитектурой. Не нужно собирать из разных библиотек.

---

*Документ подготовлен: Февраль 2026*
*Версия плана: 1.0*
