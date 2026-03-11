import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the selected projectId in SharedPreferences keyed by uid.
/// Selection survives sign-out and app restarts.
/// Only cleared when the user explicitly taps "Switch Project".
class ProjectSelectionController extends ChangeNotifier {
  String? _selectedProjectId;

  String? get selectedProjectId => _selectedProjectId;

  static String _prefKey(String uid) => 'selected_project_$uid';

  /// Load persisted selection for the current user.
  Future<void> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey(uid));
    if (saved != null && saved != _selectedProjectId) {
      _selectedProjectId = saved;
      notifyListeners();
    }
  }

  /// Select a project and persist it.
  Future<void> select(String projectId) async {
    _selectedProjectId = projectId;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey(uid), projectId);
    }
  }

  /// Clear selection and remove from storage.
  Future<void> clear() async {
    _selectedProjectId = null;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey(uid));
    }
  }
}

/// Wrap [MainNavigation] with this widget so the selected project
/// persists across tabs, navigation, sign-outs, and app restarts.
class ProjectSelectionState extends StatefulWidget {
  final Widget child;
  const ProjectSelectionState({super.key, required this.child});

  static ProjectSelectionController of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_ProjectSelectionInherited>();
    assert(inherited != null,
        'No ProjectSelectionState found in context. '
        'Make sure ProjectSelectionState wraps your widget tree.');
    return inherited!.controller;
  }

  @override
  State<ProjectSelectionState> createState() =>
      _ProjectSelectionStateState();
}

class _ProjectSelectionStateState extends State<ProjectSelectionState> {
  final ProjectSelectionController _controller =
      ProjectSelectionController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    // Load persisted selection immediately
    _controller.load();
    // Also reload whenever the user signs in (covers sign-out → sign-in)
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _controller.load();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _ProjectSelectionInherited(
      controller: _controller,
      child: widget.child,
    );
  }
}

class _ProjectSelectionInherited extends InheritedWidget {
  final ProjectSelectionController controller;

  const _ProjectSelectionInherited({
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ProjectSelectionInherited old) =>
      controller.selectedProjectId != old.controller.selectedProjectId;
}