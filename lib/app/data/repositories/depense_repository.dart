import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/depense_model.dart';

class DepenseRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.depenses;

  /// Stream des dépenses, de la plus récente à la plus ancienne.
  ///
  /// - `boutiqueId == null` → pas de filtre boutique (super-admin)
  /// - `boutiqueId` vide → liste vide (utilisateur sans boutique)
  /// - `after` / `before` bornent la période sur le champ `date`
  Stream<List<DepenseModel>> watchAll({
    String? boutiqueId,
    DateTime? after,
    DateTime? before,
    int limit = 300,
  }) {
    if (boutiqueId != null && boutiqueId.isEmpty) {
      return Stream.value(<DepenseModel>[]);
    }
    Query<Map<String, dynamic>> q = _col;
    if (boutiqueId != null) {
      q = q.where('boutiqueId', isEqualTo: boutiqueId);
    }
    if (after != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    if (before != null) {
      q = q.where('date', isLessThan: Timestamp.fromDate(before));
    }
    q = q.orderBy('date', descending: true).limit(limit);
    return q.snapshots().ignorePermissionDenied().map(
          (snap) => snap.docs.map(DepenseModel.fromFirestore).toList(),
        );
  }

  Future<DepenseModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return DepenseModel.fromFirestore(snap);
  }

  Future<String> create(DepenseModel depense) async {
    if (depense.montant <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0');
    }
    if (depense.natureId.isEmpty) {
      throw ArgumentError('Nature de dépense requise');
    }
    final data = depense.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  /// Correction d'une dépense. `date`, `boutiqueId` et `userId` sont
  /// volontairement figés (audit) : seuls la nature, le montant et le
  /// commentaire sont modifiables.
  Future<void> update(DepenseModel depense) {
    if (depense.montant <= 0) {
      throw ArgumentError('Le montant doit être supérieur à 0');
    }
    return _col.doc(depense.id).update({
      'natureId': depense.natureId,
      'natureNom': depense.natureNom,
      'montant': depense.montant,
      'commentaire': depense.commentaire,
    });
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
