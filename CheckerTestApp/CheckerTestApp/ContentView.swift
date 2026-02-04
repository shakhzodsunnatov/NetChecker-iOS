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
            // Traffic Inspector
            TrafficListView()
                .tabItem {
                    Label("Traffic", systemImage: "network")
                }

            // Test API Calls
            APITestView()
                .tabItem {
                    Label("API Test", systemImage: "arrow.up.arrow.down")
                }

            // Environment Switching
            NavigationStack {
                EnvironmentTestView()
            }
            .tabItem {
                Label("Environments", systemImage: "server.rack")
            }

            // Mock Rules
            NavigationStack {
                MockRulesView()
            }
            .tabItem {
                Label("Mocks", systemImage: "theatermasks")
            }
        }
        .onAppear {
            // Start traffic interception
            TrafficInterceptor.shared.start()

            // Setup demo environments
            setupDemoEnvironments()
        }
    }

    private func setupDemoEnvironments() {
        let store = EnvironmentStore.shared

        // Only setup if no groups exist
        guard store.groups.isEmpty else { return }

        // Create JSONPlaceholder environment group
        let jsonPlaceholderGroup = EnvironmentGroup(
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
                    name: "Development",
                    emoji: "🔧",
                    baseURL: URL(string: "https://jsonplaceholder.typicode.com")!,
                    variables: ["API_VERSION": "dev", "DEBUG": "true", "LOG_LEVEL": "verbose"]
                )
            ]
        )
        store.addGroup(jsonPlaceholderGroup)

        // Create a mock API environment group
        let mockAPIGroup = EnvironmentGroup(
            name: "Mock API Server",
            sourcePattern: "api.example.com",
            environments: [
                Environment(
                    name: "Production",
                    emoji: "🟢",
                    baseURL: URL(string: "https://api.example.com")!,
                    isDefault: true
                ),
                Environment(
                    name: "Local",
                    emoji: "💻",
                    baseURL: URL(string: "http://localhost:3000")!,
                    variables: ["LOCAL": "true"]
                )
            ]
        )
        store.addGroup(mockAPIGroup)
    }
}

// MARK: - Environment Test View

struct EnvironmentTestView: View {
    @ObservedObject private var store = EnvironmentStore.shared
    @State private var selectedEnvironmentInfo: String = "No environment selected"

    var body: some View {
        List {
            // Current Environment Status
            Section("Current Status") {
                if let activeEnv = store.activeEnvironment {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(activeEnv.emoji)
                                .font(.title)
                            Text(activeEnv.name)
                                .font(.headline)
                        }

                        Text(activeEnv.baseURL.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !activeEnv.variables.isEmpty {
                            Divider()
                            ForEach(Array(activeEnv.variables.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(activeEnv.variables[key] ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("No active environment")
                        .foregroundColor(.secondary)
                }
            }

            // Quick Override Section
            Section("Quick Override") {
                if let override = store.quickOverrideURL {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Active Override")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(override.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Clear") {
                            store.clearQuickOverride()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                } else {
                    Button {
                        // Add a quick override to localhost
                        store.addQuickOverride(
                            from: "jsonplaceholder.typicode.com",
                            to: "localhost:8080",
                            autoDisableAfter: 300
                        )
                    } label: {
                        Label("Override to localhost:8080", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            // Environment Switcher
            Section("Switch Environments") {
                NavigationLink {
                    EnvironmentSwitcherView()
                } label: {
                    Label("Manage Environments", systemImage: "server.rack")
                }
            }

            // Test Environment Variables
            Section("Test Environment Variables") {
                Button {
                    testEnvironmentVariable()
                } label: {
                    Label("Read API_VERSION Variable", systemImage: "doc.text.magnifyingglass")
                }

                Text(selectedEnvironmentInfo)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Instructions
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Test:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("1. Go to 'Manage Environments' to switch between Production/Staging/Development")
                    Text("2. Use 'Quick Override' to redirect traffic to localhost")
                    Text("3. Read environment variables to verify the switch")
                    Text("4. Make API calls in 'API Test' tab to see traffic routed")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Environments")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.resetToProduction()
                } label: {
                    Text("Reset")
                }
            }
        }
    }

    private func testEnvironmentVariable() {
        if let apiVersion = TrafficInterceptor.shared.variable("API_VERSION") {
            selectedEnvironmentInfo = "API_VERSION = \(apiVersion)"
        } else {
            selectedEnvironmentInfo = "API_VERSION not found"
        }

        // Also show all variables
        let allVars = EnvironmentStore.shared.allVariables()
        if !allVars.isEmpty {
            let varsString = allVars.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            selectedEnvironmentInfo += "\n\nAll Variables:\n\(varsString)"
        }
    }
}

// MARK: - API Test View

struct APITestView: View {
    @State private var lastResult: String = "No requests yet"
    @State private var isLoading = false
    @ObservedObject private var store = EnvironmentStore.shared

    var body: some View {
        NavigationStack {
            List {
                // Current Environment Badge
                if let activeEnv = store.activeEnvironment {
                    Section {
                        HStack {
                            Text(activeEnv.emoji)
                            Text("Using: \(activeEnv.name)")
                                .font(.subheadline)
                            Spacer()
                            Text(activeEnv.baseURL.host ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Test API Calls Section
                Section("Make Test Requests") {
                    Button {
                        fetchSinglePost()
                    } label: {
                        HStack {
                            Text("Fetch Single Post")
                            Spacer()
                            if isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoading)

                    Button("Fetch Multiple Posts") {
                        fetchMultiplePosts()
                    }
                    .disabled(isLoading)

                    Button("Fetch Users") {
                        fetchUsers()
                    }
                    .disabled(isLoading)

                    Button("Test POST Request") {
                        testPostRequest()
                    }
                    .disabled(isLoading)

                    Button("Test Error (404)") {
                        testErrorRequest()
                    }
                    .disabled(isLoading)
                }

                Section("Last Result") {
                    Text(lastResult)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Section {
                    Text("After making requests, switch to the Traffic tab to see them. Try switching environments in the Environments tab to see how traffic is affected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("API Tests")
        }
    }

    private func fetchSinglePost() {
        isLoading = true
        Task {
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data)
                await MainActor.run {
                    lastResult = "Success: Got post data\n\(json)"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    lastResult = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func fetchMultiplePosts() {
        isLoading = true
        Task {
            for i in 1...3 {
                let url = URL(string: "https://jsonplaceholder.typicode.com/posts/\(i)")!
                _ = try? await URLSession.shared.data(from: url)
            }
            await MainActor.run {
                lastResult = "Fetched 3 posts successfully"
                isLoading = false
            }
        }
    }

    private func fetchUsers() {
        isLoading = true
        Task {
            let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let users = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    await MainActor.run {
                        lastResult = "Got \(users.count) users"
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    lastResult = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func testPostRequest() {
        isLoading = true
        Task {
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = """
            {
                "title": "Test Post",
                "body": "This is a test post body",
                "userId": 1
            }
            """.data(using: .utf8)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    await MainActor.run {
                        lastResult = "POST Success: Status \(httpResponse.statusCode)"
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    lastResult = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func testErrorRequest() {
        isLoading = true
        Task {
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts/99999")!
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse {
                    await MainActor.run {
                        lastResult = "Got status: \(httpResponse.statusCode)"
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    lastResult = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
