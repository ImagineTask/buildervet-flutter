import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/participant.dart';
import '../../../models/enums/participant_role.dart';

class PeopleListSection extends StatelessWidget {
  const PeopleListSection({super.key});

  // TODO: Replace with data from provider
  static const _mockPeople = [
    Participant(userId: 'usr-010', name: 'James Smith', role: ParticipantRole.contractor, email: 'james@smithsons.com'),
    Participant(userId: 'usr-020', name: 'Maria Lopez', role: ParticipantRole.designer, email: 'maria@designstudio.com'),
    Participant(userId: 'usr-030', name: 'Dave Wilson', role: ParticipantRole.electrician, email: 'dave@brightspark.com'),
    Participant(userId: 'usr-040', name: 'Sarah Green', role: ParticipantRole.landscapeDesigner, email: 'sarah@greenscapes.com'),
    Participant(userId: 'usr-050', name: 'Mike Turner', role: ParticipantRole.gasEngineer, email: 'mike@heatfix.com'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mockPeople.length,
      itemBuilder: (context, index) {
        final person = _mockPeople[index];
        return _PersonCard(person: person);
      },
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Participant person;
  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                // TODO: Open chat
              },
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
