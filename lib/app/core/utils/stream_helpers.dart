import 'dart:async';

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

  /// Émet [fallback] (ex. liste vide) à la place quand une erreur
  /// `permission-denied` survient. Utile pour les `StreamBuilder` qui
  /// resteraient sinon bloqués en `waiting` quand les rules Firestore
  /// refusent l'accès — au lieu de ça, on affiche un état vide propre.
  Stream<T> permissionDeniedAsValue(T fallback) {
    return transform(
      StreamTransformer<T, T>.fromHandlers(
        handleData: (data, sink) => sink.add(data),
        handleError: (error, stackTrace, sink) {
          if (error is FirebaseException &&
              error.code == 'permission-denied') {
            sink.add(fallback);
          } else {
            sink.addError(error, stackTrace);
          }
        },
      ),
    );
  }
}
