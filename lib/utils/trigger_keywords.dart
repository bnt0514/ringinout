/// 다국어 진입/진출 키워드 관리 유틸리티
/// 음성인식 텍스트에서 진입/진출 의도를 파악하기 위한 키워드 목록
///
/// 지원 언어: 한국어(ko), 영어(en), 일본어(ja), 중국어(zh)
class TriggerKeywords {
  /// 진입(Entry) 키워드 - 언어별 맵
  static const Map<String, List<String>> entryKeywords = {
    // 한국어 진입 키워드
    'ko': [
      // 기본 동사
      '들어가', '들어갈', '들어간', '들어갔',
      '들어오', '들어올', '들어온', '들어왔',
      '도착', '도착하', '도착할', '도착했',
      '입장', '입장하', '입장할', '입장했',
      '도달', '도달하', '도달할', '도달했',
      '진입', '진입하', '진입할', '진입했',
      // 접근/근접 표현
      '가까워지', '가까워질', '가까워졌',
      '접근', '접근하', '접근할', '접근했',
      '다가가', '다가갈', '다가간', '다가갔',
      '다가오', '다가올', '다가온', '다가왔',
      // 방향 표현
      '안에 들어', '안으로 들어',
      '안에들어', '안으로들어',
      '안쪽으로', '안으로',
      // ~에 가면, ~에 도착하면 등
      '가면', '가게 되면', '가게되면',
      '오면', '오게 되면', '오게되면',
      '갈 때', '갈때', '가는',
      '올 때', '올때', '오는',
      '근처에', '가까이', '닿으면', '닿을 때', '닿을때',
      // 도착 시점 표현
      '왔을 때', '왔을때', '도착 시', '도착시',
      '들어갈 때', '들어갈때', '들어가면',
      '들어올 때', '들어올때', '들어오면',
    ],

    // 영어 진입 키워드
    'en': [
      // Arrive/Arrival
      'arrive', 'arrives', 'arriving', 'arrived', 'arrival',
      'get to', 'gets to', 'getting to', 'got to',
      'reach', 'reaches', 'reaching', 'reached',
      // Enter/Entry
      'enter', 'enters', 'entering', 'entered', 'entry',
      'go in', 'goes in', 'going in', 'went in', 'gone in',
      'come in', 'comes in', 'coming in', 'came in',
      'get in', 'gets in', 'getting in', 'got in',
      'walk in', 'walks in', 'walking in', 'walked in',
      'step in', 'steps in', 'stepping in', 'stepped in',
      // Approach/Near
      'approach', 'approaches', 'approaching', 'approached',
      'near', 'nearing', 'neared', 'get near', 'getting near',
      'close to', 'getting close', 'get close',
      // When I ~
      'when i arrive', 'when i get', 'when i reach',
      'when i enter', 'when i go in', 'when i come in',
      'once i arrive', 'once i get', 'once i reach',
      'after i arrive', 'after arriving',
      // At/Into
      'at work', 'at home', 'at school', 'at the',
      'into', 'inside',
      // Come/Go to
      'come to', 'coming to', 'go to', 'going to',
      'head to', 'heading to', 'headed to',
      // Pull in (차량)
      'pull in', 'pulls in', 'pulling in', 'pulled in',
      // Show up
      'show up', 'shows up', 'showing up', 'showed up',
    ],

    // 일본어 진입 키워드
    'ja': [
      // 到着/着く
      '到着', '着く', '着いた', '着いたら', '着いて', '着きます', '着けば',
      'とうちゃく', 'つく', 'ついた', 'ついたら',
      // 入る/入場
      '入る', '入った', '入ったら', '入って', '入ります', '入れば',
      '入場', '入場する', '入場したら',
      'はいる', 'はいった', 'はいったら',
      // 来る/行く
      '来る', '来た', '来たら', '来て', '来ます', '来れば',
      '行く', '行った', '行ったら', '行って', '行きます', '行けば',
      'くる', 'きた', 'きたら', 'いく', 'いった', 'いったら',
      // 近づく/接近
      '近づく', '近づいた', '近づいたら', '近づけば',
      '接近', '接近する', '接近したら',
      'ちかづく', 'ちかづいた', 'ちかづいたら',
      // 到達
      '到達', '到達する', '到達したら',
      'とうたつ', 'たどり着く', 'たどりつく',
      // 中に入る
      '中に入る', '中に入った', '中に入ったら',
      // ~に着いたら, ~についたら
      'についたら', 'につく', 'についた',
      // 進入
      '進入', '進入する', '進入したら',
    ],

    // 중국어 진입 키워드
    'zh': [
      // 到达/到
      '到达', '到', '到了', '到的时候', '到达时',
      '抵达', '抵达时', '抵达了',
      // 进入/进
      '进入', '进', '进了', '进去', '进来',
      '入场', '入场时',
      '走进', '走进去', '跑进',
      // 来/去
      '来', '来了', '来到', '过来',
      '去', '去了', '去到',
      // 接近/靠近
      '接近', '接近时', '靠近', '靠近时',
      '临近', '走近',
      // 当我~/到~时
      '当我到', '当我到达', '当我进入',
      '到的时候', '进入时', '到达时',
      '进门', '入门', '入内',
      // 踏入
      '踏入', '踏进', '迈入', '迈进',
    ],
  };

