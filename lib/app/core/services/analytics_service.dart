import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:get/get.dart';

import '../../data/models/user_model.dart';

/// Point d'entrée unique vers Google Analytics (Firebase).
///
/// Deux principes :
///
/// 1. **Aucune donnée personnelle n'est envoyée.** Ni nom, ni téléphone, ni
///    e-mail, ni identifiant de client. On envoie le rôle et l'identifiant
///    technique de la boutique, qui servent à segmenter les statistiques
///    sans désigner personne.
/// 2. **Jamais bloquant.** Une erreur de mesure ne doit pas faire échouer
///    une vente : chaque appel est protégé et silencieux. Une statistique
///    manquante est sans conséquence, une vente perdue non.
class AnalyticsService extends GetxService {
  static AnalyticsService get to => Get.find<AnalyticsService>();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// À passer aux `navigatorObservers` de `GetMaterialApp` : il enregistre
  /// automatiquement un `screen_view` à chaque changement de route, sans
  /// une ligne dans les écrans.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> _silencieux(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Volontairement muet : cf. principe 2.
    }
  }

  /// Rattache les événements suivants à un profil, après connexion.
  ///
  /// `userId` est l'uid Firebase : un identifiant technique, déjà connu de
  /// Google, et qui ne révèle rien par lui-même.
  Future<void> identifier(UserModel user) async {
    await _silencieux(() async {
      await _analytics.setUserId(id: user.id);
      await _analytics.setUserProperty(name: 'role', value: user.role.name);
      await _analytics.setUserProperty(
        name: 'boutique_id',
        value: user.boutiqueId ?? 'aucune',
      );
      await _analytics.setUserProperty(
        name: 'aussi_gestionnaire',
        value: user.alsoGestionnaire.toString(),
      );
    });
  }

  /// Déconnexion : on coupe le rattachement pour que la session suivante,
  /// éventuellement d'un autre utilisateur sur le même téléphone, ne soit
  /// pas comptée sur le profil précédent.
  Future<void> oublier() async {
    await _silencieux(() async {
      await _analytics.logEvent(name: 'deconnexion');
      await _analytics.setUserId(id: null);
    });
  }

  Future<void> logConnexion({required String methode}) async {
    await _silencieux(() => _analytics.logLogin(loginMethod: methode));
  }

  /// Vente validée. `logPurchase` est un événement **standard** de Google
  /// Analytics : il alimente les rapports de revenu tout faits, là où un
  /// événement maison n'apparaîtrait que dans les rapports personnalisés.
  Future<void> logVente({
    required double total,
    required int nbArticles,
    required bool aCredit,
    required String devise,
  }) async {
    await _silencieux(() async {
      await _analytics.logPurchase(currency: devise, value: total);
      await _analytics.logEvent(
        name: 'vente_validee',
        parameters: {
          'nb_articles': nbArticles,
          'a_credit': aCredit ? 1 : 0,
        },
      );
    });
  }

  /// Arrivage enregistré — le pendant de la vente côté achats.
  Future<void> logArrivage({
    required double total,
    required int nbLignes,
  }) async {
    await _silencieux(() => _analytics.logEvent(
          name: 'arrivage_valide',
          parameters: {'total': total, 'nb_lignes': nbLignes},
        ));
  }

  Future<void> logDepense({required double montant}) async {
    await _silencieux(() => _analytics.logEvent(
          name: 'depense_declaree',
          parameters: {'montant': montant},
        ));
  }
}
