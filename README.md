# NetChecker iOS Demo App

A demo iOS app showcasing the [NetChecker](https://github.com/shakhzodsunnatov/NetChecker) SDK.

Targets NetChecker **2.0.0**.

## Features Demonstrated

### Shake-to-Open Inspector

```swift
ContentView()
    .netChecker()  // Shake the device to open
```

### Traffic Monitoring
- Real-time request/response capture
- Status codes, timing and body inspection
- Search and filtering
- HAR export and import

### Environments
- Switch between Production / Staging / Local
- Quick URL overrides
- Per-environment variables

### Mock Rules
- Mock responses for testing
- Simulated errors and delays
- Pattern-based URL matching

### Network Conditions
- 3G, EDGE, flaky-link and offline profiles
- Latency, bandwidth limiting and packet loss
- Toggle straight from the Home tab

### Breakpoints
- Pause requests and responses
- Edit headers and body before resuming

## Requirements

- iOS 16.0+
- Xcode 15.0+

## Getting Started

1. Clone this repository **next to** the SDK repository:

   ```
   YourFolder/
     NetCheckerSDK/     ← github.com/shakhzodsunnatov/NetChecker
     NetChecker-iOS/    ← this repository
   ```

2. Open `CheckerTestApp/CheckerTestApp.xcodeproj`.
3. Build and run.

The project references the SDK as a **local** Swift package at `../../NetCheckerSDK`, so changes to the SDK are picked up on the next build without publishing a version. To point at the released package instead, replace the local package reference in Xcode with `https://github.com/shakhzodsunnatov/NetChecker.git`.

## Testing the Shake Gesture

- **Device:** shake it
- **Simulator:** Device → Shake (⌃⌘Z)

## Tabs

| Tab | What it shows |
|-----|---------------|
| Home | Feature overview, live counters, quick actions |
| API Test | Requests against the JSONPlaceholder API |
| Traffic | Every captured request, with HAR import/export |
| Mocks | Mock rule management |
| Breakpoints | Breakpoint rules and paused requests |

Environments and Network Conditions live inside the inspector itself — shake to open it, or use the Environments tab and the Settings tab there.

## UI Tests

`CheckerTestAppUITests` covers tab navigation, the traffic toolbar, and the network-condition toggle. Two of them are regression tests for 2.0.0 bugs: a missing navigation bar on the traffic screen, and toolbar buttons collapsing when two items shared a placement.

```bash
xcodebuild -project CheckerTestApp/CheckerTestApp.xcodeproj \
  -scheme CheckerTestApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CheckerTestAppUITests test
```

## Related

- [NetChecker SDK](https://github.com/shakhzodsunnatov/NetChecker)

## License

MIT — see [LICENSE](LICENSE).
