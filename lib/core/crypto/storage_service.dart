import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  // Kita pakai FlutterSecureStorage
  // Di Android -> Keystore (Hardware backed security)
  // Di iOS -> Keychain
  // Di Linux -> LibSecret (Gnome Keyring)
  final _storage = const FlutterSecureStorage();

  static const _privateKeyKey = 'silent_mesh_priv_key';
  static const _publicKeyKey = 'silent_mesh_pub_key';

  // 1. SIMPAN Identitas
  Future<void> saveIdentity(String base64PrivKey, String base64PubKey) async {
    await _storage.write(key: _privateKeyKey, value: base64PrivKey);
    await _storage.write(key: _publicKeyKey, value: base64PubKey);
  }

  // 2. AMBIL Identitas (Kalau ada)
  Future<Map<String, String>?> getIdentity() async {
    final priv = await _storage.read(key: _privateKeyKey);
    final pub = await _storage.read(key: _publicKeyKey);

    if (priv != null && pub != null) {
      return {
        'private': priv,
        'public': pub,
      };
    }
    return null; // Belum punya akun
  }

  // 3. HAPUS Identitas (Fitur Self-Destruct nanti)
  Future<void> wipeData() async {
    await _storage.deleteAll();
  }
}
