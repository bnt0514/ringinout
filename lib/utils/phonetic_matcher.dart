// lib/utils/phonetic_matcher.dart
//
// 음성인식 결과와 등록된 이름 간 음성학적 유사도 매칭
// ─ 한국어: 자모 분해 → 유사 자음 그룹핑 → Levenshtein 비교
// ─ 기타 언어: 정규화 후 Levenshtein 비교
// ─ 모든 언어: substring 포함 여부도 함께 검사

class PhoneticMatcher {
  // ── 공개 API ──────────────────────────────────────────────

  /// [input] 음성인식 원문(소문자/공백 제거 전)에서
  /// [candidates] 목록 중 가장 유사한 이름을 찾아 인덱스를 반환.
  /// [threshold] 이하의 정규화 거리(0.0~1.0)면 매칭 성공.
  /// 매칭 실패 시 -1.
  static int findBestMatch({
    required String input,
    required List<String> candidates,
    double threshold = 0.45,
  }) {
    if (input.isEmpty || candidates.isEmpty) return -1;

    final normalizedInput = _normalize(input);
    if (normalizedInput.isEmpty) return -1;

    // ── 1단계: 정확한 substring 포함 (기존 로직) ──
    // 긴 이름부터 먼저 매칭 (더 정확)
    final indexed = List.generate(candidates.length, (i) => i);
    indexed.sort(
      (a, b) => candidates[b].length.compareTo(candidates[a].length),
    );

    for (final i in indexed) {
      final norm = _normalize(candidates[i]);
      if (norm.isEmpty) continue;
      if (normalizedInput.contains(norm)) return i;
    }

    // ── 2단계: 음성학적 유사도 매칭 ──
    // 입력에서 각 후보 이름 길이만큼 슬라이딩 윈도우로 최적 유사도를 찾음
    int bestIdx = -1;
    double bestScore = double.infinity;

    for (final i in indexed) {
      final candidateNorm = _normalize(candidates[i]);
      if (candidateNorm.isEmpty) continue;

      // 한국어 포함 여부 판별
      final bool hasKorean = _containsKorean(candidateNorm);

      // 후보의 자모 분해 (한국어) 또는 원본 (비한국어)
      final candidatePhonetic =
          hasKorean ? _decomposeKorean(candidateNorm) : candidateNorm;
      final inputPhonetic =
          hasKorean ? _decomposeKorean(normalizedInput) : normalizedInput;

      // 유사 자음 그룹 치환 (한국어)
      final candidateGrouped =
          hasKorean
              ? _applyConsonantGroups(candidatePhonetic)
              : candidatePhonetic;
      final inputGrouped =
          hasKorean ? _applyConsonantGroups(inputPhonetic) : inputPhonetic;

      // 슬라이딩 윈도우: 입력 텍스트에서 후보 길이만큼 잘라 비교
      final cLen = candidateGrouped.length;
      if (cLen == 0) continue;

      double minDist = double.infinity;

      if (inputGrouped.length <= cLen) {
        // 입력이 후보보다 짧으면 전체 비교
        final dist = _levenshteinDistance(inputGrouped, candidateGrouped);
        final normalized = dist / cLen;
        minDist = normalized;
      } else {
        // 슬라이딩 윈도우
        for (int start = 0; start <= inputGrouped.length - cLen; start++) {
          final window = inputGrouped.substring(start, start + cLen);
          final dist = _levenshteinDistance(window, candidateGrouped);
          final normalized = dist / cLen;
          if (normalized < minDist) {
            minDist = normalized;
          }
          // 완벽 매칭이면 즉시 중단
          if (minDist == 0) break;
        }
        // 후보보다 약간 긴 윈도우도 시도 (음소 하나 차이)
        for (
          int extra = 1;
          extra <= 2 && cLen + extra <= inputGrouped.length;
          extra++
        ) {
          for (
            int start = 0;
            start <= inputGrouped.length - (cLen + extra);
            start++
          ) {
            final window = inputGrouped.substring(start, start + cLen + extra);
            final dist = _levenshteinDistance(window, candidateGrouped);
            final normalized = dist / cLen;
            if (normalized < minDist) {
              minDist = normalized;
            }
          }
        }
      }

      if (minDist < bestScore) {
        bestScore = minDist;
        bestIdx = i;
      }
    }

    // 초성 매칭도 시도 (한국어 전용, 더 관대한 매칭)
    final choIdx = _matchByChoseong(normalizedInput, candidates, indexed);
    if (choIdx >= 0 && bestScore > 0.3) {
      // 초성 매칭 성공 + 자모 매칭이 애매하면 초성 우선
      return choIdx;
    }

    return bestScore <= threshold ? bestIdx : -1;
  }

