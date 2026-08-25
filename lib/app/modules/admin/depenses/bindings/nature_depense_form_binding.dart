import 'package:get/get.dart';

import '../controllers/nature_depense_form_controller.dart';

class NatureDepenseFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NatureDepenseFormController>(
      () => NatureDepenseFormController(),
    );
  }
}
