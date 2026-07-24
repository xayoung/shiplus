class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.version,
    required this.publishedAt,
    required this.notes,
  });

  final String tagName;
  final String version;
  final DateTime? publishedAt;
  final String notes;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.release,
    required this.updateAvailable,
  });

  final String currentVersion;
  final AppRelease release;
  final bool updateAvailable;
}
