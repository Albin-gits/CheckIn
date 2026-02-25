import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/system_settings_controller.dart';

class SystemSettingsView extends GetView<SystemSettingsController> {
  const SystemSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _loadAdminProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final adminName = data?['name'] ?? 'Admin User';
        final adminEmail = data?['email'] ?? '';
        final role = data?['role'] ?? 'admin';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      adminName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Profile Information
              const Text(
                'Profile Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.person,
                label: 'Full Name',
                value: adminName,
                color: Colors.blue,
              ),
              _buildInfoCard(
                icon: Icons.email,
                label: 'Email',
                value: adminEmail,
                color: Colors.purple,
              ),
              _buildInfoCard(
                icon: Icons.admin_panel_settings,
                label: 'Role',
                value: role.toUpperCase(),
                color: Colors.orange,
              ),
              _buildInfoCard(
                icon: Icons.security,
                label: 'Privileges',
                value: 'Full System Access',
                color: Colors.green,
              ),
              const SizedBox(height: 24),

              // System Stats
              const Text(
                'System Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildStatCard(),
              const SizedBox(height: 24),

              // About
              const Text(
                'About',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: const [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Check-In App',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.copyright, color: Colors.white70, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<DocumentSnapshot> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
    }
    throw Exception('No user logged in');
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSystemStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            {
              'departments': 0,
              'teachers': 0,
              'students': 0,
              'classes': 0,
              'attendance': 0.0,
            };

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.business,
                      'Departments',
                      stats['departments'].toString(),
                      const Color(0xFF00D9FF),
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.school,
                      'Teachers',
                      stats['teachers'].toString(),
                      const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.people,
                      'Students',
                      stats['students'].toString(),
                      const Color(0xFF2196F3),
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      Icons.trending_up,
                      'Attendance',
                      '${stats['attendance'].toStringAsFixed(1)}%',
                      const Color(0xFF9C27B0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
      ],
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
      final classes = await FirebaseFirestore.instance
          .collection('classes')
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
        'classes': classes.docs.length,
        'attendance': attendancePercentage,
      };
    } catch (e) {
      return {
        'departments': 0,
        'teachers': 0,
        'students': 0,
        'classes': 0,
        'attendance': 0.0,
      };
    }
  }
}
