import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/boutique_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/abonnement_params_repository.dart';
import '../../routes/app_routes.dart';
import '../utils/network_timeouts.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'subscription_guard.dart';

/// Controller global qui maintient le UserModel courant en mémoire.
/// Réagit automatiquement aux changements de l'auth Firebase.
/// Accessible partout via `Get.find<UserController>()` ou `UserController.to`.
class UserController extends GetxController {
  static UserController get to => Get.find();

  final Rxn<UserModel> _user = Rxn<UserModel>();
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  /// Boutique actuellement sélectionnée par un admin multi-boutique.
  /// Initialisée à `user.boutiqueId` à la connexion. Pour vendeur, elle reste
  /// fixée sur `user.boutiqueId`. Pour super-admin, elle reste null.
  ///
  /// IMPORTANT : c'est cette valeur que retourne `scopeBoutiqueId` — donc
  /// changer cette valeur change la portée de TOUTES les requêtes scopées.
  /// En pratique, les contrôleurs binds leurs streams au démarrage avec
  /// `scopeBoutiqueId` ; pour qu'un switch de boutique propage partout, on
  /// fait `Get.offAllNamed(adminHome)` après le switch (voir drawer).
  final RxnString currentBoutiqueId = RxnString();

  StreamSubscription<User?>? _authSub;

  // Cache de `graceDays` (paramètres globaux d'abonnement). Lu UNE seule
  // fois au login. Utilisé par le check inline dans le stream boutique
  // pour évaluer si l'abonnement a expiré au-delà de la grâce, sans
  // faire de read Firestore supplémentaire à chaque émission.
  int? _cachedGraceDays;

  // Subscription au doc Firestore du user courant : permet aux changements
  // (ex. admin qui coche `alsoGestionnaire` sur son propre profil, ou
  // super-admin qui désactive un compte) de se propager immédiatement à
  // toute l'UI sans avoir à se reconnecter.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  // Subscription au doc Firestore de la boutique de l'utilisateur courant
  // (admin/vendeur) : permet de déconnecter automatiquement quand la
  // boutique est désactivée ou supprimée. null pour super-admin.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _boutiqueDocSub;
  String? _watchedBoutiqueId;
  // Subscription à la liste des admins de la boutique (uniquement pour les
  // gestionnaires) : si aucun admin actif n'existe pour leur boutique, on
  // les déconnecte aussi (ex. super-admin désactive l'admin de la boutique).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _boutiqueAdminsSub;

  UserModel? get user => _user.value;
  bool get isLoggedIn => _user.value != null;
  bool get isSuperAdmin => _user.value?.isSuperAdmin ?? false;
  bool get isAdmin => _user.value?.isAdmin ?? false;
  bool get isVendeur => _user.value?.isVendeur ?? false;
  bool get isAnyAdmin => _user.value?.isAnyAdmin ?? false;

  /// Vrai si l'utilisateur peut gérer le catalogue (produits, catégories,
  /// mouvements stock manuels) : super-admin ou admin de boutique. Utilisé
  /// pour exposer les FABs et actions d'édition côté listes.
  bool get canManageCatalog => isSuperAdmin || isAdmin;

  /// Vrai si l'utilisateur peut effectuer des opérations métier (ventes,
  /// règlements, encaissements, créer clients/fournisseurs, appros, etc.) :
  /// super-admin ou gestionnaire (vendeur OU admin avec alsoGestionnaire).
  bool get canPerformSales => isSuperAdmin || isVendeur;

  /// Vrai si l'utilisateur peut DÉCLARER une dépense : super-admin, admin
  /// de boutique ou gestionnaire. Le PARAMÉTRAGE des natures de dépense
  /// reste, lui, réservé à l'admin (voir [canManageCatalog]).
  bool get canDeclareDepense => isSuperAdmin || isAdmin || isVendeur;

  /// Boutique principale de l'utilisateur (admin/vendeur). null pour super-admin.
  /// Note : pour un admin multi-boutique, ne pas utiliser pour scoper les
  /// requêtes — préférer `scopeBoutiqueId` qui retourne la boutique active.
  String? get boutiqueId => _user.value?.boutiqueId;

