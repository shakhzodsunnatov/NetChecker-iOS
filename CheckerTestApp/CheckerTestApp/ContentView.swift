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
                    Label("Traffic", systemImage: "arrow.up.arrow.down.circle")
                }

            // Test API Calls
            APITestView()
                .tabItem {
                    Label("Test API", systemImage: "network")
                }
        }
        .onAppear {
            // Start traffic interception
            TrafficInterceptor.shared.start()
        }
    }
}

// MARK: - API Test View
struct APITestView: View {
    @State private var lastResult: String = "No requests yet"
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
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
                    Text("After making requests, switch to the Traffic tab to see them.")
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
