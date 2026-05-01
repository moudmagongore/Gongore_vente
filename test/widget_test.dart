import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:gongore_vente/main.dart';

void main() {
  setUpAll(() async {
    await GetStorage.init();
  });

  testWidgets('App boots and shows splash branding', (tester) async {
    await tester.pumpWidget(const GongoreApp());
    await tester.pump();
    expect(find.text('Gongoré Vente'), findsOneWidget);
  });
}
