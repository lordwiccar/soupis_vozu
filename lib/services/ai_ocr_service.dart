import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'scan_settings_service.dart';

class AiOcrService {
  static const _prompt =
      'This is a photo of a railway wagon. Find and extract the UIC wagon number. '
      'It is a 12-digit number typically written in the format XX XX XXXX XXX-X '
      '(for example: 31 54 4854 269-8). '
      'Return ONLY the 12 digits with no spaces, dashes, or other characters. '
      'If multiple UIC numbers are visible, return each on a separate line. '
      'If no UIC number can be found, return only the word NONE.';

  // Max šířka obrázku odeslaného do API – redukuje payload pod limity Anthropic (5 MB) i OpenAI.
  static const _maxImageWidth = 1024;

  static Future<List<String>> extractWagonNumbers(
      String imagePath, AiProvider provider, String apiKey) async {
    final originalBytes = await File(imagePath).readAsBytes();
    final resizedBytes = await _resizeImageToPng(originalBytes);
    final base64Image = base64Encode(resizedBytes);

    final raw = provider == AiProvider.openai
        ? await _callOpenAi(base64Image, apiKey)
        : await _callClaude(base64Image, apiKey);

    return _parseResponse(raw);
  }

  /// Zmenší obrázek na max [_maxImageWidth] px šířky a vrátí PNG bajty.
  static Future<List<int>> _resizeImageToPng(List<int> bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      targetWidth: _maxImageWidth,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  static Future<String> _callOpenAi(
      String base64Image, String apiKey) async {
    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-4o',
            'max_tokens': 100,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/png;base64,$base64Image',
                    },
                  },
                  {'type': 'text', 'text': _prompt},
                ],
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Neplatný OpenAI API klíč');
    }
    if (response.statusCode == 429) {
      throw Exception(_parseOpenAiQuotaError(response.body));
    }
    if (response.statusCode != 200) {
      throw Exception('Chyba OpenAI API (${response.statusCode})');
    }

    final json = jsonDecode(response.body);
    return json['choices'][0]['message']['content'] as String;
  }

  static Future<String> _callClaude(
      String base64Image, String apiKey) async {
    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 100,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {
                      'type': 'base64',
                      'media_type': 'image/png',
                      'data': base64Image,
                    },
                  },
                  {'type': 'text', 'text': _prompt},
                ],
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Neplatný Anthropic API klíč');
    }
    if (response.statusCode == 429) {
      throw Exception('Překročen limit Anthropic API, zkuste za chvíli');
    }
    if (response.statusCode != 200) {
      throw Exception('Chyba Anthropic API (${response.statusCode})');
    }

    final json = jsonDecode(response.body);
    return json['content'][0]['text'] as String;
  }

  /// Rozliší nedostatečný kredit (insufficient_quota) od skutečného rate limitu.
  static String _parseOpenAiQuotaError(String responseBody) {
    try {
      final error =
          jsonDecode(responseBody)['error'] as Map<String, dynamic>;
      final type = error['type'] as String? ?? '';
      final code = error['code'] as String? ?? '';
      if (type == 'insufficient_quota' || code == 'insufficient_quota') {
        return 'OpenAI účet nemá dostatečný kredit. '
            'Přidejte kredity na platform.openai.com/account/billing';
      }
    } catch (_) {}
    return 'Překročen limit OpenAI API, zkuste za chvíli';
  }

  static List<String> _parseResponse(String raw) {
    if (raw.trim().toUpperCase() == 'NONE') return [];

    final results = <String>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final digits = line.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 12) results.add(digits);
    }
    return results;
  }
}
