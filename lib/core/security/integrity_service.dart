import 'package:safe_device/safe_device.dart';
import 'dart:io';

class IntegrityService {
  // Fungsi: Periksa apakah lingkungan aman?
  // Return: String kosong "" jika Aman.
  // Return: Pesan Error jika TIDAK AMAN.
  Future<String> checkSystemIntegrity() async {
    try {
      // 1. Cek Root (Jailbreak di iOS)
      // Root adalah ancaman terbesar karena bisa baca memori aplikasi lain.
      bool isJailBroken = await SafeDevice.isJailBroken;
      if (isJailBroken) {
        return "CRITICAL THREAT: Root Access Detected!\nApp cannot run on compromised device.";
      }

      // 2. Cek Apakah HP Asli? (Anti-Emulator)
      // Hacker biasanya membongkar aplikasi lewat Emulator di PC.
      // Note: Di tahap development, kadang HP asli terdeteksi emulator kalau driver USB-nya aneh.
      // Kita tetap pasang, tapi hati-hati.
      // bool isRealDevice = await SafeDevice.isRealDevice;
      // if (!isRealDevice) {
      //   return "SECURITY ALERT: Running on Emulator/Virtual Environment.";
      // }

      // 3. Cek USB Debugging (Mode Pengembang)
      // Ini agak tricky. Kalau kamu lagi develop (colok kabel), ini pasti True.
      // Nanti saat rilis ke publik, ini harus dilarang.
      // bool isDevMode = await SafeDevice.isDevelopmentModeEnable;
      // if (isDevMode) {
      //   return "WARNING: USB Debugging is Enabled.\nPlease disable Developer Options.";
      // }

      return ""; // Kosong = AMAN SENTOSA
    } catch (e) {
      return "Security Check Failed: $e";
    }
  }
}
