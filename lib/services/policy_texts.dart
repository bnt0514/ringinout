String getSubscriptionPolicyText({required bool isBeta, String lang = 'ko'}) {
  if (lang == 'en') return _getSubscriptionPolicyEn(isBeta: isBeta);
  if (lang == 'ja') return _getSubscriptionPolicyJa(isBeta: isBeta);
  if (lang == 'zh') return _getSubscriptionPolicyZh(isBeta: isBeta);
  if (lang == 'de') return _getSubscriptionPolicyDe(isBeta: isBeta);
  if (lang == 'fr') return _getSubscriptionPolicyFr(isBeta: isBeta);
  if (lang == 'es') return _getSubscriptionPolicyEs(isBeta: isBeta);
  return _getSubscriptionPolicyKo(isBeta: isBeta);
}

String getRefundPolicyText({required bool isBeta, String lang = 'ko'}) {
  if (lang == 'en') return _getRefundPolicyEn(isBeta: isBeta);
  if (lang == 'ja') return _getRefundPolicyJa(isBeta: isBeta);
  if (lang == 'zh') return _getRefundPolicyZh(isBeta: isBeta);
  if (lang == 'de') return _getRefundPolicyDe(isBeta: isBeta);
  if (lang == 'fr') return _getRefundPolicyFr(isBeta: isBeta);
  if (lang == 'es') return _getRefundPolicyEs(isBeta: isBeta);
  return _getRefundPolicyKo(isBeta: isBeta);
}

// ═══════════════════════════════════════════════════════════
//  Korean (original)
// ═══════════════════════════════════════════════════════════

String _getSubscriptionPolicyKo({required bool isBeta}) {
  final buffer = StringBuffer();
  buffer.writeln('구독 정책');
  buffer.writeln();
  buffer.writeln('1. 서비스 개요');
  buffer.writeln(
    '- 본 서비스는 위치 기반 알람 기능을 제공합니다. 베타 기간에는 무료 플랜만 제공되며, 정식 출시 시 광고 도입 및 유료 플랜이 함께 제공될 수 있습니다.',
  );
  buffer.writeln();
  buffer.writeln('2. 무료 플랜 제공 범위');
  buffer.writeln('- 장소/알람 등록은 무제한으로 제공됩니다.');
  if (isBeta) {
    buffer.writeln('- 베타 기간에는 검색, 지도, 알람 발동을 사실상 월간 제한 없이 이용할 수 있습니다.');
    buffer.writeln(
      '- 다만 사용자 수 또는 외부 API 비용이 예상보다 크게 증가하거나 서비스 안정성 문제가 발생하는 경우, 베타 기간 중에도 공정 사용 제한이 도입될 수 있습니다.',
    );
    buffer.writeln(
      '- 정식 출시 시 Free 플랜에는 알람 발동, 검색, 지도 사용 등에 월간 제한이 적용될 수 있으며, 광고가 도입될 수 있습니다.',
    );
    buffer.writeln(
      '- 정식 출시 시 Plus/Pro 등 유료 플랜이 제공될 수 있으며, 더 높은 사용량, 광고 감소 또는 제거, 일부 기능 우선 제공 등의 혜택이 포함될 수 있습니다.',
    );
  } else {
    buffer.writeln('- 알람 발동: 월 30회 기본 제공.');
    buffer.writeln('- 주소/장소 검색: 월 5회 보장(어뷰징 방지 안전 상한 15회).');
    buffer.writeln('- 지도 로드: 월 100회(어뷰징 방지 상한).');
    buffer.writeln(
      '- 보장 한도 초과 시 보너스 시스템(안내문 동의 또는 리워드 광고)을 통해 안전 상한까지 추가 사용이 가능합니다.',
    );
    buffer.writeln('- 안전 상한은 어뷰징 방지를 위해 도달 시 보너스로도 더 이상 사용할 수 없습니다.');
    buffer.writeln(
      '- 유료 플랜 사용자에게는 더 많은 사용량, 광고 감소 또는 제거, 일부 기능 우선 제공 등의 혜택이 제공될 수 있습니다.',
    );
    buffer.writeln(
      '- 자동 구독(매월 자동 결제) 등록 시 월 구독료 할인이 적용될 수 있으며, 자세한 조건은 Google Play 상품 설명을 따릅니다.',
    );
  }
  buffer.writeln();
  buffer.writeln('2-1. 지도 서비스 제공 조건 (중요)');
  buffer.writeln('- 지도 기능은 외부 지도 API(네이버 클라우드 플랫폼, 구글 플랫폼 등)를 이용하며,');
  buffer.writeln('  외부 API 제공자의 정책, 요금 체계, 장애, 쿼터 등에 의존합니다.');
  buffer.writeln('- 정식 출시 후 명시되는 월 지도 로드 횟수는 일반적인 제공 목표이며 보장되지 않습니다.');
  buffer.writeln('- 외부 API 비용 급증, 이상 사용 감지, 서비스 운영 안정성 확보 등을 위해');
  buffer.writeln('  무료 이용자 혹은 전체 이용자의 지도 기능이 예고 없이 일시 제한되거나 중단될 수 있습니다.');
  buffer.writeln(
    '- 이는 공정 사용 정책(Fair Use Policy) 및 서비스 안정 운영을 위한 조치이며, 해당 사유로 인한 환불은 제한될 수 있습니다.',
  );
  buffer.writeln('- 제한이 발생한 경우 지도 표시, 주소 검색, 장소 검색 기능 일부가 제공되지 않을 수 있습니다.');
  buffer.writeln();
  buffer.writeln('2-2. 계정 및 활성 기기 데이터 안내');
  buffer.writeln(
    '- 로그인 제공자는 언어와 국가에 따라 Google, Kakao, Naver, LINE, Facebook, 이메일 매직 링크를 포함할 수 있습니다.',
  );
  buffer.writeln('- 연결된 로그인 방법 정보는 하나의 계정에 여러 방법으로 접근할 수 있도록 하는 목적으로만 사용됩니다.');
  buffer.writeln('- 장소와 알람은 주로 활성 기기에 저장되며, 설정에서 현재 로그인한 계정으로 전송할 수 있습니다.');
  buffer.writeln(
    '- 계정 삭제 시 서버의 계정 데이터는 삭제되지만, 기기 내 로컬 데이터는 앱 데이터 삭제 또는 앱 삭제 전까지 남아 있을 수 있습니다.',
  );
  buffer.writeln();
  buffer.writeln('3. GPS 위치 기반 서비스 안내');
  buffer.writeln('- 본 서비스는 GPS 위치 정보를 활용한 알람 서비스입니다.');
  buffer.writeln('- GPS는 대략적인 위치만 파악할 수 있으며, 실내/지하 환경이 아니어도');
  buffer.writeln('  수 미터~수십 미터의 오차가 항상 존재합니다.');
  buffer.writeln('  예) 반경 30m 설정 시, 실제로는 25m에서 알람이 울리거나 35m까지 들어가야 울릴 수 있습니다.');
  buffer.writeln('- 지하·실내·고층빌딩·전파 방해 구역에서는 오차가 더욱 커질 수 있으며,');
  buffer.writeln(
    '  실제로 경계 밖에 있어도 진입으로 인식되거나, 경계 안에 있어도 진출로 인식되어 알람이 반복해서 울릴 수 있습니다.',
  );
  buffer.writeln('- 이러한 오차 및 오발동/미작동은 GPS의 특성으로 본 앱에서 해결할 수도, 책임질 수도 없습니다.');
  buffer.writeln('- ⚡오발동 발생 시: 전체화면 알람의 "⚡오발동" 버튼을 눌러 알람을 유지한 채 소리만 끌 수 있습니다.');
  buffer.writeln('  (추후 "Passing" 기능 도입 예정: 버튼 하나로 n분 후 자동 재활성화)');
  buffer.writeln('- 미작동 발생 시: GPS 페이지의 "버그 리포트" 버튼을 눌러 로그를 전송해 주시면,');
  buffer.writeln('  수정 가능한 부분은 최대한 빠른 시일 내 수정하겠습니다.');
  buffer.writeln(
    '- 기기의 시간대 변경, 수동 날짜/시간 변경, 자정 경계, OS 시간 동기화 지연이 있는 경우 반복 알람의 기준일 계산이 달라져 알람이 지연되거나 예상과 다르게 울릴 수 있습니다.',
  );
  buffer.writeln('- 본 약관에 동의하시면, 유료 구독자를 포함하여 GPS 오차로 인한');
  buffer.writeln('  ⚡오발동 또는 미작동에 대해 개발사에 책임을 묻지 않는 것에 동의하는 것으로 간주합니다.');
  buffer.writeln();
  buffer.writeln('4. Wi-Fi 기반 보조 감지 안내');
  buffer.writeln('- Wi-Fi 감지는 알람 정확도 향상을 위한 선택적 보조 기능이며, 등록을 강제하지 않습니다.');
  buffer.writeln(
    '- Wi-Fi SSID/BSSID 정보는 기기 내에서만 장소 인식에 사용되며, 외부 서버로 전송되지 않습니다.',
  );
  buffer.writeln('- Wi-Fi 신호 환경(공유기 이전·변경·채널 충돌 등)에 따라 감지 오작동이 발생할 수 있으며,');
  buffer.writeln('  이로 인한 알람 오발동·미작동에 대한 책임은 제한됩니다.');
  buffer.writeln('- 본 약관에 동의하시면 위 사항에 동의한 것으로 간주합니다.');
  buffer.writeln();
  buffer.writeln('4-1. 앱 실행 상태 및 복구 안내 (중요)');
  buffer.writeln(
    '- 본 앱의 알람은 앱(백그라운드 서비스)이 정상적으로 실행 중일 때 작동합니다. 아래의 경우 알람이 울리지 않을 수 있으니 반드시 확인해 주세요.',
  );
  buffer.writeln(
    '- [기기 재부팅] 기기를 재부팅하면 백그라운드 알람 감시가 일시 중지됩니다. 활성화된 알람이 있는 경우, 앱을 다시 실행하도록 안내하는 푸시 알림을 주기적으로 보내드립니다. 이 알림을 확인하지 않고 앱을 다시 실행하지 않으면 알람이 정상적으로 울리지 않을 수 있습니다.',
  );
  buffer.writeln(
    '- [앱 강제 중지] 사용자가 기기 설정에서 앱을 \'강제 중지\'한 경우(또는 어떤 이유로든 강제 중지된 경우), 운영체제 정책에 따라 앱이 스스로 복구되거나 알림을 보낼 수 없습니다. 이 경우 반드시 앱을 다시 실행해야만 알람이 정상적으로 작동합니다.',
  );
  buffer.writeln(
    '- [운영체제에 의한 종료] 메모리 부족, 제조사 배터리 절전 정책 등으로 운영체제가 앱을 종료한 경우, 일정 시간이 지난 뒤 복구를 안내하는 알림을 보내드립니다. 다만 그 시간 동안에는, 그리고 사용자가 앱 종료 사실을 인지하지 못한 경우에는 알람이 울리지 않을 수 있습니다.',
  );
  buffer.writeln(
    '- 안정적인 알람 작동을 위해 배터리 최적화 예외 허용, 자동 실행 허용 등의 설정을 권장하며, 위 사유로 인한 알람 미작동에 대한 책임은 제한됩니다.',
  );
  buffer.writeln('- 본 약관에 동의하시면 위 사항에 동의한 것으로 간주합니다.');
  buffer.writeln();
  buffer.writeln('5. 결제 및 자동 갱신');
  buffer.writeln('- 구독 결제는 Google Play 결제 시스템을 통해 처리됩니다.');
  buffer.writeln(
    '- 구독은 Google Play 정책에 따라 자동 갱신되며, 갱신 주기 및 결제일은 Google Play에서 관리합니다.',
  );
  buffer.writeln('- 결제일 이전에 해지하지 않으면 자동 갱신됩니다.');
  buffer.writeln('- 결제 금액은 Google Play에 등록된 가격을 따릅니다.');
  buffer.writeln();
  buffer.writeln('6. 해지 및 플랜 변경');
  buffer.writeln('- 구독 해지는 Google Play 구독 관리에서 가능합니다.');
  buffer.writeln('- 해지 후에도 다음 갱신일까지는 구독 혜택이 유지됩니다.');
  buffer.writeln('- 플랜 변경은 Google Play 정책 및 결제 시스템 규칙에 따릅니다.');
  buffer.writeln();
  buffer.writeln('7. 광고');
  if (isBeta) {
    buffer.writeln('- 베타 기간에는 광고가 노출되지 않습니다.');
    buffer.writeln(
      '- 정식 출시 시 무료 플랜에 광고가 도입될 수 있으며, 유료 플랜은 광고가 감소되거나 제거될 수 있습니다.',
    );
  } else {
    buffer.writeln('- 무료 플랜은 일부 기능 사용 시 광고가 노출될 수 있습니다.');
    buffer.writeln('- 유료 플랜은 광고가 감소되거나 제거될 수 있습니다.');
  }
  buffer.writeln();
  buffer.writeln('8. 서비스 이용 제한');
  buffer.writeln('- 서비스 안정성 보호를 위해 버그 리포트 및 건의사항 전송은 30분 간격, 하루 최대 3회로 제한됩니다.');
  buffer.writeln('- 비정상적이거나 과도한 사용이 감지될 경우 서비스 이용이 제한될 수 있습니다.');
  buffer.writeln();
  buffer.writeln('9. 서비스 제공 및 변경');
  buffer.writeln('- 서비스 품질 향상 또는 정책 변경을 위해 기능/가격/플랜 구성이 변경될 수 있습니다.');
  buffer.writeln('- 중요한 변경은 앱 내 공지 또는 기타 합리적인 방법으로 안내합니다.');
  buffer.writeln();
  if (isBeta) {
    buffer.writeln('10. 베타 버전 이용 고지');
    buffer.writeln('- 본 서비스는 베타 버전이며 안정성, 완전성, 무중단 제공을 보장하지 않습니다.');
    buffer.writeln('- 베타 기간에는 예고 없이 기능이 변경, 중단되거나 서비스가 일시 중지될 수 있습니다.');
    buffer.writeln(
      '- 베타 기간 중 저장된 데이터, 알람 설정, 기록 등이 손실 또는 변경될 수 있으며 복구가 보장되지 않습니다.',
    );
    buffer.writeln('- 베타 기간에는 성능 저하, 위치 오차, 알람 누락/지연/오작동이 발생할 수 있습니다.');
    buffer.writeln('- 베타 기간에는 무료 플랜만 제공되며, 유료 플랜은 정식 출시 후 도입될 수 있습니다.');
    buffer.writeln('- 베타 기간의 한도 완화 등 혜택은 정식 출시 시 변경되거나 종료될 수 있습니다.');
    buffer.writeln();
    buffer.writeln('11. 책임의 제한');
  } else {
    buffer.writeln('10. 책임의 제한');
  }
  buffer.writeln(
    '- 법령이 허용하는 범위 내에서, 서비스 이용으로 인한 직접/간접/부수적/특별/결과적 손해에 대해 책임을 지지 않습니다.',
  );
  buffer.writeln('- 위치 정보는 기기/OS/통신 환경에 따라 오차가 발생할 수 있으며 이에 대한 책임은 제한됩니다.');
  buffer.writeln('- 알람 누락/지연/오작동, 데이터 손실, 서비스 중단으로 인해 발생한 손해에 대한 책임은 제한됩니다.');
  return buffer.toString();
}

