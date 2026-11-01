import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static Uri get apiBaseUri {
    final value = dotenv.env['API_BASE_URL']?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('API_BASE_URL is missing from .env.local');
    }

    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !parsed.hasAuthority ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'https' && parsed.scheme != 'http') ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw StateError('API_BASE_URL must be a valid HTTP(S) base URL');
    }

    return Uri.parse(value.endsWith('/') ? value : '$value/');
  }
}
