import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/marge_calculator.dart';
import '../models/vente_model.dart';

/// Un jeu de données purgeable, scopé à une boutique.
enum PurgeCible {
  ventes,
  reglements,
  approvisionnements,
  reglementsFournisseurs,
  mouvementsStock,
  depenses,
  produits,
  categories,
  clients,
  fournisseurs,
  naturesDepense,
  counters,
}

extension PurgeCibleX on PurgeCible {
  /// Nom de la collection Firestore visée.
  String get collection {
    switch (this) {
      case PurgeCible.ventes:
        return FirestoreKeys.ventes;
      case PurgeCible.reglements:
        return FirestoreKeys.reglements;
      case PurgeCible.approvisionnements:
        return FirestoreKeys.approvisionnements;
      case PurgeCible.reglementsFournisseurs:
        return FirestoreKeys.reglementsFournisseurs;
      case PurgeCible.mouvementsStock:
        return FirestoreKeys.mouvementsStock;
      case PurgeCible.depenses:
        return FirestoreKeys.depenses;
      case PurgeCible.produits:
        return FirestoreKeys.produits;
      case PurgeCible.categories:
        return FirestoreKeys.categories;
      case PurgeCible.clients:
        return FirestoreKeys.clients;
      case PurgeCible.fournisseurs:
        return FirestoreKeys.fournisseurs;
      case PurgeCible.naturesDepense:
        return FirestoreKeys.naturesDepense;
      case PurgeCible.counters:
        return FirestoreKeys.counters;
    }
  }

  String get label {
    switch (this) {
      case PurgeCible.ventes:
        return 'Ventes';
      case PurgeCible.reglements:
        return 'Règlements clients';
      case PurgeCible.approvisionnements:
        return 'Approvisionnements';
      case PurgeCible.reglementsFournisseurs:
        return 'Règlements fournisseurs';
      case PurgeCible.mouvementsStock:
        return 'Mouvements de stock';
      case PurgeCible.depenses:
        return 'Dépenses';
      case PurgeCible.produits:
        return 'Produits (et variantes)';
      case PurgeCible.categories:
        return 'Catégories';
      case PurgeCible.clients:
        return 'Clients';
      case PurgeCible.fournisseurs:
        return 'Fournisseurs';
      case PurgeCible.naturesDepense:
        return 'Natures de dépense';
      case PurgeCible.counters:
        return 'Compteurs de numérotation';
    }
  }

  /// Conséquence concrète de la purge, affichée sous le libellé.
  String get consequence {
    switch (this) {
      case PurgeCible.ventes:
        return 'Efface le chiffre d\'affaires et l\'historique de caisse.';
      case PurgeCible.reglements:
        return 'Les encaissements disparaissent ; les soldes clients ne sont pas recalculés.';
      case PurgeCible.approvisionnements:
        return 'Efface l\'historique d\'achat et la base du calcul du CMUP.';
      case PurgeCible.reglementsFournisseurs:
        return 'Les versements disparaissent ; les soldes fournisseurs ne sont pas recalculés.';
      case PurgeCible.mouvementsStock:
        return 'Efface la trace des sorties, pertes et ajustements manuels.';
      case PurgeCible.depenses:
        return 'Efface les charges déclarées et le résultat net des rapports.';
      case PurgeCible.produits:
        return 'Les ventes et appros existants pointeront vers des produits inexistants.';
      case PurgeCible.categories:
        return 'Les produits restants perdent leur rattachement de catégorie.';
      case PurgeCible.clients:
        return 'Les ventes à crédit perdent leur client et son solde.';
      case PurgeCible.fournisseurs:
        return 'Les appros perdent leur fournisseur et sa dette.';
      case PurgeCible.naturesDepense:
        return 'Les dépenses gardent leur libellé mais perdent leur nature.';
      case PurgeCible.counters:
        return 'La numérotation des ventes et appros repart à 1.';
    }
  }

  /// `counters` est adressé par identifiant de document (= boutiqueId) et
  /// non par champ `boutiqueId` : aucun filtre ne peut le trouver.
  bool get parDocId => this == PurgeCible.counters;

  /// Les variantes vivent en sous-collection de `produits` et ne sont pas
  /// supprimées avec leur parent : il faut les purger explicitement.
  bool get aDesSousCollections => this == PurgeCible.produits;
}

/// Opérations de maintenance réservées au super-admin : purge ciblée des
/// données d'UNE boutique, sans toucher aux autres.
///
/// Firestore n'offre pas de « DELETE ... WHERE » : on lit les documents
/// correspondants puis on les supprime par lots de [_tailleLot].
class MaintenanceRepository {
  final FirestoreService _fs = FirestoreService.to;

  /// Marge volontaire sous la limite Firestore de 500 écritures par lot.
  static const int _tailleLot = 400;

  Query<Map<String, dynamic>> _query(PurgeCible cible, String boutiqueId) {
    return _fs.db
        .collection(cible.collection)
        .where('boutiqueId', isEqualTo: boutiqueId);
  }

  /// Nombre de documents concernés, sans les télécharger (agrégat serveur).
  Future<int> compter(PurgeCible cible, String boutiqueId) async {
    if (boutiqueId.isEmpty) return 0;
    if (cible.parDocId) {
      final snap =
          await _fs.db.collection(cible.collection).doc(boutiqueId).get();
      return snap.exists ? 1 : 0;
    }
    final agg = await _query(cible, boutiqueId).count().get();
    return agg.count ?? 0;
  }

