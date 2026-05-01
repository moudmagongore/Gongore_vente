import 'package:get/get.dart';

import '../controllers/boutiques_controller.dart';

class BoutiquesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BoutiquesController>(() => BoutiquesController());
  }
}
