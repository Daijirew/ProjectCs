import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:myproject/widget/widget_support.dart';

class ScheduleIncomePage extends StatefulWidget {
  const ScheduleIncomePage({Key? key}) : super(key: key);

  @override
  State<ScheduleIncomePage> createState() => _ScheduleIncomePageState();
}

class _ScheduleIncomePageState extends State<ScheduleIncomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // ข้อมูลการจอง
  Map<DateTime, List<dynamic>> _bookingEvents = {};

  // ข้อมูลเกี่ยวกับรายได้
  double _totalIncome = 0;
  double _monthlyIncome = 0;
  double _weeklyIncome = 0;
  bool _isLoading = true;

  // รายการการจองตามวันที่เลือก
  List<dynamic> _selectedEvents = [];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _loadBookingEvents();
    _calculateIncomes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule & Income'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Income Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Calendar Tab
          Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2025, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _selectedEvents = _bookingEvents[selectedDay] ?? [];
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _selectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = _selectedEvents[index];
                    return ListTile(
                      title: Text(event['title'] ?? ''),
                      subtitle: Text(event['description'] ?? ''),
                    );
                  },
                ),
              ),
            ],
          ),
          // Income Summary Tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IncomeSummaryCard(
                        title: 'Total Income',
                        amount: _totalIncome,
                      ),
                      const SizedBox(height: 16),
                      IncomeSummaryCard(
                        title: 'Monthly Income',
                        amount: _monthlyIncome,
                      ),
                      const SizedBox(height: 16),
                      IncomeSummaryCard(
                        title: 'Weekly Income',
                        amount: _weeklyIncome,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  void _loadBookingEvents() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final bookings = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .get();

        final events = <DateTime, List<dynamic>>{};
        for (var doc in bookings.docs) {
          final data = doc.data();
          final date = (data['date'] as Timestamp).toDate();
          final dateKey = DateTime(date.year, date.month, date.day);

          if (events[dateKey] == null) events[dateKey] = [];
          events[dateKey]!.add(data);
        }

        setState(() {
          _bookingEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading booking events: $e');
    }
  }

  void _calculateIncomes() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfMonth = DateTime(now.year, now.month, 1);

        final bookings = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .get();

        double total = 0;
        double monthly = 0;
        double weekly = 0;

        for (var doc in bookings.docs) {
          final data = doc.data();
          final date = (data['date'] as Timestamp).toDate();
          final amount = (data['amount'] as num).toDouble();

          total += amount;
          if (date.isAfter(startOfMonth)) monthly += amount;
          if (date.isAfter(startOfWeek)) weekly += amount;
        }

        setState(() {
          _totalIncome = total;
          _monthlyIncome = monthly;
          _weeklyIncome = weekly;
        });
      }
    } catch (e) {
      print('Error calculating incomes: $e');
    }
  }
}

class IncomeSummaryCard extends StatelessWidget {
  final String title;
  final double amount;

  const IncomeSummaryCard({
    Key? key,
    required this.title,
    required this.amount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '฿${NumberFormat("#,##0.00").format(amount)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
