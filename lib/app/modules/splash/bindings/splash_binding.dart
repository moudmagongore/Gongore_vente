import 'package:get/get.dart';

import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Eager (`put` au lieu de `lazyPut`) parce que la SplashView ne lit pas
    // le controller : sans cela `onReady` ne se déclenche jamais et la
    // redirection ne se fait pas.
    Get.put<SplashController>(SplashController());
  }
}
