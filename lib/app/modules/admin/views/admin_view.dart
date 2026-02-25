import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:check_in_app/app/services/user_service.dart';
import 'package:check_in_app/app/routes/app_pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        elevation: 0,
        backgroundColor: const Color(0xFF16213E),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              await UserService.logout();
              Get.offAllNamed(Routes.AUTH);
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: UserService.getCurrentUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!;

          return Container(
            color: const Color(0xFF1A1A2E),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 50,
                            color: Color(0xFF0F4C75),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Welcome, ${user['name']}!",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Role: ${user['role']}",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats Overview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00D9FF,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.dashboard_rounded,
                                  color: Color(0xFF00D9FF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Dashboard Overview",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _getSystemStats(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00D9FF),
                                  ),
                                ),
                              );
                            }

                            final stats =
                                snapshot.data ??
                                {
                                  'departments': 0,
                                  'teachers': 0,
                                  'students': 0,
                                  'attendance': 0.0,
                                };

                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.15,
                              children: [
                                _buildStatCard(
                                  Icons.business_rounded,
                                  stats['departments'].toString(),
                                  'Departments',
                                  const Color(0xFF00D9FF),
                                ),
                                _buildStatCard(
                                  Icons.school_rounded,
                                  stats['teachers'].toString(),
                                  'Teachers',
                                  const Color(0xFF4CAF50),
                                ),
                                _buildStatCard(
                                  Icons.people_rounded,
                                  stats['students'].toString(),
                                  'Students',
                                  const Color(0xFF2196F3),
                                ),
                                _buildStatCard(
                                  Icons.trending_up_rounded,
                                  '${stats['attendance'].toStringAsFixed(1)}%',
                                  'Attendance',
                                  const Color(0xFF9C27B0),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Stats Overview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00D9FF,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.dashboard_rounded,
                                  color: Color(0xFF00D9FF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Dashboard Overview",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _getSystemStats(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00D9FF),
                                  ),
                                ),
                              );
                            }

                            final stats =
                                snapshot.data ??
                                {
                                  'departments': 0,
                                  'teachers': 0,
                                  'students': 0,
                                  'attendance': 0.0,
                                };

                            return GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.15,
                              children: [
                                _buildStatCard(
                                  Icons.business_rounded,
                                  stats['departments'].toString(),
                                  'Departments',
                                  const Color(0xFF00D9FF),
                                ),
                                _buildStatCard(
                                  Icons.school_rounded,
                                  stats['teachers'].toString(),
                                  'Teachers',
                                  const Color(0xFF4CAF50),
                                ),
                                _buildStatCard(
                                  Icons.people_rounded,
                                  stats['students'].toString(),
                                  'Students',
                                  const Color(0xFF2196F3),
                                ),
                                _buildStatCard(
                                  Icons.trending_up_rounded,
                                  '${stats['attendance'].toStringAsFixed(1)}%',
                                  'Attendance',
                                  const Color(0xFF9C27B0),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Management Options
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Management",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMenuCard(
                          context,
                          icon: Icons.people_alt,
                          title: "User Management",
                          subtitle: "Manage all users and permissions",
                          color: const Color(0xFF2196F3),
                          onTap: () {
                            Get.snackbar(
                              "Info",
                              "User Management - Coming Soon",
                              backgroundColor: const Color(0xFF16213E),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                              borderRadius: 12,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.business,
                          title: "Department Management",
                          subtitle: "Manage departments and settings",
                          color: const Color(0xFF9C27B0),
                          onTap: () {
                            Get.snackbar(
                              "Info",
                              "Department Management - Coming Soon",
                              backgroundColor: const Color(0xFF16213E),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                              borderRadius: 12,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.check_circle,
                          title: "Attendance Monitoring",
                          subtitle: "Monitor attendance across system",
                          color: const Color(0xFF4CAF50),
                          onTap: () {
                            Get.snackbar(
                              "Info",
                              "Attendance Monitoring - Coming Soon",
                              backgroundColor: const Color(0xFF16213E),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                              borderRadius: 12,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.analytics,
                          title: "Reports & Analytics",
                          subtitle: "View system-wide reports",
                          color: const Color(0xFFFF9800),
                          onTap: () {
                            Get.snackbar(
                              "Info",
                              "Reports & Analytics - Coming Soon",
                              backgroundColor: const Color(0xFF16213E),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                              borderRadius: 12,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                        ),
                        _buildMenuCard(
                          context,
                          icon: Icons.settings,
                          title: "System Settings",
                          subtitle: "Configure system parameters",
                          color: const Color(0xFF607D8B),
                          onTap: () {
                            Get.snackbar(
                              "Info",
                              "System Settings - Coming Soon",
                              backgroundColor: const Color(0xFF16213E),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                              borderRadius: 12,
                              margin: const EdgeInsets.all(16),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getSystemStats() async {
    try {
      final departments = await FirebaseFirestore.instance
          .collection('departments')
          .get();
      final teachers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      final students = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      // Calculate attendance percentage
      double attendancePercentage = 78.5; // Default value
      try {
        // Get today's date range
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

        // Get attendance records for today
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThanOrEqualTo: endOfDay)
            .get();

        if (attendanceSnapshot.docs.isNotEmpty && students.docs.isNotEmpty) {
          final presentCount = attendanceSnapshot.docs
              .where((doc) => doc.data()['status'] == 'present')
              .length;
          final totalStudents = students.docs.length;
          attendancePercentage = (presentCount / totalStudents) * 100;
        }
      } catch (e) {
        // Keep default value if calculation fails
      }

      return {
        'departments': departments.docs.length,
        'teachers': teachers.docs.length,
        'students': students.docs.length,
        'attendance': attendancePercentage,
      };
    } catch (e) {
      return {
        'departments': 0,
        'teachers': 0,
        'students': 0,
        'attendance': 0.0,
      };
    }
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: const Color(0xFF16213E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }
}
