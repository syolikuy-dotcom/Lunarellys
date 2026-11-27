import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DynamicIslandEvent {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;

  const DynamicIslandEvent({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
  });
}

class DynamicIslandNotifier extends StateNotifier<DynamicIslandEvent?> {
  Timer? _clearTimer;

  DynamicIslandNotifier() : super(null);

  void show(
    DynamicIslandEvent event, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _clearTimer?.cancel();
    state = event;
    _clearTimer = Timer(duration, () {
      if (mounted) state = null;
    });
  }

  void dismiss() {
    _clearTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }
}

final dynamicIslandEventProvider =
    StateNotifierProvider<DynamicIslandNotifier, DynamicIslandEvent?>((ref) {
  return DynamicIslandNotifier();
});
