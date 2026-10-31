import 'package:get/get.dart';

import '../controllers/caisse_form_controller.dart';

class CaisseFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CaisseFormController>(() => CaisseFormController());
  }
}
