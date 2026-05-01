import 'package:get/get.dart';

import '../controllers/categorie_form_controller.dart';

class CategorieFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CategorieFormController>(() => CategorieFormController());
  }
}
