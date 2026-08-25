import 'package:get/get.dart';

import '../controllers/vente_form_controller.dart';

class VenteFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VenteFormController>(() => VenteFormController());
  }
}
