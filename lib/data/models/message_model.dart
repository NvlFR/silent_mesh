class MessageModel {
  final String? id; // ID Unik pesan
  final String senderId; // Siapa pengirimnya (Public Key hash)
  final String content; // Isi pesan (Bisa teks asli atau terenkripsi)
  final int timestamp; // Kapan dikirim
  final String nonce; // "Garam" enkripsi (Wajib disimpan untuk decrypt)
  final bool isMe; // Apakah ini pesan kita sendiri?

  MessageModel({
    this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.nonce,
    required this.isMe,
  });

  // Konversi dari Database (Map) ke Object Dart
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'].toString(),
      senderId: map['sender_id'],
      content: map['content'], // Nanti ini isinya ciphertext
      timestamp: map['timestamp'],
      nonce: map['nonce'],
      isMe: map['is_me'] == 1, // Di SQL, boolean disimpan sebagai 1 atau 0
    );
  }

  // Konversi dari Object Dart ke Database (Map)
  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'content': content,
      'timestamp': timestamp,
      'nonce': nonce,
      'is_me': isMe ? 1 : 0,
    };
  }
}
