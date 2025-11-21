import 'dart:io';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';

class P2PService {
  ServerSocket? _server;
  Socket? _client;

  // Callback: Fungsi yang akan dipanggil kalau ada pesan masuk
  Function(String message)? onMessageReceived;

  // 1. CEK IP ADDRESS SENDIRI (Supaya teman bisa connect ke kita)
  Future<String> getMyIP() async {
    final info = NetworkInfo();
    var ip = await info.getWifiIP();
    return ip ?? "Unknown";
  }

  // 2. JADI SERVER (Mode Menunggu Pesan / Listening)
  Future<void> startHosting() async {
    // Kita buka Port 4040 (Angka bebas, asal sama)
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 4040);
    print("📡 SERVER STARTED: Listening on Port 4040");

    _server!.listen((Socket clientSocket) {
      print("✅ NEW CONNECTION from ${clientSocket.remoteAddress.address}");

      // Dengarkan apa yang dikirim oleh client ini
      clientSocket.listen(
        (List<int> data) {
          final message = String.fromCharCodes(data);
          print("📩 MESSAGE RECEIVED: $message");

          if (onMessageReceived != null) {
            onMessageReceived!(message);
          }
        },
        onError: (error) {
          print("❌ Connection Error: $error");
          clientSocket.destroy();
        },
        onDone: () {
          print("Connection Closed");
          clientSocket.destroy();
        },
      );
    });
  }

  // 3. JADI CLIENT (Mode Menghubungi Teman)
  Future<bool> connectToPeer(String targetIP) async {
    try {
      print("⏳ Connecting to $targetIP...");
      _client = await Socket.connect(targetIP, 4040,
          timeout: const Duration(seconds: 5));
      print("✅ CONNECTED to $targetIP");
      return true;
    } catch (e) {
      print("❌ Failed to connect: $e");
      return false;
    }
  }

  // 4. KIRIM PESAN
  void sendData(String encryptedMessage) {
    if (_client != null) {
      _client!.write(encryptedMessage);
    } else {
      print("⚠️ No active connection to send data.");
    }
  }

  // 5. MATIKAN KONEKSI
  void dispose() {
    _client?.destroy();
    _server?.close();
  }
}
