import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/mouvement_stock_model.dart';
import '../models/stock_model.dart';
import '../models/vente_model.dart';
import 'stock_repository.dart' show StockInsuffisantException;

class VenteRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _ventes => _fs.ventes;
  CollectionReference<Map<String, dynamic>> get _stocks => _fs.stocks;
  CollectionReference<Map<String, dynamic>> get _mouvements =>
      _fs.mouvementsStock;

  // ========== Lecture ==========

  Stream<List<VenteModel>> watchAll({
    String? boutiqueId,
    String? vendeurId,
    DateTime? after,
    DateTime? before,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> query = _ventes;
    if (boutiqueId != null && boutiqueId.isNotEmpty) {
      query = query.where('boutiqueId', isEqualTo: boutiqueId);
    }
    if (vendeurId != null && vendeurId.isNotEmpty) {
      query = query.where('vendeurId', isEqualTo: vendeurId);
    }
    if (after != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    if (before != null) {
      query = query.where('date', isLessThan: Timestamp.fromDate(before));
    }
    query = query.orderBy('date', descending: true).limit(limit);
    return query
        .snapshots()
        .map((s) => s.docs.map(VenteModel.fromFirestore).toList());
  }

  Future<VenteModel?> getById(String id) async {
    final snap = await _ventes.doc(id).get();
    if (!snap.exists) return null;
    return VenteModel.fromFirestore(snap);
  }

  Stream<VenteModel?> watchOne(String id) {
    return _ventes
        .doc(id)
        .snapshots()
        .map((s) => s.exists ? VenteModel.fromFirestore(s) : null);
  }

  // ========== Écriture (transactions atomiques) ==========

  /// Valide une vente :
  /// 1. Vérifie le stock disponible pour CHAQUE article (si insuffisant → throw, rien n'est fait)
  /// 2. Décrémente le stock de chaque produit
  /// 3. Crée le document vente
  /// 4. Crée un mouvement de stock par article (type=vente)
  ///
  /// Tout est atomique : en cas d'erreur, AUCUNE écriture n'est appliquée.
  Future<String> create(VenteModel vente) async {
    if (vente.articles.isEmpty) {
      throw ArgumentError('Vente sans article impossible');
    }

    return _fs.db.runTransaction<String>((tx) async {
      // ===== Étape 1 : tous les reads d'abord (contrainte Firestore) =====
      final stockReads = <String, _StockReadResult>{};
      for (final article in vente.articles) {
        final stockId = StockModel.buildId(vente.boutiqueId, article.produitId);
        if (stockReads.containsKey(stockId)) continue; // déjà lu

        final ref = _stocks.doc(stockId);
        final snap = await tx.get(ref);
        final current =
            snap.exists ? (snap.data()!['quantite'] as num).toInt() : 0;

        stockReads[stockId] = _StockReadResult(
          ref: ref,
          existing: snap.exists,
          current: current,
        );
      }

      // ===== Étape 2 : agrégation des quantités demandées par produit =====
      // (au cas où le panier contient plusieurs lignes pour le même produit)
      final demandes = <String, int>{};
      for (final article in vente.articles) {
        final key = StockModel.buildId(vente.boutiqueId, article.produitId);
        demandes[key] = (demandes[key] ?? 0) + article.quantite;
      }

      // ===== Étape 3 : vérification des disponibilités =====
      for (final entry in demandes.entries) {
        final read = stockReads[entry.key]!;
        if (read.current < entry.value) {
          // On retrouve le nom du produit pour un message clair
          final article = vente.articles.firstWhere(
            (a) =>
                StockModel.buildId(vente.boutiqueId, a.produitId) == entry.key,
          );
          throw StockInsuffisantException(
            'Stock insuffisant pour « ${article.nom} » '
            '(disponible ${read.current}, demandé ${entry.value})',
          );
        }
      }

      // ===== Étape 4 : tous les writes =====
      // 4a. Mise à jour des stocks
      for (final entry in demandes.entries) {
        final read = stockReads[entry.key]!;
        final next = read.current - entry.value;
        if (read.existing) {
          tx.update(read.ref, {
            'quantite': next,
            'derniereModif': FieldValue.serverTimestamp(),
          });
        } else {
          // Cas limite : pas de doc stock, on en crée un avec quantite=0 - demandé
          // (ne devrait pas arriver car on vérifie current >= demandé au-dessus)
          final parts = entry.key.split('_');
          tx.set(read.ref, {
            'boutiqueId': parts.first,
            'produitId': parts.skip(1).join('_'),
            'quantite': next,
            'derniereModif': FieldValue.serverTimestamp(),
          });
        }
      }

      // 4b. Création du document vente
      final venteRef = _ventes.doc();
      tx.set(venteRef, vente.toMap());

      // 4c. Création d'un mouvement par ligne (pour traçabilité par article)
      for (final article in vente.articles) {
        tx.set(_mouvements.doc(), {
          'produitId': article.produitId,
          'boutiqueId': vente.boutiqueId,
          'type': MouvementType.vente.name,
          'quantite': article.quantite,
          'date': FieldValue.serverTimestamp(),
          'userId': vente.vendeurId,
          'venteId': venteRef.id,
        });
      }

      return venteRef.id;
    });
  }

  /// Annule une vente :
  /// 1. Marque la vente comme `annulee` avec un motif
  /// 2. Restitue le stock pour chaque article
  /// 3. Crée un mouvement type=entree avec lien vers la vente annulée
  ///
  /// Atomique. Si la vente est déjà annulée, lève une exception.
  Future<void> cancel({
    required String venteId,
    required String userId,
    required String motif,
  }) async {
    await _fs.db.runTransaction((tx) async {
      final venteRef = _ventes.doc(venteId);
      final venteSnap = await tx.get(venteRef);
      if (!venteSnap.exists) {
        throw Exception('Vente introuvable');
      }
      final vente = VenteModel.fromFirestore(venteSnap);
      if (vente.statut == VenteStatut.annulee) {
        throw Exception('Vente déjà annulée');
      }

      // Lire tous les stocks concernés
      final stockReads = <String, _StockReadResult>{};
      for (final article in vente.articles) {
        final stockId = StockModel.buildId(vente.boutiqueId, article.produitId);
        if (stockReads.containsKey(stockId)) continue;
        final ref = _stocks.doc(stockId);
        final snap = await tx.get(ref);
        final current =
            snap.exists ? (snap.data()!['quantite'] as num).toInt() : 0;
        stockReads[stockId] = _StockReadResult(
          ref: ref,
          existing: snap.exists,
          current: current,
        );
      }

      // Restituer (somme par produit)
      final restitutions = <String, int>{};
      for (final article in vente.articles) {
        final key = StockModel.buildId(vente.boutiqueId, article.produitId);
        restitutions[key] = (restitutions[key] ?? 0) + article.quantite;
      }

      for (final entry in restitutions.entries) {
        final read = stockReads[entry.key]!;
        final next = read.current + entry.value;
        if (read.existing) {
          tx.update(read.ref, {
            'quantite': next,
            'derniereModif': FieldValue.serverTimestamp(),
          });
        } else {
          final parts = entry.key.split('_');
          tx.set(read.ref, {
            'boutiqueId': parts.first,
            'produitId': parts.skip(1).join('_'),
            'quantite': next,
            'derniereModif': FieldValue.serverTimestamp(),
          });
        }
      }

      // Marquer la vente comme annulée
      tx.update(venteRef, {
        'statut': VenteStatut.annulee.name,
        'motifAnnulation': motif,
      });

      // Créer un mouvement d'entrée par article (traçabilité)
      for (final article in vente.articles) {
        tx.set(_mouvements.doc(), {
          'produitId': article.produitId,
          'boutiqueId': vente.boutiqueId,
          'type': MouvementType.entree.name,
          'quantite': article.quantite,
          'date': FieldValue.serverTimestamp(),
          'userId': userId,
          'motif': 'Annulation vente : $motif',
          'venteId': venteId,
        });
      }
    });
  }
}

class _StockReadResult {
  final DocumentReference<Map<String, dynamic>> ref;
  final bool existing;
  final int current;
  _StockReadResult({
    required this.ref,
    required this.existing,
    required this.current,
  });
}
