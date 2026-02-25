import 'package:get/get.dart';
import '../controllers/teacher_reports_controller.dart';

class TeacherReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TeacherReportsController>(() => TeacherReportsController());
  }
}