  /// Renvoie le boutiqueId à utiliser pour filtrer les requêtes côté app.
  /// - Super-admin → null (pas de filtre, voit tout)
  /// - Admin / Vendeur → la boutique ACTIVE (`currentBoutiqueId`), qui
  ///   correspond à `user.boutiqueId` par défaut. Un admin multi-boutique
  ///   peut changer la boutique active via le switcher du drawer.
  String? get scopeBoutiqueId {
    if (isSuperAdmin) return null;
    return currentBoutiqueId.value ?? _user.value?.boutiqueId;
  }

  /// Liste des boutiques accessibles par l'utilisateur (admin uniquement
  /// peut en avoir plusieurs). Vide pour super-admin.
  List<String> get accessibleBoutiqueIds =>
      _user.value?.accessibleBoutiqueIds ?? const [];

  /// Vrai si l'utilisateur a accès à plusieurs boutiques (admin uniquement).
  bool get hasMultipleBoutiques =>
      _user.value?.hasMultipleBoutiques ?? false;

  /// Change la boutique active. No-op si l'ID n'est pas dans les boutiques
  /// accessibles. Le caller (drawer) navigue ensuite vers admin home pour
  /// que tous les contrôleurs se ré-initialisent avec le nouveau scope.
  void setCurrentBoutique(String boutiqueId) {
    if (!accessibleBoutiqueIds.contains(boutiqueId)) return;
    if (currentBoutiqueId.value == boutiqueId) return;
    currentBoutiqueId.value = boutiqueId;
  }

  @override
  void onInit() {
    super.onInit();
    _authSub = AuthService.to.authStateChanges.listen(_onAuthChanged);
    // Le stream du doc boutique surveille TOUJOURS la boutique ACTIVE
    // (`currentBoutiqueId`), pas la boutique principale. Quand l'admin
    // switche via le drawer, on cancel l'ancien stream et on bind sur
    // la nouvelle. Coût : 1 read par switch (négligeable, déjà payé
    // par l'utilisateur qui prend l'action).
    //
    // Avantages :
    //   • La désactivation / modification d'une boutique NON-active ne
    //     déclenche pas le listener (zéro impact sur les autres
    //     boutiques de l'admin)
    //   • La désactivation / modification de la boutique active est
    //     détectée en temps réel (sign-out + re-routage au re-login)
    ever(currentBoutiqueId, _bindBoutiqueDocStream);
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    _boutiqueDocSub?.cancel();
    _boutiqueAdminsSub?.cancel();
    super.onClose();
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    // Annule les abonnements précédents (changement d'utilisateur ou logout).
    await _userDocSub?.cancel();
    _userDocSub = null;
    await _boutiqueDocSub?.cancel();
    _boutiqueDocSub = null;
    await _boutiqueAdminsSub?.cancel();
    _boutiqueAdminsSub = null;
    _watchedBoutiqueId = null;
    _cachedGraceDays = null;

    if (firebaseUser == null) {
      _user.value = null;
      currentBoutiqueId.value = null;
      return;
    }
    await _loadUserDoc(firebaseUser.uid);
    // Charge réussi → bascule en mode live pour que les modifs serveur
    // (alsoGestionnaire toggled, active toggled, etc.) propagent en direct.
    //
    // Note : le bind du stream du doc boutique est déclenché
    // automatiquement par `ever(currentBoutiqueId, ...)` dans `onInit`
    // (la valeur de `currentBoutiqueId` a été posée par `_loadUserDoc`
    // sur la première boutique active).
    if (_user.value != null) {
      final u = _user.value!;
      _bindUserDocStream(firebaseUser.uid);
      // Charge les paramètres d'abonnement EN PARALLÈLE des bindings.
      // Lecture unique par session, mise en cache pour le check inline
      // dans le listener du doc boutique (0 read récurrent ensuite).
      unawaited(_cacheGraceDays());
      _bindBoutiqueAdminsStream(u);
    }
  }