  /// Supprime les documents de [cible] appartenant à [boutiqueId].
  ///
  /// [onProgress] est appelé après chaque lot avec le cumul supprimé, pour
  /// qu'une purge longue reste lisible côté UI.
  Future<int> purger(
    PurgeCible cible,
    String boutiqueId, {
    void Function(int supprimes)? onProgress,
  }) async {
    if (boutiqueId.isEmpty) {
      throw ArgumentError('boutiqueId requis');
    }

    if (cible.parDocId) {
      final ref = _fs.db.collection(cible.collection).doc(boutiqueId);
      final snap = await ref.get();
      if (!snap.exists) return 0;
      await ref.delete();
      onProgress?.call(1);
      return 1;
    }

    var total = 0;

    // Sous-collections d'abord : une fois le parent supprimé, ses enfants
    // deviennent inatteignables (orphelins invisibles, toujours facturés).
    if (cible.aDesSousCollections) {
      total += await _purgerVariantes(boutiqueId, onProgress: (n) {
        onProgress?.call(total + n);
      });
    }

    final query = _query(cible, boutiqueId);
    while (true) {
      final snap = await query.limit(_tailleLot).get();
      if (snap.docs.isEmpty) break;
      final batch = _fs.db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      total += snap.docs.length;
      onProgress?.call(total);
      // Dernière page : inutile de refaire un tour.
      if (snap.docs.length < _tailleLot) break;
    }
    return total;
  }

  // ================= Marges des ventes passées =================
  //
  // Les ventes enregistrées avant le lot « marge figée » n'ont pas de
  // `margeTotale` : leur marge est encore recalculée à l'affichage avec le
  // prix d'achat du jour, donc elle bouge à chaque approvisionnement.
  //
  // On ne peut pas interroger Firestore sur l'ABSENCE d'un champ
  // (`isNull` ne remonte pas les documents où la clé n'existe pas) : il
  // faut parcourir les ventes et trier côté client.

  /// Nombre de ventes de la boutique dont la marge n'est pas encore figée.
  Future<int> compterVentesSansMarge(String boutiqueId) async {
    if (boutiqueId.isEmpty) return 0;
    var total = 0;
    await _parcourirVentes(boutiqueId, (vente) async {
      if (!vente.aMargeFigee) total += 1;
    });
    return total;
  }

  /// Fige la marge des ventes passées **au prix d'achat actuel** du
  /// produit.
  ///
  /// Choix assumé : on ne reconstitue pas le CMUP historique. La marge
  /// obtenue n'est donc pas exacte au centime pour une vente ancienne,
  /// mais elle cesse définitivement de bouger — ce qui est l'objectif.
  /// Les ventes déjà figées ne sont jamais réécrites.
  Future<int> figerMargesVentes(
    String boutiqueId, {
    void Function(int traitees)? onProgress,
  }) async {
    if (boutiqueId.isEmpty) {
      throw ArgumentError('boutiqueId requis');
    }

    // Prix d'achat courant de chaque produit de la boutique.
    final produits = await _fs.produits
        .where('boutiqueId', isEqualTo: boutiqueId)
        .get();
    final prixAchat = <String, double>{
      for (final d in produits.docs)
        d.id: ((d.data())['prixAchat'] as num?)?.toDouble() ?? 0,
    };

    var traitees = 0;
    var batch = _fs.db.batch();
    var enAttente = 0;

    await _parcourirVentes(boutiqueId, (vente) async {
      if (vente.aMargeFigee) return;
      final marges = calculerMarges(
        articles: vente.articles,
        remiseGlobale: vente.remise,
        prixAchatParProduit: prixAchat,
      );
      batch.update(_fs.ventes.doc(vente.id), {
        'articles': marges.articles.map((a) => a.toMap()).toList(),
        'coutAchatTotal': marges.coutAchatTotal,
        'margeTotale': marges.margeTotale,
      });
      enAttente += 1;
      traitees += 1;

      if (enAttente >= _tailleLot) {
        await batch.commit();
        batch = _fs.db.batch();
        enAttente = 0;
        onProgress?.call(traitees);
      }
    });

    if (enAttente > 0) {
      await batch.commit();
      onProgress?.call(traitees);
    }
    return traitees;
  }

  /// Parcourt les ventes d'une boutique par pages, pour ne jamais charger
  /// tout l'historique en mémoire d'un coup.
  Future<void> _parcourirVentes(
    String boutiqueId,
    Future<void> Function(VenteModel vente) action,
  ) async {
    const taillePage = 300;
    DocumentSnapshot<Map<String, dynamic>>? dernier;
    while (true) {
      var q = _fs.ventes
          .where('boutiqueId', isEqualTo: boutiqueId)
          .orderBy(FieldPath.documentId)
          .limit(taillePage);
      if (dernier != null) q = q.startAfterDocument(dernier);
      final snap = await q.get();
      if (snap.docs.isEmpty) break;
      for (final d in snap.docs) {
        await action(VenteModel.fromFirestore(d));
      }
      dernier = snap.docs.last;
      if (snap.docs.length < taillePage) break;
    }
  }

  Future<int> _purgerVariantes(
    String boutiqueId, {
    void Function(int supprimes)? onProgress,
  }) async {
    final produits = await _fs.produits
        .where('boutiqueId', isEqualTo: boutiqueId)
        .get();
    var total = 0;
    for (final p in produits.docs) {
      final sous = _fs.variantesOf(p.id);
      while (true) {
        final snap = await sous.limit(_tailleLot).get();
        if (snap.docs.isEmpty) break;
        final batch = _fs.db.batch();
        for (final v in snap.docs) {
          batch.delete(v.reference);
        }
        await batch.commit();
        total += snap.docs.length;
        onProgress?.call(total);
        if (snap.docs.length < _tailleLot) break;
      }
    }
    return total;
  }
}
