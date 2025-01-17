import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ต้องเพิ่ม package นี้
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

class AvailableDatesPage extends StatefulWidget {
  @override
  _AvailableDatesPageState createState() => _AvailableDatesPageState();
}

class _AvailableDatesPageState extends State<AvailableDatesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // เก็บวันที่ที่เลือก
  List<DateTime?> _selectedDates = [];
  final DateFormat _dateFormat = DateFormat('EEE, MMM d, yyyy');

  // บันทึกข้อมูล
  Future<void> _saveAvailableDates() async {
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one date')),
      );
      return;
    }

    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please login to save dates')),
        );
        return;
      }

      // เตรียมข้อมูลวันที่
      List<Timestamp> availableDates = _selectedDates
          .where((date) => date != null)
          .map((date) => Timestamp.fromDate(date!))
          .toList();

      // บันทึกลง Firestore
      await _firestore.collection('users').doc(currentUser.uid).set({
        'availableDates': availableDates,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Available dates saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving dates: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Available Dates'),
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
                weekdayLabels: [
                  'Sun',
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat'
                ],
                weekdayLabelTextStyle: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                controlsHeight: 50,
                controlsTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                dayTextStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.normal,
                ),
                disabledDayTextStyle: TextStyle(
                  color: Colors.grey,
                ),
                selectableDayPredicate: (date) {
                  // ไม่ให้เลือกวันที่ผ่านมาแล้ว
                  return date.compareTo(
                          DateTime.now().subtract(Duration(days: 1))) >
                      0;
                },
              ),
              value: _selectedDates,
              onValueChanged: (dates) {
                setState(() {
                  _selectedDates = dates;
                });
              },
            ),
          ),

          // แสดงจำนวนวันที่เลือก
          if (_selectedDates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Selected ${_selectedDates.length} date(s)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // ปุ่มบันทึก
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _selectedDates.isEmpty ? null : _saveAvailableDates,
              icon: Icon(Icons.save),
              label: Text('Save Available Dates'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
