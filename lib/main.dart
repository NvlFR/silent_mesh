import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/security/integrity_service.dart';
import 'package:cryptography/cryptography.dart';
import 'core/crypto/key_manager.dart';
import 'core/crypto/cipher_service.dart';
import 'core/crypto/storage_service.dart';
import 'data/local/database_service.dart';
import 'data/models/message_model.dart';
import 'presentation/connect_screen.dart';
import 'presentation/login_screen.dart';
// GANTI SERVICE JARINGAN
import 'core/transport/webrtc_service.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GatekeeperScreen(),
  ));
}

// --- 1. GATEKEEPER ---
class GatekeeperScreen extends StatefulWidget {
  const GatekeeperScreen({super.key});
  @override
  State<GatekeeperScreen> createState() => _GatekeeperScreenState();
}

class _GatekeeperScreenState extends State<GatekeeperScreen> {
  final integrityService = IntegrityService();
  String errorMessage = "";
  bool isChecking = true;

  @override
  void initState() {
    super.initState();
    _performSecuritySweep();
  }

  Future<void> _performSecuritySweep() async {
    await Future.delayed(const Duration(seconds: 2));
    final threat = await integrityService.checkSystemIntegrity();
    if (threat.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    LoginScreen(realApp: const CryptoLabScreen())));
      }
    } else {
      setState(() {
        isChecking = false;
        errorMessage = threat;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
          child: isChecking
              ? const CircularProgressIndicator(color: Colors.greenAccent)
              : Text(errorMessage, style: const TextStyle(color: Colors.red))),
    );
  }
}

// --- 2. CRYPTO LAB (WEBRTC EDITION) ---
class CryptoLabScreen extends StatefulWidget {
  const CryptoLabScreen({super.key});
  @override
  State<CryptoLabScreen> createState() => _CryptoLabScreenState();
}

class _CryptoLabScreenState extends State<CryptoLabScreen> {
  final keyManager = KeyManager();
  final cipherService = CipherService();
  final storageService = StorageService();
  final dbService = DatabaseService();

  // PAKAI SERVICE BARU
  final webrtcService = WebRTCService();

  SimpleKeyPair? myIdentity;
  List<MessageModel> chatHistory = [];
  final textController = TextEditingController();

  String? targetPublicKeyString;
  String connectionStatus = "Offline"; // Status Jaringan

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    await _loadIdentity();
    await _loadChatHistory();

    // Inisialisasi WebRTC jika identitas sudah ada
    if (myIdentity != null) {
      await _initWebRTC();
    }
  }

  Future<void> _initWebRTC() async {
    final myPub = await keyManager.getPublicKeyString(myIdentity!);

    // Hubungkan UI dengan status WebRTC
    webrtcService.onConnectionState = (state) {
      setState(() => connectionStatus = state);
    };

    // Hubungkan UI dengan pesan masuk
    webrtcService.onMessageReceived = (incomingData) async {
      List<String> parts = incomingData.split("###");
      String senderKey = parts.length == 2 ? parts[0] : "Unknown";
      String content = parts.length == 2 ? parts[1] : incomingData;

      final newMessage = MessageModel(
        senderId: senderKey,
        content: content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        nonce: "auto",
        isMe: false,
      );

      await dbService.insertMessage(newMessage);
      await _loadChatHistory();
      HapticFeedback.mediumImpact();
    };

    // Mulai Signaling
    await webrtcService.init(myPub);
  }

  Future<void> _loadIdentity() async {
    // Logic restore identity bisa disini
  }

  Future<void> _loadChatHistory() async {
    final msgs = await dbService.getAllMessages();
    setState(() {
      chatHistory = msgs;
    });
  }

  Future<void> generateIdentity() async {
    final keyPair = await keyManager.generateNewIdentity();
    final pubKey = await keyManager.getPublicKeyString(keyPair);
    await storageService.saveIdentity("dummy_priv", pubKey);
    setState(() {
      myIdentity = keyPair;
    });

    // Langsung nyalakan WebRTC setelah generate
    await _initWebRTC();
  }

  Future<void> openConnectScreen() async {
    if (myIdentity == null) return;
    final myPubString = await keyManager.getPublicKeyString(myIdentity!);

    // Kirim Public Key sebagai 'myIP' karena di WebRTC, alamat kita adalah Public Key
    final scannedData = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ConnectScreen(myPublicKey: myPubString, myIP: myPubString)),
    );

    if (scannedData != null && scannedData is String) {
      // Format: "KEY###KEY" (Karena IP diganti Key) atau Cuma "KEY"
      List<String> parts = scannedData.split("###");
      String targetKey =
          parts.length >= 2 ? parts[1] : scannedData; // Ambil bagian Key

      setState(() {
        targetPublicKeyString = targetKey;
      });

      // PANGGIL WEBRTC CONNECT
      webrtcService.connectToPeer(targetKey);
    }
  }

  Future<void> sendMessage() async {
    if (myIdentity == null || textController.text.isEmpty) return;
    final plainText = textController.text;

    // Enkripsi
    PublicKey receiverKey;
    if (targetPublicKeyString != null) {
      receiverKey = await _strToPubKey(targetPublicKeyString!);
    } else {
      receiverKey = await myIdentity!.extractPublicKey();
    }

    final cipherBytes = await cipherService.encryptMessage(
      plaintext: plainText,
      senderKeyPair: myIdentity!,
      receiverPublicKey: receiverKey,
    );

    String encryptedString = cipherBytes.toString();
    String myPubString = await keyManager.getPublicKeyString(myIdentity!);
    String packet = "$myPubString###$encryptedString";

    // KIRIM LEWAT WEBRTC
    webrtcService.sendMessage(packet);

    final newMessage = MessageModel(
      senderId: "Me",
      content: encryptedString,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      nonce: "auto",
      isMe: true,
    );

    await dbService.insertMessage(newMessage);
    textController.clear();
    await _loadChatHistory();
  }

  Future<void> panicButton() async {
    await dbService.nukeDatabase();
    await _loadChatHistory();
    webrtcService.dispose(); // Matikan koneksi
    setState(() {
      connectionStatus = "Offline (Panic)";
      targetPublicKeyString = null;
    });
  }

