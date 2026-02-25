import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/admin_dashboard_controller.dart';
import 'admin_overview_view.dart';
import 'user_management_view.dart';
import 'department_management_view.dart';
import 'attendance_monitoring_view.dart';
import 'reports_analytics_view.dart';
import 'system_settings_view.dart';

class AdminDashboardView extends GetView<AdminDashboardController> {
  const AdminDashboardView({super.key});

  void _showLogoutConfirmation(
    BuildContext context,
    AdminDashboardController controller,
  ) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Do you want to logout?',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'No',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await controller.logout();
            },
            child: const Text(
              'Yes',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Obx(
      () => WillPopScope(
        // 🔹 AUTO-HIDE SIDEBAR ON BACK
        onWillPop: () async {
          if (controller.isMenuOpen.value) {
            controller.isMenuOpen.value = false;
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0C29),

          // 🔹 APP BAR WITH MENU ICON (TOP LEFT)
          appBar: AppBar(
            backgroundColor: const Color(0xFF1F3C88),
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                controller.isMenuOpen.value
                    ? Icons.close_rounded
                    : Icons.menu_rounded,
                color: Colors.white,
              ),
              onPressed: controller.toggleMenu,
            ),
            title: const Text(
              "Admin Dashboard",
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                onPressed: () => _showLogoutConfirmation(context, controller),
              ),
            ],
          ),

          // 🔹 BODY
          body: Stack(
            children: [
              // MAIN CONTENT
              SafeArea(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : IndexedStack(
                        index: controller.selectedTab.value,
                        children: const [
                          AdminOverviewView(),
                          UserManagementView(),
                          DepartmentManagementView(),
                          AttendanceMonitoringView(),
                          ReportsAnalyticsView(),
                          SystemSettingsView(),
                        ],
                      ),
              ),

              // 🔹 LEFT GLASS SIDEBAR
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 0,
                bottom: 0,
                left: controller.isMenuOpen.value ? 0 : -screenWidth * 0.75,
                width: screenWidth * 0.75,
                child: _buildGlassSidebar(controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================
  // 🔹 GLASS SIDEBAR
  // ================================
  Widget _buildGlassSidebar(AdminDashboardController controller) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            border: Border(
              right: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
          ),
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              _menuItem(Icons.home_rounded, "Home", 0, controller),
              _menuItem(Icons.people_alt_rounded, "Users", 1, controller),
              _menuItem(Icons.business_rounded, "Departments", 2, controller),
              _menuItem(Icons.analytics_rounded, "Attendance", 3, controller),
              _menuItem(Icons.assessment_rounded, "Reports", 4, controller),
              const Divider(color: Colors.white24),
              _menuItem(Icons.settings_rounded, "Profile", 5, controller),
            ],
          ),
        ),
      ),
    );
  }

  // ================================
  // 🔹 MENU ITEM
  // ================================
  Widget _menuItem(
    IconData icon,
    String title,
    int index,
    AdminDashboardController controller,
  ) {
    final bool isActive = controller.selectedTab.value == index;

    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.cyanAccent : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? Colors.cyanAccent : Colors.white,
          fontSize: 16,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: () => controller.changeTab(index),
    );
  }
}
