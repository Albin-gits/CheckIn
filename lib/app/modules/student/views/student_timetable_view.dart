import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentTimetableView extends StatefulWidget {
  const StudentTimetableView({super.key});

  @override
  State<StudentTimetableView> createState() => _StudentTimetableViewState();
}

class _StudentTimetableViewState extends State<StudentTimetableView> {
  String classId = '';
  String className = '';
  String departmentId = '';
  String selectedDay = 'mon';
  List<Map<String, dynamic>> timetable = [];
  bool isLoadingTimetable = true;
  Map<String, String> teachersCache = {};
  bool teachersCacheLoaded = false;

  static const List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri'];
  static const Map<String, String> periodTimes = {
    'P1': '8:30 to 9:25',
    'P2': '9:30 to 10:20',
    'P3': '10:40 to 11:35',
    'P4': '11:40 to 12:30',
    'P5': '12:35 to 1:35',
  };

  @override
  void initState() {
    super.initState();
    _loadTimetableData();
  }

  Future<void> _loadTimetableData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final clsId = data['classId']?.toString() ?? '';
          var deptId = data['departmentId']?.toString() ?? '';
          final clsFromUser = data['className']?.toString()?.trim();

          String? clsName;

          if (clsId.isNotEmpty) {
            try {
              final classDoc = await FirebaseFirestore.instance
                  .collection('classes')
                  .doc(clsId)
                  .get();
              if (classDoc.exists && classDoc.data() != null) {
                final classData = classDoc.data()!;
                clsName = clsFromUser ?? classData['name']?.toString() ?? clsId;

                if (deptId.isEmpty) {
                  deptId = classData['departmentId']?.toString() ?? '';
                }
              } else {
                clsName = clsFromUser ?? clsId;
              }
            } catch (e) {
              clsName = clsFromUser ?? clsId;
            }
          } else {
            clsName = clsFromUser;
          }

          if (mounted) {
            setState(() {
              classId = clsId;
              className = clsName ?? '';
              departmentId = deptId;
            });
          }

