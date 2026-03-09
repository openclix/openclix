import 'dart:ui' as ui;
import '../models/openclix_types.dart';

class FlutterDeviceLocaleProvider implements DeviceLocaleProvider {
  @override
  String? getLocale() {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      return locale.languageCode;
    } catch (_) {
      return null;
    }
  }
}
