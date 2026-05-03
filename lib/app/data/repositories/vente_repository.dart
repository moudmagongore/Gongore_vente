import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../models/vente_model.dart';

class VenteRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _ventes => _fs.ventes;
  CollectionReference<Map<String, dynamic>> get _clients => _fs.clients;

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
  /// 1. Génère atomiquement un numéro séquentiel `V-AAAA-NNNNN`
  /// 2. Crée le document vente
  /// 3. Si client lié et delta non nul : ajuste son solde
  ///
  /// Tout est atomique. Pas de gestion de stock (à réintroduire plus tard
  /// quand le module stock reviendra).
  Future<String> create(VenteModel vente) async {
    if (vente.articles.isEmpty) {
      throw ArgumentError('Vente sans article impossible');
    }

    return _fs.db.runTransaction<String>((tx) async {
      // Compteur séquentiel pour le numéro de vente
      final counterRef = _fs.counters.doc(vente.boutiqueId);
      final counterSnap = await tx.get(counterRef);
      final year = vente.date.year;
      final field = 'ventes$year';
      final currentCount = counterSnap.exists
          ? ((counterSnap.data() ?? {})[field] as num?)?.toInt() ?? 0
          : 0;
      final nextCount = currentCount + 1;
      final venteNumero =
          'V-$year-${nextCount.toString().padLeft(5, '0')}';

      // Création du document vente avec numéro séquentiel injecté
      final venteRef = _ventes.doc();
      tx.set(venteRef, {
        ...vente.toMap(),
        'numero': venteNumero,
      });

      // Persiste le compteur (création ou update)
      if (counterSnap.exists) {
        tx.update(counterRef, {field: nextCount});
      } else {
        tx.set(counterRef, {field: nextCount});
      }

      // Si client lié → ajuste son solde et flagge `hasOperations: true`
      // (utilisé par les rules Firestore pour bloquer la suppression d'un
      // client avec historique). On flagge pour TOUTE vente liée à un
      // client identifié, même si delta == 0 (paiement intégral cash).
      //
      // Delta = total - montantPaye, couvre 2 effets en un :
      //   • +reste à payer (nouvelle dette) si non intégralement couvert
      //   • +avance utilisée (consomme l'avance, ramène le solde négatif
      //     vers 0)
      // Comme: delta = (total - montantPaye - avanceUtilisee) + avanceUtilisee
      //              = total - montantPaye
      final delta = vente.total - vente.montantPaye;
      if (vente.clientId != null && vente.clientId!.isNotEmpty) {
        tx.update(_clients.doc(vente.clientId), {
          if (delta != 0) 'solde': FieldValue.increment(delta),
          'hasOperations': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return venteRef.id;
    });
  }

  /// Annule une vente :
  /// 1. Marque la vente comme `annulee` avec un motif
  /// 2. Inverse l'effet sur le solde du client (s'il y en a un)
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

      // Marquer la vente comme annulée
      tx.update(venteRef, {
        'statut': VenteStatut.annulee.name,
        'motifAnnulation': motif,
      });

      // Annule l'effet net de la vente sur le solde du client.
      //   • Retire la dette restante (reste à payer)
      //   • Restitue l'avance qui avait été consommée
      //   = solde -= (resteAPayer + avanceUtilisee)
      //   = solde -= (total - montantPaye)
      // Cette formule donne le bon résultat même si des règlements ont
      // imputé sur la vente entre-temps (montantPaye a été augmenté).
      final delta = vente.total - vente.montantPaye;
      if (vente.clientId != null &&
          vente.clientId!.isNotEmpty &&
          delta != 0) {
        tx.update(_clients.doc(vente.clientId), {
          'solde': FieldValue.increment(-delta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
