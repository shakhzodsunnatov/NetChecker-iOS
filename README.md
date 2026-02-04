# NetChecker iOS Test App

A demo iOS app showcasing the [NetChecker](https://github.com/shakhzodsunnatov/NetChecker) SDK capabilities.

## Features Demonstrated

### 1. Shake-to-Open Inspector
```swift
ContentView()
    .netChecker()  // Shake device to open!
```

### 2. Traffic Monitoring
- Real-time request/response capture
- Status codes, timing, and body inspection
- Search and filter capabilities

### 3. Environment Switching
- Switch between Production/Staging/Development
- Quick URL overrides to localhost
- Environment variables management

### 4. Mock Rules
- Create mock responses for testing
- Simulate errors and delays
- Pattern-based URL matching

## Requirements

- iOS 16.0+
- Xcode 15.0+
- NetChecker SPM package

## Getting Started

1. Clone this repository
2. Open `CheckerTestApp.xcodeproj`
3. Add the NetChecker package dependency:
   ```
   https://github.com/shakhzodsunnatov/NetChecker.git
   ```
4. Build and run on a device or simulator

## Testing Shake Gesture

- **Real Device**: Shake your phone
- **Simulator**: Hardware → Shake Gesture (⌃⌘Z)

## Screenshots

The app includes four main tabs:

| Tab | Description |
|-----|-------------|
| Traffic | View all captured network requests |
| API Test | Make test requests to JSONPlaceholder API |
| Environments | Switch between environments |
| Mocks | Configure mock responses |

## Related

- [NetChecker SDK](https://github.com/shakhzodsunnatov/NetChecker) - The main SDK package

## License

MIT License - See [LICENSE](LICENSE) file for details.
