import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/services/firestore_service.dart';
import '../../core/utils/caisse_calculator.dart';
import '../../core/utils/stream_helpers.dart';
import '../models/caisse_model.dart';
import '../models/mouvement_caisse_model.dart';
import '../models/paiement_caisse.dart';

/// Seul point d'accès aux caisses et à leurs mouvements.
///
/// **Aucun autre code ne modifie un solde** : toute entrée et toute sortie
/// d'argent passe par [appliquerPaiements], à l'intérieur de la transaction
/// de l'opération qui la provoque. C'est ce qui garantit qu'un solde et ses
/// mouvements ne peuvent pas diverger.
class CaisseRepository {
  final FirestoreService _fs = FirestoreService.to;

  CollectionReference<Map<String, dynamic>> get _col => _fs.caisses;
  CollectionReference<Map<String, dynamic>> get _mouvements =>
      _fs.mouvementsCaisse;

  // ========== Lecture ==========

  /// Stream scopé selon le rôle :
  /// - `scope == null` → super-admin, toutes les caisses
  /// - `scope` non vide + `gestionnaireId == null` → admin, sa boutique
  /// - `scope` non vide + `gestionnaireId` → gestionnaire, uniquement les
  ///   caisses où il figure dans `gestionnaireIds`
  /// - `scope` vide → liste vide
  ///
  /// Pas de filtre `active` côté Firestore : il économiserait peu et
  /// imposerait un index composite de plus. Le tri actif/inactif se fait
  /// côté client, comme pour les natures de dépense (volumes très faibles).
  Stream<List<CaisseModel>> watchScoped({
    required String? scope,
    String? gestionnaireId,
  }) {
    if (scope == null) {
      return _col.orderBy('ordre').snapshots().ignorePermissionDenied().map(
            (snap) => snap.docs.map(CaisseModel.fromFirestore).toList(),
          );
    }
    if (scope.isEmpty) return Stream.value(<CaisseModel>[]);

    Query<Map<String, dynamic>> q = _col.where('boutiqueId', isEqualTo: scope);
    if (gestionnaireId != null && gestionnaireId.isNotEmpty) {
      // Aligné sur les règles Firestore : un gestionnaire ne peut lire que
      // les caisses où son uid figure. Sans ce filtre la query entière
      // serait refusée (PERMISSION_DENIED), pas seulement les documents
      // hors de sa portée.
      q = q.where('gestionnaireIds', arrayContains: gestionnaireId);
    }
    return q
        .orderBy('ordre')
        .snapshots()
        .ignorePermissionDenied()
        .map((snap) => snap.docs.map(CaisseModel.fromFirestore).toList());
  }

  Future<CaisseModel?> getById(String id) async {
    if (id.isEmpty) return null;
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return CaisseModel.fromFirestore(snap);
  }

  /// Caisses actives d'une boutique, dans l'ordre d'affichage.
  ///
  /// Sert aux formulaires d'opération : liste vide ⇒ la boutique n'a pas
  /// encore de caisse, l'opération se déroule alors sans choix de caisse
  /// (RG-9).
  Future<List<CaisseModel>> getActives(
    String boutiqueId, {
    String? gestionnaireId,
  }) async {
    if (boutiqueId.isEmpty) return const [];
    Query<Map<String, dynamic>> q =
        _col.where('boutiqueId', isEqualTo: boutiqueId);
    if (gestionnaireId != null && gestionnaireId.isNotEmpty) {
      q = q.where('gestionnaireIds', arrayContains: gestionnaireId);
    }
    final snap = await q.orderBy('ordre').get();
    return snap.docs
        .map(CaisseModel.fromFirestore)
        .where((c) => c.active)
        .toList();
  }

  // ========== Paramétrage (admin) ==========

