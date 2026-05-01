import 'package:get/get.dart';

import '../controllers/vendeur_home_controller.dart';

class VendeurHomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VendeurHomeController>(() => VendeurHomeController());
  }
}
