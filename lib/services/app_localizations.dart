import 'package:flutter/material.dart';

/// 앱 전체 다국어 지원 클래스
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en', 'US'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// 번역 데이터
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // 공통
      'app_name': 'Ringinout',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'close': 'Close',
      'send': 'Send',
      'confirm': 'Confirm',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',

      // 메인 네비게이션
      'nav_alarm': 'Alarm',
      'nav_my_places': 'My Places',

      // 알람 페이지
      'alarm_title': 'Ringinout Alarm',
      'location_alarm': 'Location Alarm',
      'basic_alarm': 'Basic Alarm',
      'basic_alarm_page': 'Basic Alarm Page',
      'sort_options': 'Sort Options',
      'sort_by_time': 'By Alarm Time',
      'sort_custom': 'Custom Order',
      'no_alarms': 'No alarms yet',
      'add_alarm_hint': 'Add a location alarm!',

      // 장소 관리
      'my_places': 'My Places',
      'add_place': 'Add Place',
      'edit_place': 'Edit Place',
      'place_name': 'Place Name',
      'place_saved': '✅ Place saved',
      'place_updated': '✅ Place updated',
      'place_deleted': '🗑 Place deleted',
      'no_places': 'No saved places',
      'add_place_hint': 'Add your favorite places!',
      'search_address': 'Search address',
      'current_location': 'Current location',
      'radius': 'Radius',
      'custom': 'Custom',
      'custom_radius': 'Custom Radius',
      'confirm': 'Confirm',

      // 알람 추가/편집
      'add_location_alarm': 'Add Location Alarm',
      'edit_location_alarm': 'Edit Location Alarm',
      'alarm_name': 'Alarm Name',
      'select_place': 'Select Place',
      'alarm_sound': 'Alarm Sound',
      'vibration': 'Vibration',
      'snooze': 'Snooze',
      'alarm_enabled': 'Alarm Enabled',
      'entry_exit': 'Entry/Exit',
      'on_entry': 'On Entry',
      'on_exit': 'On Exit',
      'both': 'Both',
      'alarm_saved': '✅ Alarm saved',
      'alarm_deleted': '🗑 Alarm deleted',

      // 설정 페이지
      'settings': 'Settings',
      'language': 'Language',
      'language_select': 'Select Language',
      'system_default': 'System Default',
      'account': 'Account',
      'logged_in': 'Logged in',
      'logout': 'Logout',
      'logout_confirm':
          'Are you sure you want to log out? You will be redirected to the login screen.',
      'google_login': 'Google Sign In',
      'login_success': '✅ Login successful',
      'login_failed': '❌ Login failed',
      'logged_out': 'Logged out',
      'feedback': 'Send Feedback',
      'feedback_title': 'Send Feedback',
      'feedback_hint': 'Enter your feedback or suggestions',
      'feedback_sent': '✅ Feedback sent. Thank you!',
      'app_info': 'App Info',

      // 로그인 페이지
      'login_app_description':
          'Location-based alarm app.\nGet notified when you arrive or leave a place!',
      'login_data_security_title': 'Data Security Promise',
      'login_data_security_content':
          'Only your encrypted account identifier and payment status are stored on our servers. Location and personal information are processed only on your device.',
      'login_data_deletion_warning':
          'All saved places and alarm settings will be deleted when you uninstall the app.',
      'login_continue_with_google': 'Continue with Google',
      'login_cancelled': 'Login cancelled',
      'login_not_supported': 'Google login is not supported on this device',
      'version': 'Version',
      'location_based_alarm': 'Location-based alarm app',
      'privacy_policy': 'Privacy Policy',

      // Privacy Policy
      'privacy_policy_title': 'Privacy Policy',
      'privacy_last_updated': 'Last updated: January 2026',
      'privacy_section_1_title': '1. Information We Collect',
      'privacy_section_1_content':
          'Ringinout does not collect personal information.\n\n'
          '• Location data: Processed only on your device for alarm functionality. Not sent to external servers.\n\n'
          '• Account info: When signing in with Google, your email is converted to an anonymized random ID. Original email is not stored.',
      'privacy_section_2_title': '2. Purpose of Anonymized ID',
      'privacy_section_2_content':
          'The anonymized ID is used solely to verify premium subscription status. '
          'This ID cannot be used to identify or track individuals.',
      'privacy_section_3_title': '3. Data Storage',
      'privacy_section_3_content':
          'All alarm and location data is stored only on your device '
          'and is not transmitted to external servers.',
      'privacy_section_4_title': '4. Third-Party Sharing',
      'privacy_section_4_content':
          'Ringinout does not share any user information with third parties.',
      'privacy_section_5_title': '5. Contact',
      'privacy_section_5_content':
          'For privacy-related inquiries, please use the \'Send Feedback\' feature in the app.',

      // 권한
      'permission_required': 'Permission Required',
      'location_permission': 'Location Permission',
      'notification_permission': 'Notification Permission',
      'background_permission': 'Background Location Permission',
      'background_location_desc':
          'Detects your location even when the app is not in use.',
      'overlay_permission': 'Display Over Other Apps',
      'overlay_permission_desc': 'Required to display full-screen alarms.',
      'grant_permission': 'Grant Permission',
      'allow': 'Allow',
      'permission_settings': 'Permission Settings',
      'setup_complete': 'Setup Complete! 🎉',
      'grant_all_permissions': 'Please grant all permissions',
      'setup_later': 'Setup Later',
      'location_permission_desc': 'Required to detect alarm locations.',
      'battery_opt_warning_title': 'Battery Optimization Not Excluded',
      'battery_opt_warning_desc':
          'This notice appears because battery optimization exclusion is currently disabled. '
          'The app can still work, but alarms may be delayed or missed on some devices. '
          'We recommend excluding this app from battery optimization.',

      // GPS 페이지
      'gps_title': 'GPS',
      'geofence_service_status': 'Geofence Service Status',
      'status_running': '✅ Running',
      'status_stopped': '❌ Stopped',
      'status': 'Status',
      'last_event': 'Last Event',
      'last_event_none': 'None',
      'settings_interval':
          'Settings: {interval}s interval, {accuracy}m accuracy',
      'geofence_status_debug': 'Geofence Status (Debug)',
      'no_saved_places': 'No saved places',
      'distance': 'Distance',
      'radius_label': 'Radius',
      'current_location': 'Current Location',
      'no_location_info': 'No location info',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'updated': 'Updated',
      'active_alarm_distance': 'Active Alarm Distances',
      'no_active_alarms': 'No active alarms or no location info',
      'alarm': 'Alarm',
      'place_unknown': 'Unknown Place',
      'cannot_calculate_distance': 'Cannot calculate distance',
      'location_permission_required': 'Location permission is required.',
      'inside': 'Inside',
      'outside': 'Outside',

      // 요일
      'sun': 'Sun',
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'every_week': 'Every {days}',
      'first_entry_after_set': 'First entry after alarm set',
      'first_exit_after_set': 'First exit after alarm set',
      'no_selection': 'No selection',

      // 공휴일 설정
      'holiday_settings': 'Holiday Settings',
      'turn_off_on_holidays': 'Turn off on substitute/temporary holidays',
      'turn_on_on_holidays': 'Turn on on substitute/temporary holidays',

      // 위치 알람 추가
      'add_new_location_alarm': 'Add New Location Alarm',
      'done': 'Done',
      'alarm_name': 'Alarm Name',
      'no_name': 'No name',
      'select_place': 'Select Place',
      'alarm_on_entry': 'Alarm on Entry',
      'alarm_on_exit': 'Alarm on Exit',

      // 음성 인식
      'voice_input': 'Voice Input',
      'voice_listening': 'Listening...',
      'voice_not_recognized': 'Voice not recognized',
      'tap_to_speak': 'Tap to speak',
      'select_location_on_map': 'Select location on map',

      // 알람 화면
      'dismiss': 'Dismiss',
      'snooze_minutes': 'Snooze {minutes} min',
      'alarm_ringing': 'Alarm Ringing!',
    },

    'ko': {
      // 공통
      'app_name': 'Ringinout',
      'save': '저장',
      'cancel': '취소',
      'delete': '삭제',
      'close': '닫기',
      'send': '보내기',
      'confirm': '확인',
      'ok': '확인',
      'yes': '예',
      'no': '아니오',
      'error': '오류',
      'success': '성공',
      'loading': '로딩 중...',

      // 메인 네비게이션
      'nav_alarm': '알람',
      'nav_my_places': '내 장소',

      // 알람 페이지
      'alarm_title': 'Ringinout 알람',
      'location_alarm': '위치알람',
      'basic_alarm': '기본알람',
      'basic_alarm_page': '기본알람 페이지',
      'sort_options': '정렬 방식 선택',
      'sort_by_time': '알람 시간 순서',
      'sort_custom': '사용자 지정 순서',
      'no_alarms': '등록된 알람이 없습니다',
      'add_alarm_hint': '위치 알람을 추가해보세요!',

      // 장소 관리
      'my_places': '내 장소',
      'add_place': '장소 추가',
      'edit_place': '장소 편집',
      'place_name': '장소 이름',
      'place_saved': '✅ 장소가 저장되었습니다',
      'place_updated': '✅ 장소가 수정되었습니다',
      'place_deleted': '🗑 장소가 삭제되었습니다',
      'no_places': '저장된 장소가 없습니다',
      'add_place_hint': '자주 가는 장소를 추가해보세요!',
      'search_address': '주소 검색',
      'current_location': '현재 위치',
      'radius': '반경',
      'custom': '직접입력',
      'custom_radius': '반경 직접 입력',
      'confirm': '확인',

      // 알람 추가/편집
      'add_location_alarm': '위치 알람 추가',
      'edit_location_alarm': '위치 알람 편집',
      'alarm_name': '알람 이름',
      'select_place': '장소 선택',
      'alarm_sound': '알람 소리',
      'vibration': '진동',
      'snooze': '다시 알림',
      'alarm_enabled': '알람 활성화',
      'entry_exit': '진입/이탈',
      'on_entry': '진입 시',
      'on_exit': '이탈 시',
      'both': '모두',
      'alarm_saved': '✅ 알람이 저장되었습니다',
      'alarm_deleted': '🗑 알람이 삭제되었습니다',

      // 설정 페이지
      'settings': '설정',
      'language': '언어',
      'language_select': '언어 선택',
      'system_default': '시스템 기본',
      'account': '계정',
      'logged_in': '로그인됨',
      'logout': '로그아웃',
      'logout_confirm': '로그아웃 하시겠습니까? 로그인 화면으로 이동합니다.',
      'google_login': 'Google 로그인',
      'login_success': '✅ 로그인 성공',
      'login_failed': '❌ 로그인 실패',
      'logged_out': '로그아웃 되었습니다',
      'feedback': '건의사항 보내기',
      'feedback_title': '건의사항 보내기',
      'feedback_hint': '건의사항이나 피드백을 입력해주세요',
      'feedback_sent': '✅ 건의사항이 전송되었습니다. 감사합니다!',
      'app_info': '앱 정보',
      'version': '버전',
      'location_based_alarm': '위치 기반 알람 앱',

      // 로그인 페이지
      'login_app_description': '위치 기반 알람 앱\n특정 장소에 도착하거나 떠날 때 알림을 받으세요!',
      'login_data_security_title': '데이터 보안 약속',
      'login_data_security_content':
          '암호화된 계정 식별자와 결제 상태만 서버에 저장됩니다. 위치 및 개인정보는 기기에서만 처리됩니다.',
      'login_data_deletion_warning': '앱 삭제 시 저장된 장소와 알람 설정이 모두 삭제됩니다.',
      'login_continue_with_google': 'Google로 계속하기',
      'login_cancelled': '로그인이 취소되었습니다',
      'login_not_supported': '이 기기에서는 Google 로그인을 지원하지 않습니다',
      'privacy_policy': '개인정보 처리방침',

      // Privacy Policy
      'privacy_policy_title': '개인정보 처리방침',
      'privacy_last_updated': '최종 업데이트: 2026년 1월',
      'privacy_section_1_title': '1. 수집하는 정보',
      'privacy_section_1_content':
          'Ringinout은 사용자의 개인정보를 수집하지 않습니다.\n\n'
          '• 위치 정보: 알람 기능을 위해 기기 내에서만 처리되며, 외부 서버로 전송되지 않습니다.\n\n'
          '• 계정 정보: Google 로그인 시 이메일 주소는 익명화된 랜덤 ID로 변환되어 저장됩니다. 원본 이메일은 저장되지 않습니다.',
      'privacy_section_2_title': '2. 익명화된 ID 사용 목적',
      'privacy_section_2_content':
          '익명화된 ID는 오직 유료 구독 상태 확인 목적으로만 사용됩니다. '
          '이 ID를 통해 개인을 식별하거나 추적할 수 없습니다.',
      'privacy_section_3_title': '3. 데이터 저장',
      'privacy_section_3_content':
          '모든 알람 데이터와 장소 정보는 사용자의 기기 내에만 저장되며, '
          '외부 서버로 전송되지 않습니다.',
      'privacy_section_4_title': '4. 제3자 공유',
      'privacy_section_4_content': 'Ringinout은 어떠한 사용자 정보도 제3자와 공유하지 않습니다.',
      'privacy_section_5_title': '5. 문의',
      'privacy_section_5_content':
          '개인정보 관련 문의사항이 있으시면 앱 내 \'건의사항 보내기\' 기능을 이용해주세요.',

      // 권한
      'permission_required': '권한 필요',
      'location_permission': '위치 권한',
      'notification_permission': '알림 권한',
      'background_permission': '백그라운드 위치 권한',
      'background_location_desc': '앱을 사용하지 않을 때도 위치를 감지합니다.',
      'overlay_permission': '다른 앱 위에 표시',
      'overlay_permission_desc': '전체화면 알람을 표시하기 위해 필요합니다.',
      'grant_permission': '권한 허용',
      'allow': '허용',
      'permission_settings': '권한 설정',
      'setup_complete': '설정 완료! 🎉',
      'grant_all_permissions': '모든 권한을 허용해주세요',
      'setup_later': '나중에 설정하기',
      'location_permission_desc': '알람을 울릴 위치를 감지하기 위해 필요합니다.',
      'battery_opt_warning_title': '배터리 최적화 제외 필요',
      'battery_opt_warning_desc':
          '현재 배터리 최적화 제외가 설정되어 있지 않아 안내를 띄웁니다. '
          '앱은 사용 가능하지만 일부 기기에서 알람이 지연되거나 누락될 수 있어, '
          '배터리 최적화 제외를 권장합니다.',

      // GPS 페이지
      'gps_title': 'GPS',
      'geofence_service_status': '지오펜스 서비스 상태',
      'status_running': '✅ 실행 중',
      'status_stopped': '❌ 중지됨',
      'status': '상태',
      'last_event': '마지막 이벤트',
      'last_event_none': '없음',
      'settings_interval': '설정: {interval}초 간격, {accuracy}m 정확도',
      'geofence_status_debug': '지오펜스 상태 (디버그)',
      'no_saved_places': '저장된 장소가 없습니다.',
      'distance': '거리',
      'radius_label': '반경',
      'current_location': '현재 위치',
      'no_location_info': '위치 정보 없음',
      'latitude': '위도',
      'longitude': '경도',
      'updated': '업데이트',
      'active_alarm_distance': '활성화된 알람 거리',
      'no_active_alarms': '활성화된 알람이 없거나 위치 정보가 없습니다.',
      'alarm': '알람',
      'place_unknown': '장소 미확인',
      'cannot_calculate_distance': '거리 정보를 계산할 수 없습니다.',
      'location_permission_required': '위치 권한이 필요합니다.',
      'inside': '내부',
      'outside': '외부',

      // 요일
      'sun': '일',
      'mon': '월',
      'tue': '화',
      'wed': '수',
      'thu': '목',
      'fri': '금',
      'sat': '토',
      'every_week': '매주 {days}',
      'first_entry_after_set': '알람 설정 후 최초 진입 시',
      'first_exit_after_set': '알람 설정 후 최초 진출 시',
      'no_selection': '선택 없음',

      // 공휴일 설정
      'holiday_settings': '대체/임시 공휴일 설정',
      'turn_off_on_holidays': '대체 및 임시 공휴일에도 끄기',
      'turn_on_on_holidays': '대체 및 임시 공휴일에는 켜기',

      // 위치 알람 추가
      'add_new_location_alarm': '새 위치알람 추가',
      'done': '완료',
      'alarm_name': '알람 이름',
      'no_name': '이름 없음',
      'select_place': '장소 선택',
      'alarm_on_entry': '진입 시 알람',
      'alarm_on_exit': '진출 시 알람',

      // 음성 인식
      'voice_input': '음성 입력',
      'voice_listening': '듣고 있습니다...',
      'voice_not_recognized': '음성을 인식하지 못했습니다',
      'tap_to_speak': '말하려면 탭하세요',
      'select_location_on_map': '지도에서 위치를 선택하세요',

      // 알람 화면
      'dismiss': '해제',
      'snooze_minutes': '{minutes}분 후 다시 알림',
      'alarm_ringing': '알람이 울립니다!',
    },

    'ja': {
      // 공통
      'app_name': 'Ringinout',
      'save': '保存',
      'cancel': 'キャンセル',
      'delete': '削除',
      'close': '閉じる',
      'send': '送信',
      'confirm': '確認',
      'ok': 'OK',
      'yes': 'はい',
      'no': 'いいえ',
      'error': 'エラー',
      'success': '成功',
      'loading': '読み込み中...',

      // 메인 네비게이션
      'nav_alarm': 'アラーム',
      'nav_my_places': 'マイプレイス',

      // 알람 페이지
      'alarm_title': 'Ringinout アラーム',
      'location_alarm': '位置アラーム',
      'basic_alarm': '基本アラーム',
      'basic_alarm_page': '基本アラームページ',
      'sort_options': '並べ替え',
      'sort_by_time': 'アラーム時間順',
      'sort_custom': 'カスタム順',
      'no_alarms': 'アラームがありません',
      'add_alarm_hint': '位置アラームを追加しましょう！',

      // 장소 관리
      'my_places': 'マイプレイス',
      'add_place': '場所を追加',
      'edit_place': '場所を編集',
      'place_name': '場所の名前',
      'place_saved': '✅ 場所を保存しました',
      'place_updated': '✅ 場所を更新しました',
      'place_deleted': '🗑 場所を削除しました',
      'no_places': '保存された場所がありません',
      'add_place_hint': 'お気に入りの場所を追加しましょう！',
      'search_address': '住所検索',
      'current_location': '現在地',
      'radius': '半径',
      'custom': 'カスタム',
      'custom_radius': '半径を入力',
      'confirm': '確認',

      // 알람 추가/편집
      'add_location_alarm': '位置アラームを追加',
      'edit_location_alarm': '位置アラームを編集',
      'alarm_name': 'アラーム名',
      'select_place': '場所を選択',
      'alarm_sound': 'アラーム音',
      'vibration': 'バイブレーション',
      'snooze': 'スヌーズ',
      'alarm_enabled': 'アラーム有効',
      'entry_exit': '入場/退場',
      'on_entry': '入場時',
      'on_exit': '退場時',
      'both': '両方',
      'alarm_saved': '✅ アラームを保存しました',
      'alarm_deleted': '🗑 アラームを削除しました',

      // 설정 페이지
      'settings': '設定',
      'language': '言語',
      'language_select': '言語を選択',
      'system_default': 'システムデフォルト',
      'account': 'アカウント',
      'logged_in': 'ログイン済み',
      'logout': 'ログアウト',
      'logout_confirm': 'ログアウトしますか？ログイン画面に移動します。',
      'google_login': 'Googleログイン',
      'login_success': '✅ ログイン成功',
      'login_failed': '❌ ログイン失敗',
      'logged_out': 'ログアウトしました',
      'feedback': 'フィードバックを送信',
      'feedback_title': 'フィードバックを送信',
      'feedback_hint': 'ご意見やフィードバックを入力してください',
      'feedback_sent': '✅ フィードバックを送信しました。ありがとうございます！',
      'app_info': 'アプリ情報',
      'version': 'バージョン',
      'location_based_alarm': '位置ベースのアラームアプリ',
      'privacy_policy': 'プライバシーポリシー',

      // 로그인 페이지
      'login_app_description': '位置ベースのアラームアプリ\n特定の場所に到着または出発する時に通知を受け取れます！',
      'login_data_security_title': 'データセキュリティの約束',
      'login_data_security_content':
          '暗号化されたアカウント識別子と支払い状態のみがサーバーに保存されます。位置情報と個人情報はデバイス内でのみ処理されます。',
      'login_data_deletion_warning': 'アプリを削除すると、保存された場所とアラーム設定がすべて削除されます。',
      'login_continue_with_google': 'Googleで続行',
      'login_cancelled': 'ログインがキャンセルされました',
      'login_not_supported': 'このデバイスではGoogleログインがサポートされていません',

      // Privacy Policy
      'privacy_policy_title': 'プライバシーポリシー',
      'privacy_last_updated': '最終更新: 2026年1月',
      'privacy_section_1_title': '1. 収集する情報',
      'privacy_section_1_content':
          'Ringinoutはユーザーの個人情報を収集しません。\n\n'
          '• 位置情報: アラーム機能のためデバイス内でのみ処理され、外部サーバーには送信されません。\n\n'
          '• アカウント情報: Googleログイン時、メールアドレスは匿名化されたランダムIDに変換されて保存されます。元のメールは保存されません。',
      'privacy_section_2_title': '2. 匿名化IDの使用目的',
      'privacy_section_2_content':
          '匿名化されたIDは、プレミアムサブスクリプションの確認目的でのみ使用されます。'
          'このIDで個人を特定または追跡することはできません。',
      'privacy_section_3_title': '3. データ保存',
      'privacy_section_3_content':
          'すべてのアラームと場所データはデバイス内にのみ保存され、'
          '外部サーバーには送信されません。',
      'privacy_section_4_title': '4. 第三者への共有',
      'privacy_section_4_content': 'Ringinoutはユーザー情報を第三者と共有しません。',
      'privacy_section_5_title': '5. お問い合わせ',
      'privacy_section_5_content':
          'プライバシーに関するお問い合わせは、アプリ内の「フィードバックを送信」機能をご利用ください。',

      // 권한
      'permission_required': '権限が必要です',
      'location_permission': '位置権限',
      'notification_permission': '通知権限',
      'background_permission': 'バックグラウンド位置権限',
      'background_location_desc': 'アプリを使用していないときも位置を検出します。',
      'overlay_permission': '他のアプリの上に表示',
      'overlay_permission_desc': 'フルスクリーンアラームを表示するために必要です。',
      'grant_permission': '権限を許可',
      'allow': '許可',
      'permission_settings': '権限設定',
      'setup_complete': '設定完了！🎉',
      'grant_all_permissions': 'すべての権限を許可してください',
      'setup_later': '後で設定',
      'location_permission_desc': 'アラームの位置を検出するために必要です。',
      'battery_opt_warning_title': 'バッテリー最適化が除外されていません',
      'battery_opt_warning_desc':
          '現在バッテリー最適化の除外が無効のため、この案内を表示しています。 '
          'アプリは動作しますが、一部の端末ではアラームが遅延または見逃される可能性があります。 '
          'バッテリー最適化から除外することを推奨します。',

      // GPS 페이지
      'gps_title': 'GPS',
      'geofence_service_status': 'ジオフェンスサービス状態',
      'status_running': '✅ 実行中',
      'status_stopped': '❌ 停止',
      'status': '状態',
      'last_event': '最後のイベント',
      'last_event_none': 'なし',
      'settings_interval': '設定: {interval}秒間隔、{accuracy}m精度',
      'geofence_status_debug': 'ジオフェンス状態（デバッグ）',
      'no_saved_places': '保存された場所がありません。',
      'distance': '距離',
      'radius_label': '半径',
      'current_location': '現在地',
      'no_location_info': '位置情報なし',
      'latitude': '緯度',
      'longitude': '経度',
      'updated': '更新',
      'active_alarm_distance': 'アクティブなアラーム距離',
      'no_active_alarms': 'アクティブなアラームがないか、位置情報がありません。',
      'alarm': 'アラーム',
      'place_unknown': '不明な場所',
      'cannot_calculate_distance': '距離を計算できません。',
      'location_permission_required': '位置権限が必要です。',
      'inside': '内部',
      'outside': '外部',

      // 요일
      'sun': '日',
      'mon': '月',
      'tue': '火',
      'wed': '水',
      'thu': '木',
      'fri': '金',
      'sat': '土',
      'every_week': '毎週 {days}',
      'first_entry_after_set': 'アラーム設定後の最初の入場時',
      'first_exit_after_set': 'アラーム設定後の最初の退場時',
      'no_selection': '選択なし',

      // 공휴일 설정
      'holiday_settings': '祝日設定',
      'turn_off_on_holidays': '代替/臨時祝日にはオフ',
      'turn_on_on_holidays': '代替/臨時祝日にはオン',

      // 위치 알람 추가
      'add_new_location_alarm': '新しい位置アラームを追加',
      'done': '完了',
      'alarm_name': 'アラーム名',
      'no_name': '名前なし',
      'select_place': '場所を選択',
      'alarm_on_entry': '入場時アラーム',
      'alarm_on_exit': '退場時アラーム',

      // 음성 인식
      'voice_input': '音声入力',
      'voice_listening': '聞いています...',
      'voice_not_recognized': '音声を認識できませんでした',
      'tap_to_speak': 'タップして話す',
      'select_location_on_map': '地図で場所を選択',

      // 알람 화면
      'dismiss': '解除',
      'snooze_minutes': '{minutes}分後に再通知',
      'alarm_ringing': 'アラームが鳴っています！',
    },

    'zh': {
      // 공통
      'app_name': 'Ringinout',
      'save': '保存',
      'cancel': '取消',
      'delete': '删除',
      'close': '关闭',
      'send': '发送',
      'confirm': '确认',
      'ok': '确定',
      'yes': '是',
      'no': '否',
      'error': '错误',
      'success': '成功',
      'loading': '加载中...',

      // 메인 네비게이션
      'nav_alarm': '闹钟',
      'nav_my_places': '我的位置',

      // 알람 페이지
      'alarm_title': 'Ringinout 闹钟',
      'location_alarm': '位置闹钟',
      'basic_alarm': '基本闹钟',
      'basic_alarm_page': '基本闹钟页面',
      'sort_options': '排序方式',
      'sort_by_time': '按时间排序',
      'sort_custom': '自定义顺序',
      'no_alarms': '暂无闹钟',
      'add_alarm_hint': '添加一个位置闹钟吧！',

      // 장소 관리
      'my_places': '我的位置',
      'add_place': '添加位置',
      'edit_place': '编辑位置',
      'place_name': '位置名称',
      'place_saved': '✅ 位置已保存',
      'place_updated': '✅ 位置已更新',
      'place_deleted': '🗑 位置已删除',
      'no_places': '暂无保存的位置',
      'add_place_hint': '添加您常去的位置吧！',
      'search_address': '搜索地址',
      'current_location': '当前位置',
      'radius': '半径',
      'custom': '自定义',
      'custom_radius': '自定义半径',
      'confirm': '确认',

      // 알람 추가/편집
      'add_location_alarm': '添加位置闹钟',
      'edit_location_alarm': '编辑位置闹钟',
      'alarm_name': '闹钟名称',
      'select_place': '选择位置',
      'alarm_sound': '闹钟铃声',
      'vibration': '振动',
      'snooze': '稍后提醒',
      'alarm_enabled': '启用闹钟',
      'entry_exit': '进入/离开',
      'on_entry': '进入时',
      'on_exit': '离开时',
      'both': '两者',
      'alarm_saved': '✅ 闹钟已保存',
      'alarm_deleted': '🗑 闹钟已删除',

      // 설정 페이지
      'settings': '设置',
      'language': '语言',
      'language_select': '选择语言',
      'system_default': '系统默认',
      'account': '账户',
      'logged_in': '已登录',
      'logout': '退出登录',
      'logout_confirm': '确定要退出登录吗？将返回登录页面。',
      'google_login': 'Google 登录',
      'login_success': '✅ 登录成功',
      'login_failed': '❌ 登录失败',
      'logged_out': '已退出登录',
      'feedback': '发送反馈',
      'feedback_title': '发送反馈',
      'feedback_hint': '请输入您的意见或建议',
      'feedback_sent': '✅ 反馈已发送，谢谢！',
      'app_info': '应用信息',
      'version': '版本',
      'location_based_alarm': '基于位置的闹钟应用',
      'privacy_policy': '隐私政策',

      // 로그인 페이지
      'login_app_description': '基于位置的闹钟应用\n到达或离开特定地点时获得通知！',
      'login_data_security_title': '数据安全承诺',
      'login_data_security_content': '只有加密的账户标识符和支付状态存储在服务器上。位置和个人信息仅在您的设备上处理。',
      'login_data_deletion_warning': '删除应用时，所有保存的地点和闹钟设置都将被删除。',
      'login_continue_with_google': '使用Google继续',
      'login_cancelled': '登录已取消',
      'login_not_supported': '此设备不支持Google登录',

      // Privacy Policy
      'privacy_policy_title': '隐私政策',
      'privacy_last_updated': '最后更新：2026年1月',
      'privacy_section_1_title': '1. 收集的信息',
      'privacy_section_1_content':
          'Ringinout不收集用户的个人信息。\n\n'
          '• 位置信息：仅在设备内处理用于闹钟功能，不会发送到外部服务器。\n\n'
          '• 账户信息：使用Google登录时，电子邮件地址会被转换为匿名随机ID存储。原始电子邮件不会被存储。',
      'privacy_section_2_title': '2. 匿名ID的使用目的',
      'privacy_section_2_content':
          '匿名ID仅用于验证高级订阅状态。'
          '无法通过此ID识别或追踪个人。',
      'privacy_section_3_title': '3. 数据存储',
      'privacy_section_3_content':
          '所有闹钟和位置数据仅存储在您的设备上，'
          '不会传输到外部服务器。',
      'privacy_section_4_title': '4. 第三方共享',
      'privacy_section_4_content': 'Ringinout不会与第三方共享任何用户信息。',
      'privacy_section_5_title': '5. 联系方式',
      'privacy_section_5_content': '如有隐私相关问题，请使用应用内的"发送反馈"功能。',

      // 권한
      'permission_required': '需要权限',
      'location_permission': '位置权限',
      'notification_permission': '通知权限',
      'background_permission': '后台位置权限',
      'background_location_desc': '即使不使用应用也能检测位置。',
      'overlay_permission': '在其他应用上显示',
      'overlay_permission_desc': '显示全屏闹钟需要此权限。',
      'grant_permission': '授予权限',
      'allow': '允许',
      'permission_settings': '权限设置',
      'setup_complete': '设置完成！🎉',
      'grant_all_permissions': '请授予所有权限',
      'setup_later': '稍后设置',
      'location_permission_desc': '需要检测闹钟位置。',
      'battery_opt_warning_title': '未排除电池优化',
      'battery_opt_warning_desc':
          '由于当前未排除电池优化，因此显示此提示。应用仍可使用，但在部分设备上闹钟可能延迟或漏发。'
          '建议将应用从电池优化中排除。',

      // GPS 페이지
      'gps_title': 'GPS',
      'geofence_service_status': '地理围栏服务状态',
      'status_running': '✅ 运行中',
      'status_stopped': '❌ 已停止',
      'status': '状态',
      'last_event': '最后事件',
      'last_event_none': '无',
      'settings_interval': '设置：{interval}秒间隔，{accuracy}米精度',
      'geofence_status_debug': '地理围栏状态（调试）',
      'no_saved_places': '没有保存的地点。',
      'distance': '距离',
      'radius_label': '半径',
      'current_location': '当前位置',
      'no_location_info': '无位置信息',
      'latitude': '纬度',
      'longitude': '经度',
      'updated': '更新',
      'active_alarm_distance': '活动闹钟距离',
      'no_active_alarms': '没有活动闹钟或没有位置信息。',
      'alarm': '闹钟',
      'place_unknown': '未知地点',
      'cannot_calculate_distance': '无法计算距离。',
      'location_permission_required': '需要位置权限。',
      'inside': '内部',
      'outside': '外部',

      // 요일
      'sun': '日',
      'mon': '一',
      'tue': '二',
      'wed': '三',
      'thu': '四',
      'fri': '五',
      'sat': '六',
      'every_week': '每周 {days}',
      'first_entry_after_set': '设置闹钟后首次进入时',
      'first_exit_after_set': '设置闹钟后首次离开时',
      'no_selection': '未选择',

      // 공휴일 설정
      'holiday_settings': '节假日设置',
      'turn_off_on_holidays': '在替代/临时节假日关闭',
      'turn_on_on_holidays': '在替代/临时节假日开启',

      // 위치 알람 추가
      'add_new_location_alarm': '添加新位置闹钟',
      'done': '完成',
      'alarm_name': '闹钟名称',
      'no_name': '无名称',
      'select_place': '选择地点',
      'alarm_on_entry': '进入时闹钟',
      'alarm_on_exit': '离开时闹钟',

      // 음성 인식
      'voice_input': '语音输入',
      'voice_listening': '正在听...',
      'voice_not_recognized': '未能识别语音',
      'tap_to_speak': '点击说话',
      'select_location_on_map': '在地图上选择位置',

      // 알람 화면
      'dismiss': '解除',
      'snooze_minutes': '{minutes}分钟后提醒',
      'alarm_ringing': '闹钟响了！',
    },
  };

  String get(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  /// 플레이스홀더 대체 지원
  String getWithArgs(String key, Map<String, String> args) {
    String value = get(key);
    args.forEach((argKey, argValue) {
      value = value.replaceAll('{$argKey}', argValue);
    });
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ko', 'ja', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
