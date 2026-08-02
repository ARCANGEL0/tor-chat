import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tor_hidden_service_platform_interface.dart';

/// An implementation of [TorHiddenServicePlatform] that uses method channels.
class MethodChannelTorHiddenService extends TorHiddenServicePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('tor_hidden_service');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