          if (classId.isNotEmpty && departmentId.isNotEmpty) {
            await loadTimetable();
          } else {
            if (mounted) {
              setState(() {
                isLoadingTimetable = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              isLoadingTimetable = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoadingTimetable = false;
          });
        }
      }
    } catch (e) {
      print('Error loading timetable data: $e');
      if (mounted) {
        setState(() {
          isLoadingTimetable = false;
        });
      }
    }
  }

  String dayLabel(String dayKey) {
    switch (dayKey) {
      case 'mon':
        return 'Monday';
      case 'tue':
        return 'Tuesday';
      case 'wed':
        return 'Wednesday';
      case 'thu':
        return 'Thursday';
      case 'fri':
        return 'Friday';
      default:
        return dayKey;
    }
  }

  Future<void> loadTimetable() async {
    if (departmentId.isEmpty || classId.isEmpty) {
      if (mounted) {
        setState(() {
          isLoadingTimetable = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingTimetable = true;
      });
    }

    try {
      final slotsQuery = await FirebaseFirestore.instance
          .collection('timetable')
          .doc(departmentId)
          .collection(classId)
          .doc(selectedDay)
          .collection('slots')
          .get();

      final teacherUids = <String>{};
      for (var doc in slotsQuery.docs) {
        var teacherUid = doc.data()['teacherUid']?.toString() ?? '';
        if (teacherUid.isEmpty) {
          teacherUid = doc.data()['overrideTeacherUid']?.toString() ?? '';
        }
        if (teacherUid.isNotEmpty) {
          teacherUids.add(teacherUid);
        }
      }

      if (!teachersCacheLoaded ||
          teacherUids.any((uid) => !teachersCache.containsKey(uid))) {
        await _loadTeachersCache(teacherUids);
      }

      final schedule = <Map<String, dynamic>>[];
      final periods = ['P1', 'P2', 'P3', 'P4', 'P5'];

      for (final period in periods) {
        final matchingSlots = slotsQuery.docs
            .where((doc) => doc.id == period)
            .toList();

        if (matchingSlots.isNotEmpty) {
          final data = matchingSlots.first.data();
          var teacherUid = data['teacherUid']?.toString() ?? '';
          if (teacherUid.isEmpty) {
            teacherUid = data['overrideTeacherUid']?.toString() ?? '';
          }
          final subject = data['subject']?.toString() ?? '';

          String teacherName = teachersCache[teacherUid] ?? '';
          if (teacherName.isEmpty && teacherUid.isNotEmpty) {
            try {
              final teacherDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(teacherUid)
                  .get();
              if (teacherDoc.exists) {
                final td = teacherDoc.data() ?? {};
                teacherName = (td['name']?.toString() ?? '').trim();
                if (teacherName.isEmpty) {
                  teacherName = (td['displayName']?.toString() ?? '').trim();
                }
                if (teacherName.isEmpty) {
                  teacherName = (td['email']?.toString() ?? '').trim();
                }
                if (teacherName.isEmpty) {
                  teacherName = teacherUid;
                }
                teachersCache[teacherUid] = teacherName;
              } else {
                teacherName = teacherUid;
                teachersCache[teacherUid] = teacherName;
              }
            } catch (e) {
              print('Error loading teacher $teacherUid: $e');
              teacherName = teacherUid;
              teachersCache[teacherUid] = teacherName;
            }
          } else if (teacherName.isEmpty) {
            teacherName = 'Not Assigned';
          }

          schedule.add({
            'period': period,
            'subject': subject,
            'teacher': teacherName,
            'hasClass': true,
          });
        } else {
          schedule.add({
            'period': period,
            'subject': '',
            'teacher': '',
            'hasClass': false,
          });
        }
      }

      if (mounted) {
        setState(() {
          timetable = schedule;
          isLoadingTimetable = false;
        });
      }
    } catch (e) {
      print('Error in loadTimetable: $e');
      if (mounted) {
        setState(() {
          isLoadingTimetable = false;
        });
      }
    }
  }

  Future<void> _loadTeachersCache(Set<String> requiredUids) async {
    try {
      if (requiredUids.isEmpty) {
        final teachersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .where('departmentId', isEqualTo: departmentId)
            .get();

        for (var doc in teachersQuery.docs) {
          final name = doc.data()['name']?.toString() ?? doc.id;
          teachersCache[doc.id] = name;
        }
      } else {
        final missingUids = requiredUids
            .where((uid) => !teachersCache.containsKey(uid))
            .toList();

        if (missingUids.isNotEmpty) {
          final futures = missingUids.map(
            (uid) =>
                FirebaseFirestore.instance.collection('users').doc(uid).get(),
          );

          final results = await Future.wait(futures);

          for (var doc in results) {
            if (doc.exists) {
              final name = doc.data()?['name']?.toString() ?? doc.id;
              teachersCache[doc.id] = name;
            } else {
              teachersCache[doc.id] = 'Unknown Teacher';
            }
          }
        }
      }
      teachersCacheLoaded = true;
    } catch (e) {
      print('Error loading teachers cache: $e');
    }
  }

  void onDayChanged(String day) {
    setState(() {
      selectedDay = day;
    });
    loadTimetable();
  }

  Widget _buildDaySelector() {
    final dayLabels = [
      {'key': 'mon', 'label': 'Monday'},
      {'key': 'tue', 'label': 'Tuesday'},
      {'key': 'wed', 'label': 'Wednesday'},
      {'key': 'thu', 'label': 'Thursday'},
      {'key': 'fri', 'label': 'Friday'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          const Text(
            'Day:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedDay,
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                items: dayLabels.map((day) {
                  return DropdownMenuItem<String>(
                    value: day['key'],
                    child: Text(
                      day['label']!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onDayChanged(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetable() {
    if (isLoadingTimetable) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: List.generate(5, (index) => _buildSkeletonPeriod()),
        ),
      );
    }

    if (timetable.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.event_busy, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                classId.isEmpty || departmentId.isEmpty
                    ? 'Student class/department not configured'
                    : 'No timetable found for ${dayLabel(selectedDay)}',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (classId.isNotEmpty && departmentId.isNotEmpty) ...[
                Text(
                  'Class: $className ($classId)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Department: $departmentId',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'HOD needs to create the timetable for this class',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.7),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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
        children: timetable.asMap().entries.map((entry) {
          final index = entry.key;
          final period = entry.value;
          final isLast = index == timetable.length - 1;
          final hasClass = period['hasClass'] == true;

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasClass
                        ? const Color(0xFF2196F3).withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasClass
                          ? const Color(0xFF2196F3).withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    period['period']?.toString() ?? '',
                    style: TextStyle(
                      color: hasClass ? const Color(0xFF2196F3) : Colors.grey,
                      fontSize: 14,
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
                        hasClass
                            ? (period['subject']?.toString() ?? 'No Subject')
                            : 'Free Period',
                        style: TextStyle(
                          color: hasClass ? Colors.white : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasClass) ...[
                        const SizedBox(height: 4),
                        Text(
                          periodTimes[period['period']?.toString() ?? ''] ??
                              'Unknown',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkeletonPeriod() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          'My Timetable',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadTimetableData();
          },
          color: const Color(0xFF00D9FF),
          backgroundColor: const Color(0xFF16213E),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Info Card
                if (className.isNotEmpty || classId.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.class_, color: Colors.white, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Class',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                className.isNotEmpty ? className : classId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Timetable Title
                Text(
                  dayLabel(selectedDay),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Day Selector
                _buildDaySelector(),
                const SizedBox(height: 20),

                // Timetable
                _buildTimetable(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
