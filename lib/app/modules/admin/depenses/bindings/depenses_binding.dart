import 'package:get/get.dart';

import '../controllers/depenses_controller.dart';

class DepensesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DepensesController>(() => DepensesController());
  }
}
