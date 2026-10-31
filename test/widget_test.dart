import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gongore_vente/app/core/constants/app_constants.dart';
import 'package:gongore_vente/app/modules/splash/views/splash_view.dart';

/// Ce test montait auparavant `GongoreApp` en entier. Il échouait pour deux
/// raisons cumulées, et pas seulement le changement de nom de l'app :
///
///   1. `GetStorage.init()` appelle `path_provider`, dont aucun binding
///      natif n'existe sous `flutter test` → `MissingPluginException` ;
///   2. monter l'app entière déclenche la route splash, donc
///      `SplashController.onReady` → `AuthService` / `FirestoreService`,
///      c'est-à-dire Firebase. Non initialisable en test unitaire sans
///      toute une infrastructure de mocks.
///
/// On teste donc l'écran isolément, dans un `MaterialApp` neutre : c'est
/// stable, rapide, et cela vérifie réellement le rendu. Un test de bout en
/// bout du démarrage relèverait d'un test d'intégration.
void main() {
  testWidgets('Le splash affiche son accroche et son indicateur de chargement',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashView()));
    await tester.pump();

    expect(
      find.textContaining('Gardez le contrôle de votre boutique'),
      findsOneWidget,
    );
    expect(find.text('Chargement...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('Le nom de l\'application est celui attendu', () {
    expect(AppConstants.appName, 'Gongore App');
  });
}
