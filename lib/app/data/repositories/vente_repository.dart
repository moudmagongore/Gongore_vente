import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/vente_model.dart';

/// Levée par [VenteRepository.create] quand le stock est insuffisant pour
/// une ou plusieurs lignes. Le `message` contient un libellé prêt à
/// afficher à l'utilisateur (avec nom du produit + qté dispo / demandée).
class StockInsuffisantException implements Exception {
  final String message;
  StockInsuffisantException(this.message);
  @override
  String toString() => message;
}

class VenteRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _ventes => _fs.ventes;
  CollectionReference<Map<String, dynamic>> get _clients => _fs.clients;
  CollectionReference<Map<String, dynamic>> get _produits => _fs.produits;

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
        .snapshots().ignorePermissionDenied()
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
        .snapshots().ignorePermissionDenied()
        .map((s) => s.exists ? VenteModel.fromFirestore(s) : null);
  }

  // ========== Écriture (transactions atomiques) ==========

  /// Valide une vente :
  /// 1. **Vérifie le stock disponible** pour chaque produit (lève
  ///    [StockInsuffisantException] si insuffisant — rien n'est écrit).
  /// 2. Génère atomiquement un numéro séquentiel `V-AAAA-NNNNN`
  /// 3. Décrémente `quantiteStock` de chaque produit
  /// 4. Crée le document vente
  /// 5. Si client lié : ajuste son solde + flagge `hasOperations: true`
  ///
  /// Tout est atomique.
  Future<String> create(VenteModel vente) async {
    if (vente.articles.isEmpty) {
      throw ArgumentError('Vente sans article impossible');
    }

    return _fs.db.runTransaction<String>((tx) async {
      // ===== Étape 1 : tous les reads d'abord =====

      // Agrège les qtés par produit (total) et par (produit, variante).
      final qteParProduit = <String, int>{};
      final qteParVariante = <String, Map<String, int>>{}; // pid -> {vid: qte}
      for (final a in vente.articles) {
        qteParProduit[a.produitId] =
            (qteParProduit[a.produitId] ?? 0) + a.quantite;
        if (a.varianteId != null && a.varianteId!.isNotEmpty) {
          final byV = qteParVariante.putIfAbsent(
            a.produitId,
            () => <String, int>{},
          );
          byV[a.varianteId!] = (byV[a.varianteId!] ?? 0) + a.quantite;
        }
      }

      final produitSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final pid in qteParProduit.keys) {
        produitSnaps[pid] = await tx.get(_produits.doc(pid));
      }

      // Reads variantes
      final varianteSnaps = <String,
          Map<String, DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final entry in qteParVariante.entries) {
        final pid = entry.key;
        final byV = entry.value;
        final m = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final vid in byV.keys) {
          m[vid] = await tx.get(_fs.variantesOf(pid).doc(vid));
        }
        varianteSnaps[pid] = m;
      }

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

      // ===== Étape 1b : vérification du stock =====
      // Pour les produits SANS variantes : check sur quantiteStock total.
      // Pour les produits AVEC variantes : check par variante (le total est
      // déjà la somme des variantes, donc pas besoin de double check).
      qteParProduit.forEach((pid, qteDemandee) {
        final snap = produitSnaps[pid];
        if (snap == null || !snap.exists) return; // produit supprimé : skip
        final data = snap.data() ?? {};
        final hasVar = (data['hasVariantes'] ?? false) as bool;
        final nom = (data['nom'] ?? '?') as String;
        if (hasVar) {
          final byV = qteParVariante[pid] ?? const <String, int>{};
          if (byV.isEmpty) {
            throw StockInsuffisantException(
              '« $nom » nécessite une variante (pointure / taille).',
            );
          }
          byV.forEach((vid, qte) {
            final vsnap = varianteSnaps[pid]?[vid];
            if (vsnap == null || !vsnap.exists) {
              throw StockInsuffisantException(
                'Variante introuvable pour « $nom ».',
              );
            }
            final vstock =
                ((vsnap.data() ?? {})['stock'] as num?)?.toInt() ?? 0;
            if (vstock < qte) {
              final lib =
                  ((vsnap.data() ?? {})['libelle'] ?? '?') as String;
              throw StockInsuffisantException(
                'Stock insuffisant pour « $nom — $lib » : '
                'disponible $vstock, demandé $qte.',
              );
            }
          });
        } else {
          final qteEnStock =
              (data['quantiteStock'] as num?)?.toInt() ?? 0;
          if (qteEnStock < qteDemandee) {
            throw StockInsuffisantException(
              'Stock insuffisant pour « $nom » : '
              'disponible $qteEnStock, demandé $qteDemandee.',
            );
          }
        }
      });

      // ===== Étape 2 : tous les writes =====

      // 2a. Décrémente le stock des produits existants (skip silencieusement
      // ceux supprimés — l'historique de vente reste cohérent grâce au
      // snapshot du nom dans l'article). Pour les produits à variantes,
      // décrémente AUSSI le stock de chaque variante touchée. Le total
      // produit reste la somme des variantes par construction.
      qteParProduit.forEach((pid, qte) {
        final snap = produitSnaps[pid];
        if (snap == null || !snap.exists) return;
        tx.update(snap.reference, {
          'quantiteStock': FieldValue.increment(-qte),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final byV = qteParVariante[pid];
        if (byV != null) {
          byV.forEach((vid, vqte) {
            final vsnap = varianteSnaps[pid]?[vid];
            if (vsnap == null || !vsnap.exists) return;
            tx.update(vsnap.reference, {
              'stock': FieldValue.increment(-vqte),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
        }
      });

      // 2b. Création du document vente avec numéro séquentiel injecté
      final venteRef = _ventes.doc();
      tx.set(venteRef, {
        ...vente.toMap(),
        'numero': venteNumero,
      });

      // 2c. Persiste le compteur
      if (counterSnap.exists) {
        tx.update(counterRef, {field: nextCount});
      } else {
        tx.set(counterRef, {field: nextCount});
      }

      // 2d. Si client lié → ajuste son solde et flagge `hasOperations: true`
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
  /// 2. **Restitue `quantiteStock`** de chaque produit (peut faire passer
  ///    un stock négatif à positif si la vente avait été faite avant son
  ///    appro régularisateur).
  /// 3. Inverse l'effet sur le solde du client (s'il y en a un).
  ///
  /// Atomique. Si la vente est déjà annulée, lève une exception.
  Future<void> cancel({
    required String venteId,
    required String userId,
    required String motif,
  }) async {
    await _fs.db.runTransaction((tx) async {
      // ===== Reads =====
      final venteRef = _ventes.doc(venteId);
      final venteSnap = await tx.get(venteRef);
      if (!venteSnap.exists) {
        throw Exception('Vente introuvable');
      }
      final vente = VenteModel.fromFirestore(venteSnap);
      if (vente.statut == VenteStatut.annulee) {
        throw Exception('Vente déjà annulée');
      }

      final qteParProduit = <String, int>{};
      final qteParVariante = <String, Map<String, int>>{};
      for (final a in vente.articles) {
        qteParProduit[a.produitId] =
            (qteParProduit[a.produitId] ?? 0) + a.quantite;
        if (a.varianteId != null && a.varianteId!.isNotEmpty) {
          final byV = qteParVariante.putIfAbsent(
            a.produitId,
            () => <String, int>{},
          );
          byV[a.varianteId!] = (byV[a.varianteId!] ?? 0) + a.quantite;
        }
      }
      final produitSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final pid in qteParProduit.keys) {
        produitSnaps[pid] = await tx.get(_produits.doc(pid));
      }
      final varianteSnaps = <String,
          Map<String, DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final entry in qteParVariante.entries) {
        final pid = entry.key;
        final m = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final vid in entry.value.keys) {
          m[vid] = await tx.get(_fs.variantesOf(pid).doc(vid));
        }
        varianteSnaps[pid] = m;
      }

      // ===== Writes =====

      // Restitue le stock total + le stock par variante.
      qteParProduit.forEach((pid, qte) {
        final snap = produitSnaps[pid];
        if (snap == null || !snap.exists) return;
        tx.update(snap.reference, {
          'quantiteStock': FieldValue.increment(qte),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final byV = qteParVariante[pid];
        if (byV != null) {
          byV.forEach((vid, vqte) {
            final vsnap = varianteSnaps[pid]?[vid];
            if (vsnap == null || !vsnap.exists) return;
            tx.update(vsnap.reference, {
              'stock': FieldValue.increment(vqte),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });
        }
      });

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
