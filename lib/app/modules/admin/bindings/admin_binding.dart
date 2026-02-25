import 'package:get/get.dart';
import '../controllers/admin_dashboard_controller.dart';
import '../controllers/user_management_controller.dart';
import '../controllers/department_management_controller.dart';
import '../controllers/reports_analytics_controller.dart';
import '../controllers/attendance_monitoring_controller.dart';
import '../controllers/system_settings_controller.dart';

class AdminBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminDashboardController>(() => AdminDashboardController());
    Get.lazyPut<UserManagementController>(() => UserManagementController());
    Get.lazyPut<DepartmentManagementController>(
      () => DepartmentManagementController(),
    );
    Get.lazyPut<ReportsAnalyticsController>(() => ReportsAnalyticsController());
    Get.lazyPut<AttendanceMonitoringController>(
      () => AttendanceMonitoringController(),
    );
    Get.lazyPut<SystemSettingsController>(() => SystemSettingsController());
  }
}
