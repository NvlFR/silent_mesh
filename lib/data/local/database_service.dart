import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/message_model.dart';
import '../models/contact_model.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Ganti nama DB lagi biar bersih (V2.1)
    _database = await _initDB('silent_mesh_v2_1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabel Pesan (Updated: ada chat_id)
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id TEXT NOT NULL, 
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        nonce TEXT NOT NULL,
        is_me INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        pub_key TEXT PRIMARY KEY,
        initials TEXT NOT NULL,
        color_code INTEGER NOT NULL
      )
    ''');
  }

  // --- PESAN ---
  Future<void> insertMessage(MessageModel message) async {
    final db = await database;
    await db.insert('messages', message.toMap());
  }

  // FUNGSI BARU: Ambil pesan HANYA untuk kontak tertentu
  Future<List<MessageModel>> getMessagesForChat(String chatId) async {
    final db = await database;
    final result = await db.query('messages',
        where: 'chat_id = ?', whereArgs: [chatId], orderBy: 'timestamp DESC');
    return result.map((json) => MessageModel.fromMap(json)).toList();
  }

  // --- KONTAK ---
  Future<void> saveContact(ContactModel contact) async {
    final db = await database;
    await db.insert('contacts', contact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ContactModel>> getAllContacts() async {
    final db = await database;
    final result = await db.query('contacts');
    return result.map((c) => ContactModel.fromMap(c)).toList();
  }

  Future<ContactModel?> getContact(String pubKey) async {
    final db = await database;
    final result =
        await db.query('contacts', where: 'pub_key = ?', whereArgs: [pubKey]);
    if (result.isNotEmpty) return ContactModel.fromMap(result.first);
    return null;
  }

  // --- DELETE ---
  Future<void> nukeDatabase() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('contacts');
  }
}
