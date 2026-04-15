import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class IdVerificationResult {
  final bool isValid;
  final String message;
  final Map<String, String> details;

  const IdVerificationResult({
    required this.isValid,
    required this.message,
    required this.details,
  });
}

class _OcrSnapshot {
  final List<String> lines;
  final String allText;

  const _OcrSnapshot({required this.lines, required this.allText});
}

class PhilippineIdVerificationService {
  Future<IdVerificationResult> verifyDocument({
    required String documentType,
    required String imagePath,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final snapshots = <_OcrSnapshot>[];
    final tempFiles = <String>[];

    try {
      final paths = [imagePath];
      for (final angle in const [90, 180, 270]) {
        final rotated = await _createRotatedTempImage(imagePath, angle);
        if (rotated != null) {
          paths.add(rotated);
          tempFiles.add(rotated);
        }
      }

      for (final path in paths) {
        final inputImage = InputImage.fromFilePath(path);
        final recognizedText = await recognizer.processImage(inputImage);
        final lines = recognizedText.blocks
            .expand((block) => block.lines)
            .map((line) => line.text.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (lines.isEmpty) continue;
        snapshots.add(_OcrSnapshot(lines: lines, allText: lines.join('\n')));
      }

      if (snapshots.isEmpty) {
        return const IdVerificationResult(
          isValid: false,
          message: 'No readable text found. Please retake a clearer photo.',
          details: {
            'fullName': 'Not detected',
            'dob': 'Not detected',
            'sex': 'Not detected',
            'idNumber': 'Not detected',
            'bloodType': 'Not detected',
          },
        );
      }

      if (documentType.toLowerCase().contains('national')) {
        return _bestNationalResult(snapshots);
      }
      if (documentType.toLowerCase().contains('driver')) {
        return _bestDriverLicenseResult(snapshots);
      }
      return _bestStudentResult(snapshots);
    } finally {
      for (final tempPath in tempFiles) {
        try {
          final file = File(tempPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {
          // Ignore temp cleanup failures.
        }
      }
      await recognizer.close();
    }
  }

  Future<String?> _createRotatedTempImage(String sourcePath, int angle) async {
    try {
      final sourceFile = File(sourcePath);
      final bytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final rotated = img.copyRotate(decoded, angle: angle.toDouble());
      final jpg = img.encodeJpg(rotated, quality: 92);
      final outputPath =
          '${Directory.systemTemp.path}/kbsync_ocr_${DateTime.now().microsecondsSinceEpoch}_$angle.jpg';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(jpg, flush: true);
      return outputPath;
    } catch (_) {
      return null;
    }
  }

  IdVerificationResult _bestNationalResult(List<_OcrSnapshot> snapshots) {
    IdVerificationResult? best;
    var bestScore = -999;
    for (final snapshot in snapshots) {
      final result = _verifyNationalId(snapshot.lines, snapshot.allText);
      var score = 0;
      if (result.isValid) score += 12;
      if ((result.details['fullName'] ?? 'Not detected') != 'Not detected') {
        score += 3;
      }
      if ((result.details['idNumber'] ?? 'Not detected') != 'Not detected') {
        score += 4;
      }
      if (score > bestScore) {
        best = result;
        bestScore = score;
      }
    }
    return best ??
        _verifyNationalId(snapshots.first.lines, snapshots.first.allText);
  }

  IdVerificationResult _bestDriverLicenseResult(List<_OcrSnapshot> snapshots) {
    IdVerificationResult? best;
    var bestScore = -999;
    for (final snapshot in snapshots) {
      final result = _verifyDriverLicense(snapshot.lines, snapshot.allText);
      var score = 0;
      if (result.isValid) score += 12;
      if ((result.details['fullName'] ?? 'Not detected') != 'Not detected') {
        score += 3;
      }
      if ((result.details['idNumber'] ?? 'Not detected') != 'Not detected') {
        score += 4;
      }
      if (score > bestScore) {
        best = result;
        bestScore = score;
      }
    }
    return best ??
        _verifyDriverLicense(snapshots.first.lines, snapshots.first.allText);
  }

  IdVerificationResult _bestStudentResult(List<_OcrSnapshot> snapshots) {
    IdVerificationResult? best;
    var bestScore = -999;
    for (final snapshot in snapshots) {
      final result = _verifyStudentId(snapshot.lines, snapshot.allText);
      final fullName = result.details['fullName'] ?? 'Not detected';
      var score = 0;
      if (result.isValid) score += 12;
      if (fullName != 'Not detected') score += _studentNameScore(fullName);
      if (_containsCourseTerms(fullName)) score -= 20;
      if ((result.details['idNumber'] ?? 'Not detected') != 'Not detected') {
        score += 3;
      }
      if (score > bestScore) {
        best = result;
        bestScore = score;
      }
    }
    return best ??
        _verifyStudentId(snapshots.first.lines, snapshots.first.allText);
  }

  IdVerificationResult _verifyNationalId(List<String> lines, String text) {
    final upper = text.toUpperCase();
    final hasPhMarker =
        upper.contains('REPUBLIC OF THE PHILIPPINES') ||
        upper.contains('PHILIPPINE IDENTIFICATION CARD') ||
        upper.contains('PHILID');
    final idNumber = _extractNationalIdNumber(text);
    final fullName = _extractName(lines, documentType: 'national');
    final dob = _extractDate(text);
    final sex = _extractSex(upper);
    final bloodType = _extractBloodType(upper);

    final isValid =
        hasPhMarker &&
        idNumber != null &&
        fullName != null &&
        dob != null &&
        sex != null;

    return IdVerificationResult(
      isValid: isValid,
      message: isValid
          ? 'National ID verified successfully.'
          : 'Unable to validate this as a Philippine National ID. Please retake clearly.',
      details: {
        'fullName': fullName ?? 'Not detected',
        'dob': dob ?? 'Not detected',
        'sex': sex ?? 'Not detected',
        'idNumber': idNumber ?? 'Not detected',
        'bloodType': bloodType ?? 'Not detected',
      },
    );
  }

  IdVerificationResult _verifyStudentId(List<String> lines, String text) {
    final upper = text.toUpperCase();
    final hasStudentMarker =
        upper.contains('STUDENT') ||
        upper.contains('UNIVERSITY') ||
        upper.contains('COLLEGE') ||
        upper.contains('SCHOOL') ||
        upper.contains('INSTITUTE');
    final studentNumber = _extractStudentIdNumber(lines, text);
    final fullName = _extractStudentName(lines, text);
    final dob = _extractDate(text);
    final sex = _extractSex(upper);
    final bloodType = _extractBloodType(upper);

    final isValid =
        hasStudentMarker && studentNumber != null && fullName != null;

    return IdVerificationResult(
      isValid: isValid,
      message: isValid
          ? 'Student ID verified successfully.'
          : 'Unable to validate this as a Philippine Student ID. Please retake clearly.',
      details: {
        'fullName': fullName ?? 'Not detected',
        'dob': dob ?? 'Not detected',
        'sex': sex ?? 'Not detected',
        'idNumber': studentNumber ?? 'Not detected',
        'bloodType': bloodType ?? 'Not detected',
      },
    );
  }

  IdVerificationResult _verifyDriverLicense(List<String> lines, String text) {
    final upper = text.toUpperCase();
    final hasDriverMarkers =
        upper.contains('DRIVER') ||
        upper.contains('DRIVER\'S LICENSE') ||
        upper.contains('DRIVERS LICENSE') ||
        upper.contains('LAND TRANSPORTATION OFFICE') ||
        upper.contains('LTO') ||
        upper.contains('REPUBLIC OF THE PHILIPPINES');

    final licenseNumber = _extractDriverLicenseNumber(lines, text);
    final fullName = _extractDriverName(lines, text);
    final dob = _extractDriverDob(lines, text);
    final sex = _extractDriverSex(lines, text);
    final bloodType = _extractBloodType(upper);

    final isValid =
        hasDriverMarkers &&
        licenseNumber != null &&
        fullName != null &&
        dob != null &&
        sex != null;

    return IdVerificationResult(
      isValid: isValid,
      message: isValid
          ? 'Driver\'s License verified successfully.'
          : 'Unable to validate this as a Philippine Driver\'s License. Please retake clearly.',
      details: {
        'fullName': fullName ?? 'Not detected',
        'dob': dob ?? 'Not detected',
        'sex': sex ?? 'Not detected',
        'idNumber': licenseNumber ?? 'Not detected',
        'bloodType': bloodType ?? 'Not detected',
      },
    );
  }

  String? _extractNationalIdNumber(String text) {
    final match = RegExp(
      r'(\d{4})\s*[- ]\s*(\d{4})\s*[- ]\s*(\d{4})',
    ).firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
  }

  String? _extractStudentIdNumber(List<String> lines, String text) {
    for (final line in lines) {
      final normalized = line.toUpperCase();
      if (!normalized.contains('ID')) continue;
      final match = RegExp(
        r'([A-Z]{0,4}\d{4,12}(?:-\d{2,6})?)',
      ).firstMatch(normalized.replaceAll(' ', ''));
      if (match != null) return match.group(1);
    }

    final fallback = RegExp(r'\b(\d{4,6}[- ]\d{3,6})\b').firstMatch(text);
    return fallback?.group(1)?.replaceAll(' ', '-');
  }

  String? _extractDriverLicenseNumber(List<String> lines, String text) {
    final patterns = <RegExp>[
      RegExp(r'\b([A-Z]{1,2}\d{2}-\d{2}-\d{6})\b'),
      RegExp(r'\b([A-Z]\d{2}\s*\d{2}\s*\d{6})\b'),
      RegExp(r'\b([A-Z0-9]{5,15})\b'),
    ];

    for (final line in lines) {
      final upper = line.toUpperCase();
      if (!(upper.contains('LICENSE') ||
          upper.contains('LICENCE') ||
          upper.contains('LIC NO') ||
          upper.contains('NO.'))) {
        continue;
      }
      for (final pattern in patterns) {
        final match = pattern.firstMatch(upper.replaceAll(' ', ''));
        if (match != null) {
          return match.group(1);
        }
      }
    }

    for (final pattern in patterns.take(2)) {
      final match = pattern.firstMatch(text.toUpperCase().replaceAll(' ', ''));
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _extractName(
    List<String> lines, {
    required String documentType,
    bool allowScanOrderFallback = true,
  }) {
    final isStudent = documentType.toLowerCase().contains('student');
    final labelPatterns = isStudent
        ? <RegExp>[
            RegExp(r'^\s*STUDENT\s*NAME\b', caseSensitive: false),
            RegExp(r'^\s*NAME\s+OF\s+STUDENT\b', caseSensitive: false),
            RegExp(r'^\s*NAME\b', caseSensitive: false),
          ]
        : <RegExp>[RegExp(r'^\s*NAME\b', caseSensitive: false)];

    for (var i = 0; i < lines.length; i++) {
      final current = lines[i].trim();

      // 1) Exact label line then next line value.
      final hasLabel = labelPatterns.any(
        (pattern) => pattern.hasMatch(current),
      );
      if (hasLabel) {
        if (i + 1 < lines.length) {
          final next = _normalizeLine(lines[i + 1]);
          final extracted = _extractPersonNameFromLine(next) ?? next;
          if (_isLikelyName(extracted, strict: true)) return extracted;
        }

        // 2) Label and value on the same line (e.g., NAME: JUAN DELA CRUZ)
        final sameLine = RegExp(
          r'^\s*(STUDENT\s*NAME|NAME\s+OF\s+STUDENT|NAME)\s*[:\-]?\s*(.+)$',
          caseSensitive: false,
        ).firstMatch(current);
        if (sameLine != null) {
          final candidate =
              _extractPersonNameFromLine(_normalizeLine(sameLine.group(2)!)) ??
              _normalizeLine(sameLine.group(2)!);
          if (_isLikelyName(candidate, strict: true)) return candidate;
        }
      }
    }

    if (allowScanOrderFallback) {
      // Deterministic fallback: first likely name-like line in scan order.
      for (final line in lines) {
        final candidate =
            _extractPersonNameFromLine(_normalizeLine(line)) ??
            _normalizeLine(line);
        if (_isLikelyName(candidate, strict: false)) return candidate;
      }
    }

    return null;
  }

  String? _extractStudentName(List<String> lines, String text) {
    final byLabel = _extractName(
      lines,
      documentType: 'student',
      allowScanOrderFallback: false,
    );
    if (byLabel != null) return byLabel;

    final byStrongPattern = _extractStudentNameByStrongPattern(lines, text);
    if (byStrongPattern != null) return byStrongPattern;

    final byContextRanking = _extractBestStudentNameCandidate(lines);
    if (byContextRanking != null) return byContextRanking;

    // Student IDs often place the name very near the STUDENT label.
    final nearStudent = _extractNameNearStudentMarker(lines);
    if (nearStudent != null) return nearStudent;

    // Final fallback: parse full OCR text for person-name pattern.
    final fromText = _extractPersonNameFromLine(text);
    if (fromText != null &&
        _isLikelyName(fromText, strict: false) &&
        !_containsCourseTerms(fromText)) {
      return fromText;
    }

    return null;
  }

  String? _extractDriverName(List<String> lines, String text) {
    // Prefer labeled fields for driver's license.
    final labelPatterns = <RegExp>[
      RegExp(r'^\s*NAME\b', caseSensitive: false),
      RegExp(r'^\s*LAST\s*NAME\b', caseSensitive: false),
      RegExp(r'^\s*FIRST\s*NAME\b', caseSensitive: false),
      RegExp(r'^\s*SURNAME\b', caseSensitive: false),
      RegExp(r'^\s*GIVEN\s*NAME\b', caseSensitive: false),
    ];

    for (var i = 0; i < lines.length; i++) {
      final current = lines[i].trim();
      final hasLabel = labelPatterns.any(
        (pattern) => pattern.hasMatch(current),
      );
      if (!hasLabel) continue;

      if (i + 1 < lines.length) {
        final next = _normalizeLine(lines[i + 1]);
        final extracted = _extractPersonNameFromLine(next) ?? next;
        if (_isLikelyName(extracted, strict: true)) return extracted;
      }

      final sameLine = RegExp(
        r'^\s*(NAME|LAST\s*NAME|FIRST\s*NAME|SURNAME|GIVEN\s*NAME)\s*[:\-]?\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(current);
      if (sameLine != null) {
        final candidate =
            _extractPersonNameFromLine(_normalizeLine(sameLine.group(2)!)) ??
            _normalizeLine(sameLine.group(2)!);
        if (_isLikelyName(candidate, strict: true)) return candidate;
      }
    }

    // Fallback to generic extraction with scan-order fallback enabled.
    return _extractName(
      lines,
      documentType: 'driver',
      allowScanOrderFallback: true,
    );
  }

  String? _extractDriverSex(List<String> lines, String text) {
    final allLines = [...lines, text];

    for (var i = 0; i < allLines.length; i++) {
      final line = _normalizeForMatching(allLines[i]);

      final sameLine = RegExp(
        r'\b(SEX|GENDER)\b\s*[:\-]?\s*(MALE|FEMALE|M|F)\b',
      ).firstMatch(line);
      if (sameLine != null) {
        return _normalizeSexValue(sameLine.group(2)!);
      }

      if (line.contains('SEX') || line.contains('GENDER')) {
        if (i + 1 < allLines.length) {
          final next = _normalizeForMatching(allLines[i + 1]);
          final nextValue = RegExp(r'\b(MALE|FEMALE|M|F)\b').firstMatch(next);
          if (nextValue != null) {
            return _normalizeSexValue(nextValue.group(1)!);
          }
        }
      }
    }

    return _extractSex(_normalizeForMatching(text));
  }

  String _normalizeSexValue(String raw) {
    final upper = _normalizeForMatching(raw);
    if (upper == 'F' || upper == 'FEMALE') return 'Female';
    return 'Male';
  }

  String? _extractDriverDob(List<String> lines, String text) {
    final allLines = [...lines, text];

    for (var i = 0; i < allLines.length; i++) {
      final line = _normalizeForMatching(allLines[i]);

      final sameLineDate = _extractDateFromLine(line);
      if (_containsDobLabel(line) && sameLineDate != null) {
        return sameLineDate;
      }

      if (_containsDobLabel(line) && i + 1 < allLines.length) {
        final next = _normalizeForMatching(allLines[i + 1]);
        final nextDate = _extractDateFromLine(next);
        if (nextDate != null) return nextDate;
      }
    }

    return _extractDate(_normalizeForMatching(text));
  }

  bool _containsDobLabel(String line) {
    return line.contains('DATE OF BIRTH') ||
        line.contains('BIRTH DATE') ||
        line.contains('BIRTHDATE') ||
        line.contains('DOB');
  }

  String? _extractDateFromLine(String line) {
    final normalized = _normalizeDateChars(line);

    final ymd = RegExp(
      r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',
    ).firstMatch(normalized);
    if (ymd != null) return ymd.group(1);

    final dmyOrMdy = RegExp(
      r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',
    ).firstMatch(normalized);
    if (dmyOrMdy != null) return dmyOrMdy.group(1);

    final dayMonthYear = RegExp(
      r'\b(\d{1,2}\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\s+\d{2,4})\b',
    ).firstMatch(normalized);
    if (dayMonthYear != null) return dayMonthYear.group(1);

    final monthDayYear = RegExp(
      r'\b((JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\s+\d{1,2},?\s+\d{2,4})\b',
    ).firstMatch(normalized);
    if (monthDayYear != null) return monthDayYear.group(1);

    return null;
  }

  String _normalizeDateChars(String value) {
    return value.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');
  }

  String? _extractBestStudentNameCandidate(List<String> lines) {
    var bestCandidate = '';
    var bestScore = -999;

    for (var i = 0; i < lines.length; i++) {
      final raw = _normalizeLine(lines[i]);
      final candidate = _extractPersonNameFromLine(raw) ?? raw;
      if (!_isLikelyName(candidate, strict: false)) continue;
      if (_containsCourseTerms(candidate)) continue;

      var score = _studentNameScore(candidate);
      final context = _nearbyContext(lines, i, radius: 2);

      if (_containsAny(context, const ['STUDENT', 'ID NO', 'PROGRAM'])) {
        score += 4;
      }

      if (_containsAny(context, const [
        'BACHELOR',
        'SCIENCE',
        'INFORMATION',
        'TECHNOLOGY',
        'COURSE',
      ])) {
        score -= 5;
      }

      if (_containsAny(context, const [
        'DIRECTOR',
        'OFFICE',
        'REGISTRAR',
        'DEAN',
        'CHANCELLOR',
        'PRESIDENT',
        'SECRETARY',
        'STUDENT AFFAIRS',
        'AFFAIRS',
      ])) {
        score -= 6;
      }

      if (RegExp(r'^[A-Z .,\-]+$').hasMatch(candidate.toUpperCase())) {
        score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    if (bestScore < 0) return null;
    return bestCandidate;
  }

  String? _extractStudentNameByStrongPattern(List<String> lines, String text) {
    final lineText = lines.join(' ').toUpperCase();
    final combined = '$lineText ${text.toUpperCase()}';

    // Strong pattern: FIRST MIDDLE INITIAL SURNAME
    final middleInitialMatches = RegExp(
      r'\b([A-Z]{2,}\s+[A-Z]{2,}\s+[A-Z]\.?\s+[A-Z]{2,})\b',
    ).allMatches(combined);
    for (final match in middleInitialMatches) {
      final candidate = _normalizeLine(match.group(1)!.replaceAll('.', '. '));
      if (_isLikelyName(candidate, strict: false) &&
          !_containsCourseTerms(candidate)) {
        return candidate;
      }
    }

    // Backup pattern: 3 to 4 all-alpha name words.
    final longNameMatches = RegExp(
      r'\b([A-Z]{2,}(?:\s+[A-Z]{2,}){2,3})\b',
    ).allMatches(combined);
    for (final match in longNameMatches) {
      final candidate = _normalizeLine(match.group(1)!);
      if (_isLikelyName(candidate, strict: false) &&
          !_containsCourseTerms(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  String _nearbyContext(List<String> lines, int index, {required int radius}) {
    final start = (index - radius).clamp(0, lines.length - 1);
    final end = (index + radius).clamp(0, lines.length - 1);
    return lines.sublist(start, end + 1).join(' ').toUpperCase();
  }

  bool _containsAny(String text, List<String> terms) {
    for (final term in terms) {
      if (text.contains(term)) return true;
    }
    return false;
  }

  String? _extractNameNearStudentMarker(List<String> lines) {
    var bestCandidate = '';
    var bestScore = -1;

    for (var i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();
      if (!upper.contains('STUDENT')) continue;

      for (var offset = -4; offset <= 4; offset++) {
        if (offset == 0) continue;
        final index = i + offset;
        if (index < 0 || index >= lines.length) continue;

        final raw = _normalizeLine(lines[index]);
        final candidate = _extractPersonNameFromLine(raw) ?? raw;
        if (!_isLikelyName(candidate, strict: false)) continue;
        if (_containsCourseTerms(candidate)) continue;

        final score = _studentNameScore(candidate);
        if (score > bestScore) {
          bestScore = score;
          bestCandidate = candidate;
        }
      }
    }

    return bestScore >= 0 ? bestCandidate : null;
  }

  int _studentNameScore(String candidate) {
    final upper = candidate.toUpperCase();
    final words = candidate
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();

    var score = 0;
    if (words.length >= 2 && words.length <= 5) score += 2;
    if (RegExp(r'\b[A-Z]\.\b').hasMatch(upper)) score += 2;
    if (RegExp(r'^[A-Z .,\-]+$').hasMatch(upper)) score += 2;
    if (words.any((word) => word.length >= 5)) score += 1;
    return score;
  }

  String? _extractPersonNameFromLine(String raw) {
    final line = _normalizeLine(raw);
    if (line.isEmpty) return null;

    // Build token windows and stop when course/institution tokens begin.
    final tokens = line
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9.\-\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    String? best;
    var bestScore = -999;

    for (var i = 0; i < tokens.length; i++) {
      final window = <String>[];
      for (var j = i; j < tokens.length && window.length < 6; j++) {
        final token = tokens[j];
        final canonical = _normalizeForMatching(token);
        if (_isHardStopToken(canonical)) break;
        if (!_looksLikeNameToken(token)) break;

        window.add(token);
        if (window.length < 2) continue;

        final candidate = window.join(' ');
        if (!_isLikelyName(candidate, strict: false)) continue;
        if (_containsCourseTerms(candidate)) continue;

        var score = _studentNameScore(candidate);
        if (RegExp(r'\b[A-Z]\.\b').hasMatch(candidate)) score += 2;
        if (window.length >= 3) score += 1;

        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }
    }

    return best;
  }

  String _normalizeLine(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isLikelyName(String value, {required bool strict}) {
    if (value.length < 4) return false;
    if (RegExp(r'\d').hasMatch(value)) return false;

    final upper = value.toUpperCase();
    const blockedKeywords = <String>[
      'REPUBLIC',
      'PHILIPPINE',
      'IDENTIFICATION',
      'NATIONAL',
      'NUMBER',
      'ID NUMBER',
      'DATE',
      'BIRTH',
      'BLOOD',
      'SEX',
      'STUDENT',
      'UNIVERSITY',
      'COLLEGE',
      'SCHOOL',
      'INSTITUTE',
      'ADDRESS',
      'VALID',
      'SIGNATURE',
    ];
    for (final keyword in blockedKeywords) {
      if (upper.contains(keyword)) return false;
    }
    if (_containsCourseTerms(value)) return false;
    if (_containsCampusLocationTerms(value)) return false;

    final words = value
        .split(' ')
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length < 2) return false;

    final wordPattern = strict
        ? RegExp(r"^[A-Za-z][A-Za-z'.\-]{1,}$")
        : RegExp(r"^[A-Za-z][A-Za-z'.\-]{0,}$");
    final validWordCount = words
        .where((word) => wordPattern.hasMatch(word))
        .length;

    if (strict) {
      return validWordCount == words.length;
    }
    return validWordCount >= 2;
  }

  bool _containsCourseTerms(String value) {
    final upper = _normalizeForMatching(value);
    const courseTerms = <String>[
      'BACHELOR',
      'SCIENCE',
      'INFORMATION',
      'TECHNOLOGY',
      'ENGINEERING',
      'COURSE',
      'PROGRAM',
      'MAJOR',
      'BSIT',
      'BSCS',
      'BSIS',
      'BSBA',
      'COLLEGE OF',
      'DEPARTMENT',
      'NEW VISAYAS',
      'PANABO CITY',
      'STATE COLLEGE',
      'UNIVERSITY',
    ];
    for (final term in courseTerms) {
      if (upper.contains(term)) return true;
    }
    return false;
  }

  bool _containsCampusLocationTerms(String value) {
    final upper = _normalizeForMatching(value);
    const locationTerms = <String>[
      'DAVAO DEL NORTE',
      'PANABO CITY',
      'NEW VISAYAS',
      'STATE COLLEGE',
      'CITY OF',
      'PROVINCE OF',
    ];
    for (final term in locationTerms) {
      if (upper.contains(term)) return true;
    }
    return false;
  }

  String _normalizeForMatching(String value) {
    return value
        .toUpperCase()
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll(RegExp(r'[^A-Z.\-\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isHardStopToken(String token) {
    const stopTokens = <String>{
      'BACHELOR',
      'SCIENCE',
      'INFORMATION',
      'TECHNOLOGY',
      'COURSE',
      'PROGRAM',
      'MAJOR',
      'UNIVERSITY',
      'COLLEGE',
      'SCHOOL',
      'INSTITUTE',
      'DIRECTOR',
      'OFFICE',
      'REGISTRAR',
      'DEAN',
      'PRESIDENT',
      'SECRETARY',
      'AFFAIRS',
      'VALID',
      'ADDRESS',
      'ID',
      'NO',
    };
    return stopTokens.contains(token);
  }

  bool _looksLikeNameToken(String token) {
    return RegExp(r"^[A-Z][A-Z'.-]*$").hasMatch(token);
  }

  String? _extractDate(String text) {
    final upper = _normalizeDateChars(text.toUpperCase());
    final ymd = RegExp(r'\b(\d{4}[/-]\d{1,2}[/-]\d{1,2})\b').firstMatch(upper);
    if (ymd != null) {
      return ymd.group(1);
    }

    final monthDate = RegExp(
      r'\b(\d{1,2}\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\s+\d{2,4})\b',
    ).firstMatch(upper);
    if (monthDate != null) {
      return monthDate.group(1);
    }

    final slashDate = RegExp(
      r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b',
    ).firstMatch(upper);
    return slashDate?.group(1);
  }

  String? _extractSex(String upper) {
    final fullWord = RegExp(r'\b(MALE|FEMALE)\b').firstMatch(upper);
    if (fullWord != null) {
      final value = fullWord.group(1)!;
      return value[0] + value.substring(1).toLowerCase();
    }

    final shortWord = RegExp(r'SEX[:\s]+([MF])\b').firstMatch(upper);
    if (shortWord == null) return null;
    return shortWord.group(1) == 'F' ? 'Female' : 'Male';
  }

  String? _extractBloodType(String upper) {
    final blood = RegExp(
      r'BLOOD\s*TYPE[:\s-]*([ABO]{1,2}[+-]?)',
    ).firstMatch(upper);
    return blood?.group(1);
  }
}
