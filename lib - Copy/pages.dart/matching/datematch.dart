// booking_page.dart
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:myproject/pages.dart/matching/matchpage.dart';

class BookingPage extends StatefulWidget {
  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  List<DateTime?> _selectedDates = [];

  void _navigateToFindSitter() {
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('กรุณาเลือกวันที่')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FindSitterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เลือกวันที่ต้องการฝากเลี้ยง'),
      ),
      body: Column(
        children: [
          Expanded(
            child: CalendarDatePicker2(
              config: CalendarDatePicker2Config(
                calendarType: CalendarDatePicker2Type.multi,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(Duration(days: 365)),
                selectedDayHighlightColor: Colors.blue,
              ),
              value: _selectedDates,
              onValueChanged: (dates) => setState(() => _selectedDates = dates),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _navigateToFindSitter,
              child: Text('ต่อไป'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                backgroundColor: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// find_sitter_screen.dart