  /// Charge `graceDays` depuis Firestore et le met en cache mémoire.
  /// Best-effort : valeur par défaut conservatrice si la lecture échoue.
  Future<void> _cacheGraceDays() async {
    try {
      final params = await AbonnementParamsRepository().get();
      _cachedGraceDays = params.graceDays;
    } catch (_) {
      _cachedGraceDays = 3;
    }
  }

  /// Pour les gestionnaires uniquement : surveille la liste des admins
  /// de leur boutique. Si aucun admin n'est actif (tous désactivés/supprimés),
  /// déconnecte le gestionnaire — il ne peut pas opérer sans admin actif.
  void _bindBoutiqueAdminsStream(UserModel currentUser) {
    if (currentUser.role != UserRole.vendeur) return;
    final bid = currentUser.boutiqueId;
    if (bid == null || bid.isEmpty) return;

    _boutiqueAdminsSub = FirestoreService.to.users
        .where('boutiqueId', isEqualTo: bid)
        .where('role', isEqualTo: UserRole.admin.name)
        .snapshots()
        .listen(
      (snap) async {
        if (snap.metadata.isFromCache) return;
        final hasActiveAdmin = snap.docs.any((d) {
          final data = d.data();
          return (data['active'] as bool? ?? true) == true;
        });
        if (!hasActiveAdmin) {
          await _forceSignOut(
            'L\'administrateur de votre boutique a été désactivé. '
            'Contactez le support.',
          );
        }
      },
      onError: (e) {
        errorMessage.value =
            'Erreur de synchronisation des administrateurs : $e';
      },
    );
  }

  /// Souscrit au doc Firestore de la boutique du user (admin/vendeur).
  /// Si la boutique passe à `active=false` ou est supprimée, on déconnecte
  /// l'utilisateur avec un message clair. Pour super-admin (boutiqueId null),
  /// pas de souscription.
  ///
  /// On ignore les snapshots venus du cache local (`isFromCache`) car ils
  /// peuvent contenir un état périmé (ex. boutique désactivée à l'ancienne
  /// session). On attend la confirmation serveur avant de forcer un signOut.
  void _bindBoutiqueDocStream(String? boutiqueId) {
    // Déjà observée → no-op
    if (_watchedBoutiqueId == boutiqueId) return;
    // Cancel le stream précédent (switch de boutique active ou signOut)
    _boutiqueDocSub?.cancel();
    _boutiqueDocSub = null;
    _watchedBoutiqueId = boutiqueId;
    // Nouvelle boutique null/vide (signOut) → on s'arrête là
    if (boutiqueId == null || boutiqueId.isEmpty) return;
    _boutiqueDocSub =
        FirestoreService.to.boutiques.doc(boutiqueId).snapshots().listen(
      (snap) async {
        if (snap.metadata.isFromCache) return;
        if (!snap.exists) {
          await _forceSignOut(
            'Votre boutique a été supprimée. Contactez l\'administrateur.',
          );
          return;
        }
        final boutique = BoutiqueModel.fromFirestore(snap);
        if (!boutique.active) {
          await _forceSignOut(
            'Votre boutique a été désactivée. Contactez l\'administrateur.',
          );
          return;
        }
        // Check inline d'expiration de l'abonnement : 0 read Firestore
        // supplémentaire (toutes les données viennent du snapshot et du
        // cache local `_cachedGraceDays`). Déclenché à chaque émission
        // du stream, c'est-à-dire quand la boutique change réellement
        // côté serveur (super-admin modifie / supprime un paiement).
        final grace = _cachedGraceDays;
        if (grace == null) return; // params pas encore chargés
        final endsAt = boutique.subscriptionEndsAt;
        if (endsAt == null) {
          await _forceSignOut(
            'Aucun abonnement actif pour votre boutique. '
            'Contactez le support pour activer votre compte.',
          );
          return;
        }
        final now = DateTime.now();
        final deadline = endsAt.add(Duration(days: grace));
        if (now.isAfter(deadline)) {
          final daysSince = now.difference(endsAt).inDays;
          await _forceSignOut(
            'Votre abonnement a expiré depuis $daysSince jours. '
            'Contactez le support pour le réactiver.',
          );
        }
      },
      onError: (e) {
        errorMessage.value = 'Erreur de synchronisation de la boutique : $e';
      },
    );
  }

