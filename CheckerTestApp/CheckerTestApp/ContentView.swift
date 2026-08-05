//
//  ContentView.swift
//  CheckerTestApp
//
//  Created by Shakhzod on 04/02/26.
//

import SwiftUI
import NetCheckerTraffic

struct ContentView: View {
    var body: some View {
        TabView {
            // Home - Feature Overview
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            // API Testing
            NavigationStack {
                APITestView()
            }
            .tabItem {
                Label("API Test", systemImage: "arrow.up.arrow.down")
            }

            // Traffic Inspector.
            // Начиная с 2.0.0 экран не создаёт собственный NavigationStack —
            // без обёртки пропадают заголовок и панель инструментов
            NavigationStack {
                TrafficListView()
            }
            .tabItem {
                Label("Traffic", systemImage: "network")
            }

            // API Flows — сценарии из связанных запросов
            NavigationStack {
                FlowListView()
            }
            .tabItem {
                Label("Flows", systemImage: "point.3.connected.trianglepath.dotted")
            }

            // Моки и брейкпоинты вместе: TabView на iOS показывает пять вкладок,
            // шестая уехала бы в «More» и перестала быть доступной напрямую
            NavigationStack {
                RulesDemoView()
            }
            .tabItem {
                Label("Rules", systemImage: "slider.horizontal.3")
            }
        }
        .onAppear {
            startInterceptor()
            setupDemoEnvironments()
        }
    }

    /// Начиная с 2.0.0 перехват не стартует в Release без явного разрешения.
    /// TestFlight собирается как Release, поэтому границу проводит флаг сборки,
    /// а не `#if DEBUG`: с ним тестировщики получают инспектор, а сборка
    /// в App Store остаётся нетронутой.
    private func startInterceptor() {
        var config = InterceptorConfiguration()

        #if TESTFLIGHT
        config.enableInRelease = true
        #endif

        // Демонстрационные лимиты: тела крупнее 512 КБ не сохраняются,
        // записи живут десять минут
        config.maxRecords = 300
        config.maxBodySizeToCapture = 512 * 1024
        config.retentionPeriod = 600

        TrafficInterceptor.shared.start(configuration: config)
    }

    private func setupDemoEnvironments() {
        let store = EnvironmentStore.shared
        guard store.groups.isEmpty else { return }

        let apiGroup = EnvironmentGroup(
            name: "JSONPlaceholder API",
            sourcePattern: "jsonplaceholder.typicode.com",
            environments: [
                Environment(
                    name: "Production",
                    emoji: "🟢",
                    baseURL: URL(string: "https://jsonplaceholder.typicode.com")!,
                    isDefault: true,
                    variables: ["API_VERSION": "v1", "DEBUG": "false"]
                ),
                Environment(
                    name: "Staging",
                    emoji: "🟡",
                    baseURL: URL(string: "https://jsonplaceholder.typicode.com")!,
                    variables: ["API_VERSION": "v2-beta", "DEBUG": "true"]
                ),
                Environment(
                    name: "Local",
                    emoji: "💻",
                    baseURL: URL(string: "http://localhost:3000")!,
                    variables: ["LOCAL": "true"]
                )
            ]
        )
        store.addGroup(apiGroup)
    }
}

// MARK: - Rules Demo

/// Моки и брейкпоинты на одном экране с переключателем
struct RulesDemoView: View {
    private enum Section: String, CaseIterable {
        case mocks = "Mocks"
        case breakpoints = "Breakpoints"
    }

    @State private var section: Section = .mocks

    var body: some View {
        VStack(spacing: 0) {
            Picker("Раздел", selection: $section) {
                ForEach(Section.allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch section {
            case .mocks: MockDemoView()
            case .breakpoints: BreakpointDemoView()
            }
        }
    }
}

// MARK: - Home View

struct HomeView: View {
    @State private var requestCount = 0
    @ObservedObject private var trafficStore = TrafficStore.shared
    @ObservedObject private var mockEngine = MockEngine.shared
    @ObservedObject private var breakpointEngine = BreakpointEngine.shared
    @ObservedObject private var conditioner = NetworkConditioner.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)

                    Text("NetChecker")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Network Traffic Inspector")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Stats Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(
                        title: "Requests",
                        value: "\(trafficStore.records.count)",
                        icon: "arrow.up.arrow.down.circle.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "Mock Rules",
                        value: "\(mockEngine.rules.count)",
                        icon: "theatermasks.circle.fill",
                        color: .purple
                    )