// Helper Baru V2.0: Decode Wallet Address (Base58) ke Bytes
  List<int> _decodeWalletAddress(String walletString) {
    try {
      // Kita panggil fungsi helper yang sudah kita buat di KeyManager tadi
      // Atau panggil langsung dari bs58 kalau mau import di sini.
      // Supaya rapi, kita pakai instance keyManager:
      return keyManager.decodeWalletAddress(walletString);
    } catch (e) {
      print("Error decoding address: $e");
      return [];
    }
  }

  Future<PublicKey> _strToPubKey(String str) async {
    List<int> bytes = _decodeWalletAddress(str);
    return SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  @override
  void dispose() {
    webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SilentMesh Global", style: TextStyle(fontSize: 16)),
            // Tampilkan Status WebRTC
            Text(connectionStatus,
                style: TextStyle(
                    fontSize: 10,
                    color: connectionStatus.contains("READY")
                        ? Colors.greenAccent
                        : Colors.orangeAccent)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
              onPressed: openConnectScreen),
          IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: panicButton)
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatHistory.isEmpty
                ? const Center(
                    child: Text("No messages",
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: chatHistory.length,
                    itemBuilder: (context, index) {
                      final msg = chatHistory[index];
                      return FutureBuilder<String>(
                        future: Future(() async {
                          if (myIdentity == null) return "Locked";
                          List<int> bytes = _decodeWalletAddress(msg.content);
                          try {
                            PublicKey senderKey;
                            if (msg.isMe) {
                              if (targetPublicKeyString != null) {
                                senderKey =
                                    await _strToPubKey(targetPublicKeyString!);
                              } else {
                                senderKey =
                                    await myIdentity!.extractPublicKey();
                              }
                            } else {
                              senderKey = await _strToPubKey(msg.senderId);
                            }
                            return await cipherService.decryptMessage(
                              encryptedData: bytes,
                              receiverKeyPair: myIdentity!,
                              senderPublicKey: senderKey,
                            );
                          } catch (e) {
                            return "Decryption Failed";
                          }
                        }),
                        builder: (context, snapshot) {
                          String text =
                              snapshot.hasData ? snapshot.data! : "...";
                          return Align(
                            alignment: msg.isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: msg.isMe
                                        ? const Color(0xFF1F1F1F)
                                        : Colors.green[900],
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(text,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Courier'))),
                          );
                        },
                      );
                    }),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: "Type secure message...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none))),
              FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.greenAccent,
                  onPressed:
                      myIdentity == null ? generateIdentity : sendMessage,
                  child: const Icon(Icons.send, color: Colors.black))
            ]),
          ),
        ],
      ),
    );
  }
}
