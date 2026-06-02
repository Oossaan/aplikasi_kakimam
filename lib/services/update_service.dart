import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String apkUrl;
  final String exeUrl;
  final DateTime releaseDate;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.apkUrl,
    required this.exeUrl,
    required this.releaseDate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '',
      releaseNotes: json['release_notes'] ?? '',
      apkUrl: json['apk_url'] ?? '',
      exeUrl: json['exe_url'] ?? '',
      releaseDate:
          DateTime.tryParse(json['release_date'] ?? '') ?? DateTime.now(),
    );
  }
}

class UpdateService {
  // Ganti dengan username dan repo kamu
  static const String _owner = 'Oossaan';
  static const String _repo = 'aplikasi_kakimam';

  // Link ke version.json di repo kamu
  static const String _versionFileUrl =
      'https://raw.githubusercontent.com/$_owner/$_repo/main/version.json';

  /// Cek apakah ada update terbaru
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(_versionFileUrl));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromJson(json);

        // Bandingkan versi
        final currentVersion = await _getCurrentVersion();

        if (_isNewerVersion(updateInfo.version, currentVersion)) {
          return updateInfo;
        }
      } else if (response.statusCode == 404) {
        throw Exception('File version.json tidak ditemukan di repository. Pastikan repo dan file sudah ada.');
      } else {
        throw Exception('Gagal mengambil info update. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      rethrow; // Rethrow agar bisa ditangkap di UI
    }
  }

  /// Ambil versi app saat ini
  static Future<String> _getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '1.0.0';
    }
  }

  /// Bandingkan versi (misal: 1.0.2 > 1.0.1)
  /// Aman untuk panjang versi berbeda dan menangani build number (+N)
  static bool _isNewerVersion(String newVersion, String currentVersion) {
    // Hapus suffix build number (+N) agar bisa dibandingkan
    final cleanNew = newVersion.split('+').first;
    final cleanCurrent = currentVersion.split('+').first;

    final newParts =
        cleanNew.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts =
        cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength =
        newParts.length > currentParts.length
            ? newParts.length
            : currentParts.length;

    for (int i = 0; i < maxLength; i++) {
      final newPart = i < newParts.length ? newParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;

      if (newPart > currentPart) return true;
      if (newPart < currentPart) return false;
    }
    return false;
  }

  /// Buka link download di browser
  static Future<void> downloadUpdate(
      BuildContext context, UpdateInfo updateInfo, bool isWindows) async {
    final url = isWindows ? updateInfo.exeUrl : updateInfo.apkUrl;

    if (url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link download belum tersedia')),
        );
      }
      return;
    }

    // Buka browser untuk download
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
