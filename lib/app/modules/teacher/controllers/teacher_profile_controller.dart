import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherProfileController extends GetxController {
  final email = ''.obs;

  @override
  void onInit() {
    super.onInit();
    email.value = FirebaseAuth.instance.currentUser!.email ?? '';
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    Get.offAllNamed('/auth');
  }
}
