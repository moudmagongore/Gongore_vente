import 'package:cloud_firestore/cloud_firestore.dart';

/// Helpers pour les streams Firestore.
extension FirestoreSafeStream<T> on Stream<T> {
  /// Avale silencieusement les erreurs `permission-denied` qui surviennent
  /// inévitablement après un `signOut` (les listeners actifs sur les
  /// collections protégées émettent une erreur tant qu'ils ne sont pas
  /// cancelés explicitement). Toutes les autres erreurs continuent à
  /// remonter normalement.
  ///
  /// À appliquer juste après `query.snapshots()` dans les repositories,
  /// avant le `.map(...)`. Évite les "Unhandled Exception" qui polluent
  /// la console après une déconnexion forcée (compte/boutique désactivés).
  Stream<T> ignorePermissionDenied() {
    return handleError(
      (dynamic _) {
        // Avalé silencieusement : c'est attendu pendant un signOut.
      },
      test: (dynamic error) =>
          error is FirebaseException && error.code == 'permission-denied',
    );
  }
}
