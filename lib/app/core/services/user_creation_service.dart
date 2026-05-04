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

  /// Résultat d'une création de user. `emailSent` indique si l'envoi du
  /// mail de définition de mot de passe a réussi (false si demandé mais
  /// échoué — le compte reste créé, on remonte juste le message).
  /// `emailError` contient le message d'erreur le cas échéant.
  ///
  /// On ne fait pas échouer la création si l'email plante : le compte
  /// existe en base, on prévient juste l'admin pour qu'il renvoie le mail
  /// manuellement depuis la liste utilisateurs.

  /// Crée un nouvel utilisateur (Auth + Firestore) et envoie en option
  /// le mail de définition de mot de passe. Renvoie un objet avec l'UID
  /// + le statut de l'envoi de l'email.
  ///
  /// Important : on envoie le mail depuis l'instance Firebase secondaire
  /// (la même qui vient de créer l'utilisateur) pour éviter les soucis
  /// de session avec l'instance principale (admin connecté).
  Future<UserCreationResult> createUser({
    required String email,
    required String password,
    required String nom,
    String? telephone,
    required UserRole role,
    String? boutiqueId,
    bool active = true,
    bool alsoGestionnaire = false,
    bool sendPasswordResetEmail = true,
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
        alsoGestionnaire: alsoGestionnaire,
      );

      await _userRepo.createDoc(newUser);

      // Envoi du mail depuis l'instance secondaire (le user vient d'être
      // créé dessus, Firebase le reconnaît immédiatement). On capture
      // l'erreur sans faire échouer la création — l'admin pourra renvoyer
      // le mail manuellement depuis la liste utilisateurs.
      bool emailSent = false;
      String? emailError;
      if (sendPasswordResetEmail) {
        try {
          await secondaryAuth.sendPasswordResetEmail(email: email.trim());
          emailSent = true;
        } catch (e) {
          emailError = e is FirebaseAuthException
              ? (e.message ?? e.code)
              : e.toString();
        }
      }

      // Déconnecter l'instance secondaire pour ne pas garder de session inutile
      await secondaryAuth.signOut();

      return UserCreationResult(
        uid: uid,
        emailSent: emailSent,
        emailError: emailError,
      );
    } finally {
      // Toujours nettoyer l'instance secondaire, même en cas d'erreur
      await secondaryApp.delete();
    }
  }

  /// Envoie un email de réinitialisation de mot de passe à un utilisateur
  /// existant (utilisé depuis la liste users pour renvoyer le lien).
  Future<void> sendPasswordResetEmail(String email) {
    return FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }
}

/// Résultat d'un createUser : l'UID créé + le statut de l'envoi mail.
class UserCreationResult {
  final String uid;
  final bool emailSent;
  final String? emailError;

  const UserCreationResult({
    required this.uid,
    required this.emailSent,
    this.emailError,
  });
}
