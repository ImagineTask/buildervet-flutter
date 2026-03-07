import 'package:flutter/material.dart';

/// How the action is displayed when triggered
enum ActionDisplayMode {
  /// Opens a full Flutter screen (complex actions with custom UI)
  fullScreen,

  /// Slides up a bottom sheet (quick actions)
  bottomSheet,

  /// Opens an in-app WebView (web-hosted features)
  webView,
}

/// What generic screen type to use (avoids building custom screens)
enum ActionScreenType {
  /// A custom-built Flutter screen (use sparingly)
  custom,

  /// A generic form with configurable fields
  form,

  /// A simple confirmation dialog (yes/no)
  confirmation,

  /// A selection list (pick from options)
  selection,

  /// A text input sheet (notes, comments)
  textInput,

  /// A phone/contact action
  phone,

  /// A web page loaded in WebView
  web,
}

/// Configuration for a single registered system action
class ActionConfig {
  /// Unique key matching the string in task.actionSpace
  final String key;

  /// Human-readable label displayed on the tile
  final String label;

  /// Short description for AI and tooltips
  final String description;

  /// Icon displayed on the tile
  final IconData icon;

  /// Tile colour
  final Color color;

  /// How to display: full screen, bottom sheet, or web view
  final ActionDisplayMode displayMode;

  /// What kind of screen to render
  final ActionScreenType screenType;

  /// URL for web view actions
  final String? url;

  /// Which task types this action applies to (empty = all)
  final List<String> applicableTo;

  /// What data the task must have for this action to be available
  /// e.g. ['quotes'] means only show if task has quotes
  final List<String> requiresData;

  /// Priority for AI ordering (higher = more important)
  final int priority;

  /// Form field config for generic form screen type
  final List<Map<String, dynamic>>? formFields;

  /// Confirmation message for confirmation screen type
  final String? confirmMessage;

  /// Label for the confirm button
  final String? confirmLabel;

  const ActionConfig({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.displayMode,
    this.screenType = ActionScreenType.custom,
    this.url,
    this.applicableTo = const [],
    this.requiresData = const [],
    this.priority = 50,
    this.formFields,
    this.confirmMessage,
    this.confirmLabel,
  });
}

/// ─── THE REGISTRY ───────────────────────────────────────
/// Single source of truth for all system actions.
/// To add a new action:
///   1. Add an entry here
///   2. If screenType is 'custom', build the screen
///   3. If screenType is generic (form, confirmation, etc.), just configure
///   4. If displayMode is webView, just provide the URL

class ActionRegistry {
  ActionRegistry._();

