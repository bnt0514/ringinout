String getSubscriptionPolicyText({required bool isBeta}) {
  final buffer = StringBuffer();
  buffer.writeln('구독 정책');
  buffer.writeln();
  buffer.writeln('1. 서비스 개요');
  buffer.writeln('- 본 서비스는 위치 기반 알람 기능을 제공하며, 일부 기능은 유료 구독을 통해 이용할 수 있습니다.');
  buffer.writeln();
  buffer.writeln('2. 구독 상품 및 제공 범위');
  buffer.writeln('- Free: 장소 2개, 활성 알람 2개');
  buffer.writeln('- Basic: 장소 5개, 활성 알람 10개 (광고 제거 포함)');
  buffer.writeln('- Premium: 장소/알람 무제한 (광고 제거 포함)');
  buffer.writeln();
  buffer.writeln('3. 결제 및 자동 갱신');
  buffer.writeln('- 구독 결제는 Google Play 결제 시스템을 통해 처리됩니다.');
  buffer.writeln('- 자동 구독은 31일마다 자동 결제되며, 결제일 이전에 해지하지 않으면 자동 갱신됩니다.');
  buffer.writeln('- 결제 금액은 Google Play에 등록된 가격을 따릅니다.');
  buffer.writeln();
  buffer.writeln('4. 해지 및 플랜 변경');
  buffer.writeln('- 구독 해지는 Google Play 구독 관리에서 가능합니다.');
  buffer.writeln('- 해지 후에도 다음 갱신일까지는 구독 혜택이 유지됩니다.');
  buffer.writeln('- 플랜 변경은 Google Play 정책 및 결제 시스템 규칙에 따릅니다.');
  buffer.writeln();
  buffer.writeln('5. 광고');
  buffer.writeln('- Free 플랜은 장소 등록/알람 생성 시 광고가 노출될 수 있습니다.');
  buffer.writeln('- Basic/Premium 플랜은 광고가 제거됩니다.');
  buffer.writeln();
  buffer.writeln('6. 서비스 제공 및 변경');
  buffer.writeln('- 서비스 품질 향상 또는 정책 변경을 위해 기능/가격/플랜 구성이 변경될 수 있습니다.');
  buffer.writeln('- 중요한 변경은 앱 내 공지 또는 기타 합리적인 방법으로 안내합니다.');
  buffer.writeln();
  if (isBeta) {
    buffer.writeln('7. 베타 버전 이용 고지');
    buffer.writeln('- 본 서비스는 베타 버전이며 안정성, 완전성, 무중단 제공을 보장하지 않습니다.');
    buffer.writeln('- 베타 기간에는 예고 없이 기능이 변경, 중단되거나 서비스가 일시 중지될 수 있습니다.');
    buffer.writeln(
      '- 베타 기간 중 저장된 데이터, 알람 설정, 기록 등이 손실 또는 변경될 수 있으며 복구가 보장되지 않습니다.',
    );
    buffer.writeln('- 베타 기간에는 성능 저하, 위치 오차, 알람 누락/지연/오작동이 발생할 수 있습니다.');
    buffer.writeln('- 유료 플랜 구독은 베타 종료 후 활성화됩니다.');
    buffer.writeln();
    buffer.writeln('8. 책임의 제한');
  } else {
    buffer.writeln('7. 책임의 제한');
  }
  buffer.writeln(
    '- 법령이 허용하는 범위 내에서, 서비스 이용으로 인한 직접/간접/부수적/특별/결과적 손해에 대해 책임을 지지 않습니다.',
  );
  buffer.writeln('- 위치 정보는 기기/OS/통신 환경에 따라 오차가 발생할 수 있으며 이에 대한 책임은 제한됩니다.');
  buffer.writeln('- 알람 누락/지연/오작동, 데이터 손실, 서비스 중단으로 인해 발생한 손해에 대한 책임은 제한됩니다.');
  return buffer.toString();
}

String getRefundPolicyText({required bool isBeta}) {
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
