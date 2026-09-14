/// `mm:ss`, or `h:mm:ss` past an hour.
String formatDuration(Duration d) {
  String two(int n) => n < 10 ? '0$n' : '$n';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
