import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionsService {
  static const _key = 'permissions_requested_v1';

  static Future<bool> shouldRequest() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key) ?? false);
  }

  static Future<void> requestAll(BuildContext context) async {
    // Dialogové vysvětlení před samotným systémovým dotazem
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Potřebná oprávnění'),
        content: const Text(
          'Aplikace potřebuje:\n\n'
          '• Přístup ke kameře — pro skenování čísel vozů\n'
          '• Přístup k poloze — pro zaznamenání místa skenování do soupisu',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Rozumím'),
          ),
        ],
      ),
    );

    // Systémové dotazy na oprávnění
    await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
