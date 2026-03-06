import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';

class AiRequestScreen extends ConsumerStatefulWidget {
  const AiRequestScreen({super.key});

  @override
  ConsumerState<AiRequestScreen> createState() => _AiRequestScreenState();
}

class _AiRequestScreenState extends ConsumerState<AiRequestScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;
  _GenerateResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final context = _controller.text.trim();
    if (context.isEmpty) return;

    final authState = ref.read(authStateProvider);
    final user = authState.valueOrNull;
    final appUser = ref.read(appUserProvider).valueOrNull;

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/tasks/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': user?.uid ?? 'anonymous',
          'userName': appUser?.name ?? user?.displayName ?? 'User',
          'userRole': appUser?.role ?? 'homeowner',
          'context': context,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _result = _GenerateResult(
            projectName: data['project_name'] as String? ?? 'Project',
            projectDescription: data['project_description'] as String? ?? '',
            tasksCount: data['tasks_count'] as int? ?? 0,
            projectId: data['project_id'] as String? ?? '',
          );
        });
      } else {
        final data = json.decode(response.body);
        setState(() {
          _error = data['detail'] as String? ?? 'Failed to generate tasks';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect to server. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Describe your project',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tell us what you need and our AI will create a detailed task plan with cost estimates.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Input
            TextField(
              controller: _controller,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. I need a full kitchen renovation including new cabinets, plumbing, and electrical work...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Suggestion chips
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _SuggestionChip(
                  label: 'Kitchen renovation',
                  onTap: () => _controller.text = 'I need a full kitchen renovation including new cabinets, plumbing, and electrical',
                ),
                _SuggestionChip(
                  label: 'Bathroom refresh',
                  onTap: () => _controller.text = 'I need a bathroom renovation with new shower, tiling, and plumbing',
                ),
                _SuggestionChip(
                  label: 'Loft conversion',
                  onTap: () => _controller.text = 'I want to convert my loft into a bedroom with en-suite bathroom',
                ),
                _SuggestionChip(
                  label: 'Extension',
                  onTap: () => _controller.text = 'I need a single storey rear extension for a larger kitchen-diner',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isLoading ? 'Generating your plan...' : 'Generate Task Plan',
                  style: const TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: TextStyle(fontSize: 13, color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ],

            // Result
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ResultCard(
                result: _result!,
                onViewProject: () {
                  context.go('/home');
                  // TODO: Navigate to project detail after tasks are loaded from Firestore
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Result Card ─────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final _GenerateResult result;
  final VoidCallback onViewProject;

  const _ResultCard({required this.result, required this.onViewProject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF00B894).withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: const Color(0xFF00B894).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: const Color(0xFF00B894), size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Project Created!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00B894),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            result.projectName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            result.projectDescription,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${result.tasksCount} tasks generated',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onViewProject,
              child: const Text('View Project'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Suggestion Chip ─────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: AppColors.surfaceLight,
      side: BorderSide(color: AppColors.border),
    );
  }
}

// ─── Result Model ────────────────────────────────────────

class _GenerateResult {
  final String projectName;
  final String projectDescription;
  final int tasksCount;
  final String projectId;

  _GenerateResult({
    required this.projectName,
    required this.projectDescription,
    required this.tasksCount,
    required this.projectId,
  });
}