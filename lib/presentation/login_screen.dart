import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk vibrate & exit
import '../data/local/database_service.dart'; // Untuk Panic Wipe
import '../core/crypto/storage_service.dart'; // Untuk Panic Wipe
import 'dummy_screen.dart'; // Layar Palsu

class LoginScreen extends StatefulWidget {
  // Kita butuh widget ChatScreen asli dioper ke sini
  final Widget realApp;

  const LoginScreen({super.key, required this.realApp});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String enteredPin = "";

  // Variabel untuk menampung PIN dari database lokal
  String? savedMaster;
  String? savedGhost;
  String? savedPanic;

  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  // Ambil PIN dari Brankas saat layar login dibuka
  Future<void> _loadPins() async {
    final pins = await _storage.getPins();
    if (pins != null) {
      setState(() {
        savedMaster = pins['master'];
        savedGhost = pins['ghost'];
        savedPanic = pins['panic'];
      });
    }
  }

  // Fungsi saat tombol angka ditekan
  void _onKeyPressed(String value) {
    if (enteredPin.length < 6) {
      setState(() {
        enteredPin += value;
      });
      HapticFeedback.lightImpact(); // Getar halus saat ketik
    }

    // Cek otomatis jika sudah 6 digit
    if (enteredPin.length == 6) {
      _checkPin();
    }
  }

  void _delete() {
    if (enteredPin.isNotEmpty) {
      setState(() {
        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
      });
      HapticFeedback.lightImpact();
    }
  }

  // LOGIKA PENGECEKAN PIN
  Future<void> _checkPin() async {
    // Delay sedikit biar user lihat titik terakhir terisi
    await Future.delayed(const Duration(milliseconds: 150));

    // Pastikan PIN sudah termuat dari storage
    if (savedMaster == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Error: PINs not loaded. Restart App."),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Bandingkan input dengan data Storage
    if (enteredPin == savedMaster) {
      // 1. PIN ASLI -> Masuk SilentMesh
      _navigate(widget.realApp);
    } else if (enteredPin == savedGhost) {
      // 2. PIN PALSU -> Masuk Notes Biasa
      _navigate(const DummyScreen());
    } else if (enteredPin == savedPanic) {
      // 3. PANIC -> HAPUS DATA + Masuk Notes Biasa
      await _performSelfDestruct();
      _navigate(const DummyScreen());
    } else {
      // Salah Password
      // Getar Panjang (Error)
      HapticFeedback.heavyImpact();

      // Animasi Reset (Clear)
      setState(() {
        enteredPin = "";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incorrect PIN"),
          backgroundColor: Colors.red,
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  Future<void> _performSelfDestruct() async {
    await DatabaseService().nukeDatabase();
    await StorageService().wipeData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("System Cache Cleared.")),
    );
  }

  void _navigate(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("ENTER PASSCODE",
                style: TextStyle(
                    color: Colors.grey, letterSpacing: 2, fontSize: 16)),
            const SizedBox(height: 40),

            // --- INDIKATOR PIN (DIPERBAIKI) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                // Logic: Apakah digit ke-index ini sudah diisi?
                bool isFilled = index < enteredPin.length;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Kalau terisi: Hijau Penuh. Kalau kosong: Transparan
                    color: isFilled ? Colors.greenAccent : Colors.transparent,
                    // Kalau terisi: Border Hijau. Kalau kosong: Border Abu
                    border: Border.all(
                      color: isFilled
                          ? Colors.greenAccent
                          : Colors.grey.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2)
                          ]
                        : [],
                  ),
                );
              }),
            ),
            const SizedBox(height: 60),

            // Keypad Angka
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildRow(["1", "2", "3"]),
        _buildRow(["4", "5", "6"]),
        _buildRow(["7", "8", "9"]),
        _buildRow(["", "0", "DEL"]),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox(width: 75); // Spacer kosong
          return _buildButton(key);
        }).toList(),
      ),
    );
  }

  Widget _buildButton(String text) {
    return InkWell(
      onTap: () => text == "DEL" ? _delete() : _onKeyPressed(text),
      customBorder: const CircleBorder(),
      child: Container(
        width: 75,
        height: 75,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.1),
          border: Border.all(color: Colors.white10), // Border tipis di tombol
        ),
        child: text == "DEL"
            ? const Icon(Icons.backspace_outlined,
                color: Colors.white, size: 24)
            : Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w300)), // Font lebih tipis & elegan
      ),
    );
  }
}
