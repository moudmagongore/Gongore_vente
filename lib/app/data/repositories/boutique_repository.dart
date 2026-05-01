import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/boutique_model.dart';

/// Couche d'accès aux boutiques.
class BoutiqueRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.boutiques;

  /// Stream temps réel de toutes les boutiques (triées par nom).
  Stream<List<BoutiqueModel>> watchAll({bool? actives}) {
    Query<Map<String, dynamic>> query = _col.orderBy('nom');
    if (actives != null) {
      query = query.where('active', isEqualTo: actives);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map(BoutiqueModel.fromFirestore).toList(),
        );
  }

  /// Stream scopé selon le rôle de l'utilisateur :
  /// - `scope == null` → super-admin, toutes les boutiques
  /// - `scope` non vide → admin/vendeur, uniquement la sienne
  /// - `scope` vide → liste vide (pas de boutique assignée)
  Stream<List<BoutiqueModel>> watchScoped({
    required String? scope,
    bool? actives,
  }) {
    if (scope == null) {
      return watchAll(actives: actives);
    }
    if (scope.isEmpty) {
      return Stream.value(<BoutiqueModel>[]);
    }
    return _col.doc(scope).snapshots().map((snap) {
      if (!snap.exists) return <BoutiqueModel>[];
      final b = BoutiqueModel.fromFirestore(snap);
      if (actives == true && !b.active) return <BoutiqueModel>[];
      return [b];
    });
  }

  Future<List<BoutiqueModel>> fetchAll({bool? actives}) async {
    Query<Map<String, dynamic>> query = _col.orderBy('nom');
    if (actives != null) {
      query = query.where('active', isEqualTo: actives);
    }
    final snap = await query.get();
    return snap.docs.map(BoutiqueModel.fromFirestore).toList();
  }

  Future<BoutiqueModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return BoutiqueModel.fromFirestore(snap);
  }

  /// Crée une nouvelle boutique. Renvoie l'ID Firestore généré.
  Future<String> create(BoutiqueModel boutique) async {
    final data = boutique.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(data);
    return ref.id;
  }

  Future<void> update(BoutiqueModel boutique) {
    return _col.doc(boutique.id).update(boutique.toMap());
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

  /// Suppression EN CASCADE de la boutique :
  /// supprime tous les users, produits, catégories, stocks, mouvements,
  /// ventes et clients liés à la boutique, puis la boutique elle-même.
  ///
  /// ⚠️ DANGEREUX, irréversible. Ne supprime PAS les comptes Firebase Auth
  /// des utilisateurs (limitation sans Cloud Functions).
  ///
  /// Réservé au super-admin (vérification dans le controller).
  Future<({int users, int produits, int categories, int stocks, int mouvements, int ventes, int clients})> deleteCascade(
      String boutiqueId) async {
    int users = 0, produits = 0, categories = 0;
    int stocks = 0, mouvements = 0, ventes = 0, clients = 0;

    Future<int> deleteWhere(
      CollectionReference<Map<String, dynamic>> col,
      String fieldName,
    ) async {
      int count = 0;
      const pageSize = 400;
      while (true) {
        final snap = await col
            .where(fieldName, isEqualTo: boutiqueId)
            .limit(pageSize)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = _fs.db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        count += snap.docs.length;
        if (snap.docs.length < pageSize) break;
      }
      return count;
    }

    users = await deleteWhere(_fs.users, 'boutiqueId');
    produits = await deleteWhere(_fs.produits, 'boutiqueId');
    categories = await deleteWhere(_fs.categories, 'boutiqueId');
    stocks = await deleteWhere(_fs.stocks, 'boutiqueId');
    mouvements = await deleteWhere(_fs.mouvementsStock, 'boutiqueId');
    ventes = await deleteWhere(_fs.ventes, 'boutiqueId');
    clients = await deleteWhere(_fs.clients, 'boutiqueId');

    await _col.doc(boutiqueId).delete();

    return (
      users: users,
      produits: produits,
      categories: categories,
      stocks: stocks,
      mouvements: mouvements,
      ventes: ventes,
      clients: clients,
    );
  }
}
