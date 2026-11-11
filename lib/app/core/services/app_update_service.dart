import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repositories/app_update_repository.dart';
import '../utils/network_timeouts.dart';

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
      // Borné : ce check est facultatif, il ne doit jamais retenir le
      // splash si le réseau traîne (voir [kOptionalReadTimeout]).
      final config = await AppUpdateRepository()
          .get()
          .timeout(kOptionalReadTimeout);
      // La version exigée dépend de la plateforme : le super-admin peut
      // ne forcer qu'Android, par exemple quand une version iOS est
      // encore en relecture chez Apple.
      final estAndroid = Platform.isAndroid;
      final exigee = config.minVersionPour(android: estAndroid);
      if (exigee.isEmpty) return null;

      final pkg = await PackageInfo.fromPlatform();
      final installed = pkg.version;

      if (_compareSemver(installed, exigee) >= 0) {
        return null; // À jour ou plus récent
      }

      return AppUpdateRequired(
        installedVersion: installed,
        minVersion: exigee,
        storeUrl: config.storeUrlPour(android: estAndroid),
        message: config.message,
      );
    } catch (_) {
      return null;
    }
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
