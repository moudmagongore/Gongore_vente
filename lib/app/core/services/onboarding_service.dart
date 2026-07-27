import 'package:get_storage/get_storage.dart';

/// Mémorise si l'onboarding de première ouverture a déjà été parcouru.
///
/// Stocké dans GetStorage (même box que le thème) : la valeur survit aux
/// redémarrages de l'app mais pas à une désinstallation — l'onboarding ne
/// se rejoue donc que sur une nouvelle installation.
class OnboardingService {
  OnboardingService._();

  static const _storageKey = 'onboarding_seen';
  static final _box = GetStorage();

  static bool get hasSeen => _box.read<bool>(_storageKey) ?? false;

  static Future<void> markSeen() => _box.write(_storageKey, true);

  /// Rejoue l'onboarding à la prochaine ouverture. Utile en debug et pour
  /// une éventuelle entrée « Revoir la présentation » dans les paramètres.
  static Future<void> reset() => _box.remove(_storageKey);
}
