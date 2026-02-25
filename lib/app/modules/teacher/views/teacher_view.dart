import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:check_in_app/app/services/user_service.dart';
import 'package:check_in_app/app/routes/app_pages.dart';

class TeacherView extends StatefulWidget {
  const TeacherView({super.key});

  @override
  State<TeacherView> createState() => _TeacherViewState();
}

class _TeacherViewState extends State<TeacherView> {
  bool isMenuOpen = false;
  String teacherName = '';
  String teacherEmail = '';
  String teacherDepartmentId = '';
  String teacherDepartmentName = '';
  String teacherUid = '';
  List<Map<String, dynamic>> todaySchedule = [];
  bool isLoadingSchedule = true;

  @override
  void initState() {
    super.initState();
    loadTeacherInfo();
  }

  Future<void> loadTeacherInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final departmentId = data['departmentId']?.toString() ?? '';
          final departmentFromUser = data['department']?.toString()?.trim();
          String? departmentName;
          if (departmentFromUser != null && departmentFromUser.isNotEmpty) {
            departmentName = departmentFromUser;
          } else {
            departmentName = await UserService.resolveDepartmentName(
              departmentId,
            );
          }
          if (mounted) {
            setState(() {
              teacherName = data['name']?.toString() ?? '';
              teacherEmail = data['email']?.toString() ?? '';
              teacherDepartmentId = departmentId;
              teacherDepartmentName = departmentName ?? '';
              teacherUid = user.uid;
            });
          }