String _getRefundPolicyKo({required bool isBeta}) {
  final buffer = StringBuffer();
  buffer.writeln('환불 정책');
  buffer.writeln();
  buffer.writeln('1. 환불 원칙');
  buffer.writeln('- 결제 및 환불은 Google Play 환불 정책 및 절차를 따릅니다.');
  buffer.writeln('- 구독 결제는 이미 사용한 기간에 대한 환불이 제한될 수 있습니다.');
  buffer.writeln();
  buffer.writeln('2. 환불 요청 방법');
  buffer.writeln('- Google Play 결제 내역에서 환불 요청을 진행할 수 있습니다.');
  buffer.writeln('- 환불 가능 여부와 처리 기준은 Google Play 정책에 따릅니다.');
  buffer.writeln();
  buffer.writeln('3. 서비스 장애 및 중대한 오류');
  buffer.writeln(
    '- 서비스 장애 등 중대한 오류가 발생한 경우, Google Play 정책 범위 내에서 환불 또는 보상이 검토될 수 있습니다.',
  );
  buffer.writeln('- 환불 또는 보상 여부는 개별 사례에 따라 결정됩니다.');
  buffer.writeln();
  if (isBeta) {
    buffer.writeln('4. 베타 버전 이용 고지');
    buffer.writeln('- 베타 기간에는 기능/정책 변경, 서비스 중단, 데이터 손실이 발생할 수 있습니다.');
    buffer.writeln(
      '- 베타 기간 중 발생한 성능 저하, 위치 오차, 알람 누락/지연 등으로 인한 손해에 대해 책임은 제한됩니다.',
    );
    buffer.writeln('- 베타 버전 사용으로 인한 손해에 대해서는 관련 법령이 허용하는 범위 내에서 책임이 제한됩니다.');
    buffer.writeln();
    buffer.writeln('5. 자동 갱신 취소');
  } else {
    buffer.writeln('4. 자동 갱신 취소');
  }
  buffer.writeln('- 자동 갱신 취소는 Google Play 구독 관리에서 가능합니다.');
  buffer.writeln('- 취소 후에도 다음 갱신일까지는 구독 혜택이 유지됩니다.');
  return buffer.toString();
}

// ═══════════════════════════════════════════════════════════
//  English
// ═══════════════════════════════════════════════════════════

