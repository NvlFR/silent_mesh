import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

class SignalingService {
  MqttServerClient? client;

  // Callback ke WebRTC
  Function(Map<String, dynamic> signalData)? onSignalReceived;
  Function(String status)? onStatusChange;

  Future<void> connect(String myPublicKey) async {
    // Kita pakai Broker Publik Gratis (test.mosquitto.org)
    // Client ID harus unik, kita pakai potongan Public Key
    String clientId =
        'silentmesh_${myPublicKey.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient('test.mosquitto.org', clientId);
    client!.port = 1883;
    client!.logging(on: false);
    client!.keepAlivePeriod = 20;
    client!.autoReconnect = true;

    try {
      await client!.connect();
      onStatusChange?.call("🌐 Connected to Signaling Server");
    } catch (e) {
      onStatusChange?.call("❌ Signaling Error: $e");
      return;
    }

    // Subscribe ke Topik Sendiri: "silentmesh/[MY_KEY]"
    // Ini ibarat nomor telepon kita.
    final topic = 'silentmesh/$myPublicKey';
    client!.subscribe(topic, MqttQos.atLeastOnce);

    // Dengarkan Pesan Masuk
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      try {
        // Kirim data JSON ke WebRTC Service
        if (onSignalReceived != null) {
          onSignalReceived!(jsonDecode(payload));
        }
      } catch (e) {
        print("Error parsing signal: $e");
      }
    });
  }

  // Kirim Sinyal ke Teman (Target Key)
  void sendSignal(String targetKey, Map<String, dynamic> data) {
    if (client != null &&
        client!.connectionStatus!.state == MqttConnectionState.connected) {
      final topic = 'silentmesh/$targetKey';
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(data));

      client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }
}
