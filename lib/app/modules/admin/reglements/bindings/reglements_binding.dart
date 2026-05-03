import 'package:get/get.dart';

import '../controllers/reglements_controller.dart';

class ReglementsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReglementsController>(() => ReglementsController());
  }
}
