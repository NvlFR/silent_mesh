import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math'; // Untuk random warna
import 'core/security/integrity_service.dart';

// Import Library Kripto & Data
import 'package:cryptography/cryptography.dart';
import 'core/crypto/key_manager.dart';
import 'core/crypto/storage_service.dart';
import 'data/local/database_service.dart';
import 'data/models/message_model.dart';
import 'data/models/contact_model.dart'; // Model Kontak

// Import Layar
import 'presentation/connect_screen.dart';
import 'presentation/login_screen.dart';
import 'presentation/chat_screen.dart'; // Layar Chat Khusus

// Import Jaringan (Pilih salah satu: P2PService atau WebRTCService)
// Di sini saya pakai P2PService sesuai file terakhirmu,
// tapi logic-nya siap untuk WebRTC juga.
import 'core/transport/p2p_service.dart';
// import 'core/transport/webrtc_service.dart'; // Aktifkan ini jika mau pakai WebRTC

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GatekeeperScreen(),
  ));
}

// --- 1. GATEKEEPER (SATPAM) ---
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
        // Masuk ke Login -> Arahkan ke HomeScreen
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    LoginScreen(realApp: const HomeScreen())));
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

// --- 2. HOME SCREEN (DAFTAR KONTAK) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final KeyManager keyManager = KeyManager();
  final StorageService storageService = StorageService();
  final DatabaseService dbService = DatabaseService();
  final P2PService networkService =
      P2PService(); // Ganti ke WebRTCService() jika pakai internet

  SimpleKeyPair? myIdentity;
  List<ContactModel> contacts = [];
  String myAddress = "Loading...";
  String status = "Offline";

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _loadIdentity();
    await _loadContacts();
    await _startNetwork();
  }

  Future<void> _loadIdentity() async {
    // Di real app, kita load private key dari storage.
    // Di prototype ini, kita generate baru atau load dummy.
    // Agar konsisten, kita generate baru dulu setiap sesi untuk keamanan demo.
    final keyPair = await keyManager.generateNewIdentity();
    final pubStr = await keyManager.getPublicKeyString(keyPair);

    setState(() {
      myIdentity = keyPair;
      myAddress = pubStr; // Ini format Base58
    });
  }

  Future<void> _loadContacts() async {
    final list = await dbService.getAllContacts();
    setState(() {
      contacts = list;
    });
  }

  Future<void> _startNetwork() async {
    // Start Listening (Server Mode)
    await networkService.startHosting(); // Atau .init() jika WebRTC

    // Cek IP (Opsional, kalau pakai P2P LAN)
    String ip = await networkService.getMyIP();

    setState(() {
      status = "Active ($ip)";
    });

    // Global Listener: Menangani pesan masuk untuk SEMUA chat
    networkService.onMessageReceived = (packet) async {
      // Format: KEY###CONTENT
      List<String> parts = packet.split("###");
      String senderKey = parts.length >= 2 ? parts[0] : "Unknown";
      String content = parts.length >= 2 ? parts[1] : packet;

      // Simpan ke Database
      final newMessage = MessageModel(
        chatId: senderKey, // Masuk ke folder chat pengirim
        senderId: senderKey,
        content: content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        nonce: "auto",
        isMe: false,
      );

      await dbService.insertMessage(newMessage);

      // Notifikasi Getar
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("📩 New message from ${senderKey.substring(0, 5)}..."),
          backgroundColor: Colors.green));
    };
  }

  // --- ADD CONTACT FLOW ---
  Future<void> _openScanner() async {
    if (myIdentity == null) return;

    // Buka Scanner
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                ConnectScreen(myPublicKey: myAddress, myIP: myAddress)));

    if (result != null && result is String) {
      // Parse Result: IP###KEY atau KEY
      List<String> parts = result.split("###");
      String targetKey = parts.length >= 2 ? parts[1] : result;
      String targetIp = parts.length >= 2 ? parts[0] : "";

      // Connect Jaringan
      if (targetIp.isNotEmpty) {
        networkService.connectToPeer(
            targetIp); // Atau connectToPeer(targetKey) jika WebRTC
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Connecting...")));
      }

      // Tampilkan Dialog Simpan Kontak
      _showSaveContactDialog(targetKey);
    }
  }

  Future<void> _showSaveContactDialog(String key) async {
    // Cek duplikat
    if (await dbService.getContact(key) != null) return;

    String initials = "";
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF222222),
              title: const Text("New Contact",
                  style: TextStyle(color: Colors.white)),
              content: TextField(
                autofocus: true,
                maxLength: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    hintText: "Initials (e.g. AB)",
                    hintStyle: TextStyle(color: Colors.grey)),
                onChanged: (v) => initials = v,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () async {
                      if (initials.isNotEmpty) {
                        // Simpan Kontak Baru
                        final newContact = ContactModel(
                            pubKey: key,
                            initials: initials.toUpperCase(),
                            colorCode: Colors
                                .primaries[
                                    Random().nextInt(Colors.primaries.length)]
                                .value);
                        await dbService.saveContact(newContact);
                        await _loadContacts(); // Refresh List
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("SAVE",
                        style: TextStyle(color: Colors.greenAccent))),
              ],
            ));
  }

  // --- HAPUS DATA ---
  Future<void> _panic() async {
    await dbService.nukeDatabase();
    await _loadContacts();
    networkService.dispose();
    setState(() => status = "Panic: Data Wiped");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text("SilentMesh",
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Center(
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(status,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.greenAccent)))),
          IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: _panic),
          const SizedBox(width: 10),
        ],
      ),
      body: contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey[800]),
                  const SizedBox(height: 20),
                  const Text("No Contacts Yet",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  const Text("Tap + to scan QR Code",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(contact.colorCode),
                    child: Text(contact.initials,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(contact.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  subtitle: Text("${contact.pubKey.substring(0, 15)}...",
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'Courier')),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // Buka Chat Room
                    if (myIdentity != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                  contact: contact,
                                  myIdentity: myIdentity!,
                                  p2pService: networkService)));
                    }
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openScanner,
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.qr_code_scanner, color: Colors.black),
      ),
    );
  }
}
