import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/message_model.dart'; // Pastikan model yang tadi dibuat ada di sini

class DatabaseService {
  static Database? _database;

  // 1. Buka Koneksi ke Database
  Future<Database> get database async {
    if (_database != null) return _database!;

    // Cek OS: Jika Linux/Windows, kita harus inisialisasi FFI dulu
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDB('silent_mesh_chat.db');
    return _database!;
  }

  // 2. Konfigurasi Lokasi & Tabel
  Future<Database> _initDB(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // 3. Bikin Tabel (Kolom-kolom Excel-nya)
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        nonce TEXT NOT NULL,
        is_me INTEGER NOT NULL
      )
    ''');
  }

  // 4. CREATE: Simpan Pesan Baru
  Future<void> insertMessage(MessageModel message) async {
    final db = await database;
    await db.insert('messages', message.toMap());
  }

  // 5. READ: Ambil Semua History Chat
  Future<List<MessageModel>> getAllMessages() async {
    final db = await database;
    // Ambil data, urutkan dari yang terbaru (DESC)
    final result = await db.query('messages', orderBy: 'timestamp DESC');

    return result.map((json) => MessageModel.fromMap(json)).toList();
  }

  // 6. DELETE: Hapus Semua (Fitur Panic Button)
  Future<void> nukeDatabase() async {
    final db = await database;
    await db.delete('messages');
  }
}