  static final Map<String, ActionConfig> _actions = {
    // ─── TASK STATUS ACTIONS (bottom sheet, confirmation) ──────

    'start_task': const ActionConfig(
      key: 'start_task',
      label: 'Start Task',
      description: 'Mark this task as started and in progress',
      icon: Icons.play_circle,
      color: Color(0xFF2ECC71),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.confirmation,
      confirmMessage: 'Start working on this task? The status will change to "In Progress".',
      confirmLabel: 'Start',
      priority: 90,
    ),

    'mark_complete': const ActionConfig(
      key: 'mark_complete',
      label: 'Mark Complete',
      description: 'Mark this task as completed',
      icon: Icons.check_circle,
      color: Color(0xFF00B894),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.confirmation,
      confirmMessage: 'Mark this task as completed? This will notify all participants.',
      confirmLabel: 'Complete',
      priority: 85,
    ),

    // ─── QUOTE ACTIONS (full screen, custom) ──────────────────

    'review_quotes': const ActionConfig(
      key: 'review_quotes',
      label: 'Review Quotes',
      description: 'Compare and accept or reject contractor quotes',
      icon: Icons.request_quote,
      color: Color(0xFFFF6B6B),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      requiresData: ['quotes'],
      priority: 95,
    ),

    'request_quote': const ActionConfig(
      key: 'request_quote',
      label: 'Request Quote',
      description: 'Send a quote request to one or more contractors',
      icon: Icons.receipt_long,
      color: Color(0xFFE17055),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 80,
    ),

    'request_quotes': const ActionConfig(
      key: 'request_quotes',
      label: 'Request Quotes',
      description: 'Send quote requests to multiple contractors at once',
      icon: Icons.request_page,
      color: Color(0xFFFF6348),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 80,
    ),

    'approve_quote': const ActionConfig(
      key: 'approve_quote',
      label: 'Approve Quote',
      description: 'Accept a specific contractor quote',
      icon: Icons.thumb_up,
      color: Color(0xFF55A3F5),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.confirmation,
      requiresData: ['quotes'],
      confirmMessage: 'Approve this quote? The contractor will be notified.',
      confirmLabel: 'Approve',
      priority: 85,
    ),

    // ─── PEOPLE ACTIONS (full screen, custom) ─────────────────

    'assign_contractor': const ActionConfig(
      key: 'assign_contractor',
      label: 'Assign Contractor',
      description: 'Browse and assign a contractor to this task',
      icon: Icons.person_add,
      color: Color(0xFF0984E3),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 75,
    ),

    'call_engineer': const ActionConfig(
      key: 'call_engineer',
      label: 'Call Engineer',
      description: 'Call the assigned engineer or contractor',
      icon: Icons.phone,
      color: Color(0xFF00CEC9),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.phone,
      requiresData: ['participants'],
      priority: 60,
    ),

    // ─── SCHEDULING ACTIONS (bottom sheet, form) ──────────────

    'schedule': const ActionConfig(
      key: 'schedule',
      label: 'Schedule',
      description: 'Set start and end dates for this task',
      icon: Icons.calendar_month,
      color: Color(0xFFFD79A8),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.form,
      formFields: [
        {'name': 'start_date', 'type': 'date', 'label': 'Start Date', 'required': true},
        {'name': 'end_date', 'type': 'date', 'label': 'End Date', 'required': true},
      ],
      priority: 70,
    ),

    'schedule_inspection': const ActionConfig(
      key: 'schedule_inspection',
      label: 'Schedule Inspection',
      description: 'Book an inspection date and time',
      icon: Icons.event,
      color: Color(0xFF45B7D1),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.form,
      formFields: [
        {'name': 'date', 'type': 'date', 'label': 'Inspection Date', 'required': true},
        {'name': 'time', 'type': 'time', 'label': 'Time', 'required': true},
        {'name': 'inspector_notes', 'type': 'text', 'label': 'Notes for Inspector', 'required': false},
      ],
      priority: 70,
    ),

    'request_inspection': const ActionConfig(
      key: 'request_inspection',
      label: 'Request Inspection',
      description: 'Request a professional inspection visit',
      icon: Icons.verified,
      color: Color(0xFF96CEB4),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.form,
      formFields: [
        {'name': 'inspection_type', 'type': 'text', 'label': 'Inspection Type', 'required': true},
        {'name': 'preferred_date', 'type': 'date', 'label': 'Preferred Date', 'required': true},
        {'name': 'notes', 'type': 'text', 'label': 'Additional Notes', 'required': false},
      ],
      priority: 65,
    ),

    // ─── CONTENT ACTIONS (bottom sheet, text/media) ───────────

    'add_note': const ActionConfig(
      key: 'add_note',
      label: 'Add Note',
      description: 'Add a text note to this task',
      icon: Icons.note_add,
      color: Color(0xFF9B59B6),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.textInput,
      priority: 60,
    ),

    'upload_photo': const ActionConfig(
      key: 'upload_photo',
      label: 'Upload Photo',
      description: 'Take a photo or upload from gallery',
      icon: Icons.camera_alt,
      color: Color(0xFFFECA57),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.custom,
      priority: 65,
    ),

    'report_issue': const ActionConfig(
      key: 'report_issue',
      label: 'Report Issue',
      description: 'Flag a problem with description and photos',
      icon: Icons.warning,
      color: Color(0xFFD63031),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 90,
    ),

    // ─── MATERIAL ACTIONS (mixed) ─────────────────────────────

    'approve_material': const ActionConfig(
      key: 'approve_material',
      label: 'Approve Material',
      description: 'Review and confirm material selections',
      icon: Icons.check_box,
      color: Color(0xFF4ECDC4),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 75,
    ),

    'confirm_materials': const ActionConfig(
      key: 'confirm_materials',
      label: 'Confirm Materials',
      description: 'Final confirmation that materials are ordered',
      icon: Icons.inventory,
      color: Color(0xFF6C5CE7),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.confirmation,
      confirmMessage: 'Confirm that all materials have been ordered?',
      confirmLabel: 'Confirm',
      priority: 70,
    ),

    'confirm_fixtures': const ActionConfig(
      key: 'confirm_fixtures',
      label: 'Confirm Fixtures',
      description: 'Confirm bathroom or kitchen fixture selections',
      icon: Icons.plumbing,
      color: Color(0xFF7ED6DF),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.confirmation,
      confirmMessage: 'Confirm the fixture selections? This will lock in the order.',
      confirmLabel: 'Confirm',
      priority: 70,
    ),

    'select_material': const ActionConfig(
      key: 'select_material',
      label: 'Select Material',
      description: 'Browse and choose materials from suppliers',
      icon: Icons.palette,
      color: Color(0xFFE84393),
      displayMode: ActionDisplayMode.webView,
      screenType: ActionScreenType.web,
      url: 'https://www.screwfix.com',
      priority: 55,
    ),

    'select_colour': const ActionConfig(
      key: 'select_colour',
      label: 'Select Colour',
      description: 'Pick paint or tile colours',
      icon: Icons.color_lens,
      color: Color(0xFFA29BFE),
      displayMode: ActionDisplayMode.webView,
      screenType: ActionScreenType.web,
      url: 'https://www.dulux.co.uk/en/colour-palettes',
      priority: 50,
    ),

    // ─── BACKEND ACTION SPACE KEYS ────────────────────────────
    // These are the exact keys sent by the backend in actionSpace.
    // Task initial_action_space: request_quote, view_details, schedule_work,
    //   upload_photo, add_note
    // Project project_action_space: view_tasks, review_quotes, schedule_work,
    //   upload_photo, view_progress, manage_team, create_invoice

    'view_details': const ActionConfig(
      key: 'view_details',
      label: 'View Details',
      description: 'Open the full task detail screen',
      icon: Icons.info_outline,
      color: Color(0xFF6366F1),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 95,
    ),

    'schedule_work': const ActionConfig(
      key: 'schedule_work',
      label: 'Schedule',
      description: 'Set start and end dates for this task',
      icon: Icons.calendar_month,
      color: Color(0xFF45B7D1),
      displayMode: ActionDisplayMode.bottomSheet,
      screenType: ActionScreenType.form,
      formFields: [
        {'name': 'start_date', 'type': 'date', 'label': 'Start Date', 'required': true},
        {'name': 'end_date', 'type': 'date', 'label': 'End Date', 'required': true},
      ],
      priority: 70,
    ),

    'view_tasks': const ActionConfig(
      key: 'view_tasks',
      label: 'View Tasks',
      description: 'See all tasks in this project',
      icon: Icons.list_alt,
      color: Color(0xFF6366F1),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      applicableTo: ['project'],
      priority: 95,
    ),

    'view_progress': const ActionConfig(
      key: 'view_progress',
      label: 'Progress',
      description: 'View the overall project progress',
      icon: Icons.bar_chart,
      color: Color(0xFF00B894),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      applicableTo: ['project'],
      priority: 80,
    ),

    'manage_team': const ActionConfig(
      key: 'manage_team',
      label: 'Manage Team',
      description: 'Add, remove, or reassign people on this project',
      icon: Icons.group,
      color: Color(0xFF0984E3),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      applicableTo: ['project'],
      priority: 75,
    ),

    'create_invoice': const ActionConfig(
      key: 'create_invoice',
      label: 'Invoice',
      description: 'Create or review an invoice for this project',
      icon: Icons.receipt_long,
      color: Color(0xFF6C5CE7),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      applicableTo: ['project'],
      priority: 70,
    ),

    // ─── DESIGN ACTIONS (full screen) ─────────────────────────

    'finalise_design': const ActionConfig(
      key: 'finalise_design',
      label: 'Finalise Design',
      description: 'Review and lock in the design plan',
      icon: Icons.design_services,
      color: Color(0xFFFF9FF3),
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 80,
    ),

    'get_planning_advice': const ActionConfig(
      key: 'get_planning_advice',
      label: 'Planning Advice',
      description: 'Get guidance on planning permission requirements',
      icon: Icons.lightbulb,
      color: Color(0xFFF9CA24),
      displayMode: ActionDisplayMode.webView,
      screenType: ActionScreenType.web,
      url: 'https://www.planningportal.co.uk',
      priority: 40,
    ),
  };

