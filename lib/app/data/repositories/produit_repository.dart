import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/produit_model.dart';

class ProduitRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.produits;
  CollectionReference<Map<String, dynamic>> get _ventes => _fs.ventes;

  /// Renvoie true si le produit a déjà été **vendu** au moins une fois.
  /// Source de vérité : la collection `ventes`. Chaque vente écrit son
  /// tableau dénormalisé `articleProduitIds`, ce qui rend cette query
  /// `array-contains` efficace et sans pagination.
  ///
  /// Le filtre `boutiqueId` est obligatoire pour aligner la query sur les
  /// rules Firestore (`resource.data.boutiqueId == userBoutiqueId()`),
  /// sinon la query est refusée d'office (PERMISSION_DENIED).
  Future<bool> hasUsage(String produitId, {required String boutiqueId}) async {
    if (produitId.isEmpty || boutiqueId.isEmpty) return false;
    final v = await _ventes
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('articleProduitIds', arrayContains: produitId)
        .limit(1)
        .get();
    return v.docs.isNotEmpty;
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

  /// Suppression simple : à n'appeler qu'après [hasUsage] négatif (sinon
  /// vous perdez la traçabilité des ventes — bien que les lignes de vente
  /// stockent un snapshot du nom et du prix).
  Future<void> delete(String id) {
    if (id.isEmpty) return Future.value();
    return _col.doc(id).delete();
  }
}
