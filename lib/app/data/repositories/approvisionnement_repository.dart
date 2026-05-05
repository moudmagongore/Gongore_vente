import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/approvisionnement_model.dart';

class ApprovisionnementRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.approvisionnements;
  CollectionReference<Map<String, dynamic>> get _produits => _fs.produits;
  CollectionReference<Map<String, dynamic>> get _fournisseurs =>
      _fs.fournisseurs;

  // ========== Lecture ==========

  Stream<List<ApprovisionnementModel>> watchAll({
    String? boutiqueId,
    String? fournisseurId,
    String? userId,
    DateTime? after,
    DateTime? before,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (boutiqueId != null && boutiqueId.isNotEmpty) {
      query = query.where('boutiqueId', isEqualTo: boutiqueId);
    }
    if (fournisseurId != null && fournisseurId.isNotEmpty) {
      query = query.where('fournisseurId', isEqualTo: fournisseurId);
    }
    if (userId != null && userId.isNotEmpty) {
      query = query.where('userId', isEqualTo: userId);
    }
    if (after != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    if (before != null) {
      query = query.where('date', isLessThan: Timestamp.fromDate(before));
    }
    query = query.orderBy('date', descending: true).limit(limit);
    return query.snapshots().ignorePermissionDenied().map(
          (s) => s.docs.map(ApprovisionnementModel.fromFirestore).toList(),
        );
  }

  Future<ApprovisionnementModel?> getById(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return ApprovisionnementModel.fromFirestore(snap);
  }

  // ========== Écriture (transactions atomiques) ==========

  /// Valide un approvisionnement :
  /// 1. Génère atomiquement un numéro séquentiel `A-AAAA-NNNNN`
  /// 2. Pour chaque produit acheté : recalcule le **CMUP** et met à jour
  ///    `prixAchat` + `quantiteStock`
  /// 3. Crée le document appro
  /// 4. Met à jour le solde fournisseur (delta = total - montantPaye) +
  ///    flagge `hasOperations: true`
  ///
  /// Tout est atomique. Lève si articles vides ou fournisseur introuvable.
  Future<String> create(ApprovisionnementModel appro) async {
    if (appro.articles.isEmpty) {
      throw ArgumentError('Approvisionnement sans article impossible');
    }
    if (appro.fournisseurId.isEmpty) {
      throw ArgumentError('fournisseurId requis');
    }

    return _fs.db.runTransaction<String>((tx) async {
      // ===== Étape 1 : tous les reads =====
      // Agrège les lignes par produit (au cas où une ligne en double).
      // Pour chaque produit on calcule la somme pondérée des PA des lignes
      // (si plusieurs lignes du même produit, leur PA peut différer).
      final lignesParProduit = <String, ({int qte, double valeur})>{};
      // Agrège aussi par (produit, variante) pour les produits à variantes.
      final qteParVariante = <String, Map<String, int>>{};
      for (final a in appro.articles) {
        final cur = lignesParProduit[a.produitId] ??
            (qte: 0, valeur: 0.0);
        lignesParProduit[a.produitId] = (
          qte: cur.qte + a.quantite,
          valeur: cur.valeur + (a.prixAchatUnitaire * a.quantite),
        );
        if (a.varianteId != null && a.varianteId!.isNotEmpty) {
          final byV = qteParVariante.putIfAbsent(
            a.produitId,
            () => <String, int>{},
          );
          byV[a.varianteId!] = (byV[a.varianteId!] ?? 0) + a.quantite;
        }
      }

      // Lit chaque produit concerné
      final produitSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final pid in lignesParProduit.keys) {
        produitSnaps[pid] = await tx.get(_produits.doc(pid));
      }
      // Lit chaque variante concernée
      final varianteSnaps = <String,
          Map<String, DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final entry in qteParVariante.entries) {
        final m = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final vid in entry.value.keys) {
          m[vid] = await tx.get(_fs.variantesOf(entry.key).doc(vid));
        }
        varianteSnaps[entry.key] = m;
      }

      // Lit le fournisseur
      final fournRef = _fournisseurs.doc(appro.fournisseurId);
      final fournSnap = await tx.get(fournRef);
      if (!fournSnap.exists) {
        throw Exception('Fournisseur introuvable');
      }

      // Lit le compteur séquentiel
      final counterRef = _fs.counters.doc(appro.boutiqueId);
      final counterSnap = await tx.get(counterRef);
      final year = appro.date.year;
      final field = 'appros$year';
      final currentCount = counterSnap.exists
          ? ((counterSnap.data() ?? {})[field] as num?)?.toInt() ?? 0
          : 0;
      final nextCount = currentCount + 1;
      final approNumero =
          'A-$year-${nextCount.toString().padLeft(5, '0')}';

      // ===== Étape 2 : writes =====

      // 2a. CMUP + stock pour chaque produit
      lignesParProduit.forEach((pid, agg) {
        final snap = produitSnaps[pid];
        if (snap == null || !snap.exists) {
          // Produit supprimé entre la création de l'appro côté UI et la tx.
          // On laisse passer (audit conservé via le snapshot de nom + PA
          // dans l'appro), mais on ne peut pas mettre à jour un produit
          // inexistant. Skip — la donnée d'appro reste cohérente.
          return;
        }
        final data = snap.data() ?? {};
        final qteActuelle = (data['quantiteStock'] as num?)?.toInt() ?? 0;
        final paActuel = (data['prixAchat'] as num?)?.toDouble() ?? 0;
        final qteAppro = agg.qte;
        final valeurAppro = agg.valeur;

        // CMUP : (qte_actuelle × pa_actuel + qte_appro × pa_appro)
        //      / (qte_actuelle + qte_appro)
        // Si qte_actuelle ≤ 0 (rétro-compat ou stock négatif), on prend
        // simplement le PA moyen de l'appro comme nouveau CMUP.
        final qteEffective = qteActuelle < 0 ? 0 : qteActuelle;
        final qteTotale = qteEffective + qteAppro;
        final double nouveauCmup;
        if (qteTotale == 0) {
          nouveauCmup = paActuel; // garde-fou, ne devrait pas arriver
        } else {
          nouveauCmup =
              (qteEffective * paActuel + valeurAppro) / qteTotale;
        }

        tx.update(snap.reference, {
          'prixAchat': nouveauCmup,
          'quantiteStock': qteActuelle + qteAppro,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Incrémente le stock de chaque variante touchée par cette appro.
        // Le total produit reste la somme des variantes par construction.
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

      // 2b. Crée le doc appro avec le numéro injecté
      final approRef = _col.doc();
      tx.set(approRef, {
        ...appro.toMap(),
        'numero': approNumero,
      });

      // 2c. Persiste le compteur
      if (counterSnap.exists) {
        tx.update(counterRef, {field: nextCount});
      } else {
        tx.set(counterRef, {field: nextCount});
      }

      // 2d. Met à jour le fournisseur (solde + hasOperations)
      //
      // Delta = total - montantPaye, couvre 2 effets en un :
      //   • +reste à payer (nouvelle dette)
      //   • +avance utilisée (consomme l'avance fournisseur, ramène le
      //     solde négatif vers 0)
      // Comme: delta = (total - montantPaye - avanceUtilisee) + avanceUtilisee
      //              = total - montantPaye
      final delta = appro.total - appro.montantPaye;
      tx.update(fournRef, {
        if (delta != 0) 'solde': FieldValue.increment(delta),
        'hasOperations': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return approRef.id;
    });
  }

  /// Annule un approvisionnement :
  /// 1. Vérifie que le stock résiduel est suffisant pour rendre les qtés
  ///    de chaque ligne (sinon refuse — déjà partiellement vendu).
  /// 2. Décrémente `quantiteStock` de chaque produit (sans toucher au PA
  ///    car le CMUP historique est perdu).
  /// 3. Inverse l'effet sur le solde fournisseur.
  /// 4. Marque l'appro `annulee` avec un motif.
  Future<void> cancel({
    required String approId,
    required String userId,
    required String motif,
  }) async {
    await _fs.db.runTransaction((tx) async {
      final approRef = _col.doc(approId);
      final approSnap = await tx.get(approRef);
      if (!approSnap.exists) {
        throw Exception('Approvisionnement introuvable');
      }
      final appro = ApprovisionnementModel.fromFirestore(approSnap);
      if (appro.statut == ApproStatut.annulee) {
        throw Exception('Approvisionnement déjà annulé');
      }

      // Agrège par produit + par (produit, variante)
      final qteParProduit = <String, int>{};
      final qteParVariante = <String, Map<String, int>>{};
      for (final a in appro.articles) {
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

      // Lit chaque produit pour vérifier la dispo
      final produitSnaps =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final pid in qteParProduit.keys) {
        produitSnaps[pid] = await tx.get(_produits.doc(pid));
      }
      // Lit chaque variante touchée
      final varianteSnaps = <String,
          Map<String, DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final entry in qteParVariante.entries) {
        final m = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final vid in entry.value.keys) {
          m[vid] = await tx.get(_fs.variantesOf(entry.key).doc(vid));
        }
        varianteSnaps[entry.key] = m;
      }

      // Vérifie que le stock courant peut absorber le retrait. Si le
      // produit a des variantes, on vérifie chaque variante (si elle existe
      // encore) ; sinon on vérifie le total.
      qteParProduit.forEach((pid, qteRetrait) {
        final snap = produitSnaps[pid];
        if (snap == null || !snap.exists) return;
        final data = snap.data() ?? {};
        final hasVar = (data['hasVariantes'] ?? false) as bool;
        final nom = (data['nom'] ?? '?') as String;
        if (hasVar) {
          final byV = qteParVariante[pid] ?? const <String, int>{};
          byV.forEach((vid, vqte) {
            final vsnap = varianteSnaps[pid]?[vid];
            if (vsnap == null || !vsnap.exists) return;
            final vstock =
                ((vsnap.data() ?? {})['stock'] as num?)?.toInt() ?? 0;
            if (vstock < vqte) {
              final lib =
                  ((vsnap.data() ?? {})['libelle'] ?? '?') as String;
              throw Exception(
                'Annulation impossible : stock insuffisant pour '
                '« $nom — $lib » (actuel $vstock, à retirer $vqte). '
                'Une partie a déjà été vendue.',
              );
            }
          });
        } else {
          final qteCourante =
              (data['quantiteStock'] as num?)?.toInt() ?? 0;
          if (qteCourante < qteRetrait) {
            throw Exception(
              'Annulation impossible : stock insuffisant pour « $nom »'
              ' (actuel $qteCourante, à retirer $qteRetrait). '
              'Une partie a déjà été vendue ou retirée.',
            );
          }
        }
      });

      // Décrémente le stock total + le stock par variante.
      qteParProduit.forEach((pid, qteRetrait) {
        final snap = produitSnaps[pid];
        if (snap == null || !snap.exists) return;
        tx.update(snap.reference, {
          'quantiteStock': FieldValue.increment(-qteRetrait),
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

      // Inverse l'effet sur le solde fournisseur
      final delta = appro.total - appro.montantPaye;
      if (delta != 0) {
        tx.update(_fournisseurs.doc(appro.fournisseurId), {
          'solde': FieldValue.increment(-delta),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Marque l'appro annulée
      tx.update(approRef, {
        'statut': ApproStatut.annulee.name,
        'motifAnnulation': motif,
      });
    });
  }
}