          // Load today's schedule after getting teacher info
          await loadTodaySchedule();
        }
      }
    } catch (e) {
      print('Error loading teacher info: $e');
    }
  }

  String getCurrentDay() {
    final now = DateTime.now();
    switch (now.weekday) {
      case 1:
        return 'mon';
      case 2:
        return 'tue';
      case 3:
        return 'wed';
      case 4:
        return 'thu';
      case 5:
        return 'fri';
      default:
        return 'mon'; // Default to Monday for weekends
    }
  }

  Future<void> loadTodaySchedule() async {
    if (teacherDepartmentId.isEmpty || teacherUid.isEmpty) return;

    if (mounted) {
      setState(() {
        isLoadingSchedule = true;
      });
    }

    try {
      final today = getCurrentDay();

      // Get all classes for this department
      final classesQuery = await FirebaseFirestore.instance
          .collection('classes')
          .where('departmentId', isEqualTo: teacherDepartmentId)
          .get();

      final classMap = <String, String>{};
      for (var doc in classesQuery.docs) {
        classMap[doc.id] = doc.data()['name']?.toString() ?? doc.id;
      }

      // Query each class's timetable for today
      // Structure: timetable/{departmentId}/{classId}/{day}/slots
      final schedule = <Map<String, dynamic>>[];

      for (var classDoc in classesQuery.docs) {
        final classId = classDoc.id;
        final className = classMap[classId] ?? classId;

        final slotsQuery = await FirebaseFirestore.instance
            .collection('timetable')
            .doc(teacherDepartmentId)
            .collection(classId)
            .doc(today)
            .collection('slots')
            .where('teacherUid', isEqualTo: teacherUid)
            .get();

        for (var slotDoc in slotsQuery.docs) {
          final data = slotDoc.data();
          schedule.add({
            'class': className,
            'subject': data['subject']?.toString() ?? '',
            'period': slotDoc.id,
            'classId': classId,
          });
        }
      }

      // Sort by period
      schedule.sort((a, b) => a['period'].compareTo(b['period']));

      if (mounted) {
        setState(() {
          todaySchedule = schedule;
          isLoadingSchedule = false;
        });
      }
    } catch (e) {
      print('Error loading schedule: $e');
      if (mounted) {
        setState(() {
          isLoadingSchedule = false;
        });
      }
    }
  }

  void toggleMenu() {
    setState(() {
      isMenuOpen = !isMenuOpen;
    });
  }

  void _showLogoutConfirmation(BuildContext context) {
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
              await FirebaseAuth.instance.signOut();
              Get.offAllNamed(Routes.AUTH);
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
    final screenHeight = MediaQuery.of(context).size.height;

    return WillPopScope(
      onWillPop: () async {
        if (isMenuOpen) {
          setState(() {
            isMenuOpen = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isMenuOpen ? Icons.close_rounded : Icons.menu_rounded,
              color: Colors.white,
            ),
            onPressed: toggleMenu,
          ),
          title: const Text(
            "Teacher Dashboard",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            // MAIN CONTENT
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome Back!",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              teacherName.isEmpty ? "Teacher" : teacherName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Department: ${teacherDepartmentName.isNotEmpty ? teacherDepartmentName : (teacherDepartmentId.isNotEmpty ? teacherDepartmentId : 'N/A')}",
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Today's Classes
                      _buildSectionTitle("Today's Schedule"),
                      const SizedBox(height: 12),
                      _buildTodaySchedule(),

                      const SizedBox(height: 24),

                      // Recent Attendance Activity
                      _buildSectionTitle("Recent Attendance Activity"),
                      const SizedBox(height: 12),
                      _buildRecentActivity(),

                      const SizedBox(height: 24),

                      // Pending Tasks
                      _buildSectionTitle("Pending Tasks"),
                      const SizedBox(height: 12),
                      _buildPendingTasks(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // GLASS SIDEBAR (MUST be outside Column)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: 0,
              bottom: 0,
              left: isMenuOpen ? 0 : -MediaQuery.of(context).size.width * 0.75,
              width: MediaQuery.of(context).size.width * 0.75,
              child: _buildGlassSidebar(),
            ),
          ],
        ),
      ),
    );
  }

  // Section Title Widget
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  // Today's Schedule
  Widget _buildTodaySchedule() {
    if (isLoadingSchedule) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFF00D9FF),
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    if (todaySchedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.event_busy, color: Colors.white54, size: 48),
              SizedBox(height: 12),
              Text(
                'No classes scheduled for today',
                style: TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: todaySchedule.asMap().entries.map((entry) {
          final index = entry.key;
          final cls = entry.value;
          final isLast = index == todaySchedule.length - 1;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.schedule,
                    color: Color(0xFF00D9FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cls['subject']?.toString() ?? 'No Subject',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cls['class']?.toString() ?? 'Unknown Class',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    cls['period']?.toString() ?? 'N/A',
                    style: const TextStyle(
                      color: Color(0xFF00D9FF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Recent Activity
  Widget _buildRecentActivity() {
    final activities = [
      {'action': 'Marked attendance for BCA 3rd Sem', 'time': '2 hours ago'},
      {'action': 'Updated attendance for BBA 2nd Sem', 'time': 'Yesterday'},
      {'action': 'Submitted monthly report', 'time': '2 days ago'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: activities.map((activity) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF4CAF50),
              radius: 6,
            ),
            title: Text(
              activity['action']!,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              activity['time']!,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Pending Tasks
  Widget _buildPendingTasks() {
    final tasks = [
      {'task': 'Mark attendance for today', 'priority': 'High'},
      {'task': 'Submit weekly report', 'priority': 'Medium'},
      {'task': 'Update student records', 'priority': 'Low'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: tasks.map((task) {
          final priorityColor = task['priority'] == 'High'
              ? Colors.red
              : task['priority'] == 'Medium'
              ? Colors.orange
              : Colors.green;
          return ListTile(
            leading: Icon(
              Icons.radio_button_unchecked,
              color: Colors.white70,
              size: 20,
            ),
            title: Text(
              task['task']!,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: priorityColor),
              ),
              child: Text(
                task['priority']!,
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Glass Sidebar
  Widget _buildGlassSidebar() {
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
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Profile Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue[700],
                      child: Text(
                        teacherName.isNotEmpty
                            ? teacherName[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      teacherName.isEmpty ? "Teacher" : teacherName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacherEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _sidebarItem(
                      Icons.check_circle_outline,
                      "Mark Attendance",
                      Routes.TEACHER_ATTENDANCE,
                    ),
                    _sidebarItem(
                      Icons.edit_note,
                      "Edit Today's Attendance",
                      Routes.EDITABLE_ATTENDANCE_LIST,
                    ),
                    _sidebarItem(
                      Icons.history,
                      "Attendance History",
                      Routes.ATTENDANCE_HISTORY,
                    ),
                    _sidebarItem(
                      Icons.groups,
                      "My Students",
                      Routes.STUDENT_LIST,
                    ),
                    _sidebarItem(
                      Icons.assignment_outlined,
                      "Leave Management",
                      Routes.LEAVE_MANAGEMENT,
                    ),
                    _sidebarItem(
                      Icons.analytics,
                      "Reports",
                      Routes.TEACHER_REPORTS,
                    ),
                    const Divider(color: Colors.white24),
                    _sidebarItem(
                      Icons.person,
                      "My Profile",
                      Routes.TEACHER_PROFILE,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sidebar Item
  Widget _sidebarItem(IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: () {
        setState(() {
          isMenuOpen = false;
        });
        Get.toNamed(route);
      },
    );
  }
}
