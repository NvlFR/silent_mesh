import 'package:cryptography/cryptography.dart';
import 'package:bs58/bs58.dart';
import 'dart:typed_data'; // <--- WAJIB DITAMBAHKAN (Untuk Uint8List)

class KeyManager {
  final algorithm = X25519();

  // Generate Identitas Baru
  Future<SimpleKeyPair> generateNewIdentity() async {
    final keyPair = await algorithm.newKeyPair();
    return keyPair;
  }

  // FUNGSI BARU: Mengubah Public Key jadi String Cantik (Base58)
  Future<String> getPublicKeyString(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();

    // --- PERBAIKAN DI SINI ---
    // Kita ubah List<int> menjadi Uint8List agar bs58 mau menerimanya
    final bytes = Uint8List.fromList(publicKey.bytes);

    return base58.encode(bytes);
  }

  // HELPER: Mengembalikan String Base58 ke List Angka (untuk Dekripsi)
  List<int> decodeWalletAddress(String walletAddress) {
    // .toList() mengubah Uint8List kembali menjadi List<int> standar
    return base58.decode(walletAddress).toList();
  }
}
