import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// ── Cloud Run base URL ────────────────────────────────────────────────────────
const _apiBaseUrl =
    'https://imaginetask-engine-v1-268920641222.europe-west2.run.app';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class AiRequestScreen extends StatefulWidget {
  const AiRequestScreen({super.key});

  @override
  State<AiRequestScreen> createState() => _AiRequestScreenState();
}

class _AiRequestScreenState extends State<AiRequestScreen> {
  final _controller = TextEditingController();

  bool _isLoading = false;
  String? _error;
  _GenerateResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final contextText = _controller.text.trim();
    if (contextText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final body = <String, dynamic>{
        'userId': user?.uid ?? 'anonymous',
        'userName': user?.displayName ?? 'User',
        'userRole': 'homeowner',
        'context': contextText,
        'template': 'renovation',
        'provider': 'google',
      };

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/v1/tasks/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        // Response matches GenerateTasksResponse:
        // { status, message, project_id, project_name,
        //   project_description, tasks_count, task_ids, provider_used }
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _result = _GenerateResult(
            status: data['status'] as String? ?? '',
            message: data['message'] as String? ?? '',
            projectId: data['project_id'] as String? ?? '',
            projectName: data['project_name'] as String? ?? 'Project',
            projectDescription:
                data['project_description'] as String? ?? '',
            tasksCount: data['tasks_count'] as int? ?? 0,
            taskIds: List<String>.from(data['task_ids'] ?? []),
            providerUsed: data['provider_used'] as String? ?? '',
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
        _error = 'Could not connect to server. Please try again.\n$e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'New Project',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero banner ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Project Planner',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 3),
                        Text(
                          'Describe your project and get a detailed task plan with cost estimates.',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Description input ────────────────────────────────────────────
            const Text('Describe your project',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      'e.g. I need a full kitchen renovation including new cabinets, plumbing, and electrical work...',
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Quick suggestions ────────────────────────────────────────────
            const Text('Quick suggestions',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionChip(
                  label: '🍳 Kitchen renovation',
                  onTap: () => _controller.text =
                      'I need a full kitchen renovation including new cabinets, plumbing, and electrical',
                ),
                _SuggestionChip(
                  label: '🚿 Bathroom refresh',
                  onTap: () => _controller.text =
                      'I need a bathroom renovation with new shower, tiling, and plumbing',
                ),
                _SuggestionChip(
                  label: '🏠 Loft conversion',
                  onTap: () => _controller.text =
                      'I want to convert my loft into a bedroom with en-suite bathroom',
                ),
                _SuggestionChip(
                  label: '🧱 Extension',
                  onTap: () => _controller.text =
                      'I need a single storey rear extension for a larger kitchen-diner',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Submit button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isLoading
                      ? 'Generating your plan...'
                      : 'Generate Task Plan',
                  style: const TextStyle(fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            // ── Error ────────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFF6B6B).withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: Color(0xFFFF6B6B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFFF6B6B))),
                    ),
                  ],
                ),
              ),
            ],

            // ── Result ───────────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 24),
              _ResultCard(
                result: _result!,
                onViewProject: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Card
// ─────────────────────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final _GenerateResult result;
  final VoidCallback onViewProject;
  const _ResultCard({required this.result, required this.onViewProject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF43C59E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF43C59E).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF43C59E), size: 22),
              SizedBox(width: 8),
              Text('Project Created!',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF43C59E))),
            ],
          ),
          const SizedBox(height: 14),

          // Project name
          Text(result.projectName,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Text(result.projectDescription,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _StatPill(
                icon: Icons.task_alt_outlined,
                label: '${result.tasksCount} tasks',
                color: const Color(0xFF6C63FF),
              ),
              const SizedBox(width: 8),
              if (result.providerUsed.isNotEmpty)
                _StatPill(
                  icon: Icons.smart_toy_outlined,
                  label: result.providerUsed,
                  color: const Color(0xFF43C59E),
                ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onViewProject,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('View Projects'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion Chip
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF1A1A2E))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Model — mirrors GenerateTasksResponse from the backend
// ─────────────────────────────────────────────────────────────────────────────
class _GenerateResult {
  final String status;
  final String message;
  final String projectId;
  final String projectName;
  final String projectDescription;
  final int tasksCount;
  final List<String> taskIds;
  final String providerUsed;

  _GenerateResult({
    required this.status,
    required this.message,
    required this.projectId,
    required this.projectName,
    required this.projectDescription,
    required this.tasksCount,
    required this.taskIds,
    required this.providerUsed,
  });
}