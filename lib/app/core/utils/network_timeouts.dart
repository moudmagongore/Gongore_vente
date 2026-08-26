import 'dart:async';

/// Délais maximum accordés aux lectures Firestore du chemin de DÉMARRAGE
/// (splash + login).
///
/// Pourquoi c'est indispensable : un `get()` Firestore n'a **aucun timeout
/// par défaut**, et `Source.server` lui interdit de retomber sur le cache.
/// Sur une connexion lente ou instable — le cas courant sur un vrai
/// appareil, pas en émulateur — le Future ne se résout jamais et l'écran
/// de démarrage reste figé indéfiniment. Un `try/catch` n'y peut rien :
/// il n'y a pas d'exception, juste une attente sans fin.
///
/// Règle : tout `await` réseau qui bloque l'affichage doit être borné.
const Duration kStartupReadTimeout = Duration(seconds: 8);

/// Délai des vérifications **facultatives** : leur échec ne doit jamais
/// retarder l'utilisateur (check de mise à jour, avertissement
/// d'abonnement...).
const Duration kOptionalReadTimeout = Duration(seconds: 5);

extension StartupTimeout<T> on Future<T> {
  /// Borne l'attente et renvoie [fallback] en cas de dépassement, au lieu
  /// de laisser l'écran figé.
  Future<T> orAfter(Duration limit, T fallback) =>
      timeout(limit, onTimeout: () => fallback);
}
