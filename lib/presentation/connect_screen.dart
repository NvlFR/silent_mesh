import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';

class ConnectScreen extends StatefulWidget {
  final String myPublicKey;
  final String myIP; // <--- TAMBAHAN: Kita butuh IP untuk ditaruh di QR

  const ConnectScreen({
    super.key,
    required this.myPublicKey,
    required this.myIP, // Wajib diisi
  });

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool isScanning = true;
  final TextEditingController _manualController = TextEditingController();

  // Format Data QR: "IP###KEY"
  String get _qrData => "${widget.myIP}###${widget.myPublicKey}";

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _finishConnection(barcode.rawValue!);
        break;
      }
    }
  }

  void _onManualSubmit() {
    final input = _manualController.text.trim();
    if (input.isNotEmpty) {
      _finishConnection(input);
    }
  }

  void _finishConnection(String data) {
    // Kembalikan data mentah (IP###KEY) ke main.dart untuk diproses
    FocusScope.of(context).unfocus();
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(isScanning ? "Scan Friend's QR" : "My Identity"),
        backgroundColor: Colors.black,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => isScanning = !isScanning),
            icon: Icon(isScanning ? Icons.badge : Icons.camera_alt,
                color: Colors.white),
            label: Text(isScanning ? "Show My QR" : "Scan Friend",
                style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: isScanning ? _buildScannerAndInput() : _buildMyQR(),
    );
  }

  Widget _buildScannerAndInput() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent),
                borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MobileScanner(onDetect: _onDetect, fit: BoxFit.cover),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1F1F1F),
            child: Column(
              children: [
                const Text("Or enter manually (IP or Key):",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                TextField(
                  controller: _manualController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: "Paste QR Data here...",
                      filled: true,
                      fillColor: Colors.black,
                      suffixIcon: IconButton(
                        icon:
                            const Icon(Icons.paste, color: Colors.greenAccent),
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null)
                            setState(
                                () => _manualController.text = data!.text!);
                        },
                      )),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _onManualSubmit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800]),
                  child: const Text("CONNECT",
                      style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyQR() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: QrImageView(
                data: _qrData, // <-- INI KUNCINYA (IP + KEY)
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 20),
            const Text("Scan this to auto-connect & exchange keys",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _qrData));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Connection Data Copied!")));
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent),
                    borderRadius: BorderRadius.circular(5)),
                child: const Text("COPY CONNECTION DATA",
                    style: TextStyle(color: Colors.greenAccent)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
