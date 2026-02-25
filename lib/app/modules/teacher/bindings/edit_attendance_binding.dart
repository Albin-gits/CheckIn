import 'package:get/get.dart';
import '../controllers/edit_attendance_controller.dart';

class EditAttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EditAttendanceController>(() => EditAttendanceController());
  }
}
