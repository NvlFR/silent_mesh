import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk HapticFeedback
import '../core/crypto/storage_service.dart';
import '../main.dart'; // Untuk navigasi ke Gatekeeper

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _pageController = PageController();
  final StorageService _storage = StorageService();

  String pinMaster = "";
  String pinGhost = "";
  String pinPanic = "";

  int currentStep = 0;

  final List<Map<String, String>> steps = [
    {
      "title": "Create Master PIN",
      "desc": "This PIN opens your REAL Encrypted Vault.\nDon't forget it."
    },
    {
      "title": "Create Ghost PIN",
      "desc": "This PIN opens a FAKE Notes app.\nUse this under pressure."
    },
    {
      "title": "Create Panic PIN",
      "desc": "This PIN WIPES all data instantly.\nUse only in extreme danger."
    }
  ];

  void _onPinSubmitted(String pin) async {
    if (pin.length < 6) return; // Wajib 6 digit

    // Delay dikit biar animasi kelar
    await Future.delayed(const Duration(milliseconds: 150));

    if (currentStep == 0) {
      pinMaster = pin;
      _nextPage();
    } else if (currentStep == 1) {
      pinGhost = pin;
      _nextPage();
    } else if (currentStep == 2) {
      pinPanic = pin;
      await _finishSetup();
    }
  }

  void _nextPage() {
    setState(() {
      currentStep++;
    });
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _finishSetup() async {
    await _storage.savePins(
        masterPin: pinMaster, ghostPin: pinGhost, panicPin: pinPanic);

    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const GatekeeperScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar di atas
            LinearProgressIndicator(
              value: (currentStep + 1) / 3,
              backgroundColor: Colors.grey[900],
              color: _getStepColor(),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics:
                    const NeverScrollableScrollPhysics(), // Gak bisa swipe manual, harus isi PIN
                itemCount: 3,
                itemBuilder: (context, index) {
                  return _buildPinStep(
                      steps[index]['title']!, steps[index]['desc']!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStepColor() {
    if (currentStep == 0) return Colors.greenAccent;
    if (currentStep == 1) return Colors.amber;
    return Colors.redAccent;
  }

  Widget _buildPinStep(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 60, color: _getStepColor()),
          const SizedBox(height: 20),
          Text(title,
              style: TextStyle(
                  color: _getStepColor(),
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),

          // Panggil Widget Input yang Baru
          _PinInput(
            color:
                _getStepColor(), // Warna titik ikut warna step (Hijau/Kuning/Merah)
            onSubmit: _onPinSubmitted,
          ),
        ],
      ),
    );
  }
}

// --- WIDGET INPUT PIN (Updated UI) ---
class _PinInput extends StatefulWidget {
  final Color color;
  final Function(String) onSubmit;

  const _PinInput({required this.color, required this.onSubmit});

  @override
  State<_PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<_PinInput> {
  String input = "";

  void _tap(String val) {
    if (input.length < 6) {
      setState(() => input += val);
      HapticFeedback.lightImpact();
    }
    // Auto submit kalau sudah 6
    if (input.length == 6) {
      widget.onSubmit(input);
      // Kita reset input sebentar agar transisi ke page berikutnya bersih
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => input = "");
      });
    }
  }

  void _del() {
    if (input.isNotEmpty) {
      setState(() => input = input.substring(0, input.length - 1));
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- INDIKATOR TITIK BARU ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            bool isFilled = index < input.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Isi warna sesuai step (Hijau/Kuning/Merah)
                color: isFilled ? widget.color : Colors.transparent,
                border: Border.all(
                  color: isFilled ? widget.color : Colors.grey.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                            color: widget.color.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2)
                      ]
                    : [],
              ),
            );
          }),
        ),

        const SizedBox(height: 50),

        // Keypad
        Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 1; i <= 9; i++) _btn(i.toString()),
            _btn("", isEmpty: true), // Spacer kiri
            _btn("0"),
            _btn("DEL", isCmd: true), // Tombol hapus
          ],
        )
      ],
    );
  }

  Widget _btn(String txt, {bool isCmd = false, bool isEmpty = false}) {
    if (isEmpty) return const SizedBox(width: 75, height: 75);

    return InkWell(
      onTap: () => txt == "DEL" ? _del() : _tap(txt),
      customBorder: const CircleBorder(),
      child: Container(
        width: 75,
        height: 75,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.1),
          border: Border.all(color: Colors.white10),
        ),
        child: txt == "DEL"
            ? const Icon(Icons.backspace_outlined,
                color: Colors.white, size: 24)
            : Text(txt,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w300)),
      ),
    );
  }
}
