import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/nature_depense_model.dart';

class NatureDepenseRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.naturesDepense;
  CollectionReference<Map<String, dynamic>> get _depenses => _fs.depenses;

  /// Renvoie true si au moins une dépense est rattachée à cette nature.
  ///
  /// Le filtre `boutiqueId` est obligatoire pour aligner la query sur les
  /// rules Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
  /// sinon la query est refusée d'office (PERMISSION_DENIED).
  Future<bool> hasUsage(
    String natureId, {
    required String boutiqueId,
  }) async {
    if (natureId.isEmpty || boutiqueId.isEmpty) return false;
    final d = await _depenses
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('natureId', isEqualTo: natureId)
        .limit(1)
        .get();
    return d.docs.isNotEmpty;
  }

  /// Stream scopé selon le rôle :
  /// - `scope == null` → super-admin, toutes les natures
  /// - `scope` non vide → admin/gestionnaire, celles de sa boutique
  /// - `scope` vide → liste vide
  ///
  /// Pas de filtre `active` côté Firestore : pour le super-admin le scope
  /// est nul et `where(active) + orderBy(nom)` n'a pas d'index composite.
  /// Le tri actif/inactif se fait côté client (volumes très faibles).
  Stream<List<NatureDepenseModel>> watchScoped(String? scope) {
    if (scope == null) {
      return _col.orderBy('nom').snapshots().ignorePermissionDenied().map(
            (snap) => snap.docs.map(NatureDepenseModel.fromFirestore).toList(),
          );
    }
    if (scope.isEmpty) return Stream.value(<NatureDepenseModel>[]);
    return _col
        .where('boutiqueId', isEqualTo: scope)
        .orderBy('nom')
        .snapshots()
        .ignorePermissionDenied()
        .map((snap) =>
            snap.docs.map(NatureDepenseModel.fromFirestore).toList());
  }

  Future<NatureDepenseModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return NatureDepenseModel.fromFirestore(snap);
  }

  Future<String> create(NatureDepenseModel nature) async {
    final data = nature.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(NatureDepenseModel nature) {
    return _col.doc(nature.id).update(nature.toMap());
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
