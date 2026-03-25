import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'package:ringinout/config/app_config.dart';

class RemoteConfigService {
  static Future<void> initialize() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 10),
      ),
    );
    await remoteConfig.setDefaults({'is_beta': true});
    await remoteConfig.fetchAndActivate();

    AppConfig.isBetaVersion = remoteConfig.getBool('is_beta');
  }
}
