import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:check_in_app/app/services/user_service.dart';

class StudentProfileView extends StatefulWidget {
  const StudentProfileView({super.key});

  @override
  State<StudentProfileView> createState() => _StudentProfileViewState();
}

class _StudentProfileViewState extends State<StudentProfileView> {
  bool isLoading = true;
  String studentName = '';
  String studentEmail = '';
  String className = '';
  String departmentName = '';
  String role = '';
  String facultyAdvisorName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final classId = data['classId']?.toString() ?? '';
          final deptId = data['departmentId']?.toString() ?? '';

          // Get class name
          String? clsName = data['className']?.toString();
          String? facultyAdvisor;
          if ((clsName == null || clsName.isEmpty) && classId.isNotEmpty) {
            try {
              final classDoc = await FirebaseFirestore.instance
                  .collection('classes')
                  .doc(classId)
                  .get();
              if (classDoc.exists) {
                clsName = classDoc.data()?['name'] ?? classId;
                final advisorUid = classDoc.data()?['facultyAdvisorUid'];
                if (advisorUid != null) {
                  // Fetch faculty advisor name
                  final advisorDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(advisorUid)
                      .get();
                  if (advisorDoc.exists) {
                    facultyAdvisor = advisorDoc.data()?['name'] ?? 'N/A';
                  }
                }
              }
            } catch (e) {
              clsName = classId;
            }
          } else if (classId.isNotEmpty) {
            // Still fetch faculty advisor even if class name exists
            try {
              final classDoc = await FirebaseFirestore.instance
                  .collection('classes')
                  .doc(classId)
                  .get();
              if (classDoc.exists) {
                final advisorUid = classDoc.data()?['facultyAdvisorUid'];
                if (advisorUid != null) {
                  final advisorDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(advisorUid)
                      .get();
                  if (advisorDoc.exists) {
                    facultyAdvisor = advisorDoc.data()?['name'] ?? 'N/A';
                  }
                }
              }
            } catch (e) {
              // Ignore error
            }
          }

          // Get department name
          String? deptName = data['department']?.toString();
          if ((deptName == null || deptName.isEmpty) && deptId.isNotEmpty) {
            deptName = await UserService.resolveDepartmentName(deptId);
          }

          if (mounted) {
            setState(() {
              studentName = data['name'] ?? '';
              studentEmail = data['email'] ?? '';
              className = clsName ?? 'N/A';
              departmentName = deptName ?? 'N/A';
              role = data['role'] ?? '';
              facultyAdvisorName = facultyAdvisor ?? 'N/A';
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          : SingleChildScrollView(
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
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            studentName.isNotEmpty
                                ? studentName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          studentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          studentEmail,
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
                    value: studentName,
                    color: Colors.blue,
                  ),
                  _buildInfoCard(
                    icon: Icons.email,
                    label: 'Email',
                    value: studentEmail,
                    color: Colors.purple,
                  ),
                  _buildInfoCard(
                    icon: Icons.class_,
                    label: 'Class',
                    value: className,
                    color: Colors.orange,
                  ),
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    label: 'Faculty Advisor',
                    value: facultyAdvisorName,
                    color: Colors.teal,
                  ),
                  _buildInfoCard(
                    icon: Icons.business,
                    label: 'Department',
                    value: departmentName,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),

                  // App Info
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
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
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
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.copyright,
                              color: Colors.white70,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Version 1.0.0',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
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
        color: const Color(0xFF16213E),
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
