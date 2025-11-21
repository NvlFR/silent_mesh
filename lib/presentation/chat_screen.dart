import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Haptic
import 'package:cryptography/cryptography.dart';
import '../data/models/contact_model.dart';
import '../data/models/message_model.dart';
import '../data/local/database_service.dart';
import '../core/crypto/cipher_service.dart';
import '../core/crypto/key_manager.dart';
import '../core/transport/p2p_service.dart'; // Butuh akses P2P service yang aktif

class ChatScreen extends StatefulWidget {
  final ContactModel contact; // Kita chat sama siapa?
  final SimpleKeyPair myIdentity; // Identitas kita
  final P2PService p2pService; // Mesin Jaringan (dioper dari Main)

  const ChatScreen({
    super.key,
    required this.contact,
    required this.myIdentity,
    required this.p2pService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DatabaseService _db = DatabaseService();
  final CipherService _cipher = CipherService();
  final KeyManager _keyManager = KeyManager();
  final TextEditingController _textCtrl = TextEditingController();

  List<MessageModel> messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // DENGARKAN PESAN MASUK KHUSUS BUAT CHAT INI
    // Note: Ini cara sederhana. Idealnya pakai Stream/Provider.
    // Kita "menumpang" listener global di Main, nanti Main yang update DB,
    // Kita di sini cukup refresh layar kalau DB berubah.
    // TAPI, untuk real-time feel, kita pasang timer refresh sederhana atau rely on SetState parent.
    // (Untuk V2.0 ini, kita pakai refresh manual saat kirim dulu, auto-refresh nanti di V2.1)
  }

  Future<void> _loadMessages() async {
    final msgs = await _db.getMessagesForChat(widget.contact.pubKey);
    setState(() {
      messages = msgs;
    });
  }

  Future<void> _sendMessage() async {
    if (_textCtrl.text.isEmpty) return;
    String text = _textCtrl.text;

    // 1. Siapkan Key Penerima
    List<int> receiverBytes =
        _keyManager.decodeWalletAddress(widget.contact.pubKey);
    PublicKey receiverKey =
        SimplePublicKey(receiverBytes, type: KeyPairType.x25519);

    // 2. Enkripsi
    final cipherBytes = await _cipher.encryptMessage(
      plaintext: text,
      senderKeyPair: widget.myIdentity,
      receiverPublicKey: receiverKey,
    );

    String encryptedString = cipherBytes.toString();
    String myPubString =
        await _keyManager.getPublicKeyString(widget.myIdentity);

    // 3. Kirim via Jaringan (PACKET: KUNCI_SAYA###PESAN)
    String packet = "$myPubString###$encryptedString";
    widget.p2pService.sendData(packet);

    // 4. Simpan Lokal
    final newMsg = MessageModel(
      chatId: widget.contact.pubKey, // Simpan di folder teman ini
      senderId: "Me",
      content: encryptedString,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      nonce: "auto",
      isMe: true,
    );

    await _db.insertMessage(newMsg);
    _textCtrl.clear();
    _loadMessages(); // Refresh UI
  }

  // Helper Decrypt
  Future<String> _decrypt(String content) async {
    try {
      List<int> bytes = _keyManager
          .decodeWalletAddress(content.replaceAll('[', '').replaceAll(']', ''));

      // Kalau pesan kita (Me), kita buka pake kunci teman (karena kita encrypt pake public key teman)
      // Kalau pesan teman (Peer), kita buka pake kunci teman (karena dia encrypt pake public key kita, tapi shared secretnya butuh public key dia)

      List<int> keyBytes =
          _keyManager.decodeWalletAddress(widget.contact.pubKey);
      PublicKey remoteKey = SimplePublicKey(keyBytes, type: KeyPairType.x25519);

      return await _cipher.decryptMessage(
        encryptedData: bytes,
        receiverKeyPair: widget.myIdentity,
        senderPublicKey: remoteKey,
      );
    } catch (e) {
      return "🔒 Locked Message";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(widget.contact.colorCode),
              child: Text(widget.contact.initials,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(widget.contact.initials,
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          // Tombol Refresh manual (Smtara sebelum pake Stream)
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages)
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // Chat dari bawah ke atas
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return FutureBuilder<String>(
                  future: _decrypt(msg.content),
                  builder: (context, snapshot) {
                    String txt = snapshot.data ?? "...";
                    return Align(
                      alignment: msg.isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: msg.isMe
                              ? Colors.green[900]
                              : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(txt,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF1F1F1F),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Type secure message...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
