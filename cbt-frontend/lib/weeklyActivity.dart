import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class WeeklyActivityPage extends StatefulWidget {
  const WeeklyActivityPage({super.key});

  @override
  State<WeeklyActivityPage> createState() => _WeeklyActivityPageState();
}

class _WeeklyActivityPageState extends State<WeeklyActivityPage> {
  // ★ FINAL FIX: Using the exact same time formatting as your working TabBar code.
  final List<String> slots = List.generate(
    24,
        (i) {
      final startHour = i;
      final endHour = (i + 1) % 24;

      final start = TimeOfDay(hour: startHour, minute: 0);
      final end = TimeOfDay(hour: endHour, minute: 0);

      String formatTime(TimeOfDay t) {
        final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
        final suffix = t.period == DayPeriod.am ? "AM" : "PM";
        return "$h:00 $suffix";
      }

      return "${formatTime(start)} - ${formatTime(end)}";
    },
  );




  late List<DateTime> weekDays;
  late List<List<String>> activities;
  late DateTime today;

  DateTime? fixedStartDay;
  bool isLoading = true;

  // Layout constants
  static const double _timeSlotColumnWidth = 100.0;
  static const double _rowHeight = 60.0;
  double _dayColumnWidth = 120.0;

  // Scroll controllers for syncing the frozen-column layout
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _tableVerticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);
    _initPage();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _tableVerticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    await _loadFixedWeek();

    // Data structure is [slot][day] (row-first) to match the UI builder
    activities = List.generate(
      slots.length,
          (_) => List.generate(weekDays.length, (_) => ""),
    );

    await _loadActivities();

    // Sync vertical scroll controllers
    _verticalScrollController.addListener(() {
      if (_tableVerticalScrollController.hasClients &&
          _tableVerticalScrollController.offset !=
              _verticalScrollController.offset) {
        _tableVerticalScrollController
            .jumpTo(_verticalScrollController.offset);
      }
    });
    _tableVerticalScrollController.addListener(() {
      if (_verticalScrollController.hasClients &&
          _verticalScrollController.offset !=
              _tableVerticalScrollController.offset) {
        _verticalScrollController.jumpTo(_tableVerticalScrollController.offset);
      }
    });

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadFixedWeek() async {
    final stored = await DBHelper.getFixedStartDay();
    if (stored != null) {
      fixedStartDay = stored;
      weekDays = List.generate(7, (i) => fixedStartDay!.add(Duration(days: i)));
    } else {
      weekDays = List.generate(7, (i) => today.add(Duration(days: i)));
    }
  }

  Future<void> _loadActivities() async {
    final loaded = List.generate(
      slots.length,
          (_) => List.generate(weekDays.length, (_) => ""),
    );

    for (int dayIndex = 0; dayIndex < weekDays.length; dayIndex++) {
      for (int slotIndex = 0; slotIndex < slots.length; slotIndex++) {
        final dateStr = DateFormat('yyyy-MM-dd').format(weekDays[dayIndex]);
        final slotStr = slots[slotIndex]; // This now uses the correct format
        final chat = await DBHelper.getChat(dateStr, slotStr);
        if (chat != null) {
          loaded[slotIndex][dayIndex] = chat;
        }
      }
    }

    if (mounted) setState(() => activities = loaded);
  }

  void _editSlot(int dayIndex, int slotIndex) async {
    final selectedDay = weekDays[dayIndex];
    final current = DateTime.now();
    final cleanToday = DateTime(current.year, current.month, current.day);

    if (selectedDay != cleanToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only edit today's records.")),
      );
      return;
    }

    if (activities[slotIndex][dayIndex].isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This slot is already filled.")),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          "${DateFormat.E().format(selectedDay)} ${DateFormat.d().format(selectedDay)} "
              "${DateFormat.MMM().format(selectedDay)}, ${slots[slotIndex]}",
        ),
        content: TextField(
            controller: controller,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
                hintText: "Enter activity",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple, width: 2)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("Save")),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final dateStr = DateFormat('yyyy-MM-dd').format(weekDays[dayIndex]);
      final slotStr = slots[slotIndex];
      await DBHelper.saveChat(dateStr, slotStr, result.trim());

      setState(() => activities[slotIndex][dayIndex] = result.trim());
    }
  }

  Widget _buildDayHeader(DateTime day, bool isToday) {
    return Container(
      width: _dayColumnWidth,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday ? Colors.deepPurple.shade50 : Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat.E().format(day),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isToday ? Colors.deepPurple : Colors.black87)),
          Text(DateFormat.d().add_MMM().format(day),
              style: TextStyle(
                  fontSize: 10,
                  color: isToday ? Colors.deepPurple : Colors.grey.shade600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final remainingWidth = screenWidth - _timeSlotColumnWidth;
    _dayColumnWidth = remainingWidth / 7 > 120.0 ? remainingWidth / 7 : 120.0;

    final now = DateTime.now();
    final cleanToday = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(title: const Text("Weekly Activity Schedule")),
      body: Row(
        children: [
          // === FIXED LEFT COLUMN (TIME) ===
          SizedBox(
            width: _timeSlotColumnWidth,
            child: Column(
              children: [
                Container(
                  width: _timeSlotColumnWidth,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text("Time", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _verticalScrollController,
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: _timeSlotColumnWidth,
                        height: _rowHeight,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(slots[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // === SCROLLABLE RIGHT PART (DAYS AND DATA) ===
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: SizedBox(
                width: _dayColumnWidth * weekDays.length,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: weekDays
                          .map((d) => _buildDayHeader(d, d == cleanToday))
                          .toList(),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _tableVerticalScrollController,
                        itemCount: slots.length,
                        itemBuilder: (context, slotIndex) {
                          return Row(
                            children: List.generate(weekDays.length, (dayIndex) {
                              final activityText = activities[slotIndex][dayIndex];
                              final isToday = weekDays[dayIndex] == cleanToday;
                              final canEdit = isToday && activityText.isEmpty;

                              return GestureDetector(
                                onTap: () {
                                  if (canEdit) {
                                    _editSlot(dayIndex, slotIndex);
                                  } else if (activityText.isNotEmpty) {
                                    showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                            title: Text(slots[slotIndex]),
                                            content: SingleChildScrollView(child: Text(activityText)),
                                            actions: [
                                              TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text("Close"))
                                            ]));
                                  }
                                },
                                child: Container(
                                  width: _dayColumnWidth,
                                  height: _rowHeight,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? Colors.deepPurple.shade100.withOpacity(
                                        activityText.isNotEmpty ? 0.8 : 0.2)
                                        : Colors.white,
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          activityText.isEmpty ? "No activity" : activityText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: activityText.isEmpty
                                                ? Colors.grey
                                                : Colors.black87,
                                            fontStyle: activityText.isEmpty
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: canEdit
                                            ? const Icon(Icons.edit,
                                            size: 14, color: Colors.blue)
                                            : const Icon(Icons.lock_outline,
                                            size: 14, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}