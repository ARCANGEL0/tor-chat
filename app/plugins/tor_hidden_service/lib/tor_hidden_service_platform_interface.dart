import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'tor_hidden_service_method_channel.dart';

abstract class TorHiddenServicePlatform extends PlatformInterface {
  /// Constructs a TorHiddenServicePlatform.
  TorHiddenServicePlatform() : super(token: _token);

  static final Object _token = Object();

  static TorHiddenServicePlatform _instance = MethodChannelTorHiddenService();

  /// The default instance of [TorHiddenServicePlatform] to use.
  ///
  /// Defaults to [MethodChannelTorHiddenService].
  static TorHiddenServicePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TorHiddenServicePlatform] when
  /// they register themselves.
  static set instance(TorHiddenServicePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
