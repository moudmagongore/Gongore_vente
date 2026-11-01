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

  /// Suit une caisse en temps réel : son solde bouge à chaque opération.
  Stream<CaisseModel?> watchOne(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _col
        .doc(id)
        .snapshots()
        .ignorePermissionDenied()
        .map((s) => s.exists ? CaisseModel.fromFirestore(s) : null);
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

  /// Stream des mouvements d'une caisse, du plus récent au plus ancien.
  ///
  /// **Toujours filtré sur UNE caisse** : la règle de lecture de
  /// `mouvementsCaisse` contrôle l'accès du gestionnaire par un `get()` sur
  /// la caisse du mouvement. Firestore mutualise les `get()` identiques
  /// d'une requête, donc un relevé mono-caisse ne coûte qu'une lecture de
  /// plus ; une requête multi-caisses exploserait la limite de 10 accès
  /// documentaires par requête.
  Stream<List<MouvementCaisseModel>> watchMouvements({
    required String boutiqueId,
    required String caisseId,
    DateTime? after,
    DateTime? before,
    int limit = 300,
  }) {
    if (boutiqueId.isEmpty || caisseId.isEmpty) {
      return Stream.value(<MouvementCaisseModel>[]);
    }
    Query<Map<String, dynamic>> q = _mouvements
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('caisseId', isEqualTo: caisseId);
    if (after != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    if (before != null) {
      q = q.where('date', isLessThan: Timestamp.fromDate(before));
    }
    return q
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .ignorePermissionDenied()
        .map((s) => s.docs.map(MouvementCaisseModel.fromFirestore).toList());
  }

  /// Dernier mouvement antérieur à [avant], pour connaître le solde de
  /// départ d'un relevé dont la période ne contient aucun mouvement.
  Future<MouvementCaisseModel?> dernierMouvementAvant({
    required String boutiqueId,
    required String caisseId,
    required DateTime avant,
  }) async {
    if (boutiqueId.isEmpty || caisseId.isEmpty) return null;
    final snap = await _mouvements
        .where('boutiqueId', isEqualTo: boutiqueId)
        .where('caisseId', isEqualTo: caisseId)
        .where('date', isLessThan: Timestamp.fromDate(avant))
        .orderBy('date', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return MouvementCaisseModel.fromFirestore(snap.docs.first);
  }

  /// Tous les mouvements d'une boutique sur une période.
  ///
  /// Réservé à l'admin : la règle de lecture d'un gestionnaire exige un
  /// `get()` par caisse, qui ferait sauter le quota sur une requête
  /// multi-caisses. Sert au rapport de synthèse par caisse (RG-32).
  Future<List<MouvementCaisseModel>> mouvementsDeLaBoutique({
    required String boutiqueId,
    DateTime? after,
    DateTime? before,
    int limit = 1000,
  }) async {
    if (boutiqueId.isEmpty) return const [];
    Query<Map<String, dynamic>> q =
        _mouvements.where('boutiqueId', isEqualTo: boutiqueId);
    if (after != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(after));
    }
    if (before != null) {
      q = q.where('date', isLessThan: Timestamp.fromDate(before));
    }
    final snap =
        await q.orderBy('date', descending: true).limit(limit).get();
    return snap.docs.map(MouvementCaisseModel.fromFirestore).toList();
  }

  /// Transfère un montant d'une caisse vers une autre (RG-20 à RG-23).
  ///
  /// Les deux mouvements sont écrits ensemble, jamais l'un sans l'autre, et
  /// partagent un `transfertId` qui permet de les retrouver pour une
  /// annulation.
  Future<String> transferer({
    required String boutiqueId,
    required String sourceId,
    required String destinationId,
    required double montant,
    required String userId,
    required String userNom,
    String? commentaire,
  }) async {
    final transfertId = _mouvements.doc().id;

    await _fs.db.runTransaction((tx) async {
      // ===== Lectures =====
      final sourceSnap = await tx.get(_col.doc(sourceId));
      final destSnap = await tx.get(_col.doc(destinationId));
      if (!sourceSnap.exists || !destSnap.exists) {
        throw CaisseException('Caisse introuvable. Reprenez la saisie.');
      }
      final source = CaisseModel.fromFirestore(sourceSnap);
      final destination = CaisseModel.fromFirestore(destSnap);

      // Une caisse désactivée ne doit plus recevoir ni fournir d'argent
      // hors annulation : le transfert est une opération volontaire.
      if (!source.active || !destination.active) {
        throw CaisseException(
          'Une des deux caisses est désactivée : transfert impossible.',
        );
      }

      final plan = planifierTransfert(
        source: source,
        destination: destination,
        montant: montant,
      );
      final date = DateTime.now();

      // ===== Écritures =====
      for (final (mouvement, sens) in [
        (plan.sortie, SensMouvement.sortie),
        (plan.entree, SensMouvement.entree),
      ]) {
        tx.set(
          _mouvements.doc(),
          MouvementCaisseModel(
            id: '',
            boutiqueId: boutiqueId,
            caisseId: mouvement.caisseId,
            caisseNom: mouvement.caisseNom,
            sens: sens,
            montant: mouvement.montant,
            soldeApres: mouvement.soldeApres,
            type: TypeMouvementCaisse.transfert,
            transfertId: transfertId,
            motif: commentaire,
            userId: userId,
            userNom: userNom,
            date: date,
          ).toMap(),
        );
        tx.update(_col.doc(mouvement.caisseId), {
          'solde': mouvement.soldeApres,
          'hasMouvements': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return transfertId;
  }

  /// Apport, retrait ou correction : un mouvement décidé par l'admin, sans
  /// opération derrière lui (RG-25).
  ///
  /// Le motif est obligatoire — c'est la seule trace de la raison du
  /// mouvement. La règle du solde négatif s'applique aux sorties.
  Future<void> mouvementManuel({
    required String boutiqueId,
    required String caisseId,
    required double montant,
    required SensMouvement sens,
    required TypeMouvementCaisse type,
    required String motif,
    required String userId,
    required String userNom,
  }) async {
    if (!type.reserveAdmin) {
      throw ArgumentError('Type réservé aux apports, retraits, corrections');
    }
    if (motif.trim().isEmpty) {
      throw CaisseException('Le motif est obligatoire.');
    }

    await _fs.db.runTransaction((tx) async {
      final snap = await tx.get(_col.doc(caisseId));
      if (!snap.exists) {
        throw CaisseException('Caisse introuvable.');
      }
      final caisse = CaisseModel.fromFirestore(snap);

      // Une correction sert justement à rattraper une caisse désactivée
      // dont le solde est faux : on ne contrôle donc pas `active` ici.
      final plan = planifierPaiements(
        paiements: [
          PaiementCaisse(
            caisseId: caisseId,
            caisseNom: caisse.nom,
            montant: montant,
          ),
        ],
        caisses: {caisseId: caisse},
        sens: sens,
        exigerActive: false,
      );
      final m = plan.mouvements.first;

      tx.set(
        _mouvements.doc(),
        MouvementCaisseModel(
          id: '',
          boutiqueId: boutiqueId,
          caisseId: caisseId,
          caisseNom: caisse.nom,
          sens: sens,
          montant: m.montant,
          soldeApres: m.soldeApres,
          type: type,
          motif: motif.trim(),
          userId: userId,
          userNom: userNom,
          date: DateTime.now(),
        ).toMap(),
      );
      tx.update(_col.doc(caisseId), {
        'solde': m.soldeApres,
        'hasMouvements': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Annule un mouvement de caisse qui n'a pas d'opération derrière lui :
  /// transfert, apport, retrait ou correction (RG-24, RG-27).
  ///
  /// Un mouvement n'est jamais modifié ni supprimé : on écrit son inverse,
  /// qui pointe vers lui (RG-6). Pour un transfert, **les deux** mouvements
  /// sont compensés ensemble.
  ///
  /// Les mouvements issus d'une opération (vente, dépense...) ne passent
  /// pas par ici : on annule l'opération elle-même, qui s'occupe de ses
  /// mouvements.
  /// [userId] et [userNom] sont ceux de l'utilisateur qui annule, pas de
  /// l'auteur du mouvement d'origine : les règles Firestore exigent que
  /// l'auteur d'un mouvement soit celui qui l'écrit.
  Future<void> annulerMouvement(
    MouvementCaisseModel mouvement, {
    required String userId,
    required String userNom,
  }) async {
    if (mouvement.type == TypeMouvementCaisse.annulation) {
      throw CaisseException(
        'Ce mouvement est déjà une annulation : il ne s\'annule pas.',
      );
    }
    if (mouvement.sourceId != null && mouvement.sourceId!.isNotEmpty) {
      throw CaisseException(
        'Ce mouvement vient d\'une opération : annulez l\'opération '
        'elle-même pour que son effet soit repris partout.',
      );
    }
    if (mouvement.type == TypeMouvementCaisse.ouverture) {
      throw CaisseException(
        'Le solde d\'ouverture ne s\'annule pas. Utilisez une correction.',
      );
    }

    final estTransfert =
        mouvement.transfertId != null && mouvement.transfertId!.isNotEmpty;

    // Un gestionnaire ne peut annuler un transfert que si les DEUX caisses
    // lui sont accessibles (RG-24). Le contrôle est fait par les règles
    // Firestore, pas par l'écran : le relevé ne montre qu'une caisse, il
    // ne peut pas savoir si l'autre moitié lui est ouverte.
    //
    // Le refus arrive donc sous forme de `permission-denied`, sur la
    // requête de la paire ou sur l'écriture. On le traduit ici en message
    // lisible — l'appelant affiche `CaisseException.message` tel quel.
    try {
      await _annuler(mouvement, userId: userId, userNom: userNom);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      throw CaisseException(
        estTransfert
            ? 'Ce transfert touche une caisse qui ne vous est pas '
                'accessible : seul un administrateur peut l\'annuler.'
            : 'Vous n\'avez pas accès à cette caisse : demandez à votre '
                'administrateur d\'annuler ce mouvement.',
      );
    }
  }

  Future<void> _annuler(
    MouvementCaisseModel mouvement, {
    required String userId,
    required String userNom,
  }) async {
    // Un transfert a deux mouvements liés. La requête est faite HORS
    // transaction (Firestore n'y autorise pas de requête), puis chaque
    // document est relu dedans pour travailler sur l'état frais.
    final refs = <DocumentReference<Map<String, dynamic>>>[];
    final tid = mouvement.transfertId;
    if (tid != null && tid.isNotEmpty) {
      final paire = await _mouvements
          .where('boutiqueId', isEqualTo: mouvement.boutiqueId)
          .where('transfertId', isEqualTo: tid)
          .get();
      refs.addAll(paire.docs.map((d) => d.reference));
    }
    if (refs.isEmpty) refs.add(_mouvements.doc(mouvement.id));

    await _fs.db.runTransaction((tx) async {
      // ===== Lectures : les mouvements, puis leurs caisses =====
      final aCompenser = <MouvementCaisseModel>[];
      for (final ref in refs) {
        final snap = await tx.get(ref);
        if (snap.exists) {
          aCompenser.add(MouvementCaisseModel.fromFirestore(snap));
        }
      }
      if (aCompenser.isEmpty) {
        throw CaisseException('Mouvement introuvable.');
      }

      final caisses = <String, CaisseModel>{};
      for (final m in aCompenser) {
        if (caisses.containsKey(m.caisseId)) continue;
        final snap = await tx.get(_col.doc(m.caisseId));
        if (snap.exists) {
          caisses[m.caisseId] = CaisseModel.fromFirestore(snap);
        }
      }

      // ===== Écritures =====
      // Les soldes sont enchaînés dans la map au fur et à mesure : les
      // deux mouvements d'un transfert peuvent viser la même caisse dans
      // des cas tordus, et le second doit partir du solde mis à jour.
      for (final m in aCompenser) {
        final caisse = caisses[m.caisseId];
        if (caisse == null) {
          throw CaisseException(
            'La caisse « ${m.caisseNom} » n\'existe plus : annulation '
            'impossible.',
          );
        }
        final inverse = m.sens == SensMouvement.entree
            ? SensMouvement.sortie
            : SensMouvement.entree;
        final plan = planifierPaiements(
          paiements: [
            PaiementCaisse(
              caisseId: m.caisseId,
              caisseNom: caisse.nom,
              montant: m.montant,
            ),
          ],
          caisses: {m.caisseId: caisse},
          sens: inverse,
          exigerActive: false,
        );
        final planifie = plan.mouvements.first;

        tx.set(
          _mouvements.doc(),
          MouvementCaisseModel(
            id: '',
            boutiqueId: m.boutiqueId,
            caisseId: m.caisseId,
            caisseNom: caisse.nom,
            sens: inverse,
            montant: planifie.montant,
            soldeApres: planifie.soldeApres,
            type: TypeMouvementCaisse.annulation,
            transfertId: m.transfertId,
            mouvementAnnuleId: m.id,
            motif: 'Annulation de ${m.type.label.toLowerCase()}',
            userId: userId,
            userNom: userNom,
            date: DateTime.now(),
          ).toMap(),
        );
        tx.update(_col.doc(m.caisseId), {
          'solde': planifie.soldeApres,
          'hasMouvements': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        caisses[m.caisseId] = caisse.copyWith(solde: planifie.soldeApres);
      }
    });
  }

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
