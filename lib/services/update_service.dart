import 'package:dio/dio.dart';

import '../models/app_release.dart';

class UpdateService {
  UpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
                'User-Agent': 'shiplus-update-checker',
              },
            ),
          );

  static const latestReleaseApi =
      'https://api.github.com/repos/xayoung/shiplus/releases/latest';
  static const currentAppVersion = String.fromEnvironment(
    'SHIPLUS_VERSION',
    defaultValue: '1.1.3',
  );

  final Dio _dio;

  Future<String> getCurrentVersion() async => currentAppVersion;

  Future<UpdateCheckResult> checkForUpdates({String? currentVersion}) async {
    final installedVersion = currentVersion ?? await getCurrentVersion();
    final response = await _dio.get<Map<String, dynamic>>(latestReleaseApi);
    final data = response.data;
    if (data == null) {
      throw const FormatException('GitHub returned an empty release response.');
    }

    final tagName = data['tag_name'] as String? ?? '';
    final latestVersion = normalizeVersion(tagName);
    if (latestVersion.isEmpty) {
      throw const FormatException('The latest release has no valid version.');
    }

    final release = AppRelease(
      tagName: tagName,
      version: latestVersion,
      publishedAt: DateTime.tryParse(data['published_at'] as String? ?? ''),
      notes: (data['body'] as String? ?? '').trim(),
    );

    return UpdateCheckResult(
      currentVersion: normalizeVersion(installedVersion),
      release: release,
      updateAvailable: compareVersions(latestVersion, installedVersion) > 0,
    );
  }

  static String normalizeVersion(String version) {
    return version.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
  }

  static int compareVersions(String left, String right) {
    final leftVersion = _SemanticVersion.parse(left);
    final rightVersion = _SemanticVersion.parse(right);
    return leftVersion.compareTo(rightVersion);
  }
}

class _SemanticVersion implements Comparable<_SemanticVersion> {
  const _SemanticVersion(this.parts, this.preRelease);

  final List<int> parts;
  final List<String> preRelease;

  factory _SemanticVersion.parse(String value) {
    final normalized = UpdateService.normalizeVersion(value);
    final segments = normalized.split('-');
    final coreParts = segments.first.split('.');
    if (coreParts.isEmpty ||
        coreParts.any((part) => int.tryParse(part) == null)) {
      throw FormatException('Invalid version: $value');
    }
    return _SemanticVersion(
      coreParts.map(int.parse).toList(),
      segments.length > 1
          ? segments.skip(1).join('-').split('.')
          : const <String>[],
    );
  }

  @override
  int compareTo(_SemanticVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var index = 0; index < length; index++) {
      final left = index < parts.length ? parts[index] : 0;
      final right = index < other.parts.length ? other.parts[index] : 0;
      if (left != right) return left.compareTo(right);
    }

    if (preRelease.isEmpty && other.preRelease.isNotEmpty) return 1;
    if (preRelease.isNotEmpty && other.preRelease.isEmpty) return -1;

    final preReleaseLength = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var index = 0; index < preReleaseLength; index++) {
      if (index >= preRelease.length) return -1;
      if (index >= other.preRelease.length) return 1;
      final left = preRelease[index];
      final right = other.preRelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      if (leftNumber != null &&
          rightNumber != null &&
          leftNumber != rightNumber) {
        return leftNumber.compareTo(rightNumber);
      }
      if (leftNumber != null && rightNumber == null) return -1;
      if (leftNumber == null && rightNumber != null) return 1;
      final comparison = left.compareTo(right);
      if (comparison != 0) return comparison;
    }
    return 0;
  }
}
