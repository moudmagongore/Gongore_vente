import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../firebase_options.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';

/// Crée un compte Firebase Auth + le document Firestore correspondant
/// SANS déconnecter l'admin courant.
///
/// Comment ça marche : on initialise une instance Firebase nommée
/// `AdminCreator` en parallèle de l'app principale. Le signup se fait
/// sur cette instance secondaire, on récupère l'UID, on crée le doc
/// Firestore, puis on déconnecte et supprime l'instance secondaire.
/// La session de l'admin sur l'instance par défaut reste intacte.
class UserCreationService {
  static const _secondaryAppName = 'AdminCreator';

  final UserRepository _userRepo = UserRepository();

  /// Crée un nouvel utilisateur (Auth + Firestore).
  /// Renvoie l'UID Firebase créé.
  Future<String> createUser({
    required String email,
    required String password,
    required String nom,
    String? telephone,
    required UserRole role,
    String? boutiqueId,
    bool active = true,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: _secondaryAppName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = cred.user!.uid;

      // Créer le document Firestore avec UID = id du document
      final newUser = UserModel(
        id: uid,
        nom: nom.trim(),
        email: email.trim(),
        telephone: telephone?.trim().isEmpty ?? true ? null : telephone!.trim(),
        role: role,
        boutiqueId: boutiqueId,
        active: active,
      );

      await _userRepo.createDoc(newUser);

      // Déconnecter l'instance secondaire pour ne pas garder de session inutile
      await secondaryAuth.signOut();

      return uid;
    } finally {
      // Toujours nettoyer l'instance secondaire, même en cas d'erreur
      await secondaryApp.delete();
    }
  }

  /// Envoie un email de réinitialisation de mot de passe à l'utilisateur.
  /// Utile pour qu'il définisse lui-même son mot de passe à la première connexion.
  Future<void> sendPasswordResetEmail(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }
}
