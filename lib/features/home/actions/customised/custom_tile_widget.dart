import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'custom_tile_model.dart';
import 'custom_tile_service.dart';

/// Renders a custom tile in the action grid — same look as BaseActionTile
class CustomTileWidget extends StatelessWidget {
  final CustomTileModel tile;
  final String projectId;
  final CustomTileService service;

  const CustomTileWidget({
    super.key,
    required this.tile,
    required this.projectId,
    required this.service,
  });

  Color get _color {
    try {
      return Color(int.parse(tile.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6C63FF);
    }
  }

  Future<void> _onTap(BuildContext context) async {
    if (tile.tileType == 'external' && tile.url != null) {
      final uri = Uri.tryParse(tile.url!);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (tile.tileType == 'internal_project') {
      // TODO: Navigate to linked project
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening ${tile.name}...')),
      );
    }
  }

  void _onLongPress(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TileOptionsSheet(
        tile: tile,
        projectId: projectId,
        service: service,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      onLongPress: () => _onLongPress(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: _buildIcon(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                tile.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (tile.iconType) {
      case 'emoji':
        return Text(tile.iconValue, style: const TextStyle(fontSize: 22));
      case 'image':
        return ClipOval(
          child: Image.network(
            tile.iconValue,
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.language, color: _color, size: 22),
          ),
        );
      default:
        return Icon(_presetIcon(tile.iconValue), color: _color, size: 22);
    }
  }

  IconData _presetIcon(String name) {
    const map = {
      'language': Icons.language,
      'store': Icons.store_outlined,
      'link': Icons.link,
      'social': Icons.people_outline,
      'email': Icons.email_outlined,
      'phone': Icons.phone_outlined,
      'map': Icons.map_outlined,
      'document': Icons.description_outlined,
      'video': Icons.play_circle_outline,
      'calendar': Icons.calendar_today_outlined,
      'accounting': Icons.calculate_outlined,
      'legal': Icons.gavel_outlined,
      'architecture': Icons.architecture,
    };
    return map[name] ?? Icons.language;
  }
}

// ─────────────────────────────────────────────
// Tile Options Sheet (long press)
// ─────────────────────────────────────────────
class _TileOptionsSheet extends StatelessWidget {
  final CustomTileModel tile;
  final String projectId;
  final CustomTileService service;

  const _TileOptionsSheet({
    required this.tile,
    required this.projectId,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(
            tile.name,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E)),
          ),
          if (tile.url != null) ...[
            const SizedBox(height: 4),
            Text(tile.url!,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
          const SizedBox(height: 24),
          // Delete
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Delete Tile',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E))),
                    content: Text('Delete "${tile.name}"?',
                        style: const TextStyle(color: Colors.grey)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await service.deleteTile(projectId, tile.id);
                }
              },
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFFF6B6B)),
              label: const Text('Delete Tile',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFFF6B6B)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
