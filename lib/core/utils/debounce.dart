import 'dart:async';
import 'package:flutter/material.dart';

class Debounce {
  Debounce._();

  static Timer? _timer;

  static void run(Duration duration, VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  static void cancel() {
    _timer?.cancel();
  }
}
