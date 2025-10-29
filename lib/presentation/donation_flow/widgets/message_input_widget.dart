import 'package:flutter/material.dart';

import '../../../core/app_export.dart';

class MessageInputWidget extends StatefulWidget {
  final Function(String) onMessageChanged;
  final String message;

  const MessageInputWidget({
    Key? key,
    required this.onMessageChanged,
    required this.message,
  }) : super(key: key);

  @override
  State<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends State<MessageInputWidget> {
  final TextEditingController _messageController = TextEditingController();
  final int _maxCharacters = 100;

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.message;
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    widget.onMessageChanged(_messageController.text);
  }

  @override
  Widget build(BuildContext context) {
    final remainingCharacters = _maxCharacters - _messageController.text.length;
    final isNearLimit = remainingCharacters <= 20;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add a Message (Optional)',
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '$remainingCharacters/$_maxCharacters',
                style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                  color:
                      isNearLimit ? AppTheme.accentRed : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _messageController.text.isNotEmpty
                    ? AppTheme.primaryOrange.withOpacity(0.5)
                    : AppTheme.borderSubtle,
                width: 1,
              ),
            ),
            child: TextFormField(
              controller: _messageController,
              maxLines: 3,
              maxLength: _maxCharacters,
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Send some encouragement to the performer...',
                hintStyle: null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                counterText: '', // Hide default counter
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Message Preview
          if (_messageController.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomIconWidget(
                    iconName: 'format_quote',
                    color: AppTheme.primaryOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _messageController.text,
                      style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Suggested Messages
          Text(
            'Quick Messages:',
            style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Keep up the great work! 🎵',
              'Amazing performance! 👏',
              'You made my day! ✨',
              'Love your energy! 🔥',
            ].map((suggestion) {
              final isSelected = _messageController.text == suggestion;
              return SizedBox(
                height: 48,
                child: ChoiceChip(
                  label: Text(
                    suggestion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                      color: isSelected ? AppTheme.primaryOrange : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    _messageController.text = suggestion;
                    widget.onMessageChanged(suggestion);
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryOrange
                          : AppTheme.borderSubtle,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  backgroundColor: AppTheme.surfaceDark,
                  selectedColor: AppTheme.primaryOrange.withOpacity(0.08),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
