import 'package:get/get.dart';

import '../controllers/fournisseur_form_controller.dart';

class FournisseurFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FournisseurFormController>(() => FournisseurFormController());
  }
}