  /// Crée une caisse et, si le solde de départ n'est pas nul, le mouvement
  /// « Ouverture » correspondant (RG-4).
  ///
  /// Un solde de départ à zéro n'écrit pas de mouvement : il n'y aurait
  /// rien à lire dans le relevé, et `hasMouvements` doit rester `false`
  /// pour qu'une caisse créée par erreur puisse encore être supprimée
  /// (RG-7).
  Future<String> create(
    CaisseModel caisse, {
    required double soldeDepart,
    required String userId,
    required String userNom,
  }) async {
    if (caisse.nom.trim().isEmpty) {
      throw ArgumentError('Nom de caisse requis');
    }
    if (caisse.boutiqueId.isEmpty) {
      throw ArgumentError('Boutique requise');
    }

    final batch = _fs.db.batch();
    final ref = _col.doc();
    final avecOuverture = soldeDepart != 0;

    batch.set(ref, {
      ...caisse.copyWith(solde: soldeDepart, hasMouvements: avecOuverture)
          .toMap(),
    });

    if (avecOuverture) {
      final now = DateTime.now();
      final mouvement = MouvementCaisseModel(
        id: '',
        boutiqueId: caisse.boutiqueId,
        caisseId: ref.id,
        caisseNom: caisse.nom,
        // Un solde de départ négatif se décrit comme une sortie : le
        // montant d'un mouvement reste toujours positif.
        sens: soldeDepart > 0 ? SensMouvement.entree : SensMouvement.sortie,
        montant: soldeDepart.abs(),
        soldeApres: soldeDepart,
        type: TypeMouvementCaisse.ouverture,
        userId: userId,
        userNom: userNom,
        date: now,
      );
      batch.set(_mouvements.doc(), mouvement.toMap());
    }

    await batch.commit();
    await _rafraichirDrapeauBoutique(caisse.boutiqueId);
    return ref.id;
  }

  /// Met à jour les paramètres d'une caisse. Le solde n'en fait pas partie
  /// (cf. `CaisseModel.toMapParametres`).
  Future<void> updateParametres(CaisseModel caisse) {
    if (caisse.nom.trim().isEmpty) {
      throw ArgumentError('Nom de caisse requis');
    }
    return _col.doc(caisse.id).update(caisse.toMapParametres());
  }

  Future<void> setActive(String id, bool active) async {
    final caisse = await getById(id);
    await _col.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (caisse != null) {
      await _rafraichirDrapeauBoutique(caisse.boutiqueId);
    }
  }

  /// Supprime une caisse qui n'a jamais servi.
  ///
  /// Le contrôle est refait ici, dans une transaction : l'écran a pu être
  /// ouvert avant le premier mouvement de la caisse.
  Future<void> delete(String id) async {
    String? boutiqueId;
    await _fs.db.runTransaction((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final caisse = CaisseModel.fromFirestore(snap);
      if (caisse.hasMouvements) {
        throw CaisseException(
          '« ${caisse.nom} » a des mouvements : elle ne peut plus être '
          'supprimée, seulement désactivée.',
        );
      }
      tx.delete(ref);
      boutiqueId = caisse.boutiqueId;
    });
    final bid = boutiqueId;
    if (bid != null) {
      await _rafraichirDrapeauBoutique(bid);
    }
  }

  /// Met à jour `boutiques/{id}.hasCaissesActives`.
  ///
  /// Appelé après chaque création, activation, désactivation ou suppression
  /// de caisse. Recalculé par une requête plutôt que déduit de l'action :
  /// le drapeau se répare ainsi tout seul s'il a divergé, et l'opération
  /// reste rare (paramétrage par l'admin uniquement).
  ///
  /// Un échec ici n'annule pas l'action sur la caisse : le drapeau est une
  /// commodité d'affichage, pas une donnée comptable. Il sera recalculé au
  /// prochain paramétrage.
  Future<void> _rafraichirDrapeauBoutique(String boutiqueId) async {
    if (boutiqueId.isEmpty) return;
    try {
      final actives = await _col
          .where('boutiqueId', isEqualTo: boutiqueId)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();
      await _fs.boutiques.doc(boutiqueId).update({
        'hasCaissesActives': actives.docs.isNotEmpty,
      });
    } catch (_) {
      // Volontairement silencieux : cf. commentaire ci-dessus.
    }
  }

  // ========== Mouvements ==========

