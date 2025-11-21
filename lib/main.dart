import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk exit app
import 'core/security/integrity_service.dart'; // Import Satpam

// Import Library Kripto & Data
import 'package:cryptography/cryptography.dart';
import 'core/crypto/key_manager.dart';
import 'core/crypto/cipher_service.dart';
import 'core/crypto/storage_service.dart';
import 'data/local/database_service.dart';
import 'data/models/message_model.dart';
import 'presentation/connect_screen.dart';
import 'presentation/login_screen.dart';
import 'core/transport/p2p_service.dart'; // Service Jaringan

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GatekeeperScreen(),
  ));
}

// --- 1. LAYAR SATPAM (GATEKEEPER) ---
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
    await Future.delayed(const Duration(seconds: 2)); // Simulasi scan
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
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 80, color: Colors.greenAccent),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: Colors.greenAccent),
                  const SizedBox(height: 20),
                  Text("SilentMesh Security Sweep...",
                      style: TextStyle(
                          color: Colors.greenAccent.withOpacity(0.8),
                          fontFamily: 'Courier')),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gpp_bad, size: 100, color: Colors.redAccent),
                  const SizedBox(height: 20),
                  const Text("ACCESS DENIED",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("EXIT APP"),
                  )
                ],
              ),
      ),
    );
  }
}

// --- 2. LAYAR UTAMA (CRYPTOLAB + P2P CHAT) ---
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
  final p2pService = P2PService();

  SimpleKeyPair? myIdentity;
  List<MessageModel> chatHistory = [];
  final textController = TextEditingController();

  String? targetPublicKey;
  String myIP = "Loading IP...";
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
    _setupP2P();
  }

  Future<void> _initializeSystem() async {
    await _loadIdentity();
    await _loadChatHistory();
  }

  // --- SETUP JARINGAN P2P (DIPERBAIKI) ---
  Future<void> _setupP2P() async {
    String ip = await p2pService.getMyIP();
    setState(() => myIP = ip);

    await p2pService.startHosting();

    p2pService.onMessageReceived = (incomingData) async {
      // FORMAT: "KUNCI###PESAN_SANDI"
      List<String> parts = incomingData.split("###");

      String senderKey = "Unknown";
      String contentToSave = incomingData; // Default kalau format lama

      if (parts.length == 2) {
        senderKey = parts[0]; // Ambil Kunci
        contentToSave = parts[1]; // Ambil Pesan Murni "[1,2,3]"
      }

      final newMessage = MessageModel(
        senderId: senderKey, // Simpan kunci pengirim
        content: contentToSave, // Simpan hanya bagian angka
        timestamp: DateTime.now().millisecondsSinceEpoch,
        nonce: "auto",
        isMe: false,
      );

      await dbService.insertMessage(newMessage);
      await _loadChatHistory();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("📩 Secure Message Received!"),
          backgroundColor: Colors.green));
    };
  }

  Future<void> _loadIdentity() async {
    final data = await storageService.getIdentity();
    // Logic restore session bisa disini
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
  }

  Future<void> connectToPeerDialog() async {
    String? ip = await showDialog<String>(
        context: context,
        builder: (context) {
          String tempIp = "";
          return AlertDialog(
            backgroundColor: const Color(0xFF1F1F1F),
            title: const Text("Connect to WiFi Peer",
                style: TextStyle(color: Colors.white)),
            content: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => tempIp = v,
              decoration: const InputDecoration(
                  hintText: "Enter Friend's IP (e.g. 192.168.x.x)",
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.greenAccent))),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(context, tempIp),
                  child: const Text("Connect",
                      style: TextStyle(color: Colors.greenAccent))),
            ],
          );
        });

    if (ip != null && ip.isNotEmpty) {
      bool success = await p2pService.connectToPeer(ip);
      if (success) {
        setState(() => isConnected = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✅ Connected to $ip!"),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("❌ Connection Failed"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> openConnectScreen() async {
    if (myIdentity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Generate Identity First!")));
      return;
    }
    final myPubString = await keyManager.getPublicKeyString(myIdentity!);
    final scannedKey = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ConnectScreen(myPublicKey: myPubString)),
    );
    if (scannedKey != null) {
      setState(() {
        targetPublicKey = scannedKey;
      });
    }
  }

  // --- SEND MESSAGE (DIPERBAIKI) ---
  Future<void> sendMessage() async {
    if (myIdentity == null || textController.text.isEmpty) return;
    final plainText = textController.text;

    PublicKey receiverKey = await myIdentity!.extractPublicKey();
    final cipherBytes = await cipherService.encryptMessage(
      plaintext: plainText,
      senderKeyPair: myIdentity!,
      receiverPublicKey: receiverKey,
    );

    String encryptedString = cipherBytes.toString();
    String myPubString = await keyManager.getPublicKeyString(myIdentity!);

    // PACKET: "KUNCI###PESAN"
    String packet = "$myPubString###$encryptedString";

    if (isConnected) {
      p2pService.sendData(packet);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Saved locally (Not connected to peer)"),
          duration: Duration(seconds: 1)));
    }

    final newMessage = MessageModel(
      senderId: "Me",
      content: encryptedString, // Simpan hanya pesannya di DB sendiri
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
    p2pService.dispose();
    setState(() {
      isConnected = false;
    });
  }

  // Helper Parser
  List<int> _parseStringToList(String content) {
    try {
      String clean = content.replaceAll('[', '').replaceAll(']', '');
      if (clean.trim().isEmpty) return [];
      return clean.split(',').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    p2pService.dispose();
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
            const Text("SilentMesh Vault", style: TextStyle(fontSize: 16)),
            Text("My IP: $myIP",
                style:
                    const TextStyle(fontSize: 10, color: Colors.greenAccent)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.wifi_tethering,
                color: isConnected ? Colors.greenAccent : Colors.grey),
            onPressed: connectToPeerDialog,
            tooltip: "Connect to IP",
          ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: targetPublicKey != null
                ? Colors.green.withOpacity(0.2)
                : Colors.blueGrey.withOpacity(0.2),
            child: Text(
                targetPublicKey != null
                    ? "Target Key: ${targetPublicKey!.substring(0, 10)}..."
                    : (isConnected
                        ? "Status: Connected P2P"
                        : "Mode: Offline / Self-Note"),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: targetPublicKey != null
                        ? Colors.greenAccent
                        : Colors.grey)),
          ),
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
                          List<int> bytes = _parseStringToList(msg.content);

                          try {
                            PublicKey keyToUse =
                                await myIdentity!.extractPublicKey();
                            return await cipherService.decryptMessage(
                              encryptedData: bytes,
                              receiverKeyPair: myIdentity!,
                              senderPublicKey: keyToUse,
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
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                padding: const EdgeInsets.all(12),
                                width: MediaQuery.of(context).size.width * 0.7,
                                decoration: BoxDecoration(
                                    color: msg.isMe
                                        ? const Color(0xFF1F1F1F)
                                        : Colors.green[900],
                                    borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(msg.isMe ? "Me" : "Peer",
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                    const SizedBox(height: 5),
                                    Text(text,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Courier')),
                                  ],
                                )),
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
