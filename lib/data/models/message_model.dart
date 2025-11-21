class MessageModel {
  final String? id;
  final String chatId; // <--- KOLOM BARU (Kunci Lawan Bicara)
  final String senderId; // Pengirim asli (Bisa 'Me' atau Key Teman)
  final String content;
  final int timestamp;
  final String nonce;
  final bool isMe;

  MessageModel({
    this.id,
    required this.chatId, // Wajib diisi
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.nonce,
    required this.isMe,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'].toString(),
      chatId: map['chat_id'] ?? 'unknown', // Baca kolom baru
      senderId: map['sender_id'],
      content: map['content'],
      timestamp: map['timestamp'],
      nonce: map['nonce'],
      isMe: map['is_me'] == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chat_id': chatId, // Simpan kolom baru
      'sender_id': senderId,
      'content': content,
      'timestamp': timestamp,
      'nonce': nonce,
      'is_me': isMe ? 1 : 0,
    };
  }
}
