import 'package:get/get.dart';

import '../controllers/fournisseur_detail_controller.dart';

class FournisseurDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FournisseurDetailController>(
      () => FournisseurDetailController(),
    );
  }
}
