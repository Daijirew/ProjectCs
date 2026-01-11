import 'dart:async';
import 'package:flutter/material.dart';

class ExpirationCountdown extends StatefulWidget {
  final DateTime expirationTime;
  final VoidCallback onExpired;

  const ExpirationCountdown({
    Key? key,
    required this.expirationTime,
    required this.onExpired,
  }) : super(key: key);

  @override
  State<ExpirationCountdown> createState() => _ExpirationCountdownState();
}

class _ExpirationCountdownState extends State<ExpirationCountdown> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _startTimer();
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (widget.expirationTime.isAfter(now)) {
      setState(() {
        _timeLeft = widget.expirationTime.difference(now);
      });
    } else {
      widget.onExpired();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _calculateTimeLeft();
      if (_timeLeft.inSeconds <= 0) {
        timer.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.inSeconds <= 0) {
      return Text(
        'หมดเวลา',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text(
      'เหลือเวลา: ${_timeLeft.inHours}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}',
      style: TextStyle(
        color: _timeLeft.inMinutes < 30 ? Colors.red : Colors.orange,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
