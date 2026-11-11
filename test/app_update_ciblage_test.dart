import 'package:flutter_test/flutter_test.dart';
import 'package:gongore_vente/app/data/models/app_update_config_model.dart';

/// Ciblage de la mise à jour forcée par plateforme.
///
/// Ce que l'écran enregistre pour chaque cible :
///   « Les deux » → minVersion = v,        android = '',  ios = ''
///   « Android »  → minVersion = '',       android = v,   ios = ''
///   « iOS »      → minVersion = '',       android = '',  ios = v
///
/// Une version exigée **vide** signifie « ne force personne » : c'est le
/// test que fait `AppUpdateService` avant même de comparer les numéros.
void main() {
  group('cible « Les deux »', () {
    const config = AppUpdateConfigModel(minVersion: '2.0.0');

    test('Android est force', () {
      expect(config.minVersionPour(android: true), '2.0.0');
    });

    test('iOS est force', () {
      expect(config.minVersionPour(android: false), '2.0.0');
    });
  });

  group('cible « iOS » seulement', () {
    const config = AppUpdateConfigModel(minVersionIos: '2.0.0');

    test('iOS est force sur la version demandee', () {
      expect(config.minVersionPour(android: false), '2.0.0');
    });

    test('Android n est PAS force : aucune version exigee', () {
      expect(config.minVersionPour(android: true), isEmpty);
    });
  });

  group('cible « Android » seulement', () {
    const config = AppUpdateConfigModel(minVersionAndroid: '2.0.0');

    test('Android est force sur la version demandee', () {
      expect(config.minVersionPour(android: true), '2.0.0');
    });

    test('iOS n est PAS force', () {
      expect(config.minVersionPour(android: false), isEmpty);
    });
  });

  group('cas de bord', () {
    test('rien de renseigne : personne n est force', () {
      const config = AppUpdateConfigModel();
      expect(config.minVersionPour(android: true), isEmpty);
      expect(config.minVersionPour(android: false), isEmpty);
    });

    test('la valeur specifique l emporte sur la valeur commune', () {
      // Cas reel : iOS en relecture chez Apple, on avance Android seul.
      const config = AppUpdateConfigModel(
        minVersion: '1.9.0',
        minVersionAndroid: '2.1.0',
      );
      expect(config.minVersionPour(android: true), '2.1.0');
      expect(config.minVersionPour(android: false), '1.9.0');
    });

    test('les espaces parasites ne creent pas une fausse exigence', () {
      const config = AppUpdateConfigModel(minVersionIos: '   ');
      expect(config.minVersionPour(android: false), isEmpty);
    });

    test('chaque plateforme a son propre lien', () {
      const config = AppUpdateConfigModel(
        androidStoreUrl: 'https://gongore.app/app.apk',
        iosStoreUrl: 'https://apps.apple.com/app/id123',
      );
      expect(config.storeUrlPour(android: true), contains('.apk'));
      expect(config.storeUrlPour(android: false), contains('apple.com'));
    });
  });
}