  /// Applique une liste de paiements aux caisses, **dans la transaction de
  /// l'opération appelante**, et renvoie ces paiements enrichis de l'id du
  /// mouvement écrit pour chacun.
  ///
  /// ⚠️ **À appeler avant la première écriture de la transaction.** Cette
  /// méthode lit les caisses puis écrit ; or Firestore interdit toute
  /// lecture après une écriture dans une même transaction. L'appeler trop
  /// tard lève une erreur à l'exécution.
  ///
  /// Trois comportements à connaître :
  ///
  /// - [paiements] vide ⇒ rien n'est lu ni écrit, la liste renvoyée est
  ///   vide. C'est le cas d'une boutique sans caisse (RG-9) et celui d'une
  ///   vente entièrement à crédit.
  /// - les lignes sont regroupées par caisse avant écriture : une caisse
  ///   ne reçoit qu'un mouvement par opération (RG-10).
  /// - une caisse qui passerait en négatif sans y être autorisée fait
  ///   échouer toute la transaction ([CaisseException], message prêt à
  ///   afficher).
  ///
  /// [exigerActive] est mis à `false` par les annulations : une caisse
  /// désactivée entre-temps doit rester créditable, sinon l'opération
  /// deviendrait impossible à annuler.
  ///
  /// [mouvementsAnnules] associe à chaque `caisseId` le mouvement d'origine
  /// que l'on compense. Les lignes étant regroupées par caisse, une caisse
  /// n'a qu'un mouvement par opération : la correspondance est exacte.
  Future<List<PaiementCaisse>> appliquerPaiements({
    required Transaction tx,
    required List<PaiementCaisse> paiements,
    required SensMouvement sens,
    required String boutiqueId,
    required TypeMouvementCaisse type,
    required String userId,
    required String userNom,
    required DateTime date,
    String? sourceType,
    String? sourceId,
    String? numero,
    String? transfertId,
    String? motif,
    Map<String, String>? mouvementsAnnules,
    bool exigerActive = true,
  }) async {
    if (paiements.isEmpty) return const [];

    // ===== Lectures =====
    final ids = regrouperParCaisse(paiements).keys.toList();
    final caisses = <String, CaisseModel>{};
    for (final id in ids) {
      final snap = await tx.get(_col.doc(id));
      if (snap.exists) {
        caisses[id] = CaisseModel.fromFirestore(snap);
      }
    }

    final plan = planifierPaiements(
      paiements: paiements,
      caisses: caisses,
      sens: sens,
      exigerActive: exigerActive,
    );

    // ===== Écritures =====
    final resultat = <PaiementCaisse>[];
    for (final m in plan.mouvements) {
      final mouvementRef = _mouvements.doc();
      tx.set(
        mouvementRef,
        MouvementCaisseModel(
          id: '',
          boutiqueId: boutiqueId,
          caisseId: m.caisseId,
          caisseNom: m.caisseNom,
          sens: sens,
          montant: m.montant,
          soldeApres: m.soldeApres,
          type: type,
          sourceType: sourceType,
          sourceId: sourceId,
          numero: numero,
          transfertId: transfertId,
          mouvementAnnuleId: mouvementsAnnules?[m.caisseId],
          motif: motif,
          userId: userId,
          userNom: userNom,
          date: date,
        ).toMap(),
      );

      // Le solde est écrit à sa valeur calculée, pas incrémenté : il reste
      // ainsi exactement égal au `soldeApres` du mouvement, et la
      // transaction garantit qu'aucune autre écriture n'est passée entre
      // la lecture et ici.
      //
      // Ces trois champs sont les seuls qu'un gestionnaire est autorisé à
      // modifier sur une caisse (cf. `firestore.rules`) : n'en ajouter
      // aucun sans mettre les règles à jour.
      tx.update(_col.doc(m.caisseId), {
        'solde': m.soldeApres,
        'hasMouvements': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      resultat.add(PaiementCaisse(
        caisseId: m.caisseId,
        caisseNom: m.caisseNom,
        montant: m.montant,
        mouvementId: mouvementRef.id,
      ));
    }
    return resultat;
  }
}
