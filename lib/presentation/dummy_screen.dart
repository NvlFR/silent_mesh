import 'package:flutter/material.dart';

class DummyScreen extends StatelessWidget {
  const DummyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Tampilan Palsu: Aplikasi Catatan Sederhana
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Daily Notes"), // Judul Lugu
        backgroundColor: Colors.amber, // Warna cerah, tidak seram
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildNoteItem("Daftar Belanja", "Telur, Susu, Roti, Sabun Cuci"),
          _buildNoteItem(
              "Tugas Kuliah/Kerja", "Revisi laporan bab 3, Email pak Budi"),
          _buildNoteItem("Jadwal Gym", "Selasa & Kamis jam 5 sore"),
          _buildNoteItem(
              "Resep Nasi Goreng", "Bawang merah, bawang putih, kecap..."),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error: Storage Full")));
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildNoteItem(String title, String preview) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: const Icon(Icons.note, color: Colors.amber),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(preview),
      ),
    );
  }
}
