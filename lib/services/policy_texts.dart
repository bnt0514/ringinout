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
  buffer.writeln('- 본 서비스는 위치 기반 알람 기능을 제공하며, 일부 기능은 유료 구독을 통해 이용할 수 있습니다.');
  buffer.writeln();
  buffer.writeln('2. 구독 상품 및 제공 범위');
  buffer.writeln('- Free: 장소 2개, 등록 가능 알람 4개, 맵 오픈 월 20회');
  buffer.writeln('- Basic: 장소 5개, 등록 가능 알람 10개 (광고 제거 포함)');
  buffer.writeln('- Premium: 장소/알람 무제한 (광고 제거 포함)');
  buffer.writeln();
  buffer.writeln('3. GPS 위치 기반 서비스 안내');
  buffer.writeln('- 본 서비스는 GPS 위치 정보를 활용한 알람 서비스입니다.');
  buffer.writeln('- 지하, 건물 내부, 전파 방해 지역 등에서는 GPS 신호가 불안정할 수 있으며,');
  buffer.writeln('  이로 인해 알람이 잘못 울리거나(⚡오발동) 울리지 않을 수(미작동) 있습니다.');
  buffer.writeln('- ⚡오발동 발생 시: 전체화면 알람의 "⚡오발동" 버튼을 눌러 알람을 유지한 채 소리만 끔 수 있습니다.');
  buffer.writeln('- 미작동 발생 시: GPS 페이지의 "버그 리포트" 버튼을 눌러 로그를 전송해 주시면,');
  buffer.writeln('  수정 가능한 부분은 최대한 빠른 시일 내 수정하겠습니다.');
  buffer.writeln('- 본 약관에 동의하시면, 유료 구독자를 포함하여 GPS 오차로 인한');
  buffer.writeln('  ⚡오발동 또는 미작동에 대해 개발사에 책임을 묻지 않는 것에 동의하는 것으로 간주합니다.');
  buffer.writeln();
  buffer.writeln('4. 결제 및 자동 갱신');
  buffer.writeln('- 구독 결제는 Google Play 결제 시스템을 통해 처리됩니다.');
  buffer.writeln('- 자동 구독은 31일마다 자동 결제되며, 결제일 이전에 해지하지 않으면 자동 갱신됩니다.');
  buffer.writeln('- 결제 금액은 Google Play에 등록된 가격을 따릅니다.');
  buffer.writeln();
  buffer.writeln('5. 해지 및 플랜 변경');
  buffer.writeln('- 구독 해지는 Google Play 구독 관리에서 가능합니다.');
  buffer.writeln('- 해지 후에도 다음 갱신일까지는 구독 혜택이 유지됩니다.');
  buffer.writeln('- 플랜 변경은 Google Play 정책 및 결제 시스템 규칙에 따릅니다.');
  buffer.writeln();
  buffer.writeln('6. 광고');
  buffer.writeln('- Free 플랜은 장소 등록/알람 생성 시 광고가 노출될 수 있습니다.');
  buffer.writeln('- Basic/Premium 플랜은 광고가 제거됩니다.');
  buffer.writeln();
  buffer.writeln('7. 서비스 제공 및 변경');
  buffer.writeln('- 서비스 품질 향상 또는 정책 변경을 위해 기능/가격/플랜 구성이 변경될 수 있습니다.');
  buffer.writeln('- 중요한 변경은 앱 내 공지 또는 기타 합리적인 방법으로 안내합니다.');
  buffer.writeln();
  if (isBeta) {
    buffer.writeln('8. 베타 버전 이용 고지');
    buffer.writeln('- 본 서비스는 베타 버전이며 안정성, 완전성, 무중단 제공을 보장하지 않습니다.');
    buffer.writeln('- 베타 기간에는 예고 없이 기능이 변경, 중단되거나 서비스가 일시 중지될 수 있습니다.');
    buffer.writeln(
      '- 베타 기간 중 저장된 데이터, 알람 설정, 기록 등이 손실 또는 변경될 수 있으며 복구가 보장되지 않습니다.',
    );
    buffer.writeln('- 베타 기간에는 성능 저하, 위치 오차, 알람 누락/지연/오작동이 발생할 수 있습니다.');
    buffer.writeln('- 유료 플랜 구독은 베타 종료 후 활성화됩니다.');
    buffer.writeln();
    buffer.writeln('9. 책임의 제한');
  } else {
    buffer.writeln('8. 책임의 제한');
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
    '- This service provides location-based alarm features. Some features require a paid subscription.',
  );
  b.writeln();
  b.writeln('2. Plans & Coverage');
  b.writeln('- Free: 2 places, 4 registered alarms, 20 map opens/month');
  b.writeln('- Basic: 5 places, 10 registered alarms (ad-free)');
  b.writeln('- Premium: Unlimited places/alarms (ad-free)');
  b.writeln();
  b.writeln('3. GPS Location-Based Service Notice');
  b.writeln('- This service uses GPS location data to trigger alarms.');
  b.writeln(
    '- GPS signals may be unstable in underground areas, inside buildings, or in areas with signal interference.',
  );
  b.writeln(
    '  This may cause alarms to trigger incorrectly (⚡False Trigger) or fail to trigger (Missed Trigger).',
  );
  b.writeln(
    '- ⚡False Trigger: Use the "⚡False Trigger" button on the alarm screen to silence the alarm while keeping it active.',
  );
  b.writeln(
    '- Missed Trigger: Use the "Bug Report" button on the GPS page to send logs. We will fix resolvable issues as quickly as possible.',
  );
  b.writeln(
    '- By agreeing to these terms, including paid subscribers, you agree not to hold the developer liable for ⚡False Triggers or Missed Triggers caused by GPS errors.',
  );
  b.writeln();
  b.writeln('4. Payment & Auto-Renewal');
  b.writeln('- Payments are processed through Google Play billing.');
  b.writeln(
    '- Subscriptions auto-renew every 31 days unless cancelled before the renewal date.',
  );
  b.writeln('- Pricing follows the amounts listed on Google Play.');
  b.writeln();
  b.writeln('5. Cancellation & Plan Changes');
  b.writeln('- Cancel subscriptions via Google Play subscription management.');
  b.writeln(
    '- Benefits remain until the next renewal date after cancellation.',
  );
  b.writeln('- Plan changes follow Google Play policies.');
  b.writeln();
  b.writeln('6. Ads');
  b.writeln('- Free plan may show ads when adding places/alarms.');
  b.writeln('- Basic/Premium plans are ad-free.');
  b.writeln();
  b.writeln('7. Service Changes');
  b.writeln(
    '- Features, pricing, and plan structure may change to improve service quality.',
  );
  b.writeln('- Important changes will be communicated through in-app notices.');
  b.writeln();
  if (isBeta) {
    b.writeln('8. Beta Notice');
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
    b.writeln('- Paid subscriptions will be activated after beta ends.');
    b.writeln();
    b.writeln('9. Limitation of Liability');
  } else {
    b.writeln('8. Limitation of Liability');
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
  b.writeln('- 本サービスは位置ベースのアラーム機能を提供し、一部の機能は有料サブスクリプションが必要です。');
  b.writeln();
  b.writeln('2. プランと提供範囲');
  b.writeln('- Free: 場所2個、登録可能アラーム4個、マップ表示月 20回');
  b.writeln('- Basic: 場所5個、アラーム10個（広告なし）');
  b.writeln('- Premium: 場所/アラーム無制限（広告なし）');
  b.writeln();
  b.writeln('3. GPS位置情報サービスのご案内');
  b.writeln('- 本サービスはGPS位置情報を利用したアラームサービスです。');
  b.writeln('- 地下、建物内、電波妨害地域等ではGPS信号が不安定になる場合があり、');
  b.writeln('  アラームが誤作動(⚡誤発動)したり、未作動する場合があります。');
  b.writeln(
    '- 本規約に同意することで、有料ユーザーを含むGPS誤差による⚡誤発動または未作動について開発者に責任を問わないことに同意するものとします。',
  );
  b.writeln();
  b.writeln('4. 決済と自動更新');
  b.writeln('- 決済はGoogle Play決済システムを通じて処理されます。');
  b.writeln('- サブスクリプションは31日ごとに自動更新されます。');
  b.writeln();
  b.writeln('5. 解約とプラン変更');
  b.writeln('- 解約はGoogle Playサブスクリプション管理から可能です。');
  b.writeln('- 解約後も次の更新日まで特典が維持されます。');
  b.writeln();
  b.writeln('6. 広告');
  b.writeln('- Freeプランでは場所登録/アラーム作成時に広告が表示される場合があります。');
  b.writeln('- Basic/Premiumプランは広告なしです。');
  b.writeln();
  b.writeln('7. サービス変更');
  b.writeln('- 機能、価格、プラン構成は品質向上のために変更される場合があります。');
  b.writeln();
  if (isBeta) {
    b.writeln('8. ベータ版のご注意');
    b.writeln('- 本サービスはベータ版であり、安定性や無中断提供は保証されません。');
    b.writeln('- ベータ期間中は機能の変更・中断が予告なく行われる場合があります。');
    b.writeln('- データの損失や変更が発生する可能性があります。');
    b.writeln('- 有料プランはベータ終了後に活性化されます。');
    b.writeln();
    b.writeln('9. 責任の制限');
  } else {
    b.writeln('8. 責任の制限');
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
  b.writeln('- 本服务提供基于位置的闹钟功能，部分功能需要付费订阅。');
  b.writeln();
  b.writeln('2. 方案与范围');
  b.writeln('- Free: 2个地点，4个闹钟，每月 20 次地图打开');
  b.writeln('- Basic: 5个地点，10个闹钟（无广告）');
  b.writeln('- Premium: 无限地点/闹钟（无广告）');
  b.writeln();
  b.writeln('3. GPS位置服务说明');
  b.writeln('- 本服务利用GPS位置信息提供闹钟服务。');
  b.writeln('- 在地下、建筑物内、信号干扰区域等，GPS信号可能不稳定，');
  b.writeln('  可能导致闹钟误触发(⚡误触发)或未触发。');
  b.writeln('- 同意本条款即表示，包括付费用户在内，均同意不就GPS误差引起的⚡误触发或未触发向开发者追究责任。');
  b.writeln();
  b.writeln('4. 支付与自动续费');
  b.writeln('- 支付通过Google Play计费系统处理。');
  b.writeln('- 订阅每31天自动续费。');
  b.writeln();
  b.writeln('5. 取消与方案变更');
  b.writeln('- 可通过Google Play订阅管理取消。');
  b.writeln('- 取消后，权益保留至下一续费日。');
  b.writeln();
  b.writeln('6. 广告');
  b.writeln('- Free方案可能在添加地点/闹钟时显示广告。');
  b.writeln('- Basic/Premium方案无广告。');
  b.writeln();
  b.writeln('7. 服务变更');
  b.writeln('- 功能、价格和方案结构可能会变更以改善服务质量。');
  b.writeln();
  if (isBeta) {
    b.writeln('8. 测试版须知');
    b.writeln('- 本服务为测试版，不保证稳定性和不间断服务。');
    b.writeln('- 测试期间功能可能会无预告变更或中断。');
    b.writeln('- 数据可能会丢失或变更。');
    b.writeln('- 付费方案将在测试结束后开放。');
    b.writeln();
    b.writeln('9. 责任限制');
  } else {
    b.writeln('8. 责任限制');
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
