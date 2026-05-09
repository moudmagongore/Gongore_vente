import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import '../../data/models/app_update_config_model.dart';
import '../../data/repositories/app_update_repository.dart';

/// Détermine si l'app installée est trop ancienne par rapport à la version
/// minimale exigée et, si oui, prépare les infos pour le dialog forcé.
///
/// Best-effort : si la lecture Firestore échoue (offline, rules), on
/// ne bloque PAS l'utilisateur — on retourne `null`.
class AppUpdateService {
  AppUpdateService._();

  /// Renvoie [AppUpdateRequired] si une mise à jour est obligatoire,
  /// `null` sinon (à jour, ou config absente, ou échec réseau).
  static Future<AppUpdateRequired?> check() async {
    try {
      final config = await AppUpdateRepository().get();
      if (config.minVersion.trim().isEmpty) return null;

      final pkg = await PackageInfo.fromPlatform();
      final installed = pkg.version;

      if (_compareSemver(installed, config.minVersion) >= 0) {
        return null; // À jour ou plus récent
      }

      return AppUpdateRequired(
        installedVersion: installed,
        minVersion: config.minVersion,
        storeUrl: _storeUrlFor(config),
        message: config.message,
      );
    } catch (_) {
      return null;
    }
  }

  static String _storeUrlFor(AppUpdateConfigModel config) {
    if (Platform.isIOS) return config.iosStoreUrl.trim();
    if (Platform.isAndroid) return config.androidStoreUrl.trim();
    return '';
  }

  /// Compare deux versions semver `MAJOR.MINOR.PATCH`. Retourne :
  /// - < 0 si `a < b`
  /// - 0 si égales
  /// - > 0 si `a > b`
  ///
  /// Tolère des suffixes (ex: `1.2.5+3`) en ne comparant que la partie
  /// principale avant le `+` ou `-`.
  static int _compareSemver(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    for (var i = 0; i < 3; i++) {
      final cmp = pa[i].compareTo(pb[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  static List<int> _parse(String v) {
    // Strip suffixes (build numbers, pre-release tags)
    final main = v.split(RegExp(r'[+\-]')).first;
    final parts = main.split('.');
    final out = [0, 0, 0];
    for (var i = 0; i < parts.length && i < 3; i++) {
      out[i] = int.tryParse(parts[i].trim()) ?? 0;
    }
    return out;
  }
}

/// Données portées au dialog forcé.
class AppUpdateRequired {
  final String installedVersion;
  final String minVersion;
  final String storeUrl;
  final String? message;

  const AppUpdateRequired({
    required this.installedVersion,
    required this.minVersion,
    required this.storeUrl,
    this.message,
  });
}
