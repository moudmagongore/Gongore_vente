import '../constants/app_constants.dart';

/// Normalise un numéro de téléphone vers le format E.164 utilisé comme
/// clé dans la collection `phone_index`.
///
/// Règles :
/// - Strip tous les caractères non-numériques sauf le `+` initial
/// - Si le résultat ne commence pas par `+`, on préfixe avec
///   [AppConstants.defaultPhoneCountryCode] (`+224`)
/// - Renvoie `null` si l'entrée est vide ou ne contient aucun digit
///
/// Exemples :
/// ```
/// '+224 621 78 56 45' → '+224621785645'
/// '00224621785645'    → '+224621785645'   (le `00` n'est pas géré ici —
///                                          retourne `+00224621785645`)
/// '621785645'         → '+224621785645'
/// '+224 (621) 78-56-45' → '+224621785645'
/// '   '               → null
/// ```
class PhoneNormalizer {
  PhoneNormalizer._();

  /// Renvoie la version normalisée ou `null` si entrée invalide / vide.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final hasPlus = trimmed.startsWith('+');
    // Garde uniquement les chiffres
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    if (hasPlus) {
      return '+$digits';
    }
    // Pas de + → on préfixe avec l'indicatif par défaut
    return '${AppConstants.defaultPhoneCountryCode}$digits';
  }

  /// `true` si l'entrée ressemble à un numéro plutôt qu'à un email.
  /// Critère : aucun `@` ET au moins 6 chiffres.
  static bool looksLikePhone(String input) {
    final t = input.trim();
    if (t.isEmpty) return false;
    if (t.contains('@')) return false;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 6;
  }
}
