String getSubscriptionPolicyText({required bool isBeta, String lang = 'ko'}) {
  if (lang == 'en') return _getSubscriptionPolicyEn(isBeta: isBeta);
  if (lang == 'ja') return _getSubscriptionPolicyJa(isBeta: isBeta);
  if (lang == 'zh') return _getSubscriptionPolicyZh(isBeta: isBeta);
  return _getSubscriptionPolicyKo(isBeta: isBeta);
}

String getRefundPolicyText({required bool isBeta, String lang = 'ko'}) {
  if (lang == 'en') return _getRefundPolicyEn(isBeta: isBeta);
  if (lang == 'ja') return _getRefundPolicyJa(isBeta: isBeta);
  if (lang == 'zh') return _getRefundPolicyZh(isBeta: isBeta);
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
  buffer.writeln(
    '- 지도 기능은 외부 지도 API(네이버 클라우드 플랫폼, 구글 플랫폼, OpenStreetMap 등)를 이용하며,',
  );
  buffer.writeln('  외부 API 제공자의 정책, 요금 체계, 장애, 쿼터 등에 의존합니다.');
  buffer.writeln('- 정식 출시 후 명시되는 월 지도 로드 횟수는 일반적인 제공 목표이며 보장되지 않습니다.');
  buffer.writeln('- 외부 API 비용 급증, 이상 사용 감지, 서비스 운영 안정성 확보 등을 위해');
  buffer.writeln('  무료 이용자 혹은 전체 이용자의 지도 기능이 예고 없이 일시 제한되거나 중단될 수 있습니다.');
  buffer.writeln(
    '- 이는 공정 사용 정책(Fair Use Policy) 및 서비스 안정 운영을 위한 조치이며, 해당 사유로 인한 환불은 제한될 수 있습니다.',
  );
  buffer.writeln('- 제한이 발생한 경우에도 OpenStreetMap 기반 대체 지도는 계속 제공될 수 있습니다.');
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
    '- Map features depend on third-party APIs (Naver Cloud Platform, Google Cloud Platform, OpenStreetMap, etc.) and are subject to those providers\' policies, pricing, downtime, and quotas.',
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
    '- OpenStreetMap-based fallback maps may continue to be available even when paid map providers are limited.',
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
    '- マップ機能は外部API（ネイバークラウド、Google Cloud、OpenStreetMap等）に依存し、それらのポリシー、料金体系、サービス状況に左右されます。',
  );
  b.writeln('- 正式リリース後に明示される月間マップ表示回数は一般的な提供目標であり、保証されるものではありません。');
  b.writeln(
    '- 外部API費用の急増、不正利用、サービス運営の安定性確保のため、無料ユーザーや全ユーザーのマップ機能が予告なく一時的に制限・停止される場合があります。',
  );
  b.writeln('- これは公正利用ポリシーとサービス安定運営のための措置であり、これによる返金は制限される場合があります。');
  b.writeln('- OpenStreetMapベースの代替マップは、有料マップ提供者が制限されている間も提供される場合があります。');
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
  b.writeln(
    '- 地图功能依赖于第三方API（Naver Cloud、Google Cloud、OpenStreetMap等），受其政策、价格、可用性和配额影响。',
  );
  b.writeln('- 正式发布后标明的每月地图打开次数为一般提供目标，并非保证。');
  b.writeln('- 为应对第三方API费用突增、滥用、运营稳定性问题，免费用户或全体用户的地图功能可能被临时限制或暂停，恕不另行通知。');
  b.writeln('- 此为公平使用政策及服务稳定运营措施，由此产生的退款可能受限。');
  b.writeln('- OpenStreetMap基础的备用地图可能在付费地图受限期间仍然提供。');
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
