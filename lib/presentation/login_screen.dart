import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import '../data/local/database_service.dart';
import '../core/crypto/storage_service.dart';
import 'dummy_screen.dart';

class LoginScreen extends StatefulWidget {
  final Widget realApp;
  const LoginScreen({super.key, required this.realApp});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _input = "";
  String _result = "0";

  String? savedMaster;
  String? savedGhost;
  String? savedPanic;

  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    final pins = await _storage.getPins();
    if (pins != null) {
      setState(() {
        savedMaster = pins['master'];
        savedGhost = pins['ghost'];
        savedPanic = pins['panic'];
      });
      print("✅ PINS LOADED: Master=$savedMaster"); // Debug Log
    } else {
      print("⚠️ NO PINS FOUND IN STORAGE"); // Debug Log
    }
  }

  void _onBtnTap(String val) {
    setState(() {
      if (val == "AC") {
        _input = "";
        _result = "0";
      } else if (val == "⌫") {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      } else if (val == "=") {
        _checkInput();
      } else {
        _input += val;
      }
    });
  }

  Future<void> _checkInput() async {
    // 1. DEBUG: Lihat apa yang diketik vs apa yang disimpan
    print("Checking Input: '$_input'");
    print("vs Saved Master: '$savedMaster'");

    // 2. Jika PIN belum termuat, coba muat lagi sekarang (Fix Masalah Loading)
    if (savedMaster == null) {
      await _loadPins();
      if (savedMaster == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Error: Storage Locked/Empty. Try Restarting App.")),
        );
        return;
      }
    }

    // 3. Cek Login
    if (_input == savedMaster) {
      print("🔓 MASTER UNLOCKED");
      _navigate(widget.realApp);
      return;
    } else if (_input == savedGhost) {
      print("👻 GHOST MODE");
      _navigate(const DummyScreen());
      return;
    } else if (_input == savedPanic) {
      print("💣 PANIC MODE");
      await _performSelfDestruct();
      _navigate(const DummyScreen());
      return;
    }

    // 4. Kalau bukan PIN, Hitung Matematika
    try {
      Parser p = Parser();
      String mathInput = _input.replaceAll('x', '*');
      Expression exp = p.parse(mathInput);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      setState(() {
        _result = eval.toString();
        if (_result.endsWith(".0")) {
          _result = _result.substring(0, _result.length - 2);
        }
        _input = _result;
        _result = "";
      });
    } catch (e) {
      setState(() {
        _result = "Error";
      });
    }
  }

  Future<void> _performSelfDestruct() async {
    await DatabaseService().nukeDatabase();
    await StorageService().wipeData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Memory Reset.")),
      );
    }
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
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_input,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 32)),
                  const SizedBox(height: 10),
                  Text(_result,
                      style: TextStyle(color: Colors.grey[400], fontSize: 24)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1C),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _row(['AC', '⌫', '%', '/'], Colors.cyanAccent, isOp: true),
                  _row(['7', '8', '9', 'x'], Colors.white),
                  _row(['4', '5', '6', '-'], Colors.white),
                  _row(['1', '2', '3', '+'], Colors.white),
                  _row(['0', '.', '='], Colors.white, isLast: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> keys, Color color,
      {bool isOp = false, bool isLast = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (isLast && key == '0') {
          return _calcButton(key, color, width: 160);
        }
        return _calcButton(
            key,
            (isOp || ['/', 'x', '-', '+', '='].contains(key))
                ? Colors.orange
                : color);
      }).toList(),
    );
  }

  Widget _calcButton(String text, Color color, {double width = 70}) {
    return InkWell(
      onTap: () => _onBtnTap(text),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: width,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(2, 2),
                  blurRadius: 4),
              BoxShadow(
                  color: Colors.grey[800]!,
                  offset: const Offset(-2, -2),
                  blurRadius: 4),
            ]),
        child: Text(
          text,
          style: TextStyle(
              color: color, fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
