import 'package:flutter/material.dart';

/// A button that visibly promises a reward for watching an ad.
/// Shows a play icon and greys out when no ad is ready.
class RewardButton extends StatelessWidget {
  const RewardButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.ready = true,
    this.icon = Icons.play_circle_outline,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool ready;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: ready ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
