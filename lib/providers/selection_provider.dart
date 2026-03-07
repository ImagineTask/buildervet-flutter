import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the selected project card (by taskId), null = none selected
final selectedProjectIdProvider = StateProvider<String?>((ref) => null);

/// Tracks the selected task card (by taskId), null = none selected
final selectedTaskIdProvider = StateProvider<String?>((ref) => null);

/// Tracks which tab is active: 0 = Projects, 1 = Tasks
final homeTabProvider = StateProvider<int>((ref) => 0);
