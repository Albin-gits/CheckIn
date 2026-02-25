import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassManagementView extends StatefulWidget {
  const ClassManagementView({super.key});

  @override
  State<ClassManagementView> createState() => _ClassManagementViewState();
}

class _ClassManagementViewState extends State<ClassManagementView> {
  String departmentId = '';
  bool isLoading = true;
  List<Map<String, dynamic>> classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final deptId = doc.data()?['departmentId']?.toString() ?? '';
          if (mounted) {
            setState(() {
              departmentId = deptId;
            });
          }

          // Load classes in department
          final classesSnapshot = await FirebaseFirestore.instance
              .collection('classes')
              .where('departmentId', isEqualTo: deptId)
              .get();

          List<Map<String, dynamic>> classesList = [];

          for (var classDoc in classesSnapshot.docs) {
            final data = classDoc.data();
            final classId = classDoc.id;

            // Get student count
            final studentsSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'student')
                .where('classId', isEqualTo: classId)
                .get();

            // Get faculty advisor name
            String? facultyAdvisorName;
            final facultyAdvisorUid = data['facultyAdvisorUid'];
            if (facultyAdvisorUid != null) {
              try {
                final teacherDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(facultyAdvisorUid)
                    .get();
                if (teacherDoc.exists) {
                  facultyAdvisorName = teacherDoc.data()?['name'];
                }
              } catch (e) {
                print('Error loading faculty advisor: $e');
              }
            }

            classesList.add({
              'id': classId,
              'name': data['name'] ?? 'Unknown',
              'studentCount': studentsSnapshot.docs.length,
              'facultyAdvisor': facultyAdvisorName,
              'facultyAdvisorUid': facultyAdvisorUid,
            });
          }

          if (mounted) {
            setState(() {
              classes = classesList;
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading classes: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _showClassDetails(Map<String, dynamic> classData) async {
    // Load students in this class
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: classData['id'])
        .get();

    final students = studentsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {'name': data['name'] ?? 'Unknown', 'email': data['email'] ?? ''};
    }).toList();

    students.sort((a, b) => a['name'].compareTo(b['name']));

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      classData['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (classData['facultyAdvisor'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Faculty Advisor: ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      classData['facultyAdvisor'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Total Students: ${students.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              const Text(
                'Students List',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No students enrolled',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green.withOpacity(0.2),
                              child: Text(
                                student['name'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    student['email'],
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
        title: const Text(
          'Class Management',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          : classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.class_outlined, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    'No classes found',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final classData = classes[index];
                return _buildClassCard(classData);
              },
            ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showClassDetails(classData),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.class_,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            classData['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (classData['facultyAdvisor'] != null)
                            Text(
                              'Advisor: ${classData['facultyAdvisor']}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.school, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${classData['studentCount']} Students',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
