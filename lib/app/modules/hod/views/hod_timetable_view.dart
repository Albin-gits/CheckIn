import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/hod_timetable_controller.dart';

class HodTimetableView extends GetView<HodTimetableController> {
  const HodTimetableView({super.key});

  Future<void> _openEditSlotDialog({
    required BuildContext context,
    required String classId,
    required String period,
    Map<String, dynamic>? existing,
  }) async {
    if (controller.classes.isEmpty || controller.teachers.isEmpty) {
      Get.snackbar(
        'Error',
        'Classes/Teachers not loaded yet',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    // Ensure teacherUid is valid (exists in teachers list)
    String existingTeacherUid = (existing?['teacherUid'] ?? '').toString();
    bool teacherExists = controller.teachers.any(
      (t) => t['uid'].toString() == existingTeacherUid,
    );
    String teacherUid = teacherExists
        ? existingTeacherUid
        : controller.teachers.first['uid'].toString();

    // Ensure subject is valid (exists in subjects list)
    String existingSubject = (existing?['subject'] ?? '').toString();
    bool subjectExists = HodTimetableController.subjects.contains(
      existingSubject,
    );
    String subject = subjectExists
        ? existingSubject
        : HodTimetableController.subjects.first;

    String? overrideTeacherUid = (existing?['overrideTeacherUid'] ?? '')
        .toString();
    // Default to 'NONE' if no substitute is assigned
    if (overrideTeacherUid == null || overrideTeacherUid.isEmpty) {
      overrideTeacherUid = 'NONE';
    }

    await Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'Add Timetable Slot' : 'Edit Timetable Slot',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Class: ${controller.className(classId)}',
                      style: const TextStyle(
                        color: Color(0xFF00D9FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Period: $period',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: teacherUid,
                    dropdownColor: const Color(0xFF16213E),
                    decoration: const InputDecoration(
                      labelText: 'Teacher',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    items: controller.teachers
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t['uid'].toString(),
                            child: Text(
                              t['name'].toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => teacherUid = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: subject,
                    dropdownColor: const Color(0xFF16213E),
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    items: HodTimetableController.subjects
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(
                              s,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => subject = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  const Text(
                    'Substitute Teacher',
                    style: TextStyle(
                      color: Color(0xFF00D9FF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: overrideTeacherUid,
                    dropdownColor: const Color(0xFF16213E),
                    decoration: const InputDecoration(
                      labelText: 'Select Substitute',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                      helperText:
                          'Teacher to mark attendance if main teacher is absent',
                      helperStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'NONE',
                        child: Text(
                          'None',
                          style: TextStyle(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      ...controller.teachers
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t['uid'].toString(),
                              child: Text(
                                t['name'].toString(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => overrideTeacherUid = v);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                try {
                  await controller.deleteSlot(classId: classId, period: period);
                  Get.back();
                  Get.snackbar(
                    'Success',
                    'Slot deleted',
                    backgroundColor: const Color(0xFF4CAF50),
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    e.toString(),
                    backgroundColor: const Color(0xFFD32F2F),
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await controller.upsertSlot(
                  classId: classId,
                  period: period,
                  teacherUid: teacherUid,
                  overrideEnabled: true,
                  overrideTeacherUid: overrideTeacherUid == 'NONE'
                      ? ''
                      : overrideTeacherUid,
                  subject: subject,
                );
                Get.back();
                Get.snackbar(
                  'Success',
                  'Slot saved',
                  backgroundColor: const Color(0xFF4CAF50),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                  margin: const EdgeInsets.all(16),
                  borderRadius: 12,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  e.toString(),
                  backgroundColor: const Color(0xFFD32F2F),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                  margin: const EdgeInsets.all(16),
                  borderRadius: 12,
                );
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Map<String, dynamic>? _getSlot(String classId, String period) {
    // Only return slot if it's for the currently selected class
    if (controller.selectedClassId.value != classId) {
      return null;
    }

    try {
      return controller.slots.firstWhere(
        (s) => s['period'].toString() == period,
      );
    } catch (e) {
      return null;
    }
  }

  Widget _buildTimetableList() {
    if (controller.classes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No classes found in your department',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Only show the selected class (not all classes)
    final displayClasses = controller.selectedClassId.value.isEmpty
        ? <Map<String, dynamic>>[]
        : controller.classes
              .where((c) => c['id'] == controller.selectedClassId.value)
              .toList();

    if (displayClasses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Please select a class from the dropdown above',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: displayClasses.length,
      itemBuilder: (context, index) {
        final classItem = displayClasses[index];
        final classId = classItem['id'].toString();
        final className = classItem['name'].toString();

        return Card(
          color: const Color(0xFF16213E),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFF00D9FF).withOpacity(0.3),
              width: 1,
            ),
          ),
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460).withOpacity(0.6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
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
                        Icons.class_,
                        color: Color(0xFF00D9FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      className,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Periods List
              Obx(
                () => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: HodTimetableController.periods.map((period) {
                      final slot = _getSlot(classId, period);
                      final hasSlot = slot != null;
                      final teacherName = hasSlot
                          ? controller.teacherName(
                              slot['teacherUid'].toString(),
                            )
                          : '';
                      final subject = hasSlot
                          ? (slot['subject']?.toString() ?? '')
                          : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: hasSlot
                              ? const Color(0xFF1A4D2E).withOpacity(0.4)
                              : const Color(0xFF1A1A2E).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasSlot
                                ? const Color(0xFF4CAF50).withOpacity(0.4)
                                : const Color(0xFF00D9FF).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: hasSlot
                                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                                  : const Color(0xFF00D9FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                period.replaceAll('Period ', 'P'),
                                style: TextStyle(
                                  color: hasSlot
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF00D9FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            hasSlot
                                ? (subject.isNotEmpty
                                      ? '$subject - $teacherName'
                                      : teacherName)
                                : 'No teacher assigned',
                            style: TextStyle(
                              color: hasSlot ? Colors.white : Colors.white54,
                              fontSize: 15,
                              fontWeight: hasSlot
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle:
                              hasSlot &&
                                  slot['overrideEnabled'] == true &&
                                  (slot['overrideTeacherUid']?.toString() ?? '')
                                      .isNotEmpty
                              ? Row(
                                  children: [
                                    const Icon(
                                      Icons.supervisor_account,
                                      size: 14,
                                      color: Color(0xFF00D9FF),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Substitute: ${controller.teacherName(slot['overrideTeacherUid']?.toString() ?? '')}',
                                        style: const TextStyle(
                                          color: Color(0xFF00D9FF),
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          trailing: Icon(
                            hasSlot ? Icons.edit : Icons.add_circle,
                            color: hasSlot
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF00D9FF),
                          ),
                          onTap: () => _openEditSlotDialog(
                            context: context,
                            classId: classId,
                            period: period,
                            existing: slot,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            'Timetable - ${controller.dayLabel(controller.selectedDay.value)}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: const Color(0xFF16213E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [],
      ),
      backgroundColor: const Color(0xFF1A1A2E),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
          );
        }

        // Show error if any
        if (controller.loadError.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error Loading Data',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.loadError.value,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      controller.onInit();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: const Color(0xFF0F0C29),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: HodTimetableController.days.map((d) {
                  final selected = controller.selectedDay.value == d;
                  return ChoiceChip(
                    label: Text(controller.dayLabel(d)),
                    selected: selected,
                    onSelected: (_) => controller.setDay(d),
                    selectedColor: const Color(0xFF00D9FF),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF0F0C29) : Colors.white,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor: const Color(0xFF16213E),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00D9FF).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_list,
                        color: Color(0xFF00D9FF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: controller.selectedClassId.value.isEmpty
                                ? null
                                : controller.selectedClassId.value,
                            hint: const Text(
                              'Select a class to view/edit timetable',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            dropdownColor: const Color(0xFF16213E),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF00D9FF),
                            ),
                            isExpanded: true,
                            items: controller.classes
                                .map(
                                  (classItem) => DropdownMenuItem<String>(
                                    value: classItem['id'].toString(),
                                    child: Text(
                                      classItem['name'].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              controller.setSelectedClass(value ?? '');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tap any period slot to add/edit teacher assignment',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Classes loaded: ${controller.classes.length} | Teachers: ${controller.teachers.length}',
                          style: const TextStyle(
                            color: Color(0xFF00D9FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(
                () => Stack(
                  children: [
                    _buildTimetableList(),
                    if (controller.isLoadingSlots.value)
                      Container(
                        color: Colors.black38,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00D9FF),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
