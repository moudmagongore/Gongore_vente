import 'package:get/get.dart';

import '../controllers/user_form_controller.dart';

class UserFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserFormController>(() => UserFormController());
  }
}
