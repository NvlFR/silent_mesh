import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class CipherService {
  // REVISI: Gunakan Chacha20 (Library otomatis support XChaCha20 via nonce panjang)
  final _algorithm = Chacha20.poly1305Aead();

  final _keyExchange = X25519();

  // FUNGSI 1: ENKRIPSI
  Future<List<int>> encryptMessage(
      {required String plaintext,
      required KeyPair senderKeyPair,
      required PublicKey receiverPublicKey}) async {
    // 1. Buat Shared Secret
    final sharedSecretKey = await _keyExchange.sharedSecretKey(
      keyPair: senderKeyPair,
      remotePublicKey: receiverPublicKey,
    );
    final secretKey = await sharedSecretKey.extract();

    // 2. Lakukan Enkripsi
    final messageBytes = utf8.encode(plaintext);

    // Library ini akan otomatis generate Nonce acak yang aman
    final secretBox = await _algorithm.encrypt(
      messageBytes,
      secretKey: secretKey,
    );

    // 3. Gabungkan hasil
    return secretBox.concatenation();
  }

  // FUNGSI 2: DEKRIPSI
  Future<String> decryptMessage({
    required List<int> encryptedData,
    required KeyPair receiverKeyPair,
    required PublicKey senderPublicKey,
  }) async {
    // 1. Buat Shared Secret
    final sharedSecretKey = await _keyExchange.sharedSecretKey(
      keyPair: receiverKeyPair,
      remotePublicKey: senderPublicKey,
    );
    final secretKey = await sharedSecretKey.extract();

    // 2. Pecah paket data
    // Nonce XChaCha20 biasanya 24 bytes, tapi Chacha20 default 12 bytes.
    // Kita biarkan library mendeteksi dari macLength (Poly1305 selalu 16 bytes).
    final secretBox = SecretBox.fromConcatenation(
      encryptedData,
      nonceLength: 12, // Default ChaCha20
      macLength: 16, // Poly1305 standard
    );

    // 3. Buka Gembok
    final decryptedBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );

    return utf8.decode(decryptedBytes);
  }
}
