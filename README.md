# PartsTrackerIOS

Native iPhone companion app for the self-hosted inventory tracker. This first
version is intentionally read-only and talks to the existing backend JSON API at
`/api/v1`.

## Requirements

- Xcode 26.5 or newer
- iOS 17+
- The existing inventory backend running separately

The backend repo is not part of this project and is not modified by the iOS app.

## What v1 Includes

- SwiftUI tab shell for Parts, Projects, Low Stock, and Server state
- Server configuration screen
- Session-based login using the backend's existing Flask login flow
- Native local-login POST to `/login`
- Web login sheet for Microsoft or server-rendered login flows
- Cookie preservation through `URLSession` / shared cookie storage
- Parts list with search, type filter, pagination, refresh, loading, empty, and error states
- Part detail with identity, description, stock, supplier part numbers, and metadata
- Projects list with search, active/archive tab, status/tag filters, pagination, refresh, and errors
- Project detail with summary, bare PCB stock, BOM summary/items, and buildability
- Low-stock list with search, type filter, pagination, and refresh
- Health/about screen showing reachability, backend API/app version, and local app state
- Basic unit tests for Codable decoding, request query construction, and `401` handling

## What v1 Does Not Include

- No part/project editing
- No create/delete flows
- No stock mutation
- No token authentication
- No custom mobile-device authentication
- No backend changes
- No third-party packages

## Running

1. Open `PartsTrackerIOS.xcodeproj` in Xcode.
2. Select the `PartsTrackerIOS` scheme.
3. Run on an iPhone simulator or device.
4. Enter the backend base URL, for example `http://localhost:5000`.
5. Use either local login or the web login sheet.

For a simulator talking to a backend on the same Mac, `http://localhost:5000`
usually works. For a physical iPhone, use an address the phone can reach on the
network.

## Testing

From this directory:

```sh
xcodebuild test -project PartsTrackerIOS.xcodeproj -scheme PartsTrackerIOS -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

## Notes

The backend currently protects inventory endpoints with the normal Flask login
session and permissions. The app treats `401` as a normal login-needed state and
keeps API/network logic outside SwiftUI views where practical.
