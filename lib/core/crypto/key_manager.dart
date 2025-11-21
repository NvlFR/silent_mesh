import 'package:cryptography/cryptography.dart';

class KeyManager {
  // Kita pilih algoritma X25519 (Standar emas untuk pertukaran kunci di HP)
  final algorithm = X25519();

  // Fungsi untuk membuat identitas baru (Private & Public Key)
  Future<SimpleKeyPair> generateNewIdentity() async {
    // 1. Generate Key Pair secara acak dan aman
    final keyPair = await algorithm.newKeyPair();

    return keyPair;
  }

  // Helper: Mengubah Public Key menjadi String (Base64) agar bisa dilihat mata
  Future<String> getPublicKeyString(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    // Kita ambil bytes-nya saja untuk ditampilkan
    return publicKey.bytes.toString();
  }
}