String _getSubscriptionPolicyEn({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Subscription Policy');
  b.writeln();
  b.writeln('1. Service Overview');
  b.writeln(
    '- This service provides location-based alarm features. During the beta period only the Free Plan is offered; ads and paid plans may be introduced upon official release.',
  );
  b.writeln();
  b.writeln('2. Free Plan Coverage');
  b.writeln('- Unlimited place and alarm registration.');
  if (isBeta) {
    b.writeln(
      '- During beta, search, maps, and alarm triggers are available without practical monthly limits.',
    );
    b.writeln(
      '- If user growth, third-party API costs, or service stability risks grow unexpectedly, fair-use limits may be introduced during beta.',
    );
    b.writeln(
      '- Upon official release, the Free Plan may include monthly limits for alarm triggers, search, and maps, and ads may be introduced.',
    );
    b.writeln(
      '- Plus/Pro paid plans may be offered with higher allowances, reduced or removed ads, and priority access to certain features.',
    );
  } else {
    b.writeln('- Alarm triggers: 30 per month (standard).');
    b.writeln(
      '- Address/place search: 5 guaranteed per month (anti-abuse safety cap 15).',
    );
    b.writeln('- Map opens: up to 100 per month (anti-abuse cap).');
    b.writeln(
      '- When a guaranteed limit is exceeded, a bonus system (notice acknowledgement or rewarded ads) allows additional use up to the safety cap.',
    );
    b.writeln(
      '- Once the safety cap is reached, no further use is possible that month even with bonuses, to prevent abuse.',
    );
    b.writeln(
      '- Paid plan users may receive higher usage allowances, reduced or removed ads, and priority access to certain features.',
    );
    b.writeln(
      '- Discounts may apply for auto-renewing subscriptions; see Google Play product details for exact pricing.',
    );
  }
  b.writeln();
  b.writeln('2-1. Map Service Provision Conditions (Important)');
  b.writeln(
    '- Map features depend on third-party APIs (Naver Cloud Platform, Google Cloud Platform, etc.) and are subject to those providers\' policies, pricing, downtime, and quotas.',
  );
  b.writeln(
    '- Monthly map-open counts stated after official release are general targets, not guaranteed availability.',
  );
  b.writeln(
    '- To protect service stability against sudden third-party API cost spikes, abuse, or operational issues, map features for free or all users may be temporarily limited or suspended without prior notice.',
  );
  b.writeln(
    '- This is a Fair Use Policy and operational safeguard. Refunds caused by such limitations may be restricted.',
  );
  b.writeln(
    '- When limitations are applied, some map display, address search, or place search features may be unavailable.',
  );
  b.writeln();
  b.writeln('2-2. Account and Active Device Data Notice');
  b.writeln(
    '- Sign-in providers may include Google, Kakao, Naver, LINE, Facebook, and email magic links depending on locale and country.',
  );
  b.writeln(
    '- Linked provider status is used only to let you access the same account with multiple sign-in methods.',
  );
  b.writeln(
    '- Places and alarms are stored primarily on the active device and can be transferred to the currently signed-in account from Settings.',
  );
  b.writeln(
    '- Account deletion removes server-side account data; local data on the device may remain until app data is cleared or the app is uninstalled.',
  );
  b.writeln();
  b.writeln('3. GPS Location-Based Service Notice');
  b.writeln('- This service uses GPS location data to trigger alarms.');
  b.writeln(
    '- GPS can only estimate your location. Even outdoors, there is always a margin of error of several to tens of meters.',
  );
  b.writeln(
    '  For example, with a 30m radius, the alarm may trigger at 25m or only at 35m.',
  );
  b.writeln(
    '- In underground areas, inside buildings, or signal-blocked zones, the error becomes even larger.',
  );
  b.writeln(
    '  The system may detect entry/exit repeatedly even without movement, causing alarms to fire multiple times.',
  );
  b.writeln(
    '- These GPS limitations (false triggers and missed triggers) cannot be resolved or guaranteed by this app.',
  );
  b.writeln(
    '- \u26a1False Trigger: Use the "\u26a1False Trigger" button on the alarm screen to silence while keeping the alarm active.',
  );
  b.writeln(
    '  ("Passing" feature coming soon: one tap to auto-reactivate after n minutes)',
  );
  b.writeln(
    '- Missed Trigger: Use the "Bug Report" button on the GPS page to send logs. We will fix resolvable issues as quickly as possible.',
  );
  b.writeln(
    '- If the device time zone, date, or time is manually changed, or if an alarm crosses midnight during OS time synchronization, repeat-alarm date calculations may change and alarms may be delayed or fire differently than expected.',
  );
  b.writeln(
    '- By agreeing to these terms, including paid subscribers, you agree not to hold the developer liable for \u26a1False Triggers or Missed Triggers caused by GPS errors.',
  );
  b.writeln();
  b.writeln('4. Wi-Fi Assisted Detection Notice');
  b.writeln(
    '- Wi-Fi detection is an optional supplementary feature to improve alarm accuracy. Registration is not mandatory.',
  );
  b.writeln(
    '- Wi-Fi SSID/BSSID data is used solely on-device for place recognition and is never transmitted to external servers.',
  );
  b.writeln(
    '- Detection errors may occur due to Wi-Fi environment changes (router relocation, replacement, channel conflicts, etc.).',
  );
  b.writeln(
    '  The developer is not liable for false or missed alarms caused by such conditions.',
  );
  b.writeln(
    '- By agreeing to these terms, you acknowledge and accept the above.',
  );
  b.writeln();
  b.writeln('4-1. App Running State & Recovery Notice (Important)');
  b.writeln(
    '- Alarms work only while the app (background service) is running normally. Please note that alarms may not ring in the following cases.',
  );
  b.writeln(
    '- [Device Reboot] After a reboot, background alarm monitoring is temporarily suspended. If you have active alarms, we periodically send a push notification asking you to reopen the app. If you ignore it and do not reopen the app, alarms may not ring properly.',
  );
  b.writeln(
    '- [Force Stop] If you "Force Stop" the app from device settings (or it is force-stopped for any reason), the operating system prevents the app from recovering itself or sending notifications. In this case, alarms work only after you manually reopen the app.',
  );
  b.writeln(
    '- [Termination by the OS] If the OS terminates the app due to low memory, manufacturer battery-saving policies, etc., we send a recovery notification after some time. However, during that period—or if you do not notice the termination—alarms may not ring.',
  );
  b.writeln(
    '- For reliable operation, we recommend allowing battery-optimization exceptions and auto-start permissions. Liability for missed alarms caused by the above is limited.',
  );
  b.writeln(
    '- By agreeing to these terms, you acknowledge and accept the above.',
  );
  b.writeln();
  b.writeln('5. Payment & Auto-Renewal');
  b.writeln('- Payments are processed through Google Play billing.');
  b.writeln(
    '- Subscriptions auto-renew according to Google Play policies. The renewal cycle and billing date are managed by Google Play.',
  );
  b.writeln(
    '- Subscriptions will auto-renew unless cancelled before the renewal date.',
  );
  b.writeln('- Pricing follows the amounts listed on Google Play.');
  b.writeln();
  b.writeln('6. Cancellation & Plan Changes');
  b.writeln('- Cancel subscriptions via Google Play subscription management.');
  b.writeln(
    '- Benefits remain until the next renewal date after cancellation.',
  );
  b.writeln('- Plan changes follow Google Play policies.');
  b.writeln();
  b.writeln('7. Ads');
  if (isBeta) {
    b.writeln('- No ads are shown during the beta period.');
    b.writeln(
      '- Upon official release, ads may be introduced for the Free Plan; paid plans may have reduced or removed ads.',
    );
  } else {
    b.writeln('- The Free Plan may show ads while using certain features.');
    b.writeln('- Paid plans may have reduced or removed ads.');
  }
  b.writeln();
  b.writeln('8. Usage Restrictions');
  b.writeln(
    '- To protect service stability, bug reports and feedback are limited to once every 30 minutes, up to 3 times per day.',
  );
  b.writeln(
    '- Abnormal or excessive usage may result in service restrictions.',
  );
  b.writeln();
  b.writeln('9. Service Changes');
  b.writeln(
    '- Features, pricing, and plan structure may change to improve service quality.',
  );
  b.writeln('- Important changes will be communicated through in-app notices.');
  b.writeln();
  if (isBeta) {
    b.writeln('10. Beta Notice');
    b.writeln(
      '- This is a beta version. Stability and uninterrupted service are not guaranteed.',
    );
    b.writeln(
      '- Features may change or be suspended without notice during beta.',
    );
    b.writeln(
      '- Data, alarm settings, and records may be lost or changed during beta.',
    );
    b.writeln(
      '- Performance issues, location errors, and alarm delays may occur.',
    );
    b.writeln(
      '- Only the Free Plan is offered during beta; paid plans may be introduced after official release.',
    );
    b.writeln(
      '- Beta benefits such as relaxed limits may be changed or ended upon official release.',
    );
    b.writeln();
    b.writeln('11. Limitation of Liability');
  } else {
    b.writeln('10. Limitation of Liability');
  }
  b.writeln(
    '- To the extent permitted by law, we are not liable for direct/indirect/incidental/special/consequential damages.',
  );
  b.writeln('- Location accuracy depends on device/OS/network conditions.');
  b.writeln(
    '- Liability for alarm failures, data loss, or service interruptions is limited.',
  );
  return b.toString();
}

String _getRefundPolicyEn({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Refund Policy');
  b.writeln();
  b.writeln('1. Refund Principles');
  b.writeln('- Payments and refunds follow Google Play refund policies.');
  b.writeln('- Refunds for already-used subscription periods may be limited.');
  b.writeln();
  b.writeln('2. How to Request a Refund');
  b.writeln('- Request refunds through Google Play payment history.');
  b.writeln('- Eligibility and processing follow Google Play policies.');
  b.writeln();
  b.writeln('3. Service Failures');
  b.writeln(
    '- In case of major service failures, refunds or compensation may be reviewed within Google Play policy.',
  );
  b.writeln();
  if (isBeta) {
    b.writeln('4. Beta Notice');
    b.writeln('- Features, policies, and services may change during beta.');
    b.writeln(
      '- Liability for issues during beta is limited to the extent permitted by law.',
    );
    b.writeln();
    b.writeln('5. Auto-Renewal Cancellation');
  } else {
    b.writeln('4. Auto-Renewal Cancellation');
  }
  b.writeln('- Cancel auto-renewal via Google Play subscription management.');
  b.writeln(
    '- Benefits remain until the next renewal date after cancellation.',
  );
  return b.toString();
}

// ═══════════════════════════════════════════════════════════
//  Japanese
// ═══════════════════════════════════════════════════════════

String _getSubscriptionPolicyJa({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('サブスクリプションポリシー');
  b.writeln();
  b.writeln('1. サービス概要');
  b.writeln(
    '- 本サービスは位置ベースのアラーム機能を提供します。ベータ期間中は無料プランのみ提供され、正式リリース時に広告の導入や有料プランが提供される場合があります。',
  );
  b.writeln();
  b.writeln('2. 無料プランの提供範囲');
  b.writeln('- 場所/アラームの登録は無制限です。');
  if (isBeta) {
    b.writeln('- ベータ期間中は、検索、マップ、アラーム発動を実質的な月間制限なくご利用いただけます。');
    b.writeln(
      '- 利用者数、外部API費用、サービス安定性のリスクが想定以上に増えた場合、ベータ中でも公正利用制限が導入される場合があります。',
    );
    b.writeln('- 正式リリース時には、無料プランにアラーム発動、検索、マップ利用などの月間制限が適用され、広告が導入される場合があります。');
    b.writeln(
      '- Plus/Proなどの有料プランが提供され、より多くの利用枠、広告の削減または除去、一部機能の優先提供などの特典が含まれる場合があります。',
    );
  } else {
    b.writeln('- アラーム発動：月30回（基本提供）。');
    b.writeln('- 住所/場所検索：月5回保証（不正利用防止の安全上限15回）。');
    b.writeln('- マップ読み込み：月100回（不正利用防止上限）。');
    b.writeln('- 保証枠を超過した場合、ボーナスシステム（お知らせへの同意またはリワード広告）で安全上限まで追加利用できます。');
    b.writeln('- 安全上限に達するとその月はボーナスでも追加利用できません。');
    b.writeln(
      '- 有料プランのユーザーには、より多くの利用枠、広告の削減または除去、一部機能の優先提供などの特典が提供される場合があります。',
    );
    b.writeln('- 自動購読設定時に割引が適用される場合があり、詳細はGoogle Playの商品説明に従います。');
  }
  b.writeln();
  b.writeln('2-1. マップサービス提供条件（重要）');
  b.writeln(
    '- マップ機能は外部API（ネイバークラウド、Google Cloud等）に依存し、それらのポリシー、料金体系、サービス状況に左右されます。',
  );
  b.writeln('- 正式リリース後に明示される月間マップ表示回数は一般的な提供目標であり、保証されるものではありません。');
  b.writeln(
    '- 外部API費用の急増、不正利用、サービス運営の安定性確保のため、無料ユーザーや全ユーザーのマップ機能が予告なく一時的に制限・停止される場合があります。',
  );
  b.writeln('- これは公正利用ポリシーとサービス安定運営のための措置であり、これによる返金は制限される場合があります。');
  b.writeln('- 制限が適用される場合、地図表示・住所検索・場所検索の一部が利用できないことがあります。');
  b.writeln();
  b.writeln('3. GPS位置情報サービスのご案内');
  b.writeln('- 本サービスはGPS位置情報を利用したアラームサービスです。');
  b.writeln('- GPSは大まかな位置しか把握できず、屋外であっても常に数m〜数十mの誤差があります。');
  b.writeln('  例）半径30m設定時、実際には25mで鳴るか、または35mまで近づかないと鳴らない場合があります。');
  b.writeln('- 地下・建物内・電波障害地域では誤差がさらに大きくなり、');
  b.writeln('  実際に移動していなくても進入/退出が繰り返し検知され、アラームが連続で鳴ることがあります。');
  b.writeln('- これらの誤差・誤発動・未発動はGPSの特性であり、本アプリでは解決も保証もできません。');
  b.writeln('- ⚡誤発動発生時：全画面アラームの「⚡誤発動」ボタンでアラームを維持したまま音声を消せます。');
  b.writeln('  （「Passing」機能を近日導入予定：ボタン1つでn分後に自動再有効化）');
  b.writeln('- 未発動発生時：GPSページの「バグレポート」ボタンでログを送信いただくと、修正可能な箇所は最大限早急に対応いたします。');
  b.writeln(
    '- 本規約に同意することで、有料ユーザーを含むGPS誤差による⚡誤発動または未発動について開発者に責任を問わないことに同意するものとみなします。',
  );
  b.writeln();
  b.writeln('4. Wi-Fi補助検知のご案内');
  b.writeln('- Wi-Fi検知はアラーム精度向上のための任意の補助機能であり、登録は強制ではありません。');
  b.writeln('- Wi-Fi SSID/BSSID情報は端末内でのみ場所認識に使用され、外部サーバーには送信されません。');
  b.writeln('- Wi-Fi環境の変化（ルーターの移動・交換・チャンネル干渉など）により検知エラーが発生する場合があります。');
  b.writeln('  これによるアラームの誤発動・未発動について、開発者は責任を負いません。');
  b.writeln('- 本規約に同意することで、上記事項に同意したものとみなします。');
  b.writeln();
  b.writeln('4-1. アプリの実行状態と復旧のご案内（重要）');
  b.writeln(
    '- 本アプリのアラームは、アプリ（バックグラウンドサービス）が正常に実行されている場合に作動します。以下の場合はアラームが鳴らないことがありますので、必ずご確認ください。',
  );
  b.writeln(
    '- 【端末の再起動】端末を再起動すると、バックグラウンドのアラーム監視が一時停止します。有効なアラームがある場合、アプリの再実行を促すプッシュ通知を定期的にお送りします。この通知を確認せずアプリを再実行しない場合、アラームが正常に鳴らないことがあります。',
  );
  b.writeln(
    '- 【アプリの強制停止】端末の設定からアプリを「強制停止」した場合（または何らかの理由で強制停止された場合）、OSの仕様によりアプリは自動復旧も通知送信もできません。この場合、アプリを手動で再実行しない限りアラームは作動しません。',
  );
  b.writeln(
    '- 【OSによる終了】メモリ不足やメーカーの省電力ポリシーなどでOSがアプリを終了した場合、一定時間の経過後に復旧をご案内する通知をお送りします。ただしその間、また終了に気づかなかった場合は、アラームが鳴らないことがあります。',
  );
  b.writeln(
    '- 安定した動作のため、電池最適化の除外や自動起動の許可などの設定を推奨します。上記による未発動について、開発者の責任は制限されます。',
  );
  b.writeln('- 本規約に同意することで、上記事項に同意したものとみなします。');
  b.writeln();
  b.writeln('5. 決済と自動更新');
  b.writeln('- 決済はGoogle Play決済システムを通じて処理されます。');
  b.writeln(
    '- サブスクリプションはGoogle Playポリシーに従って自動更新されます。更新サイクルと請求日はGoogle Playが管理します。',
  );
  b.writeln('- 更新日前にキャンセルしない場合、自動更新されます。');
  b.writeln();
  b.writeln('6. 解約とプラン変更');
  b.writeln('- 解約はGoogle Playサブスクリプション管理から可能です。');
  b.writeln('- 解約後も次の更新日まで特典が維持されます。');
  b.writeln();
  b.writeln('7. 広告');
  if (isBeta) {
    b.writeln('- ベータ期間中は広告は表示されません。');
    b.writeln('- 正式リリース時に無料プランに広告が導入される場合があり、有料プランは広告が削減または除去される場合があります。');
  } else {
    b.writeln('- 無料プランでは一部機能利用時に広告が表示される場合があります。');
    b.writeln('- 有料プランは広告が削減または除去される場合があります。');
  }
  b.writeln();
  b.writeln('8. 利用制限');
  b.writeln('- サービスの安定性を保護するため、バグレポートおよびフィードバックの送信は30分間隔、1日最大3回までに制限されています。');
  b.writeln('- 異常または過度な使用が検知された場合、サービスの利用が制限される場合があります。');
  b.writeln();
  b.writeln('9. サービス変更');
  b.writeln('- 機能、価格、プラン構成は品質向上のために変更される場合があります。');
  b.writeln();
  if (isBeta) {
    b.writeln('10. ベータ版のご注意');
    b.writeln('- 本サービスはベータ版であり、安定性や無中断提供は保証されません。');
    b.writeln('- ベータ期間中は機能の変更・中断が予告なく行われる場合があります。');
    b.writeln('- データの損失や変更が発生する可能性があります。');
    b.writeln('- ベータ期間中は無料プランのみ提供され、有料プランは正式リリース後に導入される場合があります。');
    b.writeln('- ベータ期間中の上限緩和などの特典は、正式リリース時に変更または終了される場合があります。');
    b.writeln();
    b.writeln('11. 責任の制限');
  } else {
    b.writeln('10. 責任の制限');
  }
  b.writeln('- 法令が許容する範囲内で、サービス利用による損害について責任を負いません。');
  b.writeln('- 位置情報はデバイス/OS/通信環境によって誤差が生じる場合があります。');
  return b.toString();
}

String _getRefundPolicyJa({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('返金ポリシー');
  b.writeln();
  b.writeln('1. 返金原則');
  b.writeln('- 決済と返金はGoogle Play返金ポリシーに従います。');
  b.writeln();
  b.writeln('2. 返金リクエスト方法');
  b.writeln('- Google Play決済履歴から返金リクエストを行えます。');
  b.writeln();
  b.writeln('3. サービス障害');
  b.writeln('- 重大な障害が発生した場合、Google Playポリシー範囲内で返金または補償が検討されます。');
  b.writeln();
  if (isBeta) {
    b.writeln('4. ベータ版のご注意');
    b.writeln('- ベータ期間中は機能やポリシーが変更される場合があります。');
    b.writeln();
    b.writeln('5. 自動更新キャンセル');
  } else {
    b.writeln('4. 自動更新キャンセル');
  }
  b.writeln('- 自動更新のキャンセルはGoogle Playサブスクリプション管理から可能です。');
  b.writeln('- キャンセル後も次の更新日まで特典が維持されます。');
  return b.toString();
}

// ═══════════════════════════════════════════════════════════
//  Chinese
// ═══════════════════════════════════════════════════════════

String _getSubscriptionPolicyZh({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('订阅政策');
  b.writeln();
  b.writeln('1. 服务概述');
  b.writeln('- 本服务提供基于位置的闹钟功能。测试期间仅提供免费方案；正式发布时可能引入广告并提供付费方案。');
  b.writeln();
  b.writeln('2. 免费方案范围');
  b.writeln('- 地点/闹钟注册不限。');
  if (isBeta) {
    b.writeln('- 测试期间，搜索、地图和警报触发实际上不设月度限制。');
    b.writeln('- 如果用户增长、第三方API成本或服务稳定性风险超出预期，测试期间也可能引入公平使用限制。');
    b.writeln('- 正式发布时，免费方案可能对警报触发、搜索、地图使用等设置月度限制，并可能引入广告。');
    b.writeln('- 正式发布时可能提供Plus/Pro等付费方案，包含更高额度、减少或去除广告、部分功能优先使用等权益。');
  } else {
    b.writeln('- 闹钟触发：每月 30 次（基础提供）。');
    b.writeln('- 地址/地点搜索：每月保证 5 次（防滥用安全上限 15 次）。');
    b.writeln('- 地图打开：每月最多 100 次（防滥用上限）。');
    b.writeln('- 超过保证额度时，可通过奖励系统（同意提示或奖励广告）解锁至安全上限的额外使用。');
    b.writeln('- 一旦达到安全上限，即使使用奖励也无法再扩展本月额度。');
    b.writeln('- 付费方案用户可能享有更高的使用额度、减少或去除广告、部分功能优先使用等权益。');
    b.writeln('- 自动续费订阅可能享受折扣，具体价格以Google Play商品说明为准。');
  }
  b.writeln();
  b.writeln('2-1. 地图服务提供条件（重要）');
  b.writeln('- 地图功能依赖于第三方API（Naver Cloud、Google Cloud等），受其政策、价格、可用性和配额影响。');
  b.writeln('- 正式发布后标明的每月地图打开次数为一般提供目标，并非保证。');
  b.writeln('- 为应对第三方API费用突增、滥用、运营稳定性问题，免费用户或全体用户的地图功能可能被临时限制或暂停，恕不另行通知。');
  b.writeln('- 此为公平使用政策及服务稳定运营措施，由此产生的退款可能受限。');
  b.writeln('- 当限制生效时，地图显示、地址搜索或地点搜索的部分功能可能无法使用。');
  b.writeln();
  b.writeln('3. GPS位置服务说明');
  b.writeln('- 本服务利用GPS位置信息提供闹钟服务。');
  b.writeln('- GPS只能大致判断位置，即使在室外空旷环境中，也始终存在几米到几十米的误差。');
  b.writeln('  例）设置半径30m时，实际可能在25m处触发，或进入35m才触发。');
  b.writeln('- 在地下、建筑物内、信号干扰区域，误差会更大，');
  b.writeln('  即使没有实际移动，也可能反复检测到进入/离开，导致闹钟频繁响铃。');
  b.writeln('- 这些误差、误触发及未触发属于GPS特性，本应用无法解决，也无法承担相关责任。');
  b.writeln('- ⚡误触发发生时：可使用全屏闹钟中的「⚡误触发」按钮，在保持闹钟激活的同时关闭铃声。');
  b.writeln('  （即将推出「Passing」功能：一键设置n分钟后自动重新激活）');
  b.writeln('- 未触发发生时：请使用GPS页面的「错误报告」按钮发送日志，可修复部分将尽快处理。');
  b.writeln('- 同意本条款即表示，包括付费用户在内，均同意不就GPS误差导致的⚡误触发或未触发向开发者追究责任。');
  b.writeln();
  b.writeln('4. Wi-Fi辅助检测说明');
  b.writeln('- Wi-Fi检测是提升闹钟精度的可选辅助功能，注册非强制要求。');
  b.writeln('- Wi-Fi SSID/BSSID信息仅在设备本地用于地点识别，不会传输至外部服务器。');
  b.writeln('- Wi-Fi环境变化（路由器移位、更换、频道冲突等）可能导致检测错误，');
  b.writeln('  因此造成的误触发或未触发，开发者不承担责任。');
  b.writeln('- 同意本条款即表示您已知悉并接受上述内容。');
  b.writeln();
  b.writeln('4-1. 应用运行状态与恢复说明（重要）');
  b.writeln('- 本应用的闹钟仅在应用（后台服务）正常运行时才会作动。以下情况闹钟可能不会响铃，请务必留意。');
  b.writeln(
    '- 【设备重启】设备重启后，后台闹钟监控会暂时中止。如有已启用的闹钟，我们会定期发送提示您重新打开应用的推送通知。若您忽略该通知且不重新打开应用，闹钟可能无法正常响铃。',
  );
  b.writeln(
    '- 【强制停止】当您在设备设置中“强制停止”本应用（或因任何原因被强制停止）时，根据操作系统机制，应用无法自行恢复或发送通知。此时必须手动重新打开应用，闹钟才能正常作动。',
  );
  b.writeln(
    '- 【操作系统终止】当操作系统因内存不足、厂商省电策略等终止应用时，我们会在一段时间后发送恢复通知。但在此期间，以及您未察觉应用被终止的情况下，闹钟可能不会响铃。',
  );
  b.writeln('- 为确保闹钟稳定运行，建议允许电池优化例外、自动启动等设置。对于上述原因导致的闹钟未作动，开发者责任受限。');
  b.writeln('- 同意本条款即表示您已知悉并接受上述内容。');
  b.writeln();
  b.writeln('5. 支付与自动续费');
  b.writeln('- 支付通过Google Play计费系统处理。');
  b.writeln('- 订阅按照Google Play政策自动续费。续费周期和扣款日由Google Play管理。');
  b.writeln('- 在续费日之前未取消的订阅将自动续费。');
  b.writeln();
  b.writeln('6. 取消与方案变更');
  b.writeln('- 可通过Google Play订阅管理取消。');
  b.writeln('- 取消后，权益保留至下一续费日。');
  b.writeln();
  b.writeln('7. 广告');
  if (isBeta) {
    b.writeln('- 测试期间不显示广告。');
    b.writeln('- 正式发布时可能在免费方案中引入广告；付费方案的广告可能减少或去除。');
  } else {
    b.writeln('- 免费方案在使用部分功能时可能显示广告。');
    b.writeln('- 付费方案的广告可能减少或去除。');
  }
  b.writeln();
  b.writeln('8. 使用限制');
  b.writeln('- 为保护服务稳定性，错误报告和反馈每30分钟可发送一次，每天最多3次。');
  b.writeln('- 如检测到异常或过度使用，服务可能受到限制。');
  b.writeln();
  b.writeln('9. 服务变更');
  b.writeln('- 功能、价格和方案结构可能会变更以改善服务质量。');
  b.writeln();
  if (isBeta) {
    b.writeln('10. 测试版须知');
    b.writeln('- 本服务为测试版，不保证稳定性和不间断服务。');
    b.writeln('- 测试期间功能可能会无预告变更或中断。');
    b.writeln('- 数据可能会丢失或变更。');
    b.writeln('- 测试期间仅提供免费方案，付费方案可能在正式发布后引入。');
    b.writeln('- 测试期间的限额放宽等福利可能在正式发布时变更或终止。');
    b.writeln();
    b.writeln('11. 责任限制');
  } else {
    b.writeln('10. 责任限制');
  }
  b.writeln('- 在法律允许的范围内，我们不对因使用服务而造成的损害承担责任。');
  b.writeln('- 位置精度取决于设备/操作系统/网络条件。');
  return b.toString();
}

String _getRefundPolicyZh({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('退款政策');
  b.writeln();
  b.writeln('1. 退款原则');
  b.writeln('- 支付和退款遵循Google Play退款政策。');
  b.writeln();
  b.writeln('2. 申请退款方法');
  b.writeln('- 可通过Google Play支付记录申请退款。');
  b.writeln();
  b.writeln('3. 服务故障');
  b.writeln('- 发生重大故障时，可在Google Play政策范围内审核退款或补偿。');
  b.writeln();
  if (isBeta) {
    b.writeln('4. 测试版须知');
    b.writeln('- 测试期间功能和政策可能会变更。');
    b.writeln();
    b.writeln('5. 取消自动续费');
  } else {
    b.writeln('4. 取消自动续费');
  }
  b.writeln('- 可通过Google Play订阅管理取消自动续费。');
  b.writeln('- 取消后，权益保留至下一续费日。');
  return b.toString();
}

// ═══════════════════════════════════════════════════════════
//  German
// ═══════════════════════════════════════════════════════════

String _getSubscriptionPolicyDe({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Abonnementrichtlinie');
  b.writeln();
  b.writeln('1. Überblick über den Dienst');
  b.writeln(
    '- Dieser Dienst bietet standortbasierte Alarmfunktionen. Während der Beta-Phase wird nur der kostenlose Plan angeboten; Werbung und kostenpflichtige Pläne können bei der offiziellen Veröffentlichung eingeführt werden.',
  );
  b.writeln();
  b.writeln('2. Umfang des kostenlosen Plans');
  b.writeln('- Unbegrenzte Registrierung von Orten und Alarmen.');
  if (isBeta) {
    b.writeln(
      '- Während der Beta-Phase sind Suche, Karten und Alarmauslösungen praktisch ohne monatliche Begrenzung verfügbar.',
    );
    b.writeln(
      '- Wenn Nutzerwachstum, Kosten von Drittanbieter-APIs oder Risiken für die Servicestabilität unerwartet steigen, können während der Beta-Phase Fair-Use-Beschränkungen eingeführt werden.',
    );
    b.writeln(
      '- Bei der offiziellen Veröffentlichung kann der kostenlose Plan monatliche Begrenzungen für Alarmauslösungen, Suche und Karten enthalten, und es kann Werbung eingeführt werden.',
    );
    b.writeln(
      '- Kostenpflichtige Pläne wie Plus/Pro können mit höheren Kontingenten, reduzierter oder entfernter Werbung und vorrangigem Zugang zu bestimmten Funktionen angeboten werden.',
    );
  } else {
    b.writeln('- Alarmauslösungen: 30 pro Monat (Standard).');
    b.writeln(
      '- Adress-/Ortssuche: 5 garantiert pro Monat (Sicherheitsobergrenze gegen Missbrauch 15).',
    );
    b.writeln(
      '- Kartenaufrufe: bis zu 100 pro Monat (Obergrenze gegen Missbrauch).',
    );
    b.writeln(
      '- Bei Überschreitung eines garantierten Limits ermöglicht ein Bonussystem (Bestätigung eines Hinweises oder belohnte Werbung) eine zusätzliche Nutzung bis zur Sicherheitsobergrenze.',
    );
    b.writeln(
      '- Sobald die Sicherheitsobergrenze erreicht ist, ist in diesem Monat auch mit Boni keine weitere Nutzung möglich, um Missbrauch zu verhindern.',
    );
    b.writeln(
      '- Nutzer kostenpflichtiger Pläne können höhere Nutzungskontingente, reduzierte oder entfernte Werbung und vorrangigen Zugang zu bestimmten Funktionen erhalten.',
    );
    b.writeln(
      '- Für automatisch verlängerte Abonnements können Rabatte gelten; genaue Preise finden Sie in den Google Play-Produktdetails.',
    );
  }
  b.writeln();
  b.writeln(
    '2-1. Bedingungen für die Bereitstellung des Kartendienstes (Wichtig)',
  );
  b.writeln(
    '- Kartenfunktionen hängen von Drittanbieter-APIs (Naver Cloud Platform, Google Cloud Platform usw.) ab und unterliegen deren Richtlinien, Preisen, Ausfallzeiten und Kontingenten.',
  );
  b.writeln(
    '- Die nach der offiziellen Veröffentlichung angegebenen monatlichen Kartenaufrufe sind allgemeine Zielwerte, keine garantierte Verfügbarkeit.',
  );
  b.writeln(
    '- Zum Schutz der Servicestabilität vor plötzlichen Kostenspitzen bei Drittanbieter-APIs, Missbrauch oder Betriebsproblemen können Kartenfunktionen für kostenlose oder alle Nutzer ohne Vorankündigung vorübergehend eingeschränkt oder ausgesetzt werden.',
  );
  b.writeln(
    '- Dies ist eine Fair-Use-Richtlinie und eine betriebliche Schutzmaßnahme. Rückerstattungen aufgrund solcher Einschränkungen können begrenzt sein.',
  );
  b.writeln(
    '- Wenn Einschränkungen angewendet werden, sind möglicherweise einige Funktionen für Kartenanzeige, Adresssuche oder Ortssuche nicht verfügbar.',
  );
  b.writeln();
  b.writeln('2-2. Hinweis zu Konto- und Aktivgerätedaten');
  b.writeln(
    '- Anmeldeanbieter können je nach Sprache und Land Google, Kakao, Naver, LINE, Facebook und E-Mail-Magic-Links umfassen.',
  );
  b.writeln(
    '- Informationen zu verknüpften Anmeldemethoden werden nur verwendet, um den Zugriff auf dasselbe Konto mit mehreren Anmeldemethoden zu ermöglichen.',
  );
  b.writeln(
    '- Orte und Alarme werden hauptsächlich auf dem aktiven Gerät gespeichert und können in den Einstellungen an das aktuell angemeldete Konto übertragen werden.',
  );
  b.writeln(
    '- Beim Löschen des Kontos werden die kontobezogenen Daten auf dem Server gelöscht; lokale Daten auf dem Gerät können bestehen bleiben, bis die App-Daten gelöscht oder die App deinstalliert wird.',
  );
  b.writeln();
  b.writeln('3. Hinweis zum GPS-standortbasierten Dienst');
  b.writeln(
    '- Dieser Dienst nutzt GPS-Standortdaten zur Auslösung von Alarmen.',
  );
  b.writeln(
    '- GPS kann Ihren Standort nur schätzen. Selbst im Freien besteht immer eine Fehlertoleranz von mehreren bis zu zehn Metern.',
  );
  b.writeln(
    '  Beispiel: Bei einem Radius von 30 m kann der Alarm bereits bei 25 m oder erst bei 35 m ausgelöst werden.',
  );
  b.writeln(
    '- In Untergrundbereichen, in Gebäuden oder in abgeschirmten Zonen wird der Fehler noch größer.',
  );
  b.writeln(
    '  Das System kann das Betreten/Verlassen wiederholt erkennen, auch ohne Bewegung, wodurch Alarme mehrmals ausgelöst werden.',
  );
  b.writeln(
    '- Diese GPS-bedingten Einschränkungen (Fehlauslösungen und ausgebliebene Auslösungen) können von dieser App nicht behoben oder garantiert werden.',
  );
  b.writeln(
    '- ⚡Fehlauslösung: Verwenden Sie die Schaltfläche „⚡Fehlauslösung“ im Alarmbildschirm, um den Ton stummzuschalten und den Alarm aktiv zu halten.',
  );
  b.writeln(
    '  (Die Funktion „Passing“ kommt bald: ein Tippen zur automatischen Reaktivierung nach n Minuten)',
  );
  b.writeln(
    '- Ausgebliebene Auslösung: Verwenden Sie die Schaltfläche „Fehlerbericht“ auf der GPS-Seite, um Protokolle zu senden. Wir beheben behebbare Probleme so schnell wie möglich.',
  );
  b.writeln(
    '- Wenn Zeitzone, Datum oder Uhrzeit des Geräts manuell geändert werden oder ein Alarm während der Zeitsynchronisierung des Betriebssystems Mitternacht überschreitet, kann sich die Datumsberechnung für wiederkehrende Alarme ändern und Alarme können verzögert oder anders als erwartet ausgelöst werden.',
  );
  b.writeln(
    '- Mit der Zustimmung zu diesen Bedingungen erklären Sie sich, auch als zahlende Abonnenten, damit einverstanden, den Entwickler nicht für ⚡Fehlauslösungen oder ausgebliebene Auslösungen aufgrund von GPS-Fehlern haftbar zu machen.',
  );
  b.writeln();
  b.writeln('4. Hinweis zur Wi-Fi-gestützten Erkennung');
  b.writeln(
    '- Die Wi-Fi-Erkennung ist eine optionale Zusatzfunktion zur Verbesserung der Alarmgenauigkeit. Die Registrierung ist nicht verpflichtend.',
  );
  b.writeln(
    '- Wi-Fi-SSID/BSSID-Daten werden ausschließlich auf dem Gerät zur Ortserkennung verwendet und niemals an externe Server übertragen.',
  );
  b.writeln(
    '- Erkennungsfehler können durch Änderungen der Wi-Fi-Umgebung auftreten (Verlegung oder Austausch des Routers, Kanalkonflikte usw.).',
  );
  b.writeln(
    '  Der Entwickler haftet nicht für Fehl- oder ausgebliebene Alarme aufgrund solcher Bedingungen.',
  );
  b.writeln(
    '- Mit der Zustimmung zu diesen Bedingungen erkennen Sie das Vorstehende an und akzeptieren es.',
  );
  b.writeln();
  b.writeln(
    '4-1. Hinweis zum App-Ausführungsstatus und zur Wiederherstellung (Wichtig)',
  );
  b.writeln(
    '- Alarme funktionieren nur, während die App (Hintergrunddienst) normal läuft. Bitte beachten Sie, dass Alarme in den folgenden Fällen möglicherweise nicht ertönen.',
  );
  b.writeln(
    '- [Geräteneustart] Nach einem Neustart wird die Hintergrundüberwachung der Alarme vorübergehend ausgesetzt. Wenn Sie aktive Alarme haben, senden wir regelmäßig eine Push-Benachrichtigung mit der Aufforderung, die App erneut zu öffnen. Wenn Sie diese ignorieren und die App nicht erneut öffnen, ertönen Alarme möglicherweise nicht ordnungsgemäß.',
  );
  b.writeln(
    '- [Beenden erzwingen] Wenn Sie die App in den Geräteeinstellungen über „Beenden erzwingen“ schließen (oder sie aus irgendeinem Grund zwangsweise beendet wird), verhindert das Betriebssystem, dass sich die App selbst wiederherstellt oder Benachrichtigungen sendet. In diesem Fall funktionieren Alarme erst, nachdem Sie die App manuell erneut geöffnet haben.',
  );
  b.writeln(
    '- [Beendigung durch das Betriebssystem] Wenn das Betriebssystem die App aufgrund von Speichermangel, herstellerspezifischen Energiesparrichtlinien usw. beendet, senden wir nach einiger Zeit eine Wiederherstellungsbenachrichtigung. Während dieser Zeit – oder wenn Sie die Beendigung nicht bemerken – ertönen Alarme jedoch möglicherweise nicht.',
  );
  b.writeln(
    '- Für einen zuverlässigen Betrieb empfehlen wir, Ausnahmen von der Akkuoptimierung und Autostart-Berechtigungen zuzulassen. Die Haftung für ausgebliebene Alarme aufgrund des Vorstehenden ist beschränkt.',
  );
  b.writeln(
    '- Mit der Zustimmung zu diesen Bedingungen erkennen Sie das Vorstehende an und akzeptieren es.',
  );
  b.writeln();
  b.writeln('5. Zahlung und automatische Verlängerung');
  b.writeln('- Zahlungen werden über die Google Play-Abrechnung abgewickelt.');
  b.writeln(
    '- Abonnements verlängern sich gemäß den Google Play-Richtlinien automatisch. Verlängerungszyklus und Abrechnungsdatum werden von Google Play verwaltet.',
  );
  b.writeln(
    '- Abonnements verlängern sich automatisch, sofern sie nicht vor dem Verlängerungsdatum gekündigt werden.',
  );
  b.writeln(
    '- Die Preise richten sich nach den bei Google Play angegebenen Beträgen.',
  );
  b.writeln();
  b.writeln('6. Kündigung und Plananpassungen');
  b.writeln(
    '- Kündigen Sie Abonnements über die Google Play-Abonnementverwaltung.',
  );
  b.writeln(
    '- Die Vorteile bleiben nach der Kündigung bis zum nächsten Verlängerungsdatum bestehen.',
  );
  b.writeln('- Plananpassungen unterliegen den Google Play-Richtlinien.');
  b.writeln();
  b.writeln('7. Werbung');
  if (isBeta) {
    b.writeln('- Während der Beta-Phase wird keine Werbung angezeigt.');
    b.writeln(
      '- Bei der offiziellen Veröffentlichung kann Werbung für den kostenlosen Plan eingeführt werden; bei kostenpflichtigen Plänen kann die Werbung reduziert oder entfernt werden.',
    );
  } else {
    b.writeln(
      '- Im kostenlosen Plan kann bei der Nutzung bestimmter Funktionen Werbung angezeigt werden.',
    );
    b.writeln(
      '- Bei kostenpflichtigen Plänen kann die Werbung reduziert oder entfernt werden.',
    );
  }
  b.writeln();
  b.writeln('8. Nutzungsbeschränkungen');
  b.writeln(
    '- Zum Schutz der Servicestabilität sind Fehlerberichte und Feedback auf einmal alle 30 Minuten und maximal 3-mal pro Tag begrenzt.',
  );
  b.writeln(
    '- Bei ungewöhnlicher oder übermäßiger Nutzung kann der Dienst eingeschränkt werden.',
  );
  b.writeln();
  b.writeln('9. Serviceänderungen');
  b.writeln(
    '- Funktionen, Preise und Planstruktur können zur Verbesserung der Servicequalität geändert werden.',
  );
  b.writeln('- Über wichtige Änderungen wird über In-App-Hinweise informiert.');
  b.writeln();
  if (isBeta) {
    b.writeln('10. Beta-Hinweis');
    b.writeln(
      '- Dies ist eine Beta-Version. Stabilität und unterbrechungsfreier Service werden nicht garantiert.',
    );
    b.writeln(
      '- Funktionen können während der Beta-Phase ohne Vorankündigung geändert oder ausgesetzt werden.',
    );
    b.writeln(
      '- Daten, Alarmeinstellungen und Aufzeichnungen können während der Beta-Phase verloren gehen oder geändert werden.',
    );
    b.writeln(
      '- Leistungsprobleme, Standortfehler und Alarmverzögerungen können auftreten.',
    );
    b.writeln(
      '- Während der Beta-Phase wird nur der kostenlose Plan angeboten; kostenpflichtige Pläne können nach der offiziellen Veröffentlichung eingeführt werden.',
    );
    b.writeln(
      '- Beta-Vorteile wie gelockerte Limits können bei der offiziellen Veröffentlichung geändert oder beendet werden.',
    );
    b.writeln();
    b.writeln('11. Haftungsbeschränkung');
  } else {
    b.writeln('10. Haftungsbeschränkung');
  }
  b.writeln(
    '- Soweit gesetzlich zulässig, haften wir nicht für direkte/indirekte/beiläufige/besondere/Folgeschäden.',
  );
  b.writeln(
    '- Die Standortgenauigkeit hängt von Geräte-/Betriebssystem-/Netzwerkbedingungen ab.',
  );
  b.writeln(
    '- Die Haftung für Alarmausfälle, Datenverlust oder Serviceunterbrechungen ist beschränkt.',
  );
  return b.toString();
}

String _getRefundPolicyDe({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Rückerstattungsrichtlinie');
  b.writeln();
  b.writeln('1. Grundsätze der Rückerstattung');
  b.writeln(
    '- Zahlungen und Rückerstattungen unterliegen den Rückerstattungsrichtlinien von Google Play.',
  );
  b.writeln(
    '- Rückerstattungen für bereits genutzte Abonnementzeiträume können eingeschränkt sein.',
  );
  b.writeln();
  b.writeln('2. So beantragen Sie eine Rückerstattung');
  b.writeln(
    '- Beantragen Sie Rückerstattungen über den Google Play-Zahlungsverlauf.',
  );
  b.writeln(
    '- Anspruch und Bearbeitung richten sich nach den Richtlinien von Google Play.',
  );
  b.writeln();
  b.writeln('3. Servicestörungen');
  b.writeln(
    '- Bei schwerwiegenden Servicestörungen können Rückerstattungen oder Entschädigungen im Rahmen der Google Play-Richtlinien geprüft werden.',
  );
  b.writeln();
  if (isBeta) {
    b.writeln('4. Beta-Hinweis');
    b.writeln(
      '- Funktionen, Richtlinien und Dienste können sich während der Beta-Phase ändern.',
    );
    b.writeln(
      '- Die Haftung für Probleme während der Beta-Phase ist im gesetzlich zulässigen Rahmen beschränkt.',
    );
    b.writeln();
    b.writeln('5. Kündigung der automatischen Verlängerung');
  } else {
    b.writeln('4. Kündigung der automatischen Verlängerung');
  }
  b.writeln(
    '- Kündigen Sie die automatische Verlängerung über die Google Play-Abonnementverwaltung.',
  );
  b.writeln(
    '- Die Vorteile bleiben nach der Kündigung bis zum nächsten Verlängerungsdatum bestehen.',
  );
  return b.toString();
}

// ═══════════════════════════════════════════════════════════
//  French
// ═══════════════════════════════════════════════════════════

String _getSubscriptionPolicyFr({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Politique d’abonnement');
  b.writeln();
  b.writeln('1. Aperçu du service');
  b.writeln(
    '- Ce service fournit des fonctions d’alarme basées sur la localisation. Pendant la période bêta, seul le forfait gratuit est proposé ; des publicités et des forfaits payants peuvent être introduits lors de la sortie officielle.',
  );
  b.writeln();
  b.writeln('2. Couverture du forfait gratuit');
  b.writeln('- Enregistrement illimité de lieux et d’alarmes.');
  if (isBeta) {
    b.writeln(
      '- Pendant la bêta, la recherche, les cartes et les déclenchements d’alarme sont disponibles sans limite mensuelle pratique.',
    );
    b.writeln(
      '- Si la croissance des utilisateurs, les coûts des API tierces ou les risques pour la stabilité du service augmentent de façon inattendue, des limites d’usage équitable peuvent être introduites pendant la bêta.',
    );
    b.writeln(
      '- Lors de la sortie officielle, le forfait gratuit peut inclure des limites mensuelles pour les déclenchements d’alarme, la recherche et les cartes, et des publicités peuvent être introduites.',
    );
    b.writeln(
      '- Des forfaits payants Plus/Pro peuvent être proposés avec des quotas plus élevés, des publicités réduites ou supprimées et un accès prioritaire à certaines fonctionnalités.',
    );
  } else {
    b.writeln('- Déclenchements d’alarme : 30 par mois (standard).');
    b.writeln(
      '- Recherche d’adresse/de lieu : 5 garanties par mois (plafond de sécurité anti-abus de 15).',
    );
    b.writeln(
      '- Ouvertures de carte : jusqu’à 100 par mois (plafond anti-abus).',
    );
    b.writeln(
      '- Lorsqu’une limite garantie est dépassée, un système de bonus (acceptation d’un avis ou publicités avec récompense) permet une utilisation supplémentaire jusqu’au plafond de sécurité.',
    );
    b.writeln(
      '- Une fois le plafond de sécurité atteint, aucune utilisation supplémentaire n’est possible ce mois-là, même avec des bonus, afin de prévenir les abus.',
    );
    b.writeln(
      '- Les utilisateurs des forfaits payants peuvent bénéficier de quotas d’utilisation plus élevés, de publicités réduites ou supprimées et d’un accès prioritaire à certaines fonctionnalités.',
    );
    b.writeln(
      '- Des réductions peuvent s’appliquer aux abonnements à renouvellement automatique ; consultez les détails du produit sur Google Play pour les tarifs exacts.',
    );
  }
  b.writeln();
  b.writeln(
    '2-1. Conditions de fourniture du service de cartographie (Important)',
  );
  b.writeln(
    '- Les fonctions de cartographie dépendent d’API tierces (Naver Cloud Platform, Google Cloud Platform, etc.) et sont soumises aux politiques, tarifs, interruptions et quotas de ces fournisseurs.',
  );
  b.writeln(
    '- Les nombres d’ouvertures de carte mensuelles indiqués après la sortie officielle sont des objectifs généraux, et non une disponibilité garantie.',
  );
  b.writeln(
    '- Afin de protéger la stabilité du service contre les pics soudains de coûts des API tierces, les abus ou les problèmes opérationnels, les fonctions de cartographie pour les utilisateurs gratuits ou tous les utilisateurs peuvent être temporairement limitées ou suspendues sans préavis.',
  );
  b.writeln(
    '- Il s’agit d’une politique d’usage équitable et d’une mesure de protection opérationnelle. Les remboursements liés à de telles limitations peuvent être restreints.',
  );
  b.writeln(
    '- Lorsque des limitations sont appliquées, certaines fonctions d’affichage de carte, de recherche d’adresse ou de recherche de lieu peuvent être indisponibles.',
  );
  b.writeln();
  b.writeln('2-2. Avis sur les données de compte et d’appareil actif');
  b.writeln(
    '- Les fournisseurs de connexion peuvent inclure Google, Kakao, Naver, LINE, Facebook et les liens magiques par e-mail selon la langue et le pays.',
  );
  b.writeln(
    '- Les informations sur les méthodes de connexion liées sont utilisées uniquement pour vous permettre d’accéder au même compte avec plusieurs méthodes de connexion.',
  );
  b.writeln(
    '- Les lieux et les alarmes sont stockés principalement sur l’appareil actif et peuvent être transférés vers le compte actuellement connecté depuis les Paramètres.',
  );
  b.writeln(
    '- La suppression du compte supprime les données de compte côté serveur ; les données locales sur l’appareil peuvent subsister jusqu’à ce que les données de l’application soient effacées ou que l’application soit désinstallée.',
  );
  b.writeln();
  b.writeln('3. Avis sur le service basé sur la localisation GPS');
  b.writeln(
    '- Ce service utilise les données de localisation GPS pour déclencher des alarmes.',
  );
  b.writeln(
    '- Le GPS ne peut qu’estimer votre position. Même en extérieur, il existe toujours une marge d’erreur de quelques mètres à plusieurs dizaines de mètres.',
  );
  b.writeln(
    '  Par exemple, avec un rayon de 30 m, l’alarme peut se déclencher à 25 m ou seulement à 35 m.',
  );
  b.writeln(
    '- Dans les zones souterraines, à l’intérieur des bâtiments ou dans les zones où le signal est bloqué, l’erreur devient encore plus grande.',
  );
  b.writeln(
    '  Le système peut détecter des entrées/sorties de façon répétée même sans mouvement, ce qui déclenche l’alarme plusieurs fois.',
  );
  b.writeln(
    '- Ces limitations du GPS (déclenchements intempestifs et déclenchements manqués) ne peuvent être ni résolues ni garanties par cette application.',
  );
  b.writeln(
    '- ⚡Déclenchement intempestif : utilisez le bouton « ⚡Déclenchement intempestif » sur l’écran d’alarme pour couper le son tout en gardant l’alarme active.',
  );
  b.writeln(
    '  (Fonction « Passing » bientôt disponible : un appui pour réactiver automatiquement après n minutes)',
  );
  b.writeln(
    '- Déclenchement manqué : utilisez le bouton « Rapport de bogue » sur la page GPS pour envoyer les journaux. Nous corrigerons les problèmes résolubles le plus rapidement possible.',
  );
  b.writeln(
    '- Si le fuseau horaire, la date ou l’heure de l’appareil sont modifiés manuellement, ou si une alarme franchit minuit pendant la synchronisation de l’heure du système, le calcul de la date des alarmes récurrentes peut changer et les alarmes peuvent être retardées ou se déclencher différemment de ce qui était prévu.',
  );
  b.writeln(
    '- En acceptant ces conditions, y compris les abonnés payants, vous acceptez de ne pas tenir le développeur responsable des ⚡déclenchements intempestifs ou des déclenchements manqués dus aux erreurs du GPS.',
  );
  b.writeln();
  b.writeln('4. Avis sur la détection Wi-Fi assistée');
  b.writeln(
    '- La détection Wi-Fi est une fonction complémentaire facultative destinée à améliorer la précision des alarmes. L’enregistrement n’est pas obligatoire.',
  );
  b.writeln(
    '- Les données SSID/BSSID du Wi-Fi sont utilisées uniquement sur l’appareil pour la reconnaissance des lieux et ne sont jamais transmises à des serveurs externes.',
  );
  b.writeln(
    '- Des erreurs de détection peuvent survenir en raison de changements de l’environnement Wi-Fi (déplacement ou remplacement du routeur, conflits de canaux, etc.).',
  );
  b.writeln(
    '  Le développeur n’est pas responsable des alarmes intempestives ou manquées dues à de telles conditions.',
  );
  b.writeln(
    '- En acceptant ces conditions, vous reconnaissez et acceptez ce qui précède.',
  );
  b.writeln();
  b.writeln(
    '4-1. Avis sur l’état d’exécution de l’application et la récupération (Important)',
  );
  b.writeln(
    '- Les alarmes ne fonctionnent que lorsque l’application (service en arrière-plan) s’exécute normalement. Veuillez noter que les alarmes peuvent ne pas sonner dans les cas suivants.',
  );
  b.writeln(
    '- [Redémarrage de l’appareil] Après un redémarrage, la surveillance des alarmes en arrière-plan est temporairement suspendue. Si vous avez des alarmes actives, nous envoyons régulièrement une notification push vous demandant de rouvrir l’application. Si vous l’ignorez et ne rouvrez pas l’application, les alarmes peuvent ne pas sonner correctement.',
  );
  b.writeln(
    '- [Arrêt forcé] Si vous « forcez l’arrêt » de l’application depuis les paramètres de l’appareil (ou si elle est arrêtée de force pour une raison quelconque), le système d’exploitation empêche l’application de se rétablir elle-même ou d’envoyer des notifications. Dans ce cas, les alarmes ne fonctionnent qu’après avoir rouvert manuellement l’application.',
  );
  b.writeln(
    '- [Arrêt par le système d’exploitation] Si le système d’exploitation arrête l’application en raison d’un manque de mémoire, des politiques d’économie de batterie du fabricant, etc., nous envoyons une notification de récupération après un certain temps. Cependant, pendant cette période — ou si vous ne remarquez pas l’arrêt — les alarmes peuvent ne pas sonner.',
  );
  b.writeln(
    '- Pour un fonctionnement fiable, nous recommandons d’autoriser les exceptions d’optimisation de la batterie et les autorisations de démarrage automatique. La responsabilité pour les alarmes manquées dues à ce qui précède est limitée.',
  );
  b.writeln(
    '- En acceptant ces conditions, vous reconnaissez et acceptez ce qui précède.',
  );
  b.writeln();
  b.writeln('5. Paiement et renouvellement automatique');
  b.writeln(
    '- Les paiements sont traités via le système de facturation Google Play.',
  );
  b.writeln(
    '- Les abonnements se renouvellent automatiquement conformément aux politiques de Google Play. Le cycle de renouvellement et la date de facturation sont gérés par Google Play.',
  );
  b.writeln(
    '- Les abonnements se renouvellent automatiquement sauf s’ils sont annulés avant la date de renouvellement.',
  );
  b.writeln(
    '- Les tarifs correspondent aux montants indiqués sur Google Play.',
  );
  b.writeln();
  b.writeln('6. Annulation et changements de forfait');
  b.writeln(
    '- Annulez les abonnements via la gestion des abonnements Google Play.',
  );
  b.writeln(
    '- Les avantages restent valables jusqu’à la prochaine date de renouvellement après l’annulation.',
  );
  b.writeln(
    '- Les changements de forfait sont soumis aux politiques de Google Play.',
  );
  b.writeln();
  b.writeln('7. Publicités');
  if (isBeta) {
    b.writeln('- Aucune publicité n’est affichée pendant la période bêta.');
    b.writeln(
      '- Lors de la sortie officielle, des publicités peuvent être introduites pour le forfait gratuit ; les forfaits payants peuvent avoir des publicités réduites ou supprimées.',
    );
  } else {
    b.writeln(
      '- Le forfait gratuit peut afficher des publicités lors de l’utilisation de certaines fonctionnalités.',
    );
    b.writeln(
      '- Les forfaits payants peuvent avoir des publicités réduites ou supprimées.',
    );
  }
  b.writeln();
  b.writeln('8. Restrictions d’utilisation');
  b.writeln(
    '- Afin de protéger la stabilité du service, les rapports de bogue et les commentaires sont limités à une fois toutes les 30 minutes, et jusqu’à 3 fois par jour.',
  );
  b.writeln(
    '- Une utilisation anormale ou excessive peut entraîner des restrictions de service.',
  );
  b.writeln();
  b.writeln('9. Modifications du service');
  b.writeln(
    '- Les fonctionnalités, les tarifs et la structure des forfaits peuvent changer afin d’améliorer la qualité du service.',
  );
  b.writeln(
    '- Les modifications importantes seront communiquées via des avis dans l’application.',
  );
  b.writeln();
  if (isBeta) {
    b.writeln('10. Avis concernant la version bêta');
    b.writeln(
      '- Il s’agit d’une version bêta. La stabilité et un service ininterrompu ne sont pas garantis.',
    );
    b.writeln(
      '- Les fonctionnalités peuvent changer ou être suspendues sans préavis pendant la bêta.',
    );
    b.writeln(
      '- Les données, les réglages d’alarme et les enregistrements peuvent être perdus ou modifiés pendant la bêta.',
    );
    b.writeln(
      '- Des problèmes de performances, des erreurs de localisation et des retards d’alarme peuvent survenir.',
    );
    b.writeln(
      '- Seul le forfait gratuit est proposé pendant la bêta ; des forfaits payants peuvent être introduits après la sortie officielle.',
    );
    b.writeln(
      '- Les avantages de la bêta, tels que des limites assouplies, peuvent être modifiés ou supprimés lors de la sortie officielle.',
    );
    b.writeln();
    b.writeln('11. Limitation de responsabilité');
  } else {
    b.writeln('10. Limitation de responsabilité');
  }
  b.writeln(
    '- Dans la mesure permise par la loi, nous ne sommes pas responsables des dommages directs/indirects/accessoires/spéciaux/consécutifs.',
  );
  b.writeln(
    '- La précision de la localisation dépend des conditions de l’appareil/du système d’exploitation/du réseau.',
  );
  b.writeln(
    '- La responsabilité pour les défaillances d’alarme, la perte de données ou les interruptions de service est limitée.',
  );
  return b.toString();
}

String _getRefundPolicyFr({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Politique de remboursement');
  b.writeln();
  b.writeln('1. Principes de remboursement');
  b.writeln(
    '- Les paiements et les remboursements sont soumis aux politiques de remboursement de Google Play.',
  );
  b.writeln(
    '- Les remboursements pour les périodes d’abonnement déjà utilisées peuvent être limités.',
  );
  b.writeln();
  b.writeln('2. Comment demander un remboursement');
  b.writeln(
    '- Demandez des remboursements via l’historique des paiements Google Play.',
  );
  b.writeln(
    '- L’éligibilité et le traitement sont soumis aux politiques de Google Play.',
  );
  b.writeln();
  b.writeln('3. Défaillances du service');
  b.writeln(
    '- En cas de défaillance majeure du service, des remboursements ou des compensations peuvent être examinés dans le cadre de la politique de Google Play.',
  );
  b.writeln();
  if (isBeta) {
    b.writeln('4. Avis concernant la version bêta');
    b.writeln(
      '- Les fonctionnalités, les politiques et les services peuvent changer pendant la bêta.',
    );
    b.writeln(
      '- La responsabilité pour les problèmes survenus pendant la bêta est limitée dans la mesure permise par la loi.',
    );
    b.writeln();
    b.writeln('5. Annulation du renouvellement automatique');
  } else {
    b.writeln('4. Annulation du renouvellement automatique');
  }
  b.writeln(
    '- Annulez le renouvellement automatique via la gestion des abonnements Google Play.',
  );
  b.writeln(
    '- Les avantages restent valables jusqu’à la prochaine date de renouvellement après l’annulation.',
  );
  return b.toString();
}

// ═══════════════════════════════════════════════════════════
//  Spanish
// ═══════════════════════════════════════════════════════════

String _getSubscriptionPolicyEs({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Política de suscripción');
  b.writeln();
  b.writeln('1. Descripción general del servicio');
  b.writeln(
    '- Este servicio ofrece funciones de alarma basadas en la ubicación. Durante el período beta solo se ofrece el plan gratuito; es posible que se introduzcan anuncios y planes de pago en el lanzamiento oficial.',
  );
  b.writeln();
  b.writeln('2. Cobertura del plan gratuito');
  b.writeln('- Registro ilimitado de lugares y alarmas.');
  if (isBeta) {
    b.writeln(
      '- Durante la beta, la búsqueda, los mapas y las activaciones de alarma están disponibles sin límites mensuales prácticos.',
    );
    b.writeln(
      '- Si el crecimiento de usuarios, los costes de las API de terceros o los riesgos para la estabilidad del servicio aumentan de forma inesperada, es posible que se introduzcan límites de uso justo durante la beta.',
    );
    b.writeln(
      '- En el lanzamiento oficial, el plan gratuito puede incluir límites mensuales para las activaciones de alarma, la búsqueda y los mapas, y es posible que se introduzcan anuncios.',
    );
    b.writeln(
      '- Pueden ofrecerse planes de pago Plus/Pro con cuotas más altas, anuncios reducidos o eliminados y acceso prioritario a ciertas funciones.',
    );
  } else {
    b.writeln('- Activaciones de alarma: 30 al mes (estándar).');
    b.writeln(
      '- Búsqueda de direcciones/lugares: 5 garantizadas al mes (límite de seguridad antiabuso de 15).',
    );
    b.writeln('- Aperturas de mapa: hasta 100 al mes (límite antiabuso).');
    b.writeln(
      '- Cuando se supera un límite garantizado, un sistema de bonificación (aceptación de un aviso o anuncios con recompensa) permite un uso adicional hasta el límite de seguridad.',
    );
    b.writeln(
      '- Una vez alcanzado el límite de seguridad, no es posible ningún uso adicional ese mes, ni siquiera con bonificaciones, para evitar abusos.',
    );
    b.writeln(
      '- Los usuarios de planes de pago pueden recibir cuotas de uso más altas, anuncios reducidos o eliminados y acceso prioritario a ciertas funciones.',
    );
    b.writeln(
      '- Pueden aplicarse descuentos a las suscripciones de renovación automática; consulta los detalles del producto en Google Play para conocer los precios exactos.',
    );
  }
  b.writeln();
  b.writeln(
    '2-1. Condiciones de prestación del servicio de mapas (Importante)',
  );
  b.writeln(
    '- Las funciones de mapas dependen de API de terceros (Naver Cloud Platform, Google Cloud Platform, etc.) y están sujetas a las políticas, precios, interrupciones y cuotas de dichos proveedores.',
  );
  b.writeln(
    '- Los recuentos mensuales de aperturas de mapa indicados tras el lanzamiento oficial son objetivos generales, no una disponibilidad garantizada.',
  );
  b.writeln(
    '- Para proteger la estabilidad del servicio frente a picos repentinos de costes de las API de terceros, abusos o problemas operativos, las funciones de mapas para usuarios gratuitos o para todos los usuarios pueden limitarse o suspenderse temporalmente sin previo aviso.',
  );
  b.writeln(
    '- Se trata de una política de uso justo y una medida de protección operativa. Los reembolsos derivados de dichas limitaciones pueden estar restringidos.',
  );
  b.writeln(
    '- Cuando se apliquen limitaciones, es posible que algunas funciones de visualización de mapas, búsqueda de direcciones o búsqueda de lugares no estén disponibles.',
  );
  b.writeln();
  b.writeln('2-2. Aviso sobre los datos de la cuenta y del dispositivo activo');
  b.writeln(
    '- Los proveedores de inicio de sesión pueden incluir Google, Kakao, Naver, LINE, Facebook y enlaces mágicos por correo electrónico según el idioma y el país.',
  );
  b.writeln(
    '- La información sobre los métodos de inicio de sesión vinculados se utiliza únicamente para permitirte acceder a la misma cuenta con varios métodos de inicio de sesión.',
  );
  b.writeln(
    '- Los lugares y las alarmas se almacenan principalmente en el dispositivo activo y pueden transferirse a la cuenta con la que has iniciado sesión desde Ajustes.',
  );
  b.writeln(
    '- La eliminación de la cuenta borra los datos de la cuenta en el servidor; los datos locales del dispositivo pueden permanecer hasta que se borren los datos de la aplicación o se desinstale la aplicación.',
  );
  b.writeln();
  b.writeln('3. Aviso sobre el servicio basado en la ubicación GPS');
  b.writeln(
    '- Este servicio utiliza datos de ubicación GPS para activar alarmas.',
  );
  b.writeln(
    '- El GPS solo puede estimar tu ubicación. Incluso en exteriores, siempre existe un margen de error de varios a decenas de metros.',
  );
  b.writeln(
    '  Por ejemplo, con un radio de 30 m, la alarma puede activarse a 25 m o solo a 35 m.',
  );
  b.writeln(
    '- En zonas subterráneas, dentro de edificios o en zonas con señal bloqueada, el error es aún mayor.',
  );
  b.writeln(
    '  El sistema puede detectar entradas/salidas de forma repetida incluso sin movimiento, lo que provoca que las alarmas se activen varias veces.',
  );
  b.writeln(
    '- Estas limitaciones del GPS (activaciones falsas y activaciones perdidas) no pueden resolverse ni garantizarse mediante esta aplicación.',
  );
  b.writeln(
    '- ⚡Activación falsa: usa el botón «⚡Activación falsa» en la pantalla de alarma para silenciarla manteniendo la alarma activa.',
  );
  b.writeln(
    '  (Función «Passing» disponible próximamente: un toque para reactivar automáticamente después de n minutos)',
  );
  b.writeln(
    '- Activación perdida: usa el botón «Informe de error» en la página de GPS para enviar registros. Corregiremos los problemas que se puedan resolver lo antes posible.',
  );
  b.writeln(
    '- Si la zona horaria, la fecha o la hora del dispositivo se cambian manualmente, o si una alarma cruza la medianoche durante la sincronización horaria del sistema, el cálculo de la fecha de las alarmas recurrentes puede cambiar y las alarmas pueden retrasarse o activarse de forma diferente a la esperada.',
  );
  b.writeln(
    '- Al aceptar estos términos, incluidos los suscriptores de pago, aceptas no responsabilizar al desarrollador de las ⚡activaciones falsas o las activaciones perdidas causadas por errores del GPS.',
  );
  b.writeln();
  b.writeln('4. Aviso sobre la detección asistida por Wi-Fi');
  b.writeln(
    '- La detección por Wi-Fi es una función complementaria opcional para mejorar la precisión de las alarmas. El registro no es obligatorio.',
  );
  b.writeln(
    '- Los datos SSID/BSSID del Wi-Fi se utilizan únicamente en el dispositivo para el reconocimiento de lugares y nunca se transmiten a servidores externos.',
  );
  b.writeln(
    '- Pueden producirse errores de detección debido a cambios en el entorno Wi-Fi (reubicación o sustitución del router, conflictos de canal, etc.).',
  );
  b.writeln(
    '  El desarrollador no se responsabiliza de las alarmas falsas o perdidas causadas por dichas condiciones.',
  );
  b.writeln('- Al aceptar estos términos, reconoces y aceptas lo anterior.');
  b.writeln();
  b.writeln(
    '4-1. Aviso sobre el estado de ejecución de la aplicación y la recuperación (Importante)',
  );
  b.writeln(
    '- Las alarmas solo funcionan mientras la aplicación (servicio en segundo plano) se ejecuta con normalidad. Ten en cuenta que las alarmas pueden no sonar en los siguientes casos.',
  );
  b.writeln(
    '- [Reinicio del dispositivo] Tras un reinicio, la supervisión de alarmas en segundo plano se suspende temporalmente. Si tienes alarmas activas, enviamos periódicamente una notificación push pidiéndote que vuelvas a abrir la aplicación. Si la ignoras y no vuelves a abrir la aplicación, es posible que las alarmas no suenen correctamente.',
  );
  b.writeln(
    '- [Forzar detención] Si fuerzas la detención de la aplicación desde los ajustes del dispositivo (o se detiene a la fuerza por cualquier motivo), el sistema operativo impide que la aplicación se recupere por sí misma o envíe notificaciones. En este caso, las alarmas solo funcionan después de que vuelvas a abrir manualmente la aplicación.',
  );
  b.writeln(
    '- [Terminación por el sistema operativo] Si el sistema operativo cierra la aplicación por falta de memoria, políticas de ahorro de batería del fabricante, etc., enviamos una notificación de recuperación después de un tiempo. Sin embargo, durante ese período —o si no te das cuenta de la terminación— es posible que las alarmas no suenen.',
  );
  b.writeln(
    '- Para un funcionamiento fiable, recomendamos permitir las excepciones de optimización de batería y los permisos de inicio automático. La responsabilidad por las alarmas perdidas causadas por lo anterior es limitada.',
  );
  b.writeln('- Al aceptar estos términos, reconoces y aceptas lo anterior.');
  b.writeln();
  b.writeln('5. Pago y renovación automática');
  b.writeln(
    '- Los pagos se procesan a través del sistema de facturación de Google Play.',
  );
  b.writeln(
    '- Las suscripciones se renuevan automáticamente según las políticas de Google Play. El ciclo de renovación y la fecha de facturación los gestiona Google Play.',
  );
  b.writeln(
    '- Las suscripciones se renuevan automáticamente a menos que se cancelen antes de la fecha de renovación.',
  );
  b.writeln(
    '- Los precios se rigen por los importes indicados en Google Play.',
  );
  b.writeln();
  b.writeln('6. Cancelación y cambios de plan');
  b.writeln(
    '- Cancela las suscripciones a través de la gestión de suscripciones de Google Play.',
  );
  b.writeln(
    '- Los beneficios se mantienen hasta la siguiente fecha de renovación tras la cancelación.',
  );
  b.writeln('- Los cambios de plan se rigen por las políticas de Google Play.');
  b.writeln();
  b.writeln('7. Anuncios');
  if (isBeta) {
    b.writeln('- No se muestran anuncios durante el período beta.');
    b.writeln(
      '- En el lanzamiento oficial, es posible que se introduzcan anuncios en el plan gratuito; los planes de pago pueden tener anuncios reducidos o eliminados.',
    );
  } else {
    b.writeln(
      '- El plan gratuito puede mostrar anuncios al usar ciertas funciones.',
    );
    b.writeln(
      '- Los planes de pago pueden tener anuncios reducidos o eliminados.',
    );
  }
  b.writeln();
  b.writeln('8. Restricciones de uso');
  b.writeln(
    '- Para proteger la estabilidad del servicio, los informes de error y los comentarios están limitados a una vez cada 30 minutos, hasta 3 veces al día.',
  );
  b.writeln(
    '- El uso anormal o excesivo puede dar lugar a restricciones del servicio.',
  );
  b.writeln();
  b.writeln('9. Cambios en el servicio');
  b.writeln(
    '- Las funciones, los precios y la estructura de los planes pueden cambiar para mejorar la calidad del servicio.',
  );
  b.writeln(
    '- Los cambios importantes se comunicarán mediante avisos dentro de la aplicación.',
  );
  b.writeln();
  if (isBeta) {
    b.writeln('10. Aviso sobre la versión beta');
    b.writeln(
      '- Esta es una versión beta. No se garantizan la estabilidad ni un servicio ininterrumpido.',
    );
    b.writeln(
      '- Las funciones pueden cambiar o suspenderse sin previo aviso durante la beta.',
    );
    b.writeln(
      '- Los datos, los ajustes de alarma y los registros pueden perderse o modificarse durante la beta.',
    );
    b.writeln(
      '- Pueden producirse problemas de rendimiento, errores de ubicación y retrasos en las alarmas.',
    );
    b.writeln(
      '- Durante la beta solo se ofrece el plan gratuito; los planes de pago pueden introducirse tras el lanzamiento oficial.',
    );
    b.writeln(
      '- Los beneficios de la beta, como límites más flexibles, pueden modificarse o finalizar en el lanzamiento oficial.',
    );
    b.writeln();
    b.writeln('11. Limitación de responsabilidad');
  } else {
    b.writeln('10. Limitación de responsabilidad');
  }
  b.writeln(
    '- En la medida permitida por la ley, no nos responsabilizamos de los daños directos/indirectos/incidentales/especiales/consecuentes.',
  );
  b.writeln(
    '- La precisión de la ubicación depende de las condiciones del dispositivo/sistema operativo/red.',
  );
  b.writeln(
    '- La responsabilidad por fallos de alarma, pérdida de datos o interrupciones del servicio es limitada.',
  );
  return b.toString();
}

String _getRefundPolicyEs({required bool isBeta}) {
  final b = StringBuffer();
  b.writeln('Política de reembolso');
  b.writeln();
  b.writeln('1. Principios de reembolso');
  b.writeln(
    '- Los pagos y reembolsos se rigen por las políticas de reembolso de Google Play.',
  );
  b.writeln(
    '- Los reembolsos por períodos de suscripción ya utilizados pueden estar limitados.',
  );
  b.writeln();
  b.writeln('2. Cómo solicitar un reembolso');
  b.writeln(
    '- Solicita reembolsos a través del historial de pagos de Google Play.',
  );
  b.writeln(
    '- La elegibilidad y el procesamiento se rigen por las políticas de Google Play.',
  );
  b.writeln();
  b.writeln('3. Fallos del servicio');
  b.writeln(
    '- En caso de fallos graves del servicio, los reembolsos o compensaciones pueden revisarse dentro de la política de Google Play.',
  );
  b.writeln();
  if (isBeta) {
    b.writeln('4. Aviso sobre la versión beta');
    b.writeln(
      '- Las funciones, las políticas y los servicios pueden cambiar durante la beta.',
    );
    b.writeln(
      '- La responsabilidad por problemas durante la beta es limitada en la medida permitida por la ley.',
    );
    b.writeln();
    b.writeln('5. Cancelación de la renovación automática');
  } else {
    b.writeln('4. Cancelación de la renovación automática');
  }
  b.writeln(
    '- Cancela la renovación automática a través de la gestión de suscripciones de Google Play.',
  );
  b.writeln(
    '- Los beneficios se mantienen hasta la siguiente fecha de renovación tras la cancelación.',
  );
  return b.toString();
}
