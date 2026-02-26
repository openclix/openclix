import 'dart:convert';
import 'dart:math';

final RegExp templateVariablePattern = RegExp(
  r'\{\{([a-zA-Z_][a-zA-Z0-9_.]*)\}\}',
);

Object? resolvePath(Map<String, dynamic> source, String path) {
  final segments = path.split('.');
  dynamic current = source;

  for (final segment in segments) {
    if (current == null || current is! Map) {
      return null;
    }
    current = current[segment];
  }

  return current;
}

bool hasPath(Map<String, dynamic> source, String path) {
  final segments = path.split('.');
  dynamic current = source;

  for (var index = 0; index < segments.length; index += 1) {
    if (current is! Map) return false;
    final segment = segments[index];
    if (!current.containsKey(segment)) return false;
    if (index < segments.length - 1) {
      current = current[segment];
    }
  }

  return true;
}

String valueToString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num) return value.toString();
  if (value is bool) return value ? 'true' : 'false';
  return jsonEncode(value);
}

String renderTemplate(String template, Map<String, dynamic> variables) {
  return template.replaceAllMapped(templateVariablePattern, (match) {
    final fullMatch = match.group(0)!;
    final variableName = match.group(1)!;
    final resolved = resolvePath(variables, variableName);
    if (resolved == null && !hasPath(variables, variableName)) {
      return fullMatch;
    }
    return valueToString(resolved);
  });
}

final Random randomNumberGenerator = Random();

String generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
    RegExp(r'[xy]'),
    (match) {
      final token = match.group(0)!;
      final randomValue = randomNumberGenerator.nextInt(16);
      final mappedValue = token == 'x'
          ? randomValue
          : (randomValue & 0x3) | 0x8;
      return mappedValue.toRadixString(16);
    },
  );
}
