import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/fournisseur_model.dart';

class FournisseurRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.fournisseurs;
  CollectionReference<Map<String, dynamic>> get _approvisionnements =>
      _fs.approvisionnements;
  CollectionReference<Map<String, dynamic>> get _reglementsFournisseurs =>
      _fs.reglementsFournisseurs;

  /// Renvoie true si le fournisseur a au moins un appro ou un règlement
  /// lié. Le filtre `boutiqueId` est obligatoire pour aligner la query
  /// sur les rules Firestore (sinon PERMISSION_DENIED).
  Future<bool> hasUsage(
    String fournisseurId, {
    required String boutiqueId,
  }) async {
    if (fournisseurId.isEmpty || boutiqueId.isEmpty) return false;
    final a = await _approvisionnements
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('fournisseurId', isEqualTo: fournisseurId)
        .limit(1)
        .get();
    if (a.docs.isNotEmpty) return true;
    final r = await _reglementsFournisseurs
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('fournisseurId', isEqualTo: fournisseurId)
        .limit(1)
        .get();
    return r.docs.isNotEmpty;
  }

  /// Stream scopé selon le rôle :
  /// - `scope == null` → super-admin, tous les fournisseurs
  /// - `scope` non vide → admin/vendeur, ceux de sa boutique
  /// - `scope` vide → liste vide
  Stream<List<FournisseurModel>> watchScoped(String? scope) {
    if (scope == null) {
      return _col.orderBy('nom').snapshots().ignorePermissionDenied().map(
            (snap) => snap.docs.map(FournisseurModel.fromFirestore).toList(),
          );
    }
    if (scope.isEmpty) return Stream.value(<FournisseurModel>[]);
    return _col
        .where('boutiqueId', isEqualTo: scope)
        .orderBy('nom')
        .snapshots().ignorePermissionDenied()
        .map((snap) => snap.docs.map(FournisseurModel.fromFirestore).toList());
  }

  Future<FournisseurModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return FournisseurModel.fromFirestore(snap);
  }

  /// Stream live d'un fournisseur unique (utile pour la fiche détail :
  /// le solde se met à jour automatiquement après un appro / règlement).
  Stream<FournisseurModel?> watchById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col
        .doc(id)
        .snapshots().ignorePermissionDenied()
        .map((s) => s.exists ? FournisseurModel.fromFirestore(s) : null);
  }

  Future<String> create(FournisseurModel fournisseur) async {
    final data = fournisseur.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(FournisseurModel fournisseur) {
    return _col.doc(fournisseur.id).update(fournisseur.toMap());
  }

  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
