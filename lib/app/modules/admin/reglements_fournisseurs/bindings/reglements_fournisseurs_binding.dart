import 'package:get/get.dart';

import '../controllers/reglements_fournisseurs_controller.dart';

class ReglementsFournisseursBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReglementsFournisseursController>(
      () => ReglementsFournisseursController(),
    );
  }
}
