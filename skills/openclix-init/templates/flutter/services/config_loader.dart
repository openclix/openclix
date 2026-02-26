import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/clix_types.dart';

class ConfigLoaderOptions {
  final int? timeoutMs;
  final Map<String, String>? headers;

  ConfigLoaderOptions({this.timeoutMs, this.headers});
}

const int defaultTimeoutMilliseconds = 10000;

bool isRemoteUrl(String endpoint) {
  return endpoint.startsWith('http://') || endpoint.startsWith('https://');
}

Future<Config> loadConfig(
  String endpoint, {
  ConfigLoaderOptions? options,
}) async {
  if (!isRemoteUrl(endpoint)) {
    throw Exception(
      'Local file paths are not supported by ConfigLoader in Flutter. '
      'Use replaceConfig() with a bundled config object instead. '
      'Received endpoint: "$endpoint"',
    );
  }

  final timeoutMilliseconds = options?.timeoutMs ?? defaultTimeoutMilliseconds;
  final timeoutDuration = Duration(milliseconds: timeoutMilliseconds);

  final client = HttpClient();
  client.connectionTimeout = timeoutDuration;

  try {
    final request = await client.getUrl(Uri.parse(endpoint));
    request.headers.set('Accept', 'application/json');

    for (final headerEntry
        in options?.headers?.entries ?? const <MapEntry<String, String>>[]) {
      request.headers.set(headerEntry.key, headerEntry.value);
    }

    final response = await request.close().timeout(timeoutDuration);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw Exception(
        'Config fetch returned HTTP ${response.statusCode} '
        '${response.reasonPhrase} '
        'for endpoint: "$endpoint"',
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();

    dynamic decoded;
    try {
      decoded = jsonDecode(responseBody);
    } catch (error) {
      throw Exception(
        'Failed to parse config JSON from endpoint "$endpoint": $error',
      );
    }

    if (decoded is! Map) {
      throw Exception('Config endpoint "$endpoint" did not return an object');
    }

    return Config.fromJson(Map<String, dynamic>.from(decoded));
  } on TimeoutException {
    throw Exception(
      'Config fetch timed out after ${timeoutMilliseconds}ms '
      'for endpoint: "$endpoint"',
    );
  } finally {
    client.close(force: true);
  }
}
