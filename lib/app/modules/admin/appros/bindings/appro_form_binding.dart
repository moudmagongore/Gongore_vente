import 'package:get/get.dart';

import '../controllers/appro_form_controller.dart';

class ApproFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ApproFormController>(() => ApproFormController());
  }
}