  /// 진출(Exit) 키워드 - 언어별 맵
  static const Map<String, List<String>> exitKeywords = {
    // 한국어 진출 키워드
    'ko': [
      // 기본 동사
      '나가', '나갈', '나간', '나갔',
      '나오', '나올', '나온', '나왔',
      '출발', '출발하', '출발할', '출발했',
      '떠나', '떠날', '떠난', '떠났',
      '퇴장', '퇴장하', '퇴장할', '퇴장했',
      '퇴근', '퇴근하', '퇴근할', '퇴근했',
      '진출', '진출하', '진출할', '진출했',
      // 이탈/벗어남 표현
      '벗어나', '벗어날', '벗어난', '벗어났',
      '빠져나가', '빠져나갈', '빠져나간', '빠져나갔',
      '빠져나오', '빠져나올', '빠져나온', '빠져나왔',
      '이탈', '이탈하', '이탈할', '이탈했',
      // 방향 표현
      '밖으로', '밖에 나가', '밖으로 나가',
      '밖에나가', '밖으로나가',
      '바깥으로', '외부로',
      // 멀어짐 표현
      '멀어지', '멀어질', '멀어진', '멀어졌',
      '떨어지', '떨어질', '떨어진', '떨어졌',
      // ~에서 나오면, ~을 떠나면 등
      '나올 때', '나올때', '나오면',
      '나갈 때', '나갈때', '나가면',
      '떠날 때', '떠날때', '떠나면',
      '갔을 때', '갔을때',
      '나왔을 때', '나왔을때',
      '나갔을 때', '나갔을때',
      // 출발 시점 표현
      '출발 시', '출발시', '출발할 때', '출발할때',
      '퇴근 시', '퇴근시', '퇴근할 때', '퇴근할때',
    ],

    // 영어 진출 키워드
    'en': [
      // Leave
      'leave', 'leaves', 'leaving', 'left',
      // Exit
      'exit', 'exits', 'exiting', 'exited',
      // Depart
      'depart', 'departs', 'departing', 'departed', 'departure',
      // Go out / Get out
      'go out', 'goes out', 'going out', 'went out', 'gone out',
      'get out', 'gets out', 'getting out', 'got out',
      'come out', 'comes out', 'coming out', 'came out',
      'walk out', 'walks out', 'walking out', 'walked out',
      'step out', 'steps out', 'stepping out', 'stepped out',
      // Away/Off
      'go away', 'goes away', 'going away', 'went away',
      'move away', 'moves away', 'moving away', 'moved away',
      'walk away', 'walks away', 'walking away', 'walked away',
      'head out', 'heads out', 'heading out', 'headed out',
      'take off', 'takes off', 'taking off', 'took off',
      // When I ~
      'when i leave', 'when i exit', 'when i depart',
      'when i go out', 'when i get out',
      'once i leave', 'once i exit',
      'after i leave', 'after leaving',
      // From/Out of
      'from work', 'from home', 'from school', 'from the',
      'out of', 'outside',
      // Pull out (차량)
      'pull out', 'pulls out', 'pulling out', 'pulled out',
      // Drive away
      'drive away', 'drives away', 'driving away', 'drove away',
      // Set off
      'set off', 'sets off', 'setting off',
    ],

    // 일본어 진출 키워드
    'ja': [
      // 出る/出発
      '出る', '出た', '出たら', '出て', '出ます', '出れば',
      '出発', '出発する', '出発したら', '出発した',
      'でる', 'でた', 'でたら',
      // 離れる/去る
      '離れる', '離れた', '離れたら', '離れて', '離れます', '離れれば',
      '去る', '去った', '去ったら',
      'はなれる', 'はなれた', 'はなれたら', 'さる', 'さった',
      // 退場/退出
      '退場', '退場する', '退場したら',
      '退出', '退出する', '退出したら',
      'たいじょう', 'たいしゅつ',
      // 帰る/帰宅
      '帰る', '帰った', '帰ったら', '帰って', '帰ります', '帰れば',
      '帰宅', '帰宅する', '帰宅したら',
      'かえる', 'かえった', 'かえったら', 'きたく',
      // 出かける
      '出かける', '出かけた', '出かけたら', '出かけて',
      'でかける', 'でかけた', 'でかけたら',
      // 外に出る
      '外に出る', '外に出た', '外に出たら', '外へ出る',
      'そとにでる', 'そとにでた',
      // ~から出たら, ~を出たら
      'からでたら', 'をでたら', 'から出たら', 'を出たら',
      // 抜け出す
      '抜け出す', '抜け出した', '抜け出したら',
      'ぬけだす', 'ぬけだした',
    ],

    // 중국어 진출 키워드
    'zh': [
      // 离开/走
      '离开', '离开了', '离开时', '离开的时候',
      '走', '走了', '走出', '走出去',
      // 出去/出来
      '出去', '出来', '出门', '出发',
      '出发时', '出发了', '出发的时候',
      // 退出/退场
      '退出', '退出时', '退场', '退场时',
      // 离去
      '离去', '离去时', '离去了',
      // 回家/下班
      '回家', '回家时', '下班', '下班时', '下班了',
      // 当我~/离开~时
      '当我离开', '当我出去', '当我走',
      '离开的时候', '走的时候', '出去时',
      // 远离/离
      '远离', '远离时', '离', '离了',
      // 出~
      '出公司', '出办公室', '出学校', '出家门',
    ],
  };

