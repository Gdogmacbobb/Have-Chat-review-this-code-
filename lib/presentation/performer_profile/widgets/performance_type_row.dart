import 'package:flutter/material.dart';
import 'package:ynfny/widgets/performance_type_badge.dart';
import '../../../core/app_export.dart';

class PerformanceTypeRow extends StatelessWidget {
  final List<String> performanceTypes;

  const PerformanceTypeRow({
    super.key,
    required this.performanceTypes,
  });

  @override
  Widget build(BuildContext context) {
    if (performanceTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: performanceTypes.map((type) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: PerformanceTypeBadge(
              label: type,
              isActive: true,
              isSelectable: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}
