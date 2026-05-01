import 'package:get/get.dart';

import '../controllers/produit_form_controller.dart';

class ProduitFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProduitFormController>(() => ProduitFormController());
  }
}
