import 'package:get/get.dart';

import '../controllers/produits_controller.dart';

class ProduitsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProduitsController>(() => ProduitsController());
  }
}
