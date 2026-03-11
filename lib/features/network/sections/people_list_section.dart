import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/participant.dart';
import '../../../models/enums/participant_role.dart';
import '../../../core/di/service_locator.dart';

class PeopleListSection extends ConsumerWidget {
  const PeopleListSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<Participant>>(
      stream: ref.watch(chatRepositoryProvider).getUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final people = snapshot.data ?? [];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        // Filter out current user from the list
        final others = people.where((p) => p.userId != currentUserId).toList();

        if (others.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('No other users found'),
          ));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: others.length,
          itemBuilder: (context, index) {
            final person = others[index];
            return _PersonCard(person: person);
          },
        );
      },
    );
  }
}

class _PersonCard extends ConsumerWidget {
  final Participant person;
  const _PersonCard({required this.person});

  Future<void> _startChat(BuildContext context, WidgetRef ref) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final repo = ref.read(chatRepositoryProvider);
    final participantIds = [currentUserId, person.userId];
    
    // Generate a deterministic ID for this 1:1 chat
    final conversationId = repo.getDeterministicConversationId(participantIds);

    // Create or update the conversation document
    await repo.createConversation(
      person.name, 
      participantIds,
      customId: conversationId,
    );

    // Navigate
    if (context.mounted) {
      context.push('/chat/$conversationId', extra: {'title': person.name});
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(person.role.icon, color: AppColors.primary, size: 20),
        ),
        title: Text(person.name),
        subtitle: Text(person.role.label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              onPressed: () => _startChat(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.phone_outlined, size: 20),
              onPressed: () {
                // TODO: Call
              },
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to person detail
        },
      ),
    );
  }
}
