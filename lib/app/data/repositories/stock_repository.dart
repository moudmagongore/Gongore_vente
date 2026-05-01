import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/mouvement_stock_model.dart';
import '../models/stock_model.dart';

class StockRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _stocks => _fs.stocks;
  CollectionReference<Map<String, dynamic>> get _mouvements =>
      _fs.mouvementsStock;

  // ========== Lecture ==========

  Stream<List<StockModel>> watchByBoutique(String boutiqueId) {
    return _stocks
        .where('boutiqueId', isEqualTo: boutiqueId)
        .snapshots()
        .map((snap) => snap.docs.map(StockModel.fromFirestore).toList());
  }

  /// Tous les stocks (toutes boutiques confondues). Réservé super-admin.
  Stream<List<StockModel>> watchAll() {
    return _stocks
        .snapshots()
        .map((snap) => snap.docs.map(StockModel.fromFirestore).toList());
  }

  /// Variante scopée :
  /// - `boutiqueId == null` → toutes les boutiques (super-admin)
  /// - sinon → boutique unique
  Stream<List<StockModel>> watchScoped(String? boutiqueId) {
    if (boutiqueId == null) return watchAll();
    if (boutiqueId.isEmpty) return Stream.value(<StockModel>[]);
    return watchByBoutique(boutiqueId);
  }

  Stream<StockModel?> watchOne(String boutiqueId, String produitId) {
    return _stocks
        .doc(StockModel.buildId(boutiqueId, produitId))
        .snapshots()
        .map((snap) => snap.exists ? StockModel.fromFirestore(snap) : null);
  }

  Future<StockModel?> getOne(String boutiqueId, String produitId) async {
    final snap = await _stocks
        .doc(StockModel.buildId(boutiqueId, produitId))
        .get();
    return snap.exists ? StockModel.fromFirestore(snap) : null;
  }

  Stream<List<MouvementStockModel>> watchMouvements({
    String? boutiqueId,
    String? produitId,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _mouvements;
    if (boutiqueId != null) {
      query = query.where('boutiqueId', isEqualTo: boutiqueId);
    }
    if (produitId != null) {
      query = query.where('produitId', isEqualTo: produitId);
    }
    query = query.orderBy('date', descending: true).limit(limit);
    return query
        .snapshots()
        .map((s) => s.docs.map(MouvementStockModel.fromFirestore).toList());
  }

  // ========== Écriture (transactions atomiques) ==========

  /// Entrée de stock : ajoute [quantite] au produit dans la boutique.
  /// Crée le doc stock s'il n'existe pas. Crée un mouvement type=entree.
  Future<void> entree({
    required String boutiqueId,
    required String produitId,
    required int quantite,
    required String userId,
    String? motif,
  }) async {
    if (quantite <= 0) {
      throw ArgumentError('La quantité doit être > 0');
    }
    await _fs.db.runTransaction((tx) async {
      final stockRef = _stocks.doc(StockModel.buildId(boutiqueId, produitId));
      final snap = await tx.get(stockRef);

      final current = snap.exists ? (snap.data()!['quantite'] as num).toInt() : 0;
      final next = current + quantite;

      if (snap.exists) {
        tx.update(stockRef, {
          'quantite': next,
          'derniereModif': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(stockRef, {
          'boutiqueId': boutiqueId,
          'produitId': produitId,
          'quantite': next,
          'derniereModif': FieldValue.serverTimestamp(),
        });
      }

      tx.set(_mouvements.doc(), {
        'produitId': produitId,
        'boutiqueId': boutiqueId,
        'type': MouvementType.entree.name,
        'quantite': quantite,
        'date': FieldValue.serverTimestamp(),
        'userId': userId,
        'motif': motif,
      });
    });
  }

  /// Sortie de stock (perte, casse, sortie manuelle).
  Future<void> sortie({
    required String boutiqueId,
    required String produitId,
    required int quantite,
    required MouvementType type,
    required String userId,
    String? motif,
  }) async {
    if (quantite <= 0) {
      throw ArgumentError('La quantité doit être > 0');
    }
    if (![
      MouvementType.sortie,
      MouvementType.perte,
      MouvementType.casse,
    ].contains(type)) {
      throw ArgumentError('Type invalide pour une sortie');
    }

    await _fs.db.runTransaction((tx) async {
      final stockRef = _stocks.doc(StockModel.buildId(boutiqueId, produitId));
      final snap = await tx.get(stockRef);

      final current = snap.exists ? (snap.data()!['quantite'] as num).toInt() : 0;
      if (current < quantite) {
        throw StockInsuffisantException(
          'Stock insuffisant : disponible $current, demandé $quantite',
        );
      }
      final next = current - quantite;

      tx.update(stockRef, {
        'quantite': next,
        'derniereModif': FieldValue.serverTimestamp(),
      });

      tx.set(_mouvements.doc(), {
        'produitId': produitId,
        'boutiqueId': boutiqueId,
        'type': type.name,
        'quantite': quantite,
        'date': FieldValue.serverTimestamp(),
        'userId': userId,
        'motif': motif,
      });
    });
  }

  /// Transfert atomique entre 2 boutiques.
  /// Décrémente la source, incrémente la destination, crée 2 mouvements.
  Future<void> transfert({
    required String produitId,
    required String boutiqueSourceId,
    required String boutiqueDestinationId,
    required int quantite,
    required String userId,
    String? motif,
  }) async {
    if (quantite <= 0) {
      throw ArgumentError('La quantité doit être > 0');
    }
    if (boutiqueSourceId == boutiqueDestinationId) {
      throw ArgumentError('Source et destination doivent être différentes');
    }

    await _fs.db.runTransaction((tx) async {
      final srcRef = _stocks.doc(
        StockModel.buildId(boutiqueSourceId, produitId),
      );
      final dstRef = _stocks.doc(
        StockModel.buildId(boutiqueDestinationId, produitId),
      );

      final srcSnap = await tx.get(srcRef);
      final dstSnap = await tx.get(dstRef);

      final srcQty =
          srcSnap.exists ? (srcSnap.data()!['quantite'] as num).toInt() : 0;
      if (srcQty < quantite) {
        throw StockInsuffisantException(
          'Stock source insuffisant : disponible $srcQty, demandé $quantite',
        );
      }
      final dstQty =
          dstSnap.exists ? (dstSnap.data()!['quantite'] as num).toInt() : 0;

      tx.update(srcRef, {
        'quantite': srcQty - quantite,
        'derniereModif': FieldValue.serverTimestamp(),
      });

      if (dstSnap.exists) {
        tx.update(dstRef, {
          'quantite': dstQty + quantite,
          'derniereModif': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(dstRef, {
          'boutiqueId': boutiqueDestinationId,
          'produitId': produitId,
          'quantite': dstQty + quantite,
          'derniereModif': FieldValue.serverTimestamp(),
        });
      }

      // Mouvement source (sortie transfert)
      tx.set(_mouvements.doc(), {
        'produitId': produitId,
        'boutiqueId': boutiqueSourceId,
        'type': MouvementType.transfert.name,
        'quantite': -quantite,
        'date': FieldValue.serverTimestamp(),
        'userId': userId,
        'motif': motif,
        'boutiqueDestinationId': boutiqueDestinationId,
      });
      // Mouvement destination (entrée transfert)
      tx.set(_mouvements.doc(), {
        'produitId': produitId,
        'boutiqueId': boutiqueDestinationId,
        'type': MouvementType.transfert.name,
        'quantite': quantite,
        'date': FieldValue.serverTimestamp(),
        'userId': userId,
        'motif': motif,
        'boutiqueDestinationId': boutiqueSourceId,
      });
    });
  }

  /// Ajustement d'inventaire : force la quantité à [nouvelleQuantite].
  /// Trace l'écart dans l'historique.
  Future<void> ajustement({
    required String boutiqueId,
    required String produitId,
    required int nouvelleQuantite,
    required String userId,
    required String motif,
  }) async {
    if (nouvelleQuantite < 0) {
      throw ArgumentError('Quantité négative interdite');
    }
    await _fs.db.runTransaction((tx) async {
      final stockRef = _stocks.doc(StockModel.buildId(boutiqueId, produitId));
      final snap = await tx.get(stockRef);
      final current = snap.exists
          ? (snap.data()!['quantite'] as num).toInt()
          : 0;
      final ecart = nouvelleQuantite - current;

      if (snap.exists) {
        tx.update(stockRef, {
          'quantite': nouvelleQuantite,
          'derniereModif': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(stockRef, {
          'boutiqueId': boutiqueId,
          'produitId': produitId,
          'quantite': nouvelleQuantite,
          'derniereModif': FieldValue.serverTimestamp(),
        });
      }

      tx.set(_mouvements.doc(), {
        'produitId': produitId,
        'boutiqueId': boutiqueId,
        'type': MouvementType.ajustement.name,
        'quantite': ecart, // peut être négatif
        'date': FieldValue.serverTimestamp(),
        'userId': userId,
        'motif': motif,
      });
    });
  }
}

class StockInsuffisantException implements Exception {
  final String message;
  StockInsuffisantException(this.message);
  @override
  String toString() => message;
}