  /// 주어진 텍스트에서 진입 키워드가 포함되어 있는지 확인
  /// [text] 검사할 텍스트
  /// [locale] 언어 코드 (ko, en, ja, zh) - null이면 모든 언어 검사
  static bool containsEntryKeyword(String text, {String? locale}) {
    final normalizedText = _normalizeText(text);

    if (locale != null) {
      final keywords = entryKeywords[locale] ?? [];
      return keywords.any((kw) => normalizedText.contains(_normalizeText(kw)));
    }

    // 모든 언어에서 검사
    for (final keywords in entryKeywords.values) {
      if (keywords.any((kw) => normalizedText.contains(_normalizeText(kw)))) {
        return true;
      }
    }
    return false;
  }

  /// 주어진 텍스트에서 진출 키워드가 포함되어 있는지 확인
  /// [text] 검사할 텍스트
  /// [locale] 언어 코드 (ko, en, ja, zh) - null이면 모든 언어 검사
  static bool containsExitKeyword(String text, {String? locale}) {
    final normalizedText = _normalizeText(text);

    if (locale != null) {
      final keywords = exitKeywords[locale] ?? [];
      return keywords.any((kw) => normalizedText.contains(_normalizeText(kw)));
    }

    // 모든 언어에서 검사
    for (final keywords in exitKeywords.values) {
      if (keywords.any((kw) => normalizedText.contains(_normalizeText(kw)))) {
        return true;
      }
    }
    return false;
  }

  /// 텍스트를 정규화 (소문자 변환, 공백 제거)
  /// 음성인식에서 발생하는 띄어쓰기 차이를 처리
  static String _normalizeText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// 주어진 텍스트에서 진입/진출 트리거 타입 감지
  /// 반환값: 'entry', 'exit', 'both', null
  static String? detectTriggerType(String text, {String? locale}) {
    final hasEntry = containsEntryKeyword(text, locale: locale);
    final hasExit = containsExitKeyword(text, locale: locale);

    if (hasEntry && hasExit) {
      final isKoreanContext =
          locale == 'ko' || containsExitKeyword(text, locale: 'ko');
      if (isKoreanContext) return 'exit';
      return 'both';
    }
    if (hasEntry) return 'entry';
    if (hasExit) return 'exit';
    return null;
  }

  /// 특정 언어의 모든 진입 키워드 목록 반환
  static List<String> getEntryKeywordsForLocale(String locale) {
    return entryKeywords[locale] ?? entryKeywords['en'] ?? [];
  }

  /// 특정 언어의 모든 진출 키워드 목록 반환
  static List<String> getExitKeywordsForLocale(String locale) {
    return exitKeywords[locale] ?? exitKeywords['en'] ?? [];
  }
}