  // ─── PUBLIC API ──────────────────────────────────────────

  /// Get config for a system action. Returns null if not registered.
  static ActionConfig? get(String key) => _actions[key];

  /// Check if an action is registered
  static bool isRegistered(String key) => _actions.containsKey(key);

  /// Get all registered actions
  static Map<String, ActionConfig> getAll() => Map.unmodifiable(_actions);

  /// Get actions filtered by display mode
  static List<ActionConfig> getByDisplayMode(ActionDisplayMode mode) {
    return _actions.values.where((a) => a.displayMode == mode).toList();
  }

  /// Get actions applicable to a task type
  static List<ActionConfig> getForTaskType(String taskType) {
    return _actions.values.where((a) {
      return a.applicableTo.isEmpty || a.applicableTo.contains(taskType);
    }).toList();
  }

  /// Get actions sorted by priority (highest first)
  /// Used by AI to determine which actions to recommend
  static List<ActionConfig> getByPriority() {
    final list = _actions.values.toList();
    list.sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  /// Check if a task has the required data for an action
  static bool taskMeetsRequirements(ActionConfig config, Map<String, dynamic> taskData) {
    for (final req in config.requiresData) {
      switch (req) {
        case 'quotes':
          final quotes = taskData['quotes'] as List?;
          if (quotes == null || quotes.isEmpty) return false;
          break;
        case 'participants':
          final participants = taskData['participants'] as List?;
          if (participants == null || participants.isEmpty) return false;
          break;
      }
    }
    return true;
  }

  // ─── FALLBACK CONFIG ─────────────────────────────────────
  // Used for unknown action strings that aren't in the registry

  static const _fallbackColors = [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  /// Generate a config for an unregistered action string
  /// This ensures the app never crashes on unknown actions
  static ActionConfig fallback(String key, {int index = 0}) {
    final label = key
        .split('_')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');

    return ActionConfig(
      key: key,
      label: label,
      description: 'Action: $label',
      icon: Icons.bolt,
      color: _fallbackColors[index % _fallbackColors.length],
      displayMode: ActionDisplayMode.fullScreen,
      screenType: ActionScreenType.custom,
      priority: 30,
    );
  }
}