  /// Déconnecte l'utilisateur avec un message visible (snackbar) et le
  /// renvoie sur l'écran de login. Utilisé quand le compte ou la boutique
  /// est désactivé en cours de session.
  Future<void> _forceSignOut(String message) async {
    errorMessage.value = message;
    // Snackbar visible peu importe où l'utilisateur se trouve dans l'app.
    Get.snackbar(
      'Session terminée',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade50,
      colorText: Colors.red.shade900,
      icon: Icon(Icons.error_outline_rounded, color: Colors.red.shade900),
      duration: const Duration(seconds: 5),
      isDismissible: true,
    );
    await AuthService.to.signOut();
    _user.value = null;
    currentBoutiqueId.value = null;
    // Force le retour à la page login (sinon l'utilisateur reste sur la
    // route active jusqu'à la prochaine navigation).
    Get.offAllNamed(AppRoutes.login);
  }

  /// S'abonne au doc Firestore du user courant et met à jour `_user.value`
  /// à chaque modification serveur. Force aussi un signOut si le compte
  /// est désactivé entre-temps.
  ///
  /// Les snapshots venus du cache (`isFromCache`) sont utilisés pour la
  /// mise à jour du modèle (UI réactive), mais pas pour les checks de
  /// désactivation/suppression : on attend la confirmation serveur sinon
  /// un cache périmé peut forcer un signOut alors que le serveur a déjà
  /// rétabli le compte.
  void _bindUserDocStream(String uid) {
    _userDocSub = FirestoreService.to.users.doc(uid).snapshots().listen(
      (snap) async {
        if (!snap.exists) {
          if (snap.metadata.isFromCache) return;
          await _forceSignOut(
            'Votre compte a été supprimé. Contactez l\'administrateur.',
          );
          return;
        }
        final updated = UserModel.fromFirestore(snap);
        if (!updated.active) {
          if (snap.metadata.isFromCache) return;
          await _forceSignOut(
            'Votre compte a été désactivé. Contactez l\'administrateur.',
          );
          return;
        }
        _user.value = updated;
        // Si la boutique active n'est plus accessible (super-admin a retiré
        // l'admin d'une boutique), retombe sur sa boutique principale.
        if (!updated.isSuperAdmin) {
          final selected = currentBoutiqueId.value;
          if (selected == null ||
              !updated.accessibleBoutiqueIds.contains(selected)) {
            currentBoutiqueId.value = updated.boutiqueId;
          }
        }
      },
      onError: (e) {
        errorMessage.value = 'Erreur de synchronisation du profil : $e';
      },
    );
  }

