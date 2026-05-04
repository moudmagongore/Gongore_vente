import 'package:get/get.dart';

import '../controllers/historique_mouvements_controller.dart';

class HistoriqueMouvementsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoriqueMouvementsController>(
      () => HistoriqueMouvementsController(),
    );
  }
}
