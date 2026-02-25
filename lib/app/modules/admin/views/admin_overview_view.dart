import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/admin_dashboard_controller.dart';

class AdminOverviewView extends GetView<AdminDashboardController> {
  const AdminOverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _iconBox(Icons.dashboard_rounded, const Color(0xFF00D9FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Dashboard Overview",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Institution performance summary",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= STATS GRID =================

  Widget _buildStatsGrid() {
    final stats = [
      (
        "Departments",
        controller.totalDepartments.value.toString(),
        Icons.business_rounded,
        const Color(0xFF00D9FF),
      ),
      (
        "Teachers",
        controller.totalTeachers.value.toString(),
        Icons.school_rounded,
        const Color(0xFF4CAF50),
      ),
      (
        "Students",
        controller.totalStudents.value.toString(),
        Icons.people_rounded,
        const Color(0xFF2196F3),
      ),
      (
        "Attendance",
        "${controller.attendanceCompliance.value.toStringAsFixed(1)}%",
        Icons.trending_up_rounded,
        const Color(0xFF9C27B0),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final s = stats[index];
        return _statCard(s.$1, s.$2, s.$3, s.$4);
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(icon, color),
          const SizedBox(height: 10),

          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ================= RECENT ACTIVITY =================

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.history, const Color(0xFF00D9FF)),
              const SizedBox(width: 12),
              const Text(
                "Recent Activity",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          controller.recentActivities.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No recent activities',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                )
              : Column(
                  children: controller.recentActivities.map((activity) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (activity['color'] as Color).withOpacity(
                                0.2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              activity['icon'] as IconData,
                              color: activity['color'] as Color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity['title'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activity['subtitle'] as String,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            activity['time'] as String,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // ================= COMMON UI =================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: Colors.white.withOpacity(0.15)),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
