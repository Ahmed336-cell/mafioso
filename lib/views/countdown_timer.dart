import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

class CountdownTimer extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onTimeUp;
  final TextStyle textStyle;
  final Color? backgroundColor;
  final Color? borderColor;

  const CountdownTimer({
    super.key,
    required this.duration,
    this.onTimeUp,
    required this.textStyle,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  late Duration _timeLeft;
  bool _isTimeUp = false;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.duration;
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _resetTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        } else {
          _handleTimeUp();
        }
      });
    });
  }

  void _handleTimeUp() {
    _timer.cancel();
    _isTimeUp = true;
    widget.onTimeUp?.call();
  }

  void _resetTimer() {
    _timer.cancel();
    setState(() {
      _timeLeft = widget.duration;
      _isTimeUp = false;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _timeLeft.inMinutes;
    final seconds = _timeLeft.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.black.withOpacity(0.7),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.borderColor ?? Colors.white,
          width: 2,
        ),
      ),
      child: Text(
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        style: widget.textStyle.copyWith(
          color: _isTimeUp ? Colors.red : widget.textStyle.color,
        ),
      )
          .animate(
        target: _isTimeUp ? 1 : 0,
        onComplete: _isTimeUp ? (controller) => controller.repeat(reverse: true) : null,
      )
          .shakeX(
        amount: 4,
        duration: 300.ms,
      ),
    );
  }
}