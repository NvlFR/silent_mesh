import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk vibrate & exit
import '../data/local/database_service.dart'; // Untuk Panic Wipe
import '../core/crypto/storage_service.dart'; // Untuk Panic Wipe
// import 'chat_screen.dart'; // Layar Asli (Nanti kita rename CryptoLab jadi ini)
import 'dummy_screen.dart'; // Layar Palsu
// import 'package:local_auth/local_auth.dart'; // Opsional: Biometric (Skip dulu biar simpel)

// KITA GUNAKAN PASSCODE HARDCODED DULU UNTUK PROTOTYPE
// Nanti di Phase selanjutnya baru kita simpan hash passwordnya di SecureStorage.
const String REAL_PIN = "111111";
const String FAKE_PIN = "000000";
const String PANIC_PIN = "999999";

class LoginScreen extends StatefulWidget {
  // Kita butuh widget ChatScreen asli dioper ke sini
  final Widget realApp;

  const LoginScreen({super.key, required this.realApp});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String enteredPin = "";

  // Fungsi saat tombol angka ditekan
  void _onKeyPressed(String value) {
    if (enteredPin.length < 6) {
      setState(() {
        enteredPin += value;
      });
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
    }
  }

  Future<void> _checkPin() async {
    // Delay sedikit biar kerasa mikir
    await Future.delayed(const Duration(milliseconds: 300));

    if (enteredPin == REAL_PIN) {
      // 1. PIN ASLI -> Masuk SilentMesh
      _navigate(widget.realApp);
    } else if (enteredPin == FAKE_PIN) {
      // 2. PIN PALSU -> Masuk Notes Biasa
      _navigate(const DummyScreen());
    } else if (enteredPin == PANIC_PIN) {
      // 3. PANIC -> HAPUS DATA + Masuk Notes Biasa
      await _performSelfDestruct();
      _navigate(const DummyScreen());
    } else {
      // Salah Password
      setState(() {
        enteredPin = ""; // Reset
      });
      // Getar HP (Haptic Feedback)
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Incorrect PIN"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _performSelfDestruct() async {
    // Hapus Database Chat
    await DatabaseService().nukeDatabase();
    // Hapus Key dari Vault
    await StorageService().wipeData();

    // Tampilkan notifikasi palsu seolah-olah sistem error biasa
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
            const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("ENTER PASSCODE",
                style: TextStyle(color: Colors.grey, letterSpacing: 2)),
            const SizedBox(height: 30),

            // Indikator PIN (Titik-titik)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < enteredPin.length
                        ? Colors.greenAccent
                        : Colors.grey.withOpacity(0.3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 50),

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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox(width: 80);
          return _buildButton(key);
        }).toList(),
      ),
    );
  }

  Widget _buildButton(String text) {
    return InkWell(
      onTap: () => text == "DEL" ? _delete() : _onKeyPressed(text),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.1),
        ),
        child: text == "DEL"
            ? const Icon(Icons.backspace_outlined, color: Colors.white)
            : Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }
}
