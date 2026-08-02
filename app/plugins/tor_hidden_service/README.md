# Tor Hidden Service — Flutter Plugin

A Flutter plugin that allows your mobile application to host Tor v3 Onion Services and route traffic through the Tor network.

This plugin enables Tor-Based P2P on mobile:

  * **Host:** Your app creates a public `.onion` address that routes to a local server inside your app.
  * **Client:** Your app can make anonymous requests to other `.onion` addresses.

### Features

  * **Android Support:** Uses the Guardian Project’s Tor binaries.
  * **Host Onion Services:** Maps public Onion Port 80 to local port 8080.
  * **HTTP Connect Tunnel:** Outbound proxy on port 9080.
  * **TorOnionClient:** Custom client for making plain HTTP requests to .onion addresses (bypassing SSL requirements).
  * **Bootstrap Logs:** Real-time access to Tor startup progress.

### Installation

Add the dependency:

**YAML**

```yaml
dependencies:
    tor_hidden_service: ^0.0.4
```

### Android Configuration

**1. Update AndroidManifest.xml**
To ensure the Tor binaries load correctly, add `android:extractNativeLibs="true"` to your `<application>` tag.
Also, add `android:usesCleartextTraffic="true"` to allow local communication with the Tor proxy.

**XML**

```xml
<application
    android:label="MyApp"
    android:extractNativeLibs="true"
    android:usesCleartextTraffic="true" ...>
```

**2. Permissions**
Add the internet permission to `android/app/src/main/AndroidManifest.xml`:

**XML**

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

**3. Gradle Setup (Optional)**
The plugin usually configures this automatically. If you see build errors regarding missing artifacts, add the Guardian Project repository to `android/build.gradle`:

**Gradle**

```gradle
maven { url "https://raw.githubusercontent.com/guardianproject/gpmaven/master" }
```

-----

### Usage

#### 1\. Start Tor

Tor must be running before you can host or make requests. Bootstrap takes 20–40 seconds.

**Dart**

```dart
import 'package:tor_hidden_service/tor_hidden_service.dart';

final _torService = TorHiddenService();

// Optional: Listen to bootstrap logs
_torService.onLog.listen((log) => print("TOR: $log"));

await _torService.start();
```

#### 2\. Host a Service (Incoming Traffic)

The plugin automatically maps your generated .onion address (Public Port 80) to your Localhost Port 8080.
To receive traffic, start a standard HTTP server in Flutter binding to **InternetAddress.anyIPv4**.

**Dart**

```dart
import 'dart:io';

// Bind to anyIPv4 (0.0.0.0) so the native Tor process can reach the Flutter layer
HttpServer server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

server.listen((request) {
  request.response.write('Hello from the Onion Network!');
  request.response.close();
});

// Get your public address
String? hostname = await _torService.getOnionHostname();
print("Hosting at: http://$hostname");
```

#### 3\. Make Requests (Outgoing Traffic)

You have two options depending on the protocol of the destination site.

**Option A: Plain HTTP Requests (e.g., standard .onion sites)**
Use the provided `TorOnionClient`. This handles the complex CONNECT handshake internally, allowing you to access `http://` onion sites without SSL errors.

**Dart**

```dart
// 1. Get the unsecure client
final client = _torService.getUnsecureTorClient();

// 2. Make the request (supports GET, POST, PUT, DELETE)
try {
  final response = await client.get('http://facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion');
  
  print("Status: ${response.statusCode}");
  print("Body: ${response.body}");
} catch (e) {
  print("Request failed: $e");
}
```

**Option B: Secure HTTPS Requests (e.g., clearnet sites via Tor)**
Use the standard `HttpClient` wrapper. Dart's standard client requires `https://` to trigger the proxy tunnel.

**Dart**

```dart
// 1. Get the secure client (wraps standard HttpClient)
HttpClient client = _torService.getSecureTorClient();

try {
  // Must use HTTPS
  var request = await client.getUrl(Uri.parse('https://api.ipify.org'));
  var response = await request.close();
  var body = await response.transform(utf8.decoder).join();
  print("My Tor IP: $body");
} catch (e) {
  print("Request failed: $e");
}
```

-----

### Architecture & Ports

This plugin manages specific port mappings to enable P2P functionality.

| Type | Port | Description |
| :--- | :--- | :--- |
| **SOCKS5** | 9050 | Standard Tor SOCKS proxy. |
| **HTTP Tunnel** | 9080 | Outbound Proxy. Used by `TorOnionClient` and `getSecureTorClient`. |
| **Hidden Service** | 80 → 8080 | Inbound. Traffic sent to your .onion on port 80 is forwarded to localhost:8080. |

-----

### Troubleshooting

  * **503 Service Unavailable / 502 Bad Gateway:**

      * If hosting: You may be clicking the link too fast. Wait 60 seconds after bootstrap for the Hidden Service descriptor to propagate through the Tor network.
      * If connecting: The destination onion might be offline.

  * **SocketException: Connection refused:**

      * Ensure you used `InternetAddress.anyIPv4` (0.0.0.0) when binding your server, not `localhost`. The native Tor process runs in a separate thread/namespace and sometimes cannot see `localhost`.

  * **HandshakeException:**

      * You are likely trying to use the "Secure Client" (Option B) to connect to a plain HTTP onion site. Use the `getUnsecureTorClient()` (Option A) instead.

-----

### Disclaimer

This plugin is intended for educational and research purposes. While Tor enhances privacy, your application logic may still expose identifying information. Understand Tor’s limitations before relying on it in sensitive contexts.