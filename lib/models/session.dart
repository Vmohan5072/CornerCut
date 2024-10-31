class Session {
  final DateTime date;
  final List<Duration> lapTimes;
  final Duration? bestLapTime;

  Session({required this.date, required this.lapTimes})
      : bestLapTime = lapTimes.isNotEmpty ? lapTimes.reduce((a, b) => a < b ? a : b) : null;
}