  /// Charge le document Firestore correspondant à l'UID Firebase.
  /// Renvoie true si l'utilisateur est valide et actif.
  ///
  /// Tente un read serveur (`Source.server`) pour éviter de lire un cache
  /// périmé après une réactivation côté super-admin (sinon l'utilisateur
  /// reste bloqué « désactivé » alors que le serveur dit le contraire).
  /// Vérifie aussi que la boutique est active (sauf super-admin).
  ///
  /// `Source.server` interdit tout repli sur le cache : sans borne, sur un
  /// réseau lent le Future ne se résout jamais et le splash reste figé.
  /// On borne donc l'attente, puis on retombe sur le cache local — la
  /// fraîcheur est rattrapée par [_bindUserDocStream], qui force un
  /// signOut dès que le serveur signale un compte désactivé.
  Future<bool> _loadUserDoc(String uid) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final docRef = FirestoreService.to.users.doc(uid);
      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await docRef
            .get(const GetOptions(source: Source.server))
            .timeout(kStartupReadTimeout);
      } on TimeoutException {
        snap = await docRef.get(const GetOptions(source: Source.cache));
      }
      if (!snap.exists) {
        // Auth OK mais pas de document Firestore → cas anormal,
        // on déconnecte pour forcer un état propre.
        errorMessage.value =
            "Votre compte n'est pas encore configuré. Contactez l'administrateur.";
        await AuthService.to.signOut();
        _user.value = null;
        return false;
      }

      final loaded = UserModel.fromFirestore(snap);

      if (!loaded.active) {
        errorMessage.value =
            'Votre compte a été désactivé. Contactez l\'administrateur.';
        await AuthService.to.signOut();
        _user.value = null;
        return false;
      }

      // Vérifie la boutique (sauf super-admin qui n'a pas de boutiqueId).
      final loadedBoutiqueId = loaded.boutiqueId;
      // Pour non-super-admin : cherche la PREMIÈRE boutique accessible
      // utilisable (existe, active, abonnement valide). Permet à un admin
      // multi-boutique de se connecter même si sa principale est
      // désactivée / sans abonnement, tant qu'il a au moins une autre
      // boutique fonctionnelle. Le résultat est réutilisé plus bas pour
      // initialiser `currentBoutiqueId` (évite un double appel).
      String? firstAccessibleBoutiqueId;
      if (!loaded.isSuperAdmin && loaded.accessibleBoutiqueIds.isNotEmpty) {
        firstAccessibleBoutiqueId =
            await SubscriptionGuard.firstActiveBoutiqueId(loaded);
        if (firstAccessibleBoutiqueId == null) {
          // Aucune boutique accessible n'est utilisable. Récupère le
          // message de blocage le plus pertinent (statut de la dernière
          // boutique vérifiée) via `checkAccess`.
          final blockMsg = await SubscriptionGuard.checkAccess(loaded);
          errorMessage.value = blockMsg ??
              'Aucune de vos boutiques n\'est accessible. Contactez le support.';
          await AuthService.to.signOut();
          _user.value = null;
          return false;
        }
      }

      // Pour les gestionnaires : refuse le login s'il n'y a aucun admin
      // actif dans leur boutique (l'admin a été désactivé/supprimé).
      if (loaded.role == UserRole.vendeur &&
          loadedBoutiqueId != null &&
          loadedBoutiqueId.isNotEmpty) {
        // Même borne que ci-dessus. En cas de timeout on considère le
        // contrôle comme non concluant et on laisse passer : refuser la
        // connexion sur une simple lenteur réseau serait pire. La
        // vérification est refaite en continu par
        // [_bindBoutiqueAdminsStream].
        QuerySnapshot<Map<String, dynamic>>? adminsSnap;
        try {
          adminsSnap = await FirestoreService.to.users
              .where('boutiqueId', isEqualTo: loadedBoutiqueId)
              .where('role', isEqualTo: UserRole.admin.name)
              .get(const GetOptions(source: Source.server))
              .timeout(kStartupReadTimeout);
        } catch (_) {
          adminsSnap = null; // contrôle non concluant
        }
        final hasActiveAdmin = adminsSnap == null ||
            adminsSnap.docs.any((d) {
              return (d.data()['active'] as bool? ?? true) == true;
            });
        if (!hasActiveAdmin) {
          errorMessage.value =
              'L\'administrateur de votre boutique a été désactivé. '
              'Contactez le support.';
          await AuthService.to.signOut();
          _user.value = null;
          return false;
        }
      }

      _user.value = loaded;
      // Initialise la boutique active sur la première boutique
      // accessible utilisable (calculée plus haut, on évite un 2e appel).
      // Si tout était bloqué, on aurait déjà return false plus haut.
      if (!loaded.isSuperAdmin) {
        currentBoutiqueId.value =
            firstAccessibleBoutiqueId ?? loaded.boutiqueId;
      } else {
        currentBoutiqueId.value = null;
      }
      return true;
    } catch (e) {
      errorMessage.value = 'Erreur de chargement du profil : $e';
      _user.value = null;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// À appeler après un signIn réussi pour s'assurer que le doc est chargé
  /// avant la redirection (l'authStateChanges est async et peut arriver après).
  Future<bool> refreshFromAuth() async {
    final uid = AuthService.to.uid;
    if (uid == null) {
      _user.value = null;
      return false;
    }
    return _loadUserDoc(uid);
  }

  Future<void> signOut() async {
    await AuthService.to.signOut();
    _user.value = null;
    currentBoutiqueId.value = null;
  }
}
