import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../data/models/user_model.dart';
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

  StreamSubscription<User?>? _authSub;

  UserModel? get user => _user.value;
  bool get isLoggedIn => _user.value != null;
  bool get isSuperAdmin => _user.value?.isSuperAdmin ?? false;
  bool get isAdmin => _user.value?.isAdmin ?? false;
  bool get isVendeur => _user.value?.isVendeur ?? false;
  bool get isAnyAdmin => _user.value?.isAnyAdmin ?? false;

  /// Boutique propre de l'utilisateur (admin/vendeur). null pour super-admin.
  String? get boutiqueId => _user.value?.boutiqueId;

  /// Renvoie le boutiqueId à utiliser pour filtrer les requêtes côté app.
  /// - Super-admin → null (pas de filtre, voit tout)
  /// - Admin / Vendeur → leur boutiqueId
  String? get scopeBoutiqueId =>
      isSuperAdmin ? null : _user.value?.boutiqueId;

  @override
  void onInit() {
    super.onInit();
    _authSub = AuthService.to.authStateChanges.listen(_onAuthChanged);
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user.value = null;
      return;
    }
    await _loadUserDoc(firebaseUser.uid);
  }

  /// Charge le document Firestore correspondant à l'UID Firebase.
  /// Renvoie true si l'utilisateur est valide et actif.
  Future<bool> _loadUserDoc(String uid) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final snap = await FirestoreService.to.users.doc(uid).get();
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

      _user.value = loaded;
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
  }
}
