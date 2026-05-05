import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/mouvement_stock_model.dart';

class MouvementStockRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.mouvementsStock;
  CollectionReference<Map<String, dynamic>> get _produits => _fs.produits;

  /// Stream historique des mouvements scopés à une boutique.
  Stream<List<MouvementStockModel>> watchByBoutique(
    String boutiqueId, {
    DateTime? after,
    int limit = 200,
  }) {
    if (boutiqueId.isEmpty) {
      return Stream.value(<MouvementStockModel>[]);
    }
    Query<Map<String, dynamic>> q =
        _col.where('boutiqueId', isEqualTo: boutiqueId);
    if (after != null) {
      q = q.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    q = q.orderBy('date', descending: true).limit(limit);
    return q.snapshots().ignorePermissionDenied().map(
          (s) => s.docs.map(MouvementStockModel.fromFirestore).toList(),
        );
  }

  /// Stream des mouvements liés à un produit donné (pour la fiche
  /// produit ou la time-line). Filtre `boutiqueId` requis pour aligner
  /// sur les rules.
  Stream<List<MouvementStockModel>> watchByProduit(
    String produitId, {
    required String boutiqueId,
    int limit = 100,
  }) {
    if (produitId.isEmpty || boutiqueId.isEmpty) {
      return Stream.value(<MouvementStockModel>[]);
    }
    return _col
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('produitId', isEqualTo: produitId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots().ignorePermissionDenied()
        .map((s) => s.docs.map(MouvementStockModel.fromFirestore).toList());
  }

  /// Crée un mouvement manuel et met à jour le stock du produit
  /// **atomiquement** :
  /// - `entree` / `sortie` / `perte` / `casse` : `quantite` est le nombre
  ///   d'unités, le delta est appliqué selon le signe du type.
  /// - `ajustement` : `quantite` est la valeur cible absolue ; le delta
  ///   est calculé pour atteindre cette quantité.
  ///
  /// Le PA (CMUP) du produit n'est PAS modifié — un mouvement manuel
  /// ne change pas le coût d'acquisition. Pour rentrer du stock à un
  /// PA différent, passer par un approvisionnement.
  ///
  /// Lève si :
  /// - le produit est introuvable
  /// - une `sortie`/`perte`/`casse` ferait passer le stock en négatif
  Future<MouvementStockModel> create({
    required String produitId,
    required String boutiqueId,
    required String userId,
    required MouvementStockType type,
    required int quantite,
    String? motif,
    String? varianteId,
    String? varianteLibelle,
  }) async {
    if (produitId.isEmpty || boutiqueId.isEmpty) {
      throw ArgumentError('produitId et boutiqueId requis');
    }
    if (quantite < 0) {
      throw ArgumentError('Quantité invalide');
    }

    return _fs.db.runTransaction<MouvementStockModel>((tx) async {
      final produitRef = _produits.doc(produitId);
      final produitSnap = await tx.get(produitRef);
      if (!produitSnap.exists) {
        throw Exception('Produit introuvable');
      }

      final data = produitSnap.data() ?? {};
      final hasVar = (data['hasVariantes'] ?? false) as bool;
      final nom = (data['nom'] ?? '?') as String;

      // Si le produit a des variantes, le mouvement DOIT cibler une
      // variante (sinon le stock total et la somme des variantes
      // divergeraient). Si le produit est simple, refuser un varianteId.
      if (hasVar &&
          (varianteId == null || varianteId.isEmpty)) {
        throw Exception(
          '« $nom » a des variantes : sélectionnez celle à ajuster.',
        );
      }
      if (!hasVar && varianteId != null && varianteId.isNotEmpty) {
        throw Exception(
          '« $nom » n\'a pas de variantes : aucune variante à cibler.',
        );
      }

      // Stock avant (variante si présente, sinon total).
      final int qteAvant;
      DocumentSnapshot<Map<String, dynamic>>? varianteSnap;
      if (varianteId != null && varianteId.isNotEmpty) {
        varianteSnap =
            await tx.get(_fs.variantesOf(produitId).doc(varianteId));
        if (!varianteSnap.exists) {
          throw Exception('Variante introuvable.');
        }
        qteAvant =
            ((varianteSnap.data() ?? {})['stock'] as num?)?.toInt() ?? 0;
      } else {
        qteAvant = (data['quantiteStock'] as num?)?.toInt() ?? 0;
      }

      // Libellé d'erreur plus parlant ("Veste — 40").
      final nomAffiche =
          varianteLibelle == null || varianteLibelle.isEmpty
              ? nom
              : '$nom — $varianteLibelle';

      // Calcul de la quantité après mouvement
      final int qteApres;
      switch (type) {
        case MouvementStockType.entree:
          qteApres = qteAvant + quantite;
          break;
        case MouvementStockType.sortie:
        case MouvementStockType.perte:
        case MouvementStockType.casse:
          if (qteAvant < quantite) {
            throw Exception(
              'Stock insuffisant pour « $nomAffiche » '
              '(actuel $qteAvant, à retirer $quantite).',
            );
          }
          qteApres = qteAvant - quantite;
          break;
        case MouvementStockType.ajustement:
          // quantite = valeur cible
          qteApres = quantite;
          break;
      }

      // Création du document mouvement
      final ref = _col.doc();
      final mouv = MouvementStockModel(
        id: ref.id,
        produitId: produitId,
        produitNom: nom,
        varianteId: varianteId,
        varianteLibelle: varianteLibelle,
        boutiqueId: boutiqueId,
        userId: userId,
        type: type,
        quantite: quantite,
        qteAvant: qteAvant,
        qteApres: qteApres,
        motif: motif,
        date: DateTime.now(),
      );
      tx.set(ref, mouv.toMap());

      // Mise à jour atomique. Si variante : on touche LA variante ET on
      // décale le total produit du même delta pour rester cohérent.
      if (varianteSnap != null) {
        final delta = qteApres - qteAvant;
        tx.update(varianteSnap.reference, {
          'stock': qteApres,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(produitRef, {
          'quantiteStock': FieldValue.increment(delta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(produitRef, {
          'quantiteStock': qteApres,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return mouv;
    });
  }
}
