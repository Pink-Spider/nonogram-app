import 'package:flutter/material.dart';

/// The completion reveal. Replaces the toolbar once the puzzle is solved.
///
/// The board turning into the picture IS the reward, so the card waits a
/// beat before sliding up — the player gets the bare picture first, then
/// the name and the numbers arrive as an epilogue.
class SolvedCard extends StatefulWidget {
  const SolvedCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.homeLabel,
    required this.playAgainLabel,
    required this.onHome,
    required this.onPlayAgain,
    this.note,
  });

  /// "You drew: Cat!" — or a plain "Solved!" when the shape is unknown.
  final String title;

  /// Difficulty · time · mistakes.
  final String subtitle;

  /// Extra line for the daily challenge.
  final String? note;

  final String homeLabel;
  final String playAgainLabel;
  final VoidCallback onHome;
  final VoidCallback onPlayAgain;

  @override
  State<SolvedCard> createState() => _SolvedCardState();
}

class _SolvedCardState extends State<SolvedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  // The first ~60% of the timeline is the hold on the picture.
  late final CurvedAnimation _entrance = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 1, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FadeTransition(
      opacity: _entrance,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(_entrance),
        child: Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🎉 ${widget.title}',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
                if (widget.note != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.note!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: widget.onHome,
                      child: Text(widget.homeLabel),
                    ),
                    FilledButton(
                      onPressed: widget.onPlayAgain,
                      child: Text(widget.playAgainLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
