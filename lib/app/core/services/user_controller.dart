import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/boutique_model.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

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

    if (firebaseUser == null) {
      _user.value = null;
      currentBoutiqueId.value = null;
      return;
    }
    await _loadUserDoc(firebaseUser.uid);
    // Charge réussi → bascule en mode live pour que les modifs serveur
    // (alsoGestionnaire toggled, active toggled, etc.) propagent en direct.
    if (_user.value != null) {
      final u = _user.value!;
      _bindUserDocStream(firebaseUser.uid);
      _bindBoutiqueDocStream(u.boutiqueId);
      _bindBoutiqueAdminsStream(u);
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
    if (boutiqueId == null || boutiqueId.isEmpty) return;
    if (_watchedBoutiqueId == boutiqueId) return; // déjà observé
    _watchedBoutiqueId = boutiqueId;
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
  /// Force un read serveur (`Source.server`) pour éviter de lire un cache
  /// périmé après une réactivation côté super-admin (sinon l'utilisateur
  /// reste bloqué « désactivé » alors que le serveur dit le contraire).
  /// Vérifie aussi que la boutique est active (sauf super-admin).
  Future<bool> _loadUserDoc(String uid) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final snap = await FirestoreService.to.users
          .doc(uid)
          .get(const GetOptions(source: Source.server));
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
      if (!loaded.isSuperAdmin &&
          loadedBoutiqueId != null &&
          loadedBoutiqueId.isNotEmpty) {
        final boutiqueSnap = await FirestoreService.to.boutiques
            .doc(loadedBoutiqueId)
            .get(const GetOptions(source: Source.server));
        if (!boutiqueSnap.exists) {
          errorMessage.value =
              'Votre boutique a été supprimée. Contactez l\'administrateur.';
          await AuthService.to.signOut();
          _user.value = null;
          return false;
        }
        final boutique = BoutiqueModel.fromFirestore(boutiqueSnap);
        if (!boutique.active) {
          errorMessage.value =
              'Votre boutique a été désactivée. Contactez l\'administrateur.';
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
        final adminsSnap = await FirestoreService.to.users
            .where('boutiqueId', isEqualTo: loadedBoutiqueId)
            .where('role', isEqualTo: UserRole.admin.name)
            .get(const GetOptions(source: Source.server));
        final hasActiveAdmin = adminsSnap.docs.any((d) {
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
      // Initialise la boutique active. Pour un admin multi-boutique on
      // garde sa sélection précédente si elle reste valide, sinon on
      // retombe sur sa boutique principale.
      if (!loaded.isSuperAdmin) {
        final selected = currentBoutiqueId.value;
        if (selected == null ||
            !loaded.accessibleBoutiqueIds.contains(selected)) {
          currentBoutiqueId.value = loaded.boutiqueId;
        }
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
