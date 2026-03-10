import 'package:flutter/material.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Suggestions label
                  const Text(
                    'People You May Know',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _people.length,
                itemBuilder: (context, index) => _PersonCard(person: _people[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Person {
  final String name;
  final String role;
  final String mutualConnections;
  final Color avatarColor;
  final String initials;
  bool connected;

  _Person({
    required this.name,
    required this.role,
    required this.mutualConnections,
    required this.avatarColor,
    required this.initials,
    this.connected = false,
  });
}

final _people = [
  _Person(name: 'Sarah Connor', role: 'Product Designer at Meta', mutualConnections: '12 mutual connections', avatarColor: Color(0xFFFF6B6B), initials: 'SC'),
  _Person(name: 'Mike Reynolds', role: 'Software Engineer at Google', mutualConnections: '8 mutual connections', avatarColor: Color(0xFF43C59E), initials: 'MR'),
  _Person(name: 'Emma Wilson', role: 'Marketing Lead at Apple', mutualConnections: '21 mutual connections', avatarColor: Color(0xFF6C63FF), initials: 'EW'),
  _Person(name: 'David Park', role: 'Data Scientist at Netflix', mutualConnections: '5 mutual connections', avatarColor: Color(0xFFFFB347), initials: 'DP'),
  _Person(name: 'Lisa Chen', role: 'UX Researcher at Spotify', mutualConnections: '14 mutual connections', avatarColor: Color(0xFF4ECDC4), initials: 'LC'),
  _Person(name: 'James Martins', role: 'CEO at StartupHub', mutualConnections: '32 mutual connections', avatarColor: Color(0xFFE056A0), initials: 'JM'),
];

class _PersonCard extends StatefulWidget {
  final _Person person;
  const _PersonCard({required this.person});

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<_PersonCard> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: widget.person.avatarColor,
            child: Text(
              widget.person.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.person.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.person.role,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.person.mutualConnections,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _connected = !_connected),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _connected ? Colors.grey[100] : const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _connected ? 'Connected' : 'Connect',
                style: TextStyle(
                  color: _connected ? Colors.grey[600] : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
