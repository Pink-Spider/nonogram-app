import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Undo · Erase · Notes · Hint
class GameToolbar extends StatelessWidget {
  const GameToolbar({
    super.key,
    required this.canUndo,
    required this.crossMode,
    required this.freeHintsLeft,
    required this.onUndo,
    required this.onErase,
    required this.onToggleCross,
    required this.onHint,
  });

  final bool canUndo;
  /// True when taps leave a cross. The nonogram equivalent of pencil mode.
  final bool crossMode;
  final int freeHintsLeft;
  final VoidCallback onUndo;
  final VoidCallback onErase;
  final VoidCallback onToggleCross;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ToolButton(
          icon: Icons.undo,
          label: l.undo,
          onTap: canUndo ? onUndo : null,
        ),
        _ToolButton(
          icon: Icons.backspace_outlined,
          label: l.erase,
          onTap: onErase,
        ),
        _ToolButton(
          icon: crossMode ? Icons.close : Icons.crop_square,
          label: l.notes,
          onTap: onToggleCross,
          active: crossMode,
        ),
        _ToolButton(
          icon: freeHintsLeft > 0 ? Icons.lightbulb : Icons.play_circle_outline,
          label: freeHintsLeft > 0 ? '${l.hint} · ${l.hintsLeft(freeHintsLeft)}' : l.hint,
          onTap: onHint,
          badgeColor: freeHintsLeft > 0 ? null : scheme.tertiary,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? scheme.outlineVariant
        : active
            ? scheme.primary
            : badgeColor ?? scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
