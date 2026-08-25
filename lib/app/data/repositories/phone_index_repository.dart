import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';

/// Lecture / écriture du mapping téléphone → email pour le login hybride.
///
/// La doc-id est le téléphone **normalisé** (E.164 sans espaces). Côté
/// rules Firestore, la lecture est publique (anonyme) : on ne peut pas
/// authentifier l'utilisateur avant de connaître son email.
class PhoneIndexRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.phoneIndex;

  /// Renvoie l'email associé à un téléphone, ou `null` si pas trouvé.
  Future<String?> getEmailByPhone(String normalizedPhone) async {
    if (normalizedPhone.isEmpty) return null;
    final snap = await _col.doc(normalizedPhone).get();
    if (!snap.exists) return null;
    final data = snap.data();
    return (data?['email'] as String?)?.trim();
  }

  /// Crée ou met à jour l'entrée pour un téléphone.
  Future<void> setEntry({
    required String normalizedPhone,
    required String email,
    required String uid,
  }) {
    if (normalizedPhone.isEmpty) return Future.value();
    return _col.doc(normalizedPhone).set({
      'email': email.trim(),
      'uid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime l'entrée. Tolère le cas où elle n'existe pas.
  Future<void> deleteEntry(String normalizedPhone) {
    if (normalizedPhone.isEmpty) return Future.value();
    return _col.doc(normalizedPhone).delete().catchError((_) {});
  }

  /// Migre un user vers un nouveau numéro : supprime l'ancienne entrée
  /// (si présente) et crée la nouvelle. Pas atomique au sens transaction
  /// (deux docs différents) mais best-effort suffisant pour le cas d'usage.
  Future<void> migratePhone({
    required String? oldNormalized,
    required String? newNormalized,
    required String email,
    required String uid,
  }) async {
    if (oldNormalized != null &&
        oldNormalized.isNotEmpty &&
        oldNormalized != newNormalized) {
      await deleteEntry(oldNormalized);
    }
    if (newNormalized != null && newNormalized.isNotEmpty) {
      await setEntry(
        normalizedPhone: newNormalized,
        email: email,
        uid: uid,
      );
    }
  }

  /// Vérifie si un numéro est déjà utilisé par un AUTRE utilisateur.
  /// Utilisé à la création / édition pour empêcher les collisions.
  Future<bool> isPhoneTakenByOtherUser({
    required String normalizedPhone,
    required String currentUid,
  }) async {
    if (normalizedPhone.isEmpty) return false;
    final snap = await _col.doc(normalizedPhone).get();
    if (!snap.exists) return false;
    final existingUid = (snap.data()?['uid'] as String?) ?? '';
    return existingUid.isNotEmpty && existingUid != currentUid;
  }
}
