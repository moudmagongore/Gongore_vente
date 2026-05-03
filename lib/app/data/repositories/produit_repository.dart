import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/produit_model.dart';

class ProduitRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.produits;
  CollectionReference<Map<String, dynamic>> get _mouvements =>
      _fs.mouvementsStock;
  CollectionReference<Map<String, dynamic>> get _stocks => _fs.stocks;

  /// Renvoie true si le produit a déjà été **vendu** au moins une fois.
  /// Les mouvements de stock initial (entrée, ajustement) ne comptent pas :
  /// un produit créé puis jamais vendu reste supprimable, et la cascade
  /// nettoie son stock résiduel ([delete]).
  ///
  /// Le filtre `boutiqueId` est obligatoire pour aligner la query sur les
  /// rules Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
  /// sinon la query est refusée d'office (PERMISSION_DENIED).
  Future<bool> hasUsage(String produitId, {required String boutiqueId}) async {
    if (produitId.isEmpty || boutiqueId.isEmpty) return false;
    final m = await _mouvements
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('produitId', isEqualTo: produitId)
        .where('type', isEqualTo: 'vente')
        .limit(1)
        .get();
    return m.docs.isNotEmpty;
  }

  /// Stream temps réel des produits, filtrable par boutique et catégorie.
  Stream<List<ProduitModel>> watchAll({
    String? boutiqueId,
    String? categorieId,
    bool onlyActive = false,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (boutiqueId != null && boutiqueId.isNotEmpty) {
      query = query.where('boutiqueId', isEqualTo: boutiqueId);
    }
    if (categorieId != null && categorieId.isNotEmpty) {
      query = query.where('categorieId', isEqualTo: categorieId);
    }
    if (onlyActive) {
      query = query.where('active', isEqualTo: true);
    }
    query = query.orderBy('nom');
    return query.snapshots().map(
          (snap) => snap.docs.map(ProduitModel.fromFirestore).toList(),
        );
  }

  Future<ProduitModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ProduitModel.fromFirestore(snap);
  }

  Future<ProduitModel?> findByCodeBarre(String codeBarre, String boutiqueId) async {
    final snap = await _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('codeBarre', isEqualTo: codeBarre)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ProduitModel.fromFirestore(snap.docs.first);
  }

  Future<String> create(ProduitModel produit) async {
    final data = produit.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(ProduitModel produit) {
    return _col.doc(produit.id).update(produit.toMap());
  }

  Future<void> setActive(String id, bool active) {
    return _col.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime le produit et **nettoie en cascade** ses stocks orphelins.
  /// À n'appeler qu'après [hasUsage] négatif (sinon vous perdez la traçabilité
  /// des ventes).
  ///
  /// Le filtre `boutiqueId` est obligatoire pour aligner la query stocks sur
  /// les rules Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
  /// sinon la query est refusée d'office (PERMISSION_DENIED).
  Future<void> delete(String id, {required String boutiqueId}) async {
    if (id.isEmpty || boutiqueId.isEmpty) return;
    final stockSnap = await _stocks
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('produitId', isEqualTo: id)
        .get();
    final batch = _fs.db.batch();
    for (final doc in stockSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_col.doc(id));
    await batch.commit();
  }
}
