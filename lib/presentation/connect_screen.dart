import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';

class ConnectScreen extends StatefulWidget {
  final String myPublicKey;

  const ConnectScreen({super.key, required this.myPublicKey});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  bool isScanning = true; // Default langsung mode scan
  final TextEditingController _manualController = TextEditingController();

  // 1. Fungsi saat QR terdeteksi Kamera
  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _finishConnection(barcode.rawValue!);
        break;
      }
    }
  }

  // 2. Fungsi saat tombol "Connect" ditekan manual
  void _onManualSubmit() {
    final inputKey = _manualController.text.trim();
    if (inputKey.isNotEmpty) {
      _finishConnection(inputKey);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please paste a Public Key first!")),
      );
    }
  }

  // Helper: Selesaikan proses dan kembali ke menu utama
  void _finishConnection(String targetKey) {
    // Matikan keyboard jika terbuka
    FocusScope.of(context).unfocus();
    // Kembali ke layar chat membawa Public Key teman
    Navigator.pop(context, targetKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // APP BAR: Tombol Ganti Mode (Scan vs My Identity)
      appBar: AppBar(
        title: Text(isScanning ? "Scan / Input Key" : "My Identity"),
        backgroundColor: Colors.black,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                isScanning = !isScanning;
              });
            },
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

  // TAMPILAN 1: GABUNGAN SCANNER & INPUT MANUAL
  Widget _buildScannerAndInput() {
    return Column(
      children: [
        // AREA A: KAMERA (Mengambil sisa ruang yang ada)
        Expanded(
          flex: 2, // Kamera lebih besar
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent),
                borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MobileScanner(
                onDetect: _onDetect,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        // AREA B: INPUT MANUAL (Di Bawah)
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: Color(0xFF1F1F1F),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Or connect manually:",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // TextField Input
                TextField(
                  controller: _manualController,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Courier'),
                  decoration: InputDecoration(
                      hintText: "Paste Friend's Public Key here...",
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon:
                            const Icon(Icons.paste, color: Colors.greenAccent),
                        onPressed: () async {
                          // Fitur Auto Paste dari Clipboard
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            setState(() {
                              _manualController.text = data!.text!;
                            });
                          }
                        },
                      )),
                ),
                const SizedBox(height: 10),

                // Tombol Connect
                ElevatedButton.icon(
                  onPressed: _onManualSubmit,
                  icon: const Icon(Icons.link),
                  label: const Text("CONNECT TO KEY"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // TAMPILAN 2: QR SAYA (Sama seperti sebelumnya)
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
                data: widget.myPublicKey,
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Let your friend scan this code",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Fitur Copy Key Sendiri
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.myPublicKey));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("My Public Key Copied!")),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black),
                child: Column(
                  children: [
                    const Text("TAP TO COPY MY KEY:",
                        style: TextStyle(color: Colors.grey, fontSize: 10)),
                    const SizedBox(height: 5),
                    Text(
                      widget.myPublicKey,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.greenAccent, fontFamily: 'Courier'),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
