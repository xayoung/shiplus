import 'dart:convert';

/// Keeps response structure visible without printing account or session values.
class Formula1LoginDiagnostics {
  static dynamic decodeBody(dynamic body) {
    if (body is String) {
      try {
        return jsonDecode(body);
      } on FormatException {
        return body;
      }
    }
    return body;
  }

  static Object? redact(dynamic value, {String key = '', int depth = 0}) {
    if (depth > 8) return '<nested value>';
    if (value == null) return null;
    const codeKeys = {
      'responsecode',
      'errorcode',
      'faultcode',
      'code',
      'statuscode',
    };
    if (codeKeys.contains(key.toLowerCase())) {
      final code = value.toString();
      if (RegExp(r'^[A-Za-z0-9_.-]{1,64}$').hasMatch(code)) return code;
    }
    if (value is Map) {
      return value.map(
        (key, child) => MapEntry(
          key.toString(),
          redact(child, key: key.toString(), depth: depth + 1),
        ),
      );
    }
    if (value is List) {
      return value
          .take(10)
          .map((child) => redact(child, depth: depth + 1))
          .toList();
    }
    if (value is String) return '<string: ${value.length} chars>';
    if (value is num) return '<number>';
    if (value is bool) return '<boolean>';
    return '<value>';
  }

  static String describe(int? status, dynamic body, {String? contentType}) {
    final decoded = decodeBody(body);
    final kind = decoded is Map
        ? 'object'
        : decoded is List
        ? 'array'
        : decoded is String
        ? 'text'
        : decoded == null
        ? 'empty'
        : 'scalar';
    return '[F1TV login] HTTP ${status ?? 'unknown'}; '
        'content-type=${contentType ?? 'unknown'}; body=$kind; '
        'response=${jsonEncode(redact(decoded))}';
  }
}
