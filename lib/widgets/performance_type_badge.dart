import 'package:flutter/material.dart';

class PerformanceTypeBadge extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isSelectable;
  final VoidCallback? onTap;

  const PerformanceTypeBadge({
    Key? key,
    required this.label,
    this.isActive = false,
    this.isSelectable = false,
    this.onTap,
  }) : super(key: key);

  IconData _getIconForType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('music')) {
      return Icons.music_note;
    } else if (lowerType.contains('dance')) {
      return Icons.directions_run;
    } else if (lowerType.contains('visual') || lowerType.contains('art')) {
      return Icons.brush;
    } else if (lowerType.contains('comedy')) {
      return Icons.theater_comedy;
    } else if (lowerType.contains('magic')) {
      return Icons.auto_awesome;
    } else {
      return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIconForType(label);
    
    return GestureDetector(
      onTap: isSelectable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF8C00) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: isSelectable && !isActive
              ? Border.all(color: const Color(0xFF3A3A3D), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