                    StatCard(
                        title: "Breakpoints",
                        value: "\(breakpointEngine.rules.count)",
                        icon: "hand.raised.circle.fill",
                        color: .orange
                    )

                    StatCard(
                        title: "Paused",
                        value: "\(breakpointEngine.pausedRequests.count)",
                        icon: "pause.circle.fill",
                        color: breakpointEngine.pausedRequests.isEmpty ? .gray : .red
                    )
                }
                .padding(.horizontal)

                // Feature Sections
                VStack(spacing: 16) {
                    FeatureSection(
                        title: "Traffic Monitoring",
                        description: "Capture and inspect all HTTP/HTTPS requests in real-time",
                        icon: "antenna.radiowaves.left.and.right",
                        color: .blue
                    ) {
                        FeatureRow(icon: "clock", text: "Performance timing & waterfall charts")
                        FeatureRow(icon: "doc.text", text: "Headers, body, cookies inspection")
                        FeatureRow(icon: "arrow.clockwise", text: "Edit & retry any request")
                        FeatureRow(icon: "square.and.arrow.up", text: "Export as cURL or HAR")
                    }

                    FeatureSection(
                        title: "Mock Responses",
                        description: "Create custom responses without touching your backend",
                        icon: "theatermasks",
                        color: .purple
                    ) {
                        FeatureRow(icon: "checkmark.circle", text: "Custom status codes & headers")
                        FeatureRow(icon: "clock.badge.exclamationmark", text: "Simulate delays & errors")
                        FeatureRow(icon: "magnifyingglass", text: "URL pattern matching")
                        FeatureRow(icon: "slider.horizontal.3", text: "Priority-based rule matching")
                    }

                    FeatureSection(
                        title: "Breakpoints",
                        description: "Pause, inspect, and modify requests before they're sent",
                        icon: "hand.raised",
                        color: .orange
                    ) {
                        FeatureRow(icon: "pause", text: "Pause requests in real-time")
                        FeatureRow(icon: "pencil", text: "Edit headers & body on-the-fly")
                        FeatureRow(icon: "arrow.uturn.forward", text: "Resume or cancel requests")
                        FeatureRow(icon: "timer", text: "Auto-resume with timeout")
                    }

                    FeatureSection(
                        title: "Environments",
                        description: "Switch between Dev/Staging/Production instantly",
                        icon: "server.rack",
                        color: .green
                    ) {
                        FeatureRow(icon: "arrow.triangle.swap", text: "Quick URL overrides")
                        FeatureRow(icon: "globe", text: "Per-host configuration")
                        FeatureRow(icon: "key", text: "Environment variables")
                    }

                    FeatureSection(
                        title: "Network Conditions",
                        description: "Simulate slow and unreliable connections",
                        icon: "wifi.exclamationmark",
                        color: .teal
                    ) {
                        FeatureRow(icon: "tortoise", text: "3G, EDGE and flaky-link profiles")
                        FeatureRow(icon: "airplane", text: "Simulate no connectivity at all")
                        FeatureRow(icon: "speedometer", text: "Latency, bandwidth and packet loss")
                    }

                    FeatureSection(
                        title: "HAR Import",
                        description: "Replay a recorded session offline",
                        icon: "square.and.arrow.down",
                        color: .indigo
                    ) {
                        FeatureRow(icon: "doc.badge.plus", text: "Load HAR from Chrome, Safari or Charles")
                        FeatureRow(icon: "theatermasks", text: "Turn recorded responses into mocks")
                        FeatureRow(icon: "wifi.slash", text: "Run the app against captured data")
                    }
                }
                .padding(.horizontal)

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            QuickActionButton(
                                title: "Make Request",
                                icon: "arrow.up.circle.fill",
                                color: .blue
                            ) {
                                makeQuickRequest()
                            }

                            QuickActionButton(
                                title: "Clear Traffic",
                                icon: "trash.circle.fill",
                                color: .red
                            ) {
                                TrafficStore.shared.clear()
                            }

                            QuickActionButton(
                                title: "Add Mock",
                                icon: "plus.circle.fill",
                                color: .purple
                            ) {
                                addQuickMock()
                            }

                            QuickActionButton(
                                title: "Add Breakpoint",
                                icon: "hand.raised.circle.fill",
                                color: .orange
                            ) {
                                addQuickBreakpoint()
                            }

                            QuickActionButton(
                                title: conditioner.isEnabled ? "Full Speed" : "Throttle 3G",
                                icon: conditioner.isEnabled ? "hare.circle.fill" : "tortoise.circle.fill",
                                color: .teal
                            ) {
                                if conditioner.isEnabled {
                                    conditioner.disable()
                                } else {
                                    conditioner.apply(.threeG)
                                }
                            }

                            QuickActionButton(
                                title: "Go Offline",
                                icon: "airplane.circle.fill",
                                color: .gray
                            ) {
                                conditioner.apply(.offline)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Активный профиль сети виден сразу — иначе непонятно,
                // почему запросы вдруг стали медленными или падают
                if conditioner.isEnabled {
                    HStack(spacing: 10) {
                        Text(conditioner.activeProfile.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Network: \(conditioner.activeProfile.name)")
                                .font(.subheadline.weight(.medium))
                            Text(conditioner.activeProfile.summary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Off") { conditioner.disable() }
                            .font(.caption.weight(.semibold))
                    }
                    .padding()
                    .background(Color.teal.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tip: Shake your device to open the inspector!", systemImage: "iphone.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("NetChecker Demo")
    }

    private func makeQuickRequest() {
        Task {
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
            _ = try? await URLSession.shared.data(from: url)
        }
    }

    private func addQuickMock() {
        let rule = MockRule(
            name: "Demo: Return 200 OK",
            isEnabled: true,
            matching: MockMatching(urlPattern: "*/posts/*"),
            action: .respond(MockResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: "{\"message\": \"This is a mocked response!\"}".data(using: .utf8)
            ))
        )
        mockEngine.addRule(rule)
        mockEngine.isEnabled = true
    }

    private func addQuickBreakpoint() {
        let rule = BreakpointRule(
            name: "Break: All Posts",
            matching: BreakpointMatching(urlPattern: "*/posts/*"),
            direction: .request
        )
        breakpointEngine.addRule(rule)
        breakpointEngine.isEnabled = true
    }
}

// MARK: - API Test View

struct APITestView: View {
    @State private var results: [APIResult] = []
    @State private var isLoading = false

    var body: some View {
        List {
            // Test Scenarios
            Section {
                TestButton(
                    title: "GET Single Post",
                    subtitle: "/posts/1",
                    method: "GET",
                    color: .blue,
                    isLoading: isLoading
                ) {
                    await fetchSingle()
                }

                TestButton(
                    title: "GET All Users",
                    subtitle: "/users",
                    method: "GET",
                    color: .blue,
                    isLoading: isLoading
                ) {
                    await fetchUsers()
                }

                TestButton(
                    title: "POST Create Post",
                    subtitle: "/posts",
                    method: "POST",
                    color: .green,
                    isLoading: isLoading
                ) {
                    await createPost()
                }

                TestButton(
                    title: "PUT Update Post",
                    subtitle: "/posts/1",
                    method: "PUT",
                    color: .orange,
                    isLoading: isLoading
                ) {
                    await updatePost()
                }

                TestButton(
                    title: "DELETE Post",
                    subtitle: "/posts/1",
                    method: "DELETE",
                    color: .red,
                    isLoading: isLoading
                ) {
                    await deletePost()
                }
            } header: {
                Text("Test Requests")
            } footer: {
                Text("Tap to make requests. View them in the Traffic tab.")
            }

            // Batch Tests
            Section("Batch Tests") {
                TestButton(
                    title: "Fire 5 Requests",
                    subtitle: "GET /posts/1-5",
                    method: "BATCH",
                    color: .purple,
                    isLoading: isLoading
                ) {
                    await batchRequests(count: 5)
                }

                TestButton(
                    title: "Mixed Methods",
                    subtitle: "GET, POST, PUT, DELETE",
                    method: "MIX",
                    color: .indigo,
                    isLoading: isLoading
                ) {
                    await mixedRequests()
                }
            }

            // Error Tests
            Section("Error Scenarios") {
                TestButton(
                    title: "404 Not Found",
                    subtitle: "/posts/99999",
                    method: "GET",
                    color: .gray,
                    isLoading: isLoading
                ) {
                    await fetch404()
                }

                TestButton(
                    title: "Invalid URL",
                    subtitle: "https://invalid.invalid",
                    method: "GET",
                    color: .gray,
                    isLoading: isLoading
                ) {
                    await fetchInvalidURL()
                }
            }

            // Results
            if !results.isEmpty {
                Section("Recent Results") {
                    ForEach(results.reversed()) { result in
                        HStack {
                            Circle()
                                .fill(result.success ? Color.green : Color.red)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline)
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(result.duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Clear Results") {
                        results.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("API Testing")
    }

    // MARK: - API Methods

    private func fetchSingle() async {
        let start = Date()
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            addResult("GET /posts/1", success: status == 200, message: "Status: \(status), Size: \(data.count) bytes", start: start)
        } catch {
            addResult("GET /posts/1", success: false, message: error.localizedDescription, start: start)
        }
    }

    private func fetchUsers() async {
        let start = Date()
        let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let users = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                addResult("GET /users", success: true, message: "Got \(users.count) users", start: start)
            } else {
                addResult("GET /users", success: status == 200, message: "Status: \(status)", start: start)
            }
        } catch {
            addResult("GET /users", success: false, message: error.localizedDescription, start: start)
        }
    }

    private func createPost() async {
        let start = Date()
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = """
        {"title": "Test Post", "body": "Created by NetChecker Demo", "userId": 1}
        """.data(using: .utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            addResult("POST /posts", success: status == 201, message: "Status: \(status) Created", start: start)
        } catch {
            addResult("POST /posts", success: false, message: error.localizedDescription, start: start)
        }
    }

    private func updatePost() async {
        let start = Date()
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = """
        {"id": 1, "title": "Updated Post", "body": "Updated by NetChecker", "userId": 1}
        """.data(using: .utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            addResult("PUT /posts/1", success: status == 200, message: "Status: \(status) Updated", start: start)
        } catch {
            addResult("PUT /posts/1", success: false, message: error.localizedDescription, start: start)
        }
    }

    private func deletePost() async {
        let start = Date()
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            addResult("DELETE /posts/1", success: status == 200, message: "Status: \(status) Deleted", start: start)
        } catch {
            addResult("DELETE /posts/1", success: false, message: error.localizedDescription, start: start)
        }
    }

    private func batchRequests(count: Int) async {
        let start = Date()
        var successCount = 0

        await withTaskGroup(of: Bool.self) { group in
            for i in 1...count {
                group.addTask {
                    let url = URL(string: "https://jsonplaceholder.typicode.com/posts/\(i)")!
                    do {
                        let (_, response) = try await URLSession.shared.data(from: url)
                        return (response as? HTTPURLResponse)?.statusCode == 200
                    } catch {
                        return false
                    }
                }
            }

            for await success in group {
                if success { successCount += 1 }
            }
        }

        addResult("Batch \(count) requests", success: successCount == count, message: "\(successCount)/\(count) successful", start: start)
    }

    private func mixedRequests() async {
        await fetchSingle()
        await createPost()
        await updatePost()
        await deletePost()
    }

    private func fetch404() async {
        let start = Date()
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/99999")!
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            addResult("GET /posts/99999", success: false, message: "Status: \(status) Not Found", start: start)
        } catch {
            addResult("GET /posts/99999", success: false, message: error.localizedDescription, start: start)
        }
    }

    private func fetchInvalidURL() async {
        let start = Date()
        let url = URL(string: "https://invalid.invalid/test")!
        do {
            _ = try await URLSession.shared.data(from: url)
            addResult("Invalid URL", success: false, message: "Unexpected success", start: start)
        } catch {
            addResult("Invalid URL", success: false, message: "Network error (expected)", start: start)
        }
    }

    private func addResult(_ title: String, success: Bool, message: String, start: Date) {
        let duration = String(format: "%.0fms", Date().timeIntervalSince(start) * 1000)
        DispatchQueue.main.async {
            results.append(APIResult(title: title, success: success, message: message, duration: duration))
            if results.count > 10 {
                results.removeFirst()
            }
        }
    }
}

struct APIResult: Identifiable {
    let id = UUID()
    let title: String
    let success: Bool
    let message: String
    let duration: String
}

// MARK: - Mock Demo View

struct MockDemoView: View {
    @ObservedObject private var mockEngine = MockEngine.shared
    @State private var lastTestResult: String?

    var body: some View {
        List {
            // Status
            Section {
                Toggle("Enable Mocking", isOn: $mockEngine.isEnabled)

                HStack {
                    Text("Active Rules")
                    Spacer()
                    Text("\(mockEngine.rules.count)")
                        .foregroundColor(.secondary)
                }
            }

            // Quick Add Presets
            Section {
                Button {
                    addMock200()
                } label: {
                    Label("Add 200 OK Response", systemImage: "checkmark.circle")
                }
                .foregroundColor(.green)

                Button {
                    addMock500()
                } label: {
                    Label("Add 500 Server Error", systemImage: "exclamationmark.triangle")
                }
                .foregroundColor(.red)

                Button {
                    addMockDelay()
                } label: {
                    Label("Add 3s Delay", systemImage: "clock")
                }
                .foregroundColor(.orange)

                Button {
                    addMockTimeout()
                } label: {
                    Label("Add Network Timeout", systemImage: "wifi.slash")
                }
                .foregroundColor(.gray)
            } header: {
                Text("Quick Add Mock Rules")
            } footer: {
                Text("Add mock rules to intercept API responses")
            }

            // Test Section
            Section {
                Button {
                    testMock()
                } label: {
                    HStack {
                        Label("Test: GET /posts/1", systemImage: "play.circle")
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                    }
                }

                if let result = lastTestResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Test Mock")
            } footer: {
                Text("Make a request to see how mocks affect responses")
            }

            // Manage Rules
            Section {
                NavigationLink {
                    MockRulesView()
                } label: {
                    Label("Manage All Rules", systemImage: "list.bullet.rectangle")
                }

                if !mockEngine.rules.isEmpty {
                    Button(role: .destructive) {
                        mockEngine.clearRules()
                    } label: {
                        Label("Clear All Rules", systemImage: "trash")
                    }
                }
            }

            // Info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(icon: "1.circle.fill", text: "Add a mock rule above")
                    InfoRow(icon: "2.circle.fill", text: "Enable mocking with the toggle")
                    InfoRow(icon: "3.circle.fill", text: "Make API requests in the API Test tab")
                    InfoRow(icon: "4.circle.fill", text: "See mocked responses in Traffic tab")
                }
                .padding(.vertical, 8)
            } header: {
                Text("How to Use")
            }
        }
        .navigationTitle("Mock Rules")
    }

    private func addMock200() {
        let rule = MockRule(
            name: "Demo: 200 OK",
            isEnabled: true,
            matching: MockMatching(urlPattern: "*/posts/*"),
            action: .respond(MockResponse(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: """
                {
                    "id": 1,
                    "title": "Mocked Response!",
                    "body": "This response was mocked by NetChecker",
                    "userId": 1
                }
                """.data(using: .utf8)
            ))
        )
        mockEngine.addRule(rule)
        mockEngine.isEnabled = true
    }

    private func addMock500() {
        mockEngine.addRule(.serverError(for: "*/posts/*"))
        mockEngine.isEnabled = true
    }

    private func addMockDelay() {
        mockEngine.addRule(.slow(for: "*/posts/*", delay: 3.0))
        mockEngine.isEnabled = true
    }

    private func addMockTimeout() {
        mockEngine.addRule(.timeout(for: "*/posts/*"))
        mockEngine.isEnabled = true
    }

    private func testMock() {
        Task {
            let start = Date()
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let duration = String(format: "%.0fms", Date().timeIntervalSince(start) * 1000)
                let bodyPreview = String(data: data.prefix(100), encoding: .utf8) ?? ""
                await MainActor.run {
                    lastTestResult = "Status: \(status) | \(duration)\n\(bodyPreview)..."
                }
            } catch {
                await MainActor.run {
                    lastTestResult = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Breakpoint Demo View

struct BreakpointDemoView: View {
    @ObservedObject private var breakpointEngine = BreakpointEngine.shared
    @State private var editingPausedRequest: PausedRequest?

    var body: some View {
        List {
            // Status
            Section {
                Toggle("Enable Breakpoints", isOn: $breakpointEngine.isEnabled)

                HStack {
                    Text("Active Rules")
                    Spacer()
                    Text("\(breakpointEngine.rules.count)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Paused Requests")
                    Spacer()
                    if breakpointEngine.pausedRequests.isEmpty {
                        Text("0")
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(breakpointEngine.pausedRequests.count)")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }

            // Paused Requests
            if !breakpointEngine.pausedRequests.isEmpty {
                Section {
                    ForEach(breakpointEngine.pausedRequests) { paused in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(paused.method)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)

                                Text("PAUSED")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(4)
                            }

                            Text(paused.url?.absoluteString ?? "Unknown URL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                Button {
                                    editingPausedRequest = paused
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)

                                Button {
                                    breakpointEngine.resume(id: paused.id, with: nil)
                                } label: {
                                    Label("Resume", systemImage: "play.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)

                                Button {
                                    breakpointEngine.cancel(id: paused.id)
                                } label: {
                                    Label("Cancel", systemImage: "xmark")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        Text("Paused Requests")
                        Spacer()
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }

            // Quick Add
            Section {
                Button {
                    addBreakpointAll()
                } label: {
                    Label("Break on All Requests", systemImage: "hand.raised")
                }

                Button {
                    addBreakpointPosts()
                } label: {
                    Label("Break on /posts/*", systemImage: "hand.raised")
                }

                Button {
                    addBreakpointPOST()
                } label: {
                    Label("Break on POST Requests", systemImage: "hand.raised")
                }
            } header: {
                Text("Quick Add Breakpoints")
            } footer: {
                Text("Add breakpoints to pause and inspect requests")
            }

            // Test
            Section {
                Button {
                    testBreakpoint()
                } label: {
                    HStack {
                        Label("Make Request (will pause)", systemImage: "play.circle")
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!breakpointEngine.isEnabled || breakpointEngine.rules.isEmpty)
            } header: {
                Text("Test Breakpoint")
            } footer: {
                Text("Enable breakpoints and add a rule first, then make a request to see it pause")
            }

            // Manage
            Section {
                NavigationLink {
                    BreakpointRulesView()
                } label: {
                    Label("Manage All Rules", systemImage: "list.bullet.rectangle")
                }

                if !breakpointEngine.rules.isEmpty {
                    Button(role: .destructive) {
                        breakpointEngine.clearRules()
                    } label: {
                        Label("Clear All Rules", systemImage: "trash")
                    }
                }
            }

            // Info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(icon: "1.circle.fill", text: "Add a breakpoint rule above")
                    InfoRow(icon: "2.circle.fill", text: "Enable breakpoints with the toggle")
                    InfoRow(icon: "3.circle.fill", text: "Make a request - it will pause")
                    InfoRow(icon: "4.circle.fill", text: "Resume or cancel from here")
                }
                .padding(.vertical, 8)
            } header: {
                Text("How to Use")
            }
        }
        .navigationTitle("Breakpoints")
        .sheet(item: $editingPausedRequest) { paused in
            NavigationStack {
                PausedRequestEditorView(paused: paused)
            }
        }
    }

    private func addBreakpointAll() {
        let rule = BreakpointRule(
            name: "Break: All Requests",
            matching: BreakpointMatching(urlPattern: "*"),
            direction: .request
        )
        breakpointEngine.addRule(rule)
        breakpointEngine.isEnabled = true
    }

    private func addBreakpointPosts() {
        let rule = BreakpointRule(
            name: "Break: Posts API",
            matching: BreakpointMatching(urlPattern: "*/posts/*"),
            direction: .request
        )
        breakpointEngine.addRule(rule)
        breakpointEngine.isEnabled = true
    }

    private func addBreakpointPOST() {
        let rule = BreakpointRule(
            name: "Break: POST Methods",
            matching: BreakpointMatching(method: .post),
            direction: .request
        )
        breakpointEngine.addRule(rule)
        breakpointEngine.isEnabled = true
    }

    private func testBreakpoint() {
        Task {
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
            _ = try? await URLSession.shared.data(from: url)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }
}

struct FeatureSection<Content: View>: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(.leading, 44)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 80)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct TestButton: View {
    let title: String
    let subtitle: String
    let method: String
    let color: Color
    let isLoading: Bool
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Text(method)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .foregroundColor(color)
                    .cornerRadius(4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .disabled(isLoading)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    ContentView()
}