  // ── 정규화 ────────────────────────────────────────────────

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  // ── 한국어 감지 ───────────────────────────────────────────

  static bool _containsKorean(String s) {
    return s.runes.any(
      (c) => c >= 0xAC00 && c <= 0xD7A3 || c >= 0x3131 && c <= 0x3163,
    );
  }

  // ── 한국어 자모 분해 ──────────────────────────────────────

  // 초성 19개
  static const List<String> _choseong = [
    'ㄱ',
    'ㄲ',
    'ㄴ',
    'ㄷ',
    'ㄸ',
    'ㄹ',
    'ㅁ',
    'ㅂ',
    'ㅃ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅉ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  // 중성 21개
  static const List<String> _jungseong = [
    'ㅏ',
    'ㅐ',
    'ㅑ',
    'ㅒ',
    'ㅓ',
    'ㅔ',
    'ㅕ',
    'ㅖ',
    'ㅗ',
    'ㅘ',
    'ㅙ',
    'ㅚ',
    'ㅛ',
    'ㅜ',
    'ㅝ',
    'ㅞ',
    'ㅟ',
    'ㅠ',
    'ㅡ',
    'ㅢ',
    'ㅣ',
  ];

  // 종성 28개 (0번은 종성 없음)
  static const List<String> _jongseong = [
    '',
    'ㄱ',
    'ㄲ',
    'ㄳ',
    'ㄴ',
    'ㄵ',
    'ㄶ',
    'ㄷ',
    'ㄹ',
    'ㄺ',
    'ㄻ',
    'ㄼ',
    'ㄽ',
    'ㄾ',
    'ㄿ',
    'ㅀ',
    'ㅁ',
    'ㅂ',
    'ㅄ',
    'ㅅ',
    'ㅆ',
    'ㅇ',
    'ㅈ',
    'ㅊ',
    'ㅋ',
    'ㅌ',
    'ㅍ',
    'ㅎ',
  ];

  /// 한국어 음절을 자모로 분해
  /// "짚둥이" → "ㅈㅣㅂㄷㅜㅇㅇㅣ"  (유사자음 치환 전)
  static String _decomposeKorean(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final code = rune - 0xAC00;
        final cho = code ~/ (21 * 28);
        final jung = (code % (21 * 28)) ~/ 28;
        final jong = code % 28;
        buf.write(_choseong[cho]);
        buf.write(_jungseong[jung]);
        if (jong > 0) buf.write(_jongseong[jong]);
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  /// 초성만 추출
  static String _extractChoseong(String s) {
    final buf = StringBuffer();
    for (final rune in s.runes) {
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        final code = rune - 0xAC00;
        final cho = code ~/ (21 * 28);
        buf.write(_choseong[cho]);
      }
      // 비한글은 무시 (초성 비교 시)
    }
    return buf.toString();
  }

  // ── 유사 자음 그룹핑 ──────────────────────────────────────
  // 된소리/거센소리를 같은 그룹으로 묶어 발음 차이를 흡수
  //
  // 예시:
  //   ㄱ/ㄲ/ㅋ → G    (가/까/카)
  //   ㄷ/ㄸ/ㅌ → D    (다/따/타)
  //   ㅂ/ㅃ/ㅍ → B    (바/빠/파)
  //   ㅅ/ㅆ   → S    (사/싸)
  //   ㅈ/ㅉ/ㅊ → J    (자/짜/차)
  //
  // 이렇게 하면 "짚둥이(ㅉ+ㅣ+ㅂ)" vs "집둥이(ㅈ+ㅣ+ㅂ)" →
  // 둘 다 "J+ㅣ+B" + "D+ㅜ+ㅇ" + "ㅇ+ㅣ" 로 동일해짐!

  static const Map<String, String> _consonantGroupMap = {
    'ㄱ': 'G',
    'ㄲ': 'G',
    'ㅋ': 'G',
    'ㄷ': 'D',
    'ㄸ': 'D',
    'ㅌ': 'D',
    'ㅂ': 'B',
    'ㅃ': 'B',
    'ㅍ': 'B',
    'ㅅ': 'S',
    'ㅆ': 'S',
    'ㅈ': 'J',
    'ㅉ': 'J',
    'ㅊ': 'J',
    'ㄴ': 'N',
    'ㄹ': 'R',
    'ㅁ': 'M',
    'ㅇ': 'O',
    'ㅎ': 'H',
  };

  // 유사 모음 그룹핑 (ㅐ/ㅔ, ㅚ/ㅙ/ㅞ 등 구분 어려운 모음)
  static const Map<String, String> _vowelGroupMap = {
    'ㅐ': 'AE', 'ㅔ': 'AE', // 애/에 혼동
    'ㅒ': 'YAE', 'ㅖ': 'YAE', // 얘/예 혼동
    'ㅚ': 'WE', 'ㅙ': 'WE', 'ㅞ': 'WE', // 외/왜/웨 혼동
    'ㅟ': 'WI', 'ㅢ': 'WI', // 위/의 혼동 (구어에서)
  };

  static String _applyConsonantGroups(String jamo) {
    final buf = StringBuffer();
    for (int i = 0; i < jamo.length; i++) {
      final ch = jamo[i];
      if (_consonantGroupMap.containsKey(ch)) {
        buf.write(_consonantGroupMap[ch]);
      } else if (_vowelGroupMap.containsKey(ch)) {
        buf.write(_vowelGroupMap[ch]);
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  // ── 초성 매칭 (한국어 전용) ──────────────────────────────

  /// 입력 텍스트의 초성과 후보들의 초성을 비교.
  /// 예: "ㅈㄷㅇ" 이 포함된 후보를 찾음.
  static int _matchByChoseong(
    String normalizedInput,
    List<String> candidates,
    List<int> sortedIndices,
  ) {
    if (!_containsKorean(normalizedInput)) return -1;

    final inputCho = _extractChoseong(normalizedInput);
    if (inputCho.length < 2) return -1; // 초성 1글자는 너무 모호

    for (final i in sortedIndices) {
      final candNorm = _normalize(candidates[i]);
      if (!_containsKorean(candNorm)) continue;

      final candCho = _extractChoseong(candNorm);
      if (candCho.length < 2) continue;

      // 입력 초성에 후보 초성이 포함되어 있으면 매칭
      if (inputCho.contains(candCho)) return i;
    }
    return -1;
  }

  // ── Levenshtein 거리 ──────────────────────────────────────

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final aLen = a.length;
    final bLen = b.length;

    // 메모리 최적화: 2행만 유지
    var prev = List<int>.generate(bLen + 1, (i) => i);
    var curr = List<int>.filled(bLen + 1, 0);

    for (int i = 1; i <= aLen; i++) {
      curr[0] = i;
      for (int j = 1; j <= bLen; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1, // 삭제
          curr[j - 1] + 1, // 삽입
          prev[j - 1] + cost, // 치환
        ].reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[bLen];
  }
}
