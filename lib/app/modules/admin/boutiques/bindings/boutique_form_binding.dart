import 'package:get/get.dart';

import '../controllers/boutique_form_controller.dart';

class BoutiqueFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BoutiqueFormController>(() => BoutiqueFormController());
  }
}
