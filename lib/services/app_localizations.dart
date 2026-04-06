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
      'nav_voice': 'Voice',
      'nav_subscription': 'Subscription',

      // 페이지 타이틀
      'page_title_alarm': 'Location Alarm',
      'page_title_places': 'My Places',
      'page_title_voice': 'Voice Recognition',
      'page_title_subscription': 'Subscription',

      // 선택 모드
      'select_all': 'Select All',
      'delete_selected': 'Delete',

      // 알람 페이지
      'alarm_title': 'Ringinout Alarm',
      'location_alarm': 'Location Alarm',
      'basic_alarm': 'Basic Alarm',
      'basic_alarm_page': 'Basic Alarm Page',
      'sort_options': 'Sort Options',
      'sort_by_time': 'By Alarm Time',
      'sort_custom': 'Custom Order',
      'sort_place_asc': 'Place (A → Z)',
      'sort_place_desc': 'Place (Z → A)',
      'sort_name_asc': 'Alarm Name (A → Z)',
      'sort_name_desc': 'Alarm Name (Z → A)',
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

      // 알람 추가/편집
      'add_location_alarm': 'Add Location Alarm',
      'edit_location_alarm': 'Edit Location Alarm',
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

      // 공휴일 국가 설정
      'holiday_country': 'Holiday Country',
      'holiday_country_auto': 'Auto',
      'holiday_country_auto_detected': 'Auto (Detected: {country})',
      'holiday_country_auto_detecting': 'Auto (Detecting...)',
      'country_KR': 'South Korea',
      'country_US': 'United States',
      'country_JP': 'Japan',
      'country_CN': 'China',
      'country_VN': 'Vietnam',
      'country_MY': 'Malaysia',
      'country_TH': 'Thailand',
      'country_CA': 'Canada',
      'country_BR': 'Brazil',
      'country_TW': 'Taiwan',

      // 알람 그룹핑
      'alarm_count': '{count} alarms',
      'alarm_count_one': '1 alarm',
      'other_places': 'Other',

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

      // 배터리 안내
      'battery_info_text_prefix':
          'Active alarms auto-restart when the app closes.\nFor reliable alarms, ',
      'battery_info_text_action': 'exclude from battery optimization',
      'battery_info_text_suffix': '.',
      'battery_opt_exclude': 'Exclude from battery optimization',
      'no_saved_alarms': 'No saved alarms.',

      // 웰컴/로그인
      'get_started': 'Get Started',

      // 음성 페이지
      'voice_main_title': 'Register alarms by voice',
      'voice_example_phrase': '"Notify me when I arrive at work"',
      'voice_tap_to_start': 'Tap to start',
      'voice_widget_title': 'Add widget to home screen',
      'voice_widget_subtitle': 'Start voice recognition with widget tap!',
      'voice_widget_guide_title': 'Add Home Screen Widget',
      'voice_widget_guide_subtitle': 'Start voice alarms faster!',
      'voice_widget_step1': 'Long press on empty space on home screen',
      'voice_widget_step2': 'Select "Widgets" menu',
      'voice_widget_step3': 'Find "ringinout" or "Voice Alarm"',
      'voice_widget_step4': 'Drag widget to home screen',
      'voice_widget_tip':
          'With a widget, you can start voice alarms\nright from your home screen without opening the app!',
      'voice_widget_got_it': 'Got it!',
      'voice_tip_title': '💡 Voice Recognition Examples',
      'voice_tip_examples':
          '• "Notify me when I arrive at work on Monday"\n'
          '  → Every Monday, on entry\n'
          '• "Alert me when I leave home on April 12"\n'
          '  → April 12 only, on exit\n'
          '• "Ring when I get home after 6 on Monday"\n'
          '  → Every Monday, after 6:00, on entry\n'
          '• "Remind me when I leave home at 9 on March 13"\n'
          '  → March 13, after 9:00, on exit',
      'voice_tip_note':
          'Weekdays, dates & times are set automatically\n(GPS geofence may fire within ±seconds of boundary)',
      'voice_first_visit_title': '💡 Pro Tip!',
      'voice_first_visit_desc':
          'Add a widget to your home screen\nto start voice alarms\nwithout opening the app!',
      'voice_first_visit_btn': 'See how to add widget',
      'voice_first_visit_later': 'Maybe later',

      // 구독 페이지
      'subscription_tab': 'Subscription',
      'subscription_current_plan': 'Current Plan',
      'subscription_expires': 'Expires: {date}',
      'subscription_free_plan': 'Free Plan',
      'subscription_unlimited': 'Unlimited',
      'subscription_places_n': '{n} places',
      'subscription_alarms_n': '{n} active alarms',
      'subscription_places_unlimited': 'Unlimited places',
      'subscription_alarms_unlimited': 'Unlimited alarms',
      'subscription_no_ads': 'No ads',
      'subscription_all_unlimited': 'All features unlimited',
      'subscription_dev_plan': 'Developer plan - all features unlimited',
      'subscription_subscribe': 'Subscribe',
      'subscription_in_use': 'In Use',
      'subscription_recommended': 'Recommended',
      'subscription_coming_soon': 'Subscription feature is coming soon.',
      'subscription_beta_notice':
          'Paid plans are not available during beta. They will be available after beta ends.',
      'subscription_per_month': '/ month',
      'subscription_policy': 'Subscription Policy',
      'subscription_refund_policy': 'Refund Policy',

      // 알람 추가/편집 페이지 추가 키
      'plan_upgrade_needed': 'Plan upgrade needed',
      'add_alarm_tooltip': 'Add alarm',
      'entry_trigger': 'Entry',
      'exit_trigger': 'Exit',
      'entry_exit_trigger': 'Entry/Exit',
      'am_label': 'AM',
      'pm_label': 'PM',
      'hour_suffix': ':',
      'min_suffix': '',
      'after_suffix': ' after',
      'first_trigger_immediate': 'Alarm on first {trigger}',
      'first_trigger_condition': '{conditions} first {trigger}',
      'monthly_date': '{month}/{day}({weekday})',
      'weekly_prefix': 'Every {days}',
      'listening_prompt': '🎙️ Listening... Speak now!',
      'done_btn': 'Done',
      'alarm_name_label': 'Alarm Name',
      'no_name_label': 'No name',
      'select_place_label': 'Select Place',
      'alarm_on_entry_label': 'Alarm on Entry',
      'alarm_on_exit_label': 'Alarm on Exit',
      'boundary_warning':
          'Near the geofence boundary, the alarm may ring multiple times if you stay or move back and forth. '
          'Use the "Snooze" button to delay the alarm.',
      'condition_settings': 'Condition Settings (Optional)',
      'condition_hint':
          'Without conditions, the alarm rings on the first entry/exit after saving.',
      'no_date_set': 'No date set',
      'time_condition_hint': 'Time condition (optional)',
      'time_after': '⏰ {time} after',
      'holidays_off': 'Off on holidays',
      'holidays_sub_on': 'On on substitute/temporary holidays',
      'alarm_sound_label': 'Alarm Sound',
      'alarm_sound_default': 'Device default alarm sound',
      'alarm_sound_unchangeable': 'Cannot be changed',
      'save_btn': 'Save',
      'delete_btn': 'Delete',
      'edit_alarm_title': 'Edit Location Alarm',
      'select_place_hint': 'Select a place',
      'select_place_required': 'Please select a place',
      'alarm_save_failed': 'Failed to save alarm: {error}',
      // 장소 추가 페이지
      'address_search_result': 'Address search results',
      'save_place_title': 'Save Place',
      'place_name_label': 'Place name',
      'place_name_hint': 'e.g., Home, Office, Gym',
      'radius_display': 'Radius: {radius}m',
      'radius_shown_on_map': '(Shown as circle on map)',
      'cancel_btn': 'Cancel',
      'save_place_btn': 'Save',
      'place_saved_msg': '✅ Place saved',
      'select_on_map': 'Select location on map',
      'move_to_current': 'Move to current location',
      'search_hint': 'Address or place name (e.g., Starbucks)',
      'no_search_result': 'No search results',
      'address_label': 'Address: {address}',
      'radius_label_prefix': 'Radius: ',
      'custom_input': 'Custom',
      'save_location_btn': 'Save location',
      'signal_warning':
          '📍 Radius Setup Guide\n'
          '• In GPS-unstable zones (underground, tall buildings, signal-blocked areas), false triggers may occur.\n'
          '  For one-off false triggers, tap the "⚡ False Trigger" button to dismiss them quickly.\n'
          '• If you stay near a zone boundary, the alarm may keep firing even after tapping False Trigger.\n'
          '  In that case, disable the alarm and re-enable it when needed.\n'
          '• If false triggers are frequent, try increasing the radius by 10m at a time.',
      'radius_guide_btn': '📍 Radius Setup Guide  —  Must Read!!',
      'radius_guide_dialog_body':
          '📍 GPS Accuracy Limits\n'
          'GPS can only estimate your location. Even outdoors, expect a margin of error'
          ' of several to tens of meters. This is an inherent GPS limitation.\n\n'
          '📡 GPS Signal Spikes\n'
          'In GPS-unstable environments (underground, tall buildings, signal-blocked zones),'
          ' the radius detection error can increase. Even when you are actually inside the radius,'
          ' GPS may temporarily read you as outside \u2014 or vice versa.\n'
          'In these cases, use the "\u26a1 False Trigger" button.'
          ' If the same issue keeps repeating, try increasing your radius by 10m at a time.\n\n'
          '💡 If you need to stay or move around near the configured radius boundary\n'
          'Even after tapping False Trigger, the alarm may keep firing.'
          ' In that case, disable the alarm and re-enable it when needed.\n'
          '("Standby" mode — under consideration if requested: auto-reactivate after a set duration)',
      'radius_input_range': '30m ~ 500m (10m increments)',
      // 약관 페이지
      'terms_agreement_title': 'Terms Agreement (Required)',
      'terms_agree_text':
          'I have read and agree to the Terms of Service and Refund/Subscription Policy.',
      'terms_agree_btn': 'Agree and Continue',
      'terms_disagree_btn': 'Disagree (Close App)',
      'terms_save_failed': 'Failed to save terms. Please try again.',
      // 알람음 설정
      'alarm_sound_setting_title': 'Alarm Sound Settings',
      'alarm_disabled_label': 'Alarm Disabled',
      // add_alarm_page
      'add_alarm_new_title': 'Add New Alarm',
      'edit_alarm_modify_title': 'Edit Location Alarm',
      'location_fixed_text': 'This alarm is fixed to this place',
      'no_place_label': 'No place',
      'required_fields_msg': 'Please fill in all required fields.',
      'holidays_dialog_title': 'Substitute/Temporary Holiday Settings',
      'holidays_sub_off': 'Off on substitute/temporary holidays too',
      // my_places_page
      'delete_confirm_title': 'Confirm Delete',
      'delete_locked_msg': 'Delete this locked location?',
      'delete_place_msg': 'Are you sure you want to delete this location?',
      'linked_alarm_delete_warning':
          '⚠️ {count} linked alarm(s) will also be deleted.',
      'edit_places_menu': 'Edit Place',
      'add_alarm_menu': 'Add New Alarm',
      'add_place_tooltip': 'Add new location',
      // show_alarm_popup_page
      'alarm_end_confirm': 'End alarm?',
      'no_label': 'No',
      'yes_label': 'Yes',
      'snooze_btn': 'Snooze',
      'alarm_stop_btn': 'Stop Alarm',
      // snooze/vibration setting
      'snooze_setting_title': 'Snooze Settings',
      'vibration_setting_title': 'Vibration Settings',
      // permission
      'permission_setting_title': 'Permission Settings',
      'permission_allow': 'Allow',
      'battery_opt_title': 'Disable Battery Optimization',
      'battery_opt_msg':
          'To ensure alarms work properly in the background, battery optimization must be disabled.\nGo to Settings and find "Battery Optimization" and set Ringinout to "Not Optimized".',
      'open_settings_btn': 'Open Settings',
      'later_btn': 'Later',
      // subscription management
      'subscription_mgmt_title': 'Subscription Management',
      'subscription_policy_btn': 'Subscription Policy',
      'refund_policy_btn': 'Refund Policy',
      'auto_renew_msg': 'Auto-renewed every 31 days.',
      'agree_auto_pay': 'I agree to automatic payment.',
      'agree_policy': 'I have reviewed the subscription/refund policy.',
      'start_auto_subscription': 'Start Auto Subscription',
      'current_plan': 'Current Plan',
      'cancel_subscription': 'Cancel',
      'subscribe_btn': 'Subscribe',
      'auto_subscribe_btn': 'Auto Subscribe',
      'beta_no_paid_plans':
          'Paid plans are not available during beta. They will be available after beta ends.',
      'places_5': '5 Places',
      'active_alarms_10': '10 Active Alarms',
      'ad_free_included': 'Ad-free Included',
      'places_alarms_unlimited': 'Unlimited Places/Alarms',
      'ad_remove_title': 'Remove Ads',
      'in_app_ad_remove': 'In-app Ad Removal',
      'price_loading': 'Loading price',
      'duration_1month': '1 Month',
      'duration_3months': '3 Months',
      'duration_6months': '6 Months',
      'duration_12months': '12 Months',
      'discount_5': '5% Off',
      'discount_10': '10% Off',
      'discount_20': '20% Off',
      'expiry_date_none': 'Expiry: -',
      'expiry_date_format': 'Expiry: {date}',
      'beta_sub_activate_later':
          'Subscriptions will be activated after beta ends.',
      // subscription limit dialog
      'place_limit_title': 'Place Registration Limit',
      'place_limit_msg':
          'In the {plan} plan, you can register up to {limit} places.\nPlease delete existing places or upgrade.',
      'alarm_limit_title': 'Alarm Registration Limit',
      'alarm_limit_msg':
          'In the {plan} plan, you can set up to {limit} active alarms.\nPlease delete existing alarms or upgrade.',
      'close_btn': 'Close',
      // location picker
      'place_name_input_title': 'Enter Place Name',
      'radius_default_info': 'Radius: 100m (can be changed later)',
      'location_select_title': 'Select Location',
      'fetching_location': 'Fetching current location...',
      'location_saved': '📍 Location saved!',
      // 로그인 추가
      'dev_test_mode': 'Developer Test Mode',
      'test_login_failed': 'Test login failed: {error}',
      // 맵 전환
      'switch_to_google': 'Switch to Google Maps',
      'switch_to_naver': 'Switch to Naver Map',
      // 무료 플랜 맵 차감 안내 (해외: Google)
      'map_free_limit_exceeded_title': 'Free Plan Limit',
      'map_free_limit_exceeded_body':
          'You have used all {limit} Google Maps opens this month.\n\n'
          'OSM is always available for free.\n'
          'Upgrade to a paid plan for unlimited access.',
      'map_switch_confirm_title': 'Switch to Google Maps',
      'map_switch_confirm_body':
          'Free plan allows {limit} Google Maps opens per month.\n\n'
          'Remaining: {remaining}/{limit}\n\n'
          'Switching to Google Maps uses 1 credit.\n'
          'OSM is always free and unlimited.',
      'map_switch_btn_cancel': 'Cancel',
      'map_switch_btn_confirm': 'Switch',
      // 오발동 / 알람 화면
      'btn_snooze': 'Snooze',
      'btn_dismiss': 'Dismiss Alarm',
      'btn_false_trigger': 'False Trigger',
      'false_trigger_hint': 'Triggered by GPS error',
      'snooze_time_title': 'Snooze Duration',
      'snooze_min': '{m} min',
      // 오발동 안내 타일
      'false_trigger_info_title': '⚡ What is False Trigger?',
      'false_trigger_info_subtitle':
          'Keep alarm active when triggered by GPS error',
      'false_trigger_dialog_title': 'What is False Trigger?',
      'false_trigger_dialog_body':
          'When the alarm rings, a "⚡ False Trigger" button appears'
          ' alongside "Snooze" and "Dismiss Alarm".\n\n'
          'When you tap "⚡ False Trigger":\n'
          '  • Ringtone/vibration stops immediately\n'
          '  • The alarm stays active (not disabled)\n'
          '  • The alarm can fire again from scratch\n\n'
          '📍 GPS Accuracy Limits\n'
          'GPS can only estimate your location.'
          ' Even outdoors, there is always a margin of error of several to tens of meters.'
          ' This may cause the alarm to fire a little early or late.\n\n'
          '📡 GPS Signal Spikes\n'
          'In GPS-unstable environments (underground, tall buildings, signal-blocked zones),'
          ' the radius detection error can increase. Even when you are actually inside the radius,'
          ' GPS may temporarily read you as outside — or vice versa.\n'
          'In these cases, use the "⚡ False Trigger" button.'
          ' If the same issue keeps repeating, try increasing your radius by 10m at a time.\n\n'
          '💡 If you need to stay or move around near the configured radius boundary\n'
          'Even after tapping False Trigger, the alarm may keep firing.'
          ' In that case, disable the alarm and re-enable it when needed.\n'
          '("Standby" mode — under consideration if requested: auto-reactivate after a set duration)',

      'false_trigger_dialog_ok': 'Got it',
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
      'nav_voice': '음성',
      'nav_subscription': '구독 관리',

      // 페이지 타이틀
      'page_title_alarm': '위치 알람',
      'page_title_places': '내 장소',
      'page_title_voice': '음성 인식',
      'page_title_subscription': '구독 관리',

      // 선택 모드
      'select_all': '전체 선택',
      'delete_selected': '삭제',

      // 알람 페이지
      'alarm_title': 'Ringinout 알람',
      'location_alarm': '위치알람',
      'basic_alarm': '기본알람',
      'basic_alarm_page': '기본알람 페이지',
      'sort_options': '정렬 방식 선택',
      'sort_by_time': '알람 시간 순서',
      'sort_custom': '사용자 지정 순서',
      'sort_place_asc': '장소명 (오름차순)',
      'sort_place_desc': '장소명 (내림차순)',
      'sort_name_asc': '알람명 (오름차순)',
      'sort_name_desc': '알람명 (내림차순)',
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

      // 알람 추가/편집
      'add_location_alarm': '위치 알람 추가',
      'edit_location_alarm': '위치 알람 편집',
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

      // 공휴일 국가 설정
      'holiday_country': '공휴일 국가',
      'holiday_country_auto': '자동',
      'holiday_country_auto_detected': '자동 (감지: {country})',
      'holiday_country_auto_detecting': '자동 (감지 중...)',
      'country_KR': '대한민국',
      'country_US': '미국',
      'country_JP': '일본',
      'country_CN': '중국',
      'country_VN': '베트남',
      'country_MY': '말레이시아',
      'country_TH': '태국',
      'country_CA': '캐나다',
      'country_BR': '브라질',
      'country_TW': '대만',

      // 알람 그룹핑
      'alarm_count': '{count}개 알람',
      'alarm_count_one': '1개 알람',
      'other_places': '기타',

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

      // 배터리 안내
      'battery_info_text_prefix':
          '활성 알람이 있으면 앱 종료 시 자동으로 재시작됩니다.\n안정적인 알람 작동을 위해 ',
      'battery_info_text_action': '배터리 최적화 제외',
      'battery_info_text_suffix': '를 권장합니다.',
      'battery_opt_exclude': '배터리 최적화 제외',
      'no_saved_alarms': '저장된 알람이 없습니다.',

      // 웰컴/로그인
      'get_started': '시작하기',

      // 음성 페이지
      'voice_main_title': '말로 알람을 등록하세요',
      'voice_example_phrase': '"회사 도착하면 알려줘"',
      'voice_tap_to_start': '탭하여 시작',
      'voice_widget_title': '홈 화면에 위젯 추가',
      'voice_widget_subtitle': '홈 화면 위젯 터치 시 음성 인식 바로 시작!',
      'voice_widget_guide_title': '홈 화면 위젯 추가하기',
      'voice_widget_guide_subtitle': '더 빠르게 음성 알람을 시작하세요!',
      'voice_widget_step1': '홈 화면 빈 곳을 길게 누르세요',
      'voice_widget_step2': '"위젯" 메뉴를 선택하세요',
      'voice_widget_step3': '"ringinout" 또는 "음성 알람"을 찾으세요',
      'voice_widget_step4': '위젯을 홈 화면으로 드래그하세요',
      'voice_widget_tip': '위젯을 추가하면 앱을 열지 않고도\n홈 화면에서 바로 음성 알람을 시작할 수 있어요!',
      'voice_widget_got_it': '알겠어요!',
      'voice_tip_title': '💡 음성 인식 예시',
      'voice_tip_examples':
          '• "월요일에 회사 도착하면 알려줘"\n'
          '  → 매주 월요일, 회사 진입 시\n'
          '• "4월 12일에 집에서 나갈 때 알려줘"\n'
          '  → 4/12 하루, 집 진출 시\n'
          '• "월요일 6시 이후 집에 도착하면 알려줘"\n'
          '  → 매주 월요일, 오후 6시 이후 집 진입 시\n'
          '• "3월 13일 9시에 집에서 나가면 알려줘"\n'
          '  → 3/13, 오전 9시 이후 집 진출 시',
      'voice_tip_note': '요일·날짜·시간이 자동으로 설정됩니다\n(GPS 특성상 경계 인식은 ±수십 초 오차 있음)',
      'voice_first_visit_title': '💡 꿀팁!',
      'voice_first_visit_desc':
          '홈 화면에 위젯을 추가하면\n앱을 열지 않고도 바로\n음성 알람을 시작할 수 있어요!',
      'voice_first_visit_btn': '위젯 추가 방법 보기',
      'voice_first_visit_later': '나중에 할게요',

      // 구독 페이지
      'subscription_tab': '구독 관리',
      'subscription_current_plan': '현재 플랜',
      'subscription_expires': '만료: {date}',
      'subscription_free_plan': '무료 플랜',
      'subscription_unlimited': '무제한',
      'subscription_places_n': '장소 {n}개',
      'subscription_alarms_n': '활성 알람 {n}개',
      'subscription_places_unlimited': '장소 무제한',
      'subscription_alarms_unlimited': '알람 무제한',
      'subscription_no_ads': '광고 제거',
      'subscription_all_unlimited': '모든 기능 무제한 사용',
      'subscription_dev_plan': '개발자 플랜 - 모든 기능 무제한',
      'subscription_subscribe': '구독하기',
      'subscription_in_use': '사용 중',
      'subscription_recommended': '추천',
      'subscription_coming_soon': '구독 기능은 준비 중입니다.',
      'subscription_beta_notice': '베타 기간에는 유료 플랜이 제공되지 않습니다. 베타 종료 후 공개됩니다.',
      'subscription_per_month': '/ 월',
      'subscription_policy': '구독 정책',
      'subscription_refund_policy': '환불 정책',

      // 알람 추가/편집 페이지 추가 키
      'plan_upgrade_needed': '플랜 업그레이드 필요',
      'add_alarm_tooltip': '알람 추가',
      'entry_trigger': '진입',
      'exit_trigger': '진출',
      'entry_exit_trigger': '진입/진출',
      'am_label': '오전',
      'pm_label': '오후',
      'hour_suffix': '시',
      'min_suffix': '분',
      'after_suffix': ' 이후',
      'first_trigger_immediate': '최초 {trigger} 시 알람',
      'first_trigger_condition': '{conditions} 최초 {trigger} 시',
      'monthly_date': '{month}월 {day}일({weekday})',
      'weekly_prefix': '매주 {days}',
      'listening_prompt': '🎙️ 듣는 중... 말씀해 주세요!',
      'done_btn': '완료',
      'alarm_name_label': '알람 이름',
      'no_name_label': '이름 없음',
      'select_place_label': '장소 선택',
      'alarm_on_entry_label': '진입 시 알람',
      'alarm_on_exit_label': '진출 시 알람',
      'boundary_warning':
          '반경 경계 근처에서 머무르거나 왔다갔다 하면 알람이 여러 번 울릴 수 있습니다. '
          '"다시 울림" 버튼으로 알람을 잠시 뒤로 미룰 수 있습니다.',
      'condition_settings': '조건 설정 (선택사항)',
      'condition_hint': '조건 없이 저장하면 최초 진입/진출 시 알람이 울립니다.',
      'no_date_set': '날짜 지정 없음',
      'time_condition_hint': '시간 조건 설정 (선택사항)',
      'time_after': '⏰ {time} 이후',
      'holidays_off': '공휴일에는 끄기',
      'holidays_sub_on': '대체 및 임시 공휴일에는 켜기',
      'alarm_sound_label': '알람음',
      'alarm_sound_default': '각 사용자 폰 기본 알람음',
      'alarm_sound_unchangeable': '변경불가',
      'save_btn': '저장',
      'delete_btn': '삭제',
      'edit_alarm_title': '위치알람 수정',
      'select_place_hint': '장소를 선택하세요',
      'select_place_required': '장소를 선택해주세요',
      'alarm_save_failed': '알람 저장에 실패했습니다: {error}',
      // 장소 추가 페이지
      'address_search_result': '주소 검색 결과',
      'save_place_title': '장소 저장',
      'place_name_label': '장소 이름',
      'place_name_hint': '예: 집, 회사, 헬스장 등',
      'radius_display': '반경: {radius}m',
      'radius_shown_on_map': '(지도에서 원으로 표시됨)',
      'cancel_btn': '취소',
      'save_place_btn': '저장',
      'place_saved_msg': '✅ 장소가 저장되었습니다',
      'select_on_map': '지도에서 위치 선택',
      'move_to_current': '현재 위치로 이동',
      'search_hint': '주소 또는 지역+장소명 (예: 시흥 롯데마트)',
      'no_search_result': '검색 결과가 없습니다',
      'address_label': '주소: {address}',
      'radius_label_prefix': '반경: ',
      'custom_input': '직접입력',
      'save_location_btn': '위치 저장',
      'signal_warning':
          '📍 반경 설정 안내\n'
          '• GPS 불안정 구역(지하·고층빌딩·전파방해 등)에서는 오발동이 발생할 수 있습니다.\n'
          '  일회성 오발동은 "⚡ 오발동" 버튼으로 간단히 처리할 수 있어요.\n'
          '• 반경 경계 주변에 머무르는 경우, 오발동 버튼을 눌러도 알람이 계속 발동될 수 있습니다.\n'
          '  이 경우 해당 알람을 비활성화한 후, 필요할 때 다시 활성화하세요.\n'
          '• 오발동이 잦으면 반경을 10m씩 늘려가며 테스트해 보세요.',
      'radius_guide_btn': '📍 반경 설정 안내  —  필독!!',
      'radius_guide_dialog_body':
          '📍 GPS 정확도의 한계\n'
          'GPS는 대략적인 위치만 파악하며,'
          ' 실외에서도 수 미터~수십 미터의 오차가 항상 존재합니다.'
          ' 이로 인해 알람이 조금 일찍 또는 늦게 울리는 일이 생길 수 있습니다.\n\n'
          '📡 GPS 신호 튐 현상\n'
          '지하·고층빌딩·전파방해 구역 등 GPS 불안정 환경에서는 반경 인식 오차가 커질 수 있습니다.'
          ' 실제로 반경 안에 있음에도 GPS가 일시적으로 반경 밖으로 인식하거나,'
          ' 그 반대의 경우도 발생할 수 있습니다.\n'
          '이런 경우 "⚡ 오발동" 버튼을 활용하시고,'
          ' 동일한 문제가 자주 반복된다면 반경을 10m씩 늘려서 테스트해 보세요.\n\n'
          '💡 설정 반경 경계 근처에서 머물거나 활동하는 경우\n'
          '오발동 버튼을 누르면 알람이 계속 발동할 수 있으니,'
          ' 일단 알람을 종료하고 필요할 때 다시 활성화하세요.\n'
          '("대기" 모드 — 요청이 많을 시 도입 고려: 설정한 시간 이후 자동 재활성화)',
      'radius_input_title': '반경 직접 입력',
      'radius_input_range': '30m ~ 500m (10m 단위)',
      // 약관 페이지
      'terms_agreement_title': '이용약관 동의 (필수)',
      'terms_agree_text': '이용약관 및 환불/구독 정책을 확인하고 동의합니다.',
      'terms_agree_btn': '동의하고 계속',
      'terms_disagree_btn': '동의하지 않음 (앱 종료)',
      'terms_save_failed': '약관 저장 실패. 다시 시도해주세요.',
      // 알람음 설정
      'alarm_sound_setting_title': '알람음 설정',
      'alarm_disabled_label': '알람 비활성화',
      // add_alarm_page
      'add_alarm_new_title': '새 알람 추가',
      'edit_alarm_modify_title': '위치알람 수정',
      'location_fixed_text': '이 알람은 해당 장소에 고정됩니다',
      'no_place_label': '장소 없음',
      'required_fields_msg': '필수 항목을 모두 설정해주세요.',
      'holidays_dialog_title': '대체/임시 공휴일 설정',
      'holidays_sub_off': '대체 및 임시 공휴일에도 끄기',
      // my_places_page
      'delete_confirm_title': '삭제 확인',
      'delete_locked_msg': '잠긴 위치를 삭제하시겠습니까?',
      'delete_place_msg': '정말로 이 위치를 삭제하시겠습니까?',
      'linked_alarm_delete_warning': '⚠️ 연결된 알람 {count}개도 함께 삭제됩니다.',
      'edit_places_menu': 'MyPlaces 편집',
      'add_alarm_menu': '새 알람 추가',
      'add_place_tooltip': '새 위치 추가',
      // show_alarm_popup_page
      'alarm_end_confirm': '알람을 종료하시겠습니까?',
      'no_label': '아니오',
      'yes_label': '예',
      'snooze_btn': '다시 울림',
      'alarm_stop_btn': '알람 종료',
      // snooze/vibration setting
      'snooze_setting_title': '다시 울림 설정',
      'vibration_setting_title': '진동 설정',
      // permission
      'permission_setting_title': '권한 설정',
      'permission_allow': '허용',
      'battery_opt_title': '배터리 최적화 해제',
      'battery_opt_msg':
          '백그라운드에서 알람이 정상 작동하려면 배터리 최적화를 해제해야 합니다.\n설정에서 "배터리 최적화" 항목을 찾아 Ringinout을 "최적화 안 함"으로 설정해주세요.',
      'open_settings_btn': '설정 열기',
      'later_btn': '나중에',
      // subscription management
      'subscription_mgmt_title': '구독 관리',
      'subscription_policy_btn': '구독 정책',
      'refund_policy_btn': '환불 정책',
      'auto_renew_msg': '31일마다 자동 결제됩니다.',
      'agree_auto_pay': '자동 결제에 동의합니다.',
      'agree_policy': '구독/환불 정책을 확인했습니다.',
      'start_auto_subscription': '자동 구독 시작',
      'current_plan': '현재 플랜',
      'cancel_subscription': '해지',
      'subscribe_btn': '구독하기',
      'auto_subscribe_btn': '자동 구독',
      'beta_no_paid_plans': '베타 기간에는 유료 플랜이 제공되지 않습니다. 베타 종료 후 공개됩니다.',
      'places_5': '장소 5개',
      'active_alarms_10': '활성 알람 10개',
      'ad_free_included': '광고 제거 포함',
      'places_alarms_unlimited': '장소/알람 무제한',
      'ad_remove_title': '광고 제거',
      'in_app_ad_remove': '앱 내 광고 제거',
      'price_loading': '가격 불러오는 중',
      'duration_1month': '1개월',
      'duration_3months': '3개월',
      'duration_6months': '6개월',
      'duration_12months': '12개월',
      'discount_5': '5% 할인',
      'discount_10': '10% 할인',
      'discount_20': '20% 할인',
      'expiry_date_none': '만료일: -',
      'expiry_date_format': '만료일: {date}',
      'beta_sub_activate_later': '베타 종료 후 구독이 활성화됩니다.',
      // subscription limit dialog
      'place_limit_title': '장소 등록 한도',
      'place_limit_msg':
          '{plan} 플랜에서는 장소를 {limit}개까지만 등록할 수 있습니다.\n기존 장소를 삭제하거나 업그레이드 해주세요.',
      'alarm_limit_title': '알람 등록 한도',
      'alarm_limit_msg':
          '{plan} 플랜에서는 활성 알람을 {limit}개까지만 설정할 수 있습니다.\n기존 알람을 삭제하거나 업그레이드 해주세요.',
      'close_btn': '닫기',
      // location picker
      'place_name_input_title': '장소 이름 입력',
      'radius_default_info': '반경: 100m (수정은 나중에 가능)',
      'location_select_title': '위치 선택',
      'fetching_location': '현재 위치를 가져오는 중...',
      'location_saved': '📍 위치가 저장되었습니다!',
      // 로그인 추가
      'dev_test_mode': '개발자 테스트 모드',
      'test_login_failed': '테스트 로그인 실패: {error}',
      // 맵 전환
      'switch_to_google': '구글맵으로 전환',
      'switch_to_naver': '네이버맵으로 전환',
      // 무료 플랜 맵 차감 안내 (한국: 네이버)
      'map_free_limit_exceeded_title': '무료 플랜 제한',
      'map_free_limit_exceeded_body':
          '이번 달 네이버 지도 오픈 횟수({limit}회)를 모두 사용했습니다.\n\n'
          'OSM 지도는 계속 무제한 이용 가능합니다.\n'
          '제한 없이 사용하려면 유료 플랜으로 업그레이드하세요.',
      'map_switch_confirm_title': '네이버 지도로 전환',
      'map_switch_confirm_body':
          '무료 플랜은 네이버 지도를 월 {limit}회 이용할 수 있습니다.\n\n'
          '남은 횟수: {remaining}/{limit}회\n\n'
          '네이버 지도로 전환하면 1회가 차감됩니다.\n'
          'OSM은 차감 없이 무제한 이용 가능합니다.',
      'map_switch_btn_cancel': '취소',
      'map_switch_btn_confirm': '전환',
      // 오발동 / 알람 화면
      'btn_snooze': '다시 울림',
      'btn_dismiss': '알람 종료',
      'btn_false_trigger': '오발동',
      'false_trigger_hint': 'GPS 오류로 잘못 울린 경우',
      'snooze_time_title': '다시 울림 시간 선택',
      'snooze_min': '{m}분 후',
      // 오발동 안내 타일
      'false_trigger_info_title': '⚡ 오발동 버튼이란?',
      'false_trigger_info_subtitle': 'GPS 오류로 잘못 울린 경우 알람을 유지하며 종료',
      'false_trigger_dialog_title': '오발동 버튼이란?',
      'false_trigger_dialog_body':
          '알람이 울릴 때 "다시 울림", "알람 종료" 외에'
          ' "⚡ 오발동" 버튼이 함께 표시됩니다.\n\n'
          '"⚡ 오발동"을 누르면:\n'
          '  • 벨소리·진동이 즉시 멈춥니다\n'
          '  • 알람은 비활성화되지 않고 유지됩니다\n'
          '  • 처음부터 다시 발동 가능한 상태가 됩니다\n\n'
          '📍 GPS 정확도의 한계\n'
          'GPS는 대략적인 위치만 파악하며,'
          ' 실외에서도 수 미터~수십 미터의 오차가 항상 존재합니다.'
          ' 이로 인해 알람이 조금 일찍 또는 늦게 울리는 일이 생길 수 있습니다.\n\n'
          '📡 GPS 신호 튐 현상\n'
          '지하·고층빌딩·전파방해 구역 등 GPS 불안정 환경에서는 반경 인식 오차가 커질 수 있습니다.'
          ' 실제로 반경 안에 있음에도 GPS가 일시적으로 반경 밖으로 인식하거나,'
          ' 그 반대의 경우도 발생할 수 있습니다.\n'
          '이런 경우 "⚡ 오발동" 버튼을 활용하시고,'
          ' 동일한 문제가 자주 반복된다면 반경을 10m씩 늘려서 테스트해 보세요.\n\n'
          '💡 설정 반경 경계 근처에서 머물거나 활동하는 경우\n'
          '오발동 버튼을 누르면 알람이 계속 발동할 수 있으니,'
          ' 일단 알람을 종료하고 필요할 때 다시 활성화하세요.\n'
          '("대기" 모드 — 요청이 많을 시 도입 고려: 설정한 시간 이후 자동 재활성화)',
      'false_trigger_dialog_ok': '확인',
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
      'nav_voice': '音声',
      'nav_subscription': 'サブスク',

      // 페이지 타이틀
      'page_title_alarm': '位置アラーム',
      'page_title_places': 'マイプレイス',
      'page_title_voice': '音声認識',
      'page_title_subscription': 'サブスクリプション',

      // 선택 모드
      'select_all': 'すべて選択',
      'delete_selected': '削除',

      // 알람 페이지
      'alarm_title': 'Ringinout アラーム',
      'location_alarm': '位置アラーム',
      'basic_alarm': '基本アラーム',
      'basic_alarm_page': '基本アラームページ',
      'sort_options': '並べ替え',
      'sort_by_time': 'アラーム時間順',
      'sort_custom': 'カスタム順',
      'sort_place_asc': '場所名 (昇順)',
      'sort_place_desc': '場所名 (降順)',
      'sort_name_asc': 'アラーム名 (昇順)',
      'sort_name_desc': 'アラーム名 (降順)',
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

      // 알람 추가/편집
      'add_location_alarm': '位置アラームを追加',
      'edit_location_alarm': '位置アラームを編集',
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

      // 공휴일 국가 설정
      'holiday_country': '祝日の国',
      'holiday_country_auto': '自動',
      'holiday_country_auto_detected': '自動 (検出: {country})',
      'holiday_country_auto_detecting': '自動 (検出中...)',
      'country_KR': '韓国',
      'country_US': 'アメリカ',
      'country_JP': '日本',
      'country_CN': '中国',
      'country_VN': 'ベトナム',
      'country_MY': 'マレーシア',
      'country_TH': 'タイ',
      'country_CA': 'カナダ',
      'country_BR': 'ブラジル',
      'country_TW': '台湾',

      // 알람 그룹핑
      'alarm_count': '{count}件のアラーム',
      'alarm_count_one': '1件のアラーム',
      'other_places': 'その他',

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

      // バッテリー案内
      'battery_info_text_prefix':
          'アクティブなアラームがある場合、アプリ終了時に自動的に再起動します。\n安定したアラーム動作のため、',
      'battery_info_text_action': 'バッテリー最適化の除外',
      'battery_info_text_suffix': 'を推奨します。',
      'battery_opt_exclude': 'バッテリー最適化を除外',
      'no_saved_alarms': '保存されたアラームがありません。',

      // ウェルカム/ログイン
      'get_started': '始める',

      // 音声ページ
      'voice_main_title': '音声でアラームを登録',
      'voice_example_phrase': '「会社に着いたら知らせて」',
      'voice_tap_to_start': 'タップして開始',
      'voice_widget_title': 'ホーム画面にウィジェットを追加',
      'voice_widget_subtitle': 'ホーム画面ウィジェットタップで音声認識開始！',
      'voice_widget_guide_title': 'ホーム画面ウィジェットの追加',
      'voice_widget_guide_subtitle': '音声アラームをもっと速く！',
      'voice_widget_step1': 'ホーム画面の空白を長押し',
      'voice_widget_step2': '「ウィジェット」メニューを選択',
      'voice_widget_step3': '「ringinout」または「音声アラーム」を検索',
      'voice_widget_step4': 'ウィジェットをホーム画面にドラッグ',
      'voice_widget_tip': 'ウィジェットを追加すると、アプリを開かなくても\nホーム画面から直接音声アラームを開始できます！',
      'voice_widget_got_it': 'わかりました！',
      'voice_tip_title': '💡 音声認識の例',
      'voice_tip_examples':
          '• 「月曜日に会社に着いたら知らせて」\n'
          '  → 毎週月曜日、入場時\n'
          '• 「4月12日に家を出るとき知らせて」\n'
          '  → 4/12のみ、退場時\n'
          '• 「月曜日の6時以降に家に着いたら知らせて」\n'
          '  → 毎週月曜日、18時以降、入場時\n'
          '• 「3月13日の9時に家を出たら知らせて」\n'
          '  → 3/13、9時以降、退場時',
      'voice_tip_note': '曜日・日付・時間が自動設定されます\n(GPS特性上、境界検知に数十秒の誤差あり)',
      'voice_first_visit_title': '💡 おすすめ！',
      'voice_first_visit_desc':
          'ホーム画面にウィジェットを追加すると\nアプリを開かなくても\n音声アラームを開始できます！',
      'voice_first_visit_btn': 'ウィジェットの追加方法を見る',
      'voice_first_visit_later': 'あとで',

      // サブスクリプションページ
      'subscription_tab': 'サブスクリプション',
      'subscription_current_plan': '現在のプラン',
      'subscription_expires': '期限: {date}',
      'subscription_free_plan': '無料プラン',
      'subscription_unlimited': '無制限',
      'subscription_places_n': '{n}か所',
      'subscription_alarms_n': 'アクティブアラーム{n}個',
      'subscription_places_unlimited': '場所無制限',
      'subscription_alarms_unlimited': 'アラーム無制限',
      'subscription_no_ads': '広告なし',
      'subscription_all_unlimited': 'すべての機能が無制限',
      'subscription_dev_plan': '開発者プラン - すべての機能が無制限',
      'subscription_subscribe': '購読する',
      'subscription_in_use': '使用中',
      'subscription_recommended': 'おすすめ',
      'subscription_coming_soon': 'サブスクリプション機能は準備中です。',
      'subscription_beta_notice': 'ベータ期間中は有料プランは提供されません。ベータ終了後に公開されます。',
      'subscription_per_month': '/ 月',
      'subscription_policy': 'サブスクリプションポリシー',
      'subscription_refund_policy': '返金ポリシー',

      // 알람 추가/편집 페이지 추가 키
      'plan_upgrade_needed': 'プランのアップグレードが必要',
      'add_alarm_tooltip': 'アラームを追加',
      'entry_trigger': '入場',
      'exit_trigger': '退場',
      'entry_exit_trigger': '入場/退場',
      'am_label': '午前',
      'pm_label': '午後',
      'hour_suffix': '時',
      'min_suffix': '分',
      'after_suffix': ' 以降',
      'first_trigger_immediate': '最初の{trigger}でアラーム',
      'first_trigger_condition': '{conditions} 最初の{trigger}時',
      'monthly_date': '{month}月{day}日({weekday})',
      'weekly_prefix': '毎週 {days}',
      'listening_prompt': '🎙️ 聞いています... 話してください！',
      'done_btn': '完了',
      'alarm_name_label': 'アラーム名',
      'no_name_label': '名前なし',
      'select_place_label': '場所を選択',
      'alarm_on_entry_label': '入場時アラーム',
      'alarm_on_exit_label': '退場時アラーム',
      'boundary_warning':
          'ジオフェンスの境界付近では、滞在または往復するとアラームが複数回鳴る場合があります。 '
          '「スヌーズ」ボタンでアラームを遅らせることができます。',
      'condition_settings': '条件設定（オプション）',
      'condition_hint': '条件なしで保存すると、最初の入場/退場時にアラームが鳴ります。',
      'no_date_set': '日付指定なし',
      'time_condition_hint': '時間条件設定（オプション）',
      'time_after': '⏰ {time} 以降',
      'holidays_off': '祝日はオフ',
      'holidays_sub_on': '代替/臨時祝日にはオン',
      'alarm_sound_label': 'アラーム音',
      'alarm_sound_default': 'デバイスのデフォルトアラーム音',
      'alarm_sound_unchangeable': '変更不可',
      'save_btn': '保存',
      'delete_btn': '削除',
      'edit_alarm_title': '位置アラームを編集',
      'select_place_hint': '場所を選択してください',
      'select_place_required': '場所を選択してください',
      'alarm_save_failed': 'アラームの保存に失敗しました: {error}',
      // 장소 추가 페이지
      'address_search_result': '住所検索結果',
      'save_place_title': '場所を保存',
      'place_name_label': '場所の名前',
      'place_name_hint': '例：自宅、会社、ジム',
      'radius_display': '半径: {radius}m',
      'radius_shown_on_map': '（地図上に円で表示）',
      'cancel_btn': 'キャンセル',
      'save_place_btn': '保存',
      'place_saved_msg': '✅ 場所を保存しました',
      'select_on_map': '地図で場所を選択',
      'move_to_current': '現在地に移動',
      'search_hint': '住所または場所名（例：スターバックス）',
      'no_search_result': '検索結果がありません',
      'address_label': '住所: {address}',
      'radius_label_prefix': '半径: ',
      'custom_input': 'カスタム',
      'save_location_btn': '場所を保存',
      'signal_warning':
          '📍 半径設定のガイド\n'
          '• GPS不安定ゾーン（地下・高層ビル・電波障害エリアなど）では誤発動が起こることがあります。\n'
          '  一時的な誤発動は「⚡ 誤発動」ボタンで簡単に処理できます。\n'
          '• ゾーン境界付近に留まっている場合、誤発動ボタンを押してもアラームが繰り返し発動することがあります。\n'
          '  その場合はアラームを無効にし、必要なときに再度有効にしてください。\n'
          '• 誤発動が多い場合は、半径を10mずつ広げてテストしてみてください。',
      'radius_guide_btn': '📍 半径設定ガイド  —  必読!!',
      'radius_guide_dialog_body':
          '📍 GPS精度の限界\n'
          'GPSはおおよその位置しか把握できず、屋外でも'
          '数m〜数十mの誤差が常に存在します。設定した半径に正確に一致しない場合があります。\n\n'
          '📡 GPS信号のブレ\n'
          'GPS不安定な環境（地下・高層ビル・電波障害エリアなど）では、半径の検出誤差が大きくなることがあります。'
          '実際には半径内にいるのにGPSが一時的に半径外と判定したり、逆のケースも起こり得ます。\n'
          'そのような場合は「⚡ 誤発動」ボタンをご活用ください。'
          '同じ問題が繰り返し起きる場合は、半径を10mずつ広げてテストしてみてください。\n\n'
          '💡 設定した半径の境界付近に留まったり行動する場合\n'
          '誤発動ボタンを押してもアラームが繰り返し発動する場合があります。'
          'その場合はアラームを無効にして、必要なときに再度有効にしてください。\n'
          '(「Standby」モード — 要望が多ければ導入検討: 設定した時間後に自動再有効化)',
      'radius_input_title': '半径を入力',
      'radius_input_range': '30m 〜 500m（10m単位）',
      // 약관 페이지
      'terms_agreement_title': '利用規約への同意（必須）',
      'terms_agree_text': '利用規約および返金/サブスクリプションポリシーを確認し、同意します。',
      'terms_agree_btn': '同意して続行',
      'terms_disagree_btn': '同意しない（アプリを終了）',
      'terms_save_failed': '規約の保存に失敗しました。もう一度お試しください。',
      // 알람음 설정
      'alarm_sound_setting_title': 'アラーム音設定',
      'alarm_disabled_label': 'アラーム無効',
      // add_alarm_page
      'add_alarm_new_title': '新しいアラームを追加',
      'edit_alarm_modify_title': '位置アラームを編集',
      'location_fixed_text': 'このアラームはこの場所に固定されています',
      'no_place_label': '場所なし',
      'required_fields_msg': '必須項目をすべて設定してください。',
      'holidays_dialog_title': '代替/臨時祝日設定',
      'holidays_sub_off': '代替/臨時祝日にもオフ',
      // my_places_page
      'delete_confirm_title': '削除確認',
      'delete_locked_msg': 'ロックされた場所を削除しますか？',
      'delete_place_msg': '本当にこの場所を削除しますか？',
      'linked_alarm_delete_warning': '⚠️ リンクされた{count}件のアラームも削除されます。',
      'edit_places_menu': '場所を編集',
      'add_alarm_menu': '新しいアラームを追加',
      'add_place_tooltip': '新しい場所を追加',
      // show_alarm_popup_page
      'alarm_end_confirm': 'アラームを終了しますか？',
      'no_label': 'いいえ',
      'yes_label': 'はい',
      'snooze_btn': 'スヌーズ',
      'alarm_stop_btn': 'アラーム停止',
      // snooze/vibration setting
      'snooze_setting_title': 'スヌーズ設定',
      'vibration_setting_title': 'バイブレーション設定',
      // permission
      'permission_setting_title': '権限設定',
      'permission_allow': '許可',
      'battery_opt_title': 'バッテリー最適化を無効にする',
      'battery_opt_msg':
          'バックグラウンドでアラームが正常に動作するには、バッテリー最適化を無効にする必要があります。\n設定で「バッテリー最適化」を見つけ、Ringinoutを「最適化しない」に設定してください。',
      'open_settings_btn': '設定を開く',
      'later_btn': '後で',
      // subscription management
      'subscription_mgmt_title': 'サブスクリプション管理',
      'subscription_policy_btn': 'サブスクリプションポリシー',
      'refund_policy_btn': '返金ポリシー',
      'auto_renew_msg': '31日ごとに自動更新されます。',
      'agree_auto_pay': '自動決済に同意します。',
      'agree_policy': 'サブスクリプション/返金ポリシーを確認しました。',
      'start_auto_subscription': '自動サブスクリプション開始',
      'current_plan': '現在のプラン',
      'cancel_subscription': '解約',
      'subscribe_btn': '購読する',
      'auto_subscribe_btn': '自動購読',
      'beta_no_paid_plans': 'ベータ期間中は有料プランは提供されません。ベータ終了後に公開されます。',
      'places_5': '場所5件',
      'active_alarms_10': 'アクティブアラーム10件',
      'ad_free_included': '広告除去含む',
      'places_alarms_unlimited': '場所/アラーム無制限',
      'ad_remove_title': '広告除去',
      'in_app_ad_remove': 'アプリ内広告除去',
      'price_loading': '価格読み込み中',
      'duration_1month': '1ヶ月',
      'duration_3months': '3ヶ月',
      'duration_6months': '6ヶ月',
      'duration_12months': '12ヶ月',
      'discount_5': '5%割引',
      'discount_10': '10%割引',
      'discount_20': '20%割引',
      'expiry_date_none': '有効期限: -',
      'expiry_date_format': '有効期限: {date}',
      'beta_sub_activate_later': 'ベータ終了後にサブスクリプションが有効になります。',
      // subscription limit dialog
      'place_limit_title': '場所登録上限',
      'place_limit_msg':
          '{plan}プランでは場所を{limit}件まで登録できます。\n既存の場所を削除するかアップグレードしてください。',
      'alarm_limit_title': 'アラーム登録上限',
      'alarm_limit_msg':
          '{plan}プランではアクティブアラームを{limit}件まで設定できます。\n既存のアラームを削除するかアップグレードしてください。',
      'close_btn': '閉じる',
      // location picker
      'place_name_input_title': '場所名入力',
      'radius_default_info': '半径: 100m（後で変更可能）',
      'location_select_title': '位置選択',
      'fetching_location': '現在地を取得中...',
      'location_saved': '📍 位置が保存されました！',
      // 로그인 추가
      'dev_test_mode': '開発者テストモード',
      'test_login_failed': 'テストログイン失敗: {error}',
      // 맵 전환
      'switch_to_google': 'Googleマップに切替',
      'switch_to_naver': 'NAVERマップに切替',
      // 無料プラン マップ使用案内 (해외: Google)
      'map_free_limit_exceeded_title': '無料プランの上限',
      'map_free_limit_exceeded_body':
          '今月のGoogleマップ起動回数（{limit}回）をすべて使い切りました。\n\n'
          'OSMはいつでも無制限に利用できます。\n'
          '制限なく使いたい場合は有料プランへアップグレードしてください。',
      'map_switch_confirm_title': 'Googleマップに切替',
      'map_switch_confirm_body':
          '無料プランはGoogleマップを月{limit}回利用できます。\n\n'
          '残り回数: {remaining}/{limit}回\n\n'
          'Googleマップに切り替えると1回消費されます。\n'
          'OSMは消費なしで無制限に利用できます。',
      'map_switch_btn_cancel': 'キャンセル',
      'map_switch_btn_confirm': '切替',
      // 誤発動 / アラーム画面
      'btn_snooze': 'もう一度鳴らす',
      'btn_dismiss': 'アラーム終了',
      'btn_false_trigger': '誤発動',
      'false_trigger_hint': 'GPSエラーで誤作動した場合',
      'snooze_time_title': 'スヌーズ時間を選択',
      'snooze_min': '{m}分後',
      // 誤発動 案内タイル
      'false_trigger_info_title': '⚡ 誤発動ボタンとは？',
      'false_trigger_info_subtitle': 'GPSエラーで誤作動した場合、アラームを維持して終了',
      'false_trigger_dialog_title': '誤発動ボタンとは？',
      'false_trigger_dialog_body':
          'アラームが鳴ると「もう一度鳴らす」「アラーム終了」の他に'
          '「⚡ 誤発動」ボタンが表示されます。\n\n'
          '「⚡ 誤発動」をタップすると:\n'
          '  • 鳴り音・振動が即座に止まります\n'
          '  • アラームは無効化されずに維持されます\n'
          '  • 最初から再発動できる状態になります\n\n'
          '📍 GPS精度の限界\n'
          'GPSはおおよその位置しか把握できず、屋外でも'
          '数m〜数十mの誤差が常に存在します。'
          'アラームが少し早くまたは遅く鳴ることがあります。\n\n'
          '📡 GPS信号のブレ\n'
          'GPS不安定な環境（地下・高層ビル・電波障害エリアなど）では、半径の検出誤差が大きくなることがあります。'
          '実際には半径内にいるのにGPSが一時的に半径外と判定したり、逆のケースも起こり得ます。\n'
          'そのような場合は「⚡ 誤発動」ボタンをご活用ください。'
          '同じ問題が繰り返し起きる場合は、半径を10mずつ広げてテストしてみてください。\n\n'
          '💡 設定した半径の境界付近に留まったり行動する場合\n'
          '誤発動ボタンを押してもアラームが繰り返し発動する場合があります。'
          'その場合はアラームを無効にして、必要なときに再度有効にしてください。\n'
          '(「Standby」モード — 要望が多ければ導入検討: 設定した時間後に自動再有効化)',
      'false_trigger_dialog_ok': 'OK',
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
      'nav_voice': '语音',
      'nav_subscription': '订阅管理',

      // 페이지 타이틀
      'page_title_alarm': '位置闹钟',
      'page_title_places': '我的位置',
      'page_title_voice': '语音识别',
      'page_title_subscription': '订阅管理',

      // 선택 모드
      'select_all': '全选',
      'delete_selected': '删除',

      // 알람 페이지
      'alarm_title': 'Ringinout 闹钟',
      'location_alarm': '位置闹钟',
      'basic_alarm': '基本闹钟',
      'basic_alarm_page': '基本闹钟页面',
      'sort_options': '排序方式',
      'sort_by_time': '按时间排序',
      'sort_custom': '自定义顺序',
      'sort_place_asc': '地点名 (升序)',
      'sort_place_desc': '地点名 (降序)',
      'sort_name_asc': '闹钟名 (升序)',
      'sort_name_desc': '闹钟名 (降序)',
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
      'radius': '半径',
      'custom': '自定义',
      'custom_radius': '自定义半径',

      // 알람 추가/편집
      'add_location_alarm': '添加位置闹钟',
      'edit_location_alarm': '编辑位置闹钟',
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

      // 공휴일 국가 설정
      'holiday_country': '节假日国家',
      'holiday_country_auto': '自动',
      'holiday_country_auto_detected': '自动 (检测到: {country})',
      'holiday_country_auto_detecting': '自动 (检测中...)',
      'country_KR': '韩国',
      'country_US': '美国',
      'country_JP': '日本',
      'country_CN': '中国',
      'country_VN': '越南',
      'country_MY': '马来西亚',
      'country_TH': '泰国',
      'country_CA': '加拿大',
      'country_BR': '巴西',
      'country_TW': '台湾',

      // 알람 그룹핑
      'alarm_count': '{count}个闹钟',
      'alarm_count_one': '1个闹钟',
      'other_places': '其他',

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

      // 电池案内
      'battery_info_text_prefix': '有活动闹钟时，应用关闭后会自动重启。\n为了稳定的闹钟运行，',
      'battery_info_text_action': '排除电池优化',
      'battery_info_text_suffix': '会更稳定。',
      'battery_info_text': '有活动闹钟时，应用关闭后会自动重启。\n为了稳定的闹钟运行，建议排除电池优化。',
      'battery_opt_exclude': '排除电池优化',
      'no_saved_alarms': '没有保存的闹钟。',

      // 欢迎/登录
      'get_started': '开始使用',

      // 语音页面
      'voice_main_title': '用语音注册闹钟',
      'voice_example_phrase': '"到公司时提醒我"',
      'voice_tap_to_start': '点击开始',
      'voice_widget_title': '添加主屏幕小组件',
      'voice_widget_subtitle': '点击主屏小组件直接开始语音识别！',
      'voice_widget_guide_title': '添加主屏幕小组件',
      'voice_widget_guide_subtitle': '更快地开始语音闹钟！',
      'voice_widget_step1': '长按主屏幕空白处',
      'voice_widget_step2': '选择"小组件"菜单',
      'voice_widget_step3': '搜索"ringinout"或"语音闹钟"',
      'voice_widget_step4': '将小组件拖到主屏幕',
      'voice_widget_tip': '添加小组件后，无需打开应用\n即可从主屏幕直接开始语音闹钟！',
      'voice_widget_got_it': '知道了！',
      'voice_tip_title': '💡 语音识别示例',
      'voice_tip_examples':
          '• "周一到公司时提醒我"\n'
          '  → 每周一，进入时\n'
          '• "4月12日离开家时提醒我"\n'
          '  → 仅4/12，离开时\n'
          '• "周一6点后到家时提醒我"\n'
          '  → 每周一，18点后，进入时\n'
          '• "3月13日9点离家时提醒我"\n'
          '  → 3/13，9点后，离开时',
      'voice_tip_note': '星期、日期和时间会自动设置\n(GPS特性，边界识别可能有数十秒误差)',
      'voice_first_visit_title': '💡 小贴士！',
      'voice_first_visit_desc': '在主屏幕添加小组件\n无需打开应用\n即可开始语音闹钟！',
      'voice_first_visit_btn': '查看添加方法',
      'voice_first_visit_later': '以后再说',

      // 订阅页面
      'subscription_tab': '订阅管理',
      'subscription_current_plan': '当前方案',
      'subscription_expires': '到期: {date}',
      'subscription_free_plan': '免费方案',
      'subscription_unlimited': '无限制',
      'subscription_places_n': '{n}个地点',
      'subscription_alarms_n': '{n}个活动闹钟',
      'subscription_places_unlimited': '地点无限制',
      'subscription_alarms_unlimited': '闹钟无限制',
      'subscription_no_ads': '无广告',
      'subscription_all_unlimited': '所有功能无限制',
      'subscription_dev_plan': '开发者方案 - 所有功能无限制',
      'subscription_subscribe': '订阅',
      'subscription_in_use': '使用中',
      'subscription_recommended': '推荐',
      'subscription_coming_soon': '订阅功能正在准备中。',
      'subscription_beta_notice': '测试期间不提供付费方案。测试结束后将开放。',
      'subscription_per_month': '/ 月',
      'subscription_policy': '订阅政策',
      'subscription_refund_policy': '退款政策',

      // 알람 추가/편집 페이지 추가 키
      'plan_upgrade_needed': '套餐升级需要',
      'add_alarm_tooltip': '添加闹钟',
      'entry_trigger': '进入',
      'exit_trigger': '离开',
      'entry_exit_trigger': '进入/离开',
      'am_label': '上午',
      'pm_label': '下午',
      'hour_suffix': '时',
      'min_suffix': '分',
      'after_suffix': ' 之后',
      'first_trigger_immediate': '首次{trigger}时闹钟',
      'first_trigger_condition': '{conditions} 首次{trigger}时',
      'monthly_date': '{month}月{day}日({weekday})',
      'weekly_prefix': '每周 {days}',
      'listening_prompt': '🎙️ 正在听... 请说话！',
      'done_btn': '完成',
      'alarm_name_label': '闹钟名称',
      'no_name_label': '无名称',
      'select_place_label': '选择地点',
      'alarm_on_entry_label': '进入时闹钟',
      'alarm_on_exit_label': '离开时闹钟',
      'boundary_warning':
          '在地理围栏边界附近停留或来回移动时，闹钟可能会响多次。'
          '可以使用"稍后提醒"按钮延迟闹钟。',
      'condition_settings': '条件设置（可选）',
      'condition_hint': '不设条件保存时，首次进入/离开时闹钟会响。',
      'no_date_set': '未指定日期',
      'time_condition_hint': '时间条件设置（可选）',
      'time_after': '⏰ {time} 之后',
      'holidays_off': '节假日关闭',
      'holidays_sub_on': '替代/临时节假日开启',
      'alarm_sound_label': '闹钟铃声',
      'alarm_sound_default': '设备默认闹钟声',
      'alarm_sound_unchangeable': '无法更改',
      'save_btn': '保存',
      'delete_btn': '删除',
      'edit_alarm_title': '编辑位置闹钟',
      'select_place_hint': '请选择地点',
      'select_place_required': '请选择地点',
      'alarm_save_failed': '保存闹钟失败: {error}',
      // 장소 추가 페이지
      'address_search_result': '地址搜索结果',
      'save_place_title': '保存地点',
      'place_name_label': '地点名称',
      'place_name_hint': '例如：家、公司、健身房',
      'radius_display': '半径: {radius}m',
      'radius_shown_on_map': '（在地图上以圆圈显示）',
      'cancel_btn': '取消',
      'save_place_btn': '保存',
      'place_saved_msg': '✅ 地点已保存',
      'select_on_map': '在地图上选择位置',
      'move_to_current': '移动到当前位置',
      'search_hint': '地址或地点名称',
      'no_search_result': '没有搜索结果',
      'address_label': '地址: {address}',
      'radius_label_prefix': '半径: ',
      'custom_input': '自定义',
      'save_location_btn': '保存位置',
      'signal_warning':
          '📍 半径设置说明\n'
          '• 在GPS不稳定区域（地下、高层建筑、信号受阻区域等），可能发生误触发。\n'
          '  偶发的误触发可通过「⚡ 误触发」按钮快速处理。\n'
          '• 在区域边界附近停留时，即使点击误触发按钮，闹钟也可能持续响铃。\n'
          '  此时请禁用该闹钟，需要时再重新启用。\n'
          '• 误触发频繁时，请尝试每次将半径增加10m进行测试。',
      'radius_guide_btn': '📍 半径设置说明  —  必读!!',
      'radius_guide_dialog_body':
          '📍 GPS精度限制\n'
          'GPS只能提供大致位置，即使在屋外也存在数米到数十米的误差。'
          '设定的半径可能并不能精确匹配。\n\n'
          '📡 GPS信号漂移\n'
          '在GPS不稳定环境（地下、高层建筑、信号受阻区域等）中，半径检测误差可能增大。'
          '即使实际在半径内，GPS也可能暂时将您判定为在半径外，反之亦然。\n'
          '遇到这种情况请使用「⚡ 误触发」按钮。'
          '若同样问题频繁发生，请尝试每次将半径增加10m进行测试。\n\n'
          '💡 需要在设定半径边界附近停留或活动时\n'
          '即使点击误触发按钮，闹钟也可能继续响铃。'
          '此时请禁用该闹钟，需要时再重新启用。\n'
          '("Standby"模式 — 如需求较多将考虑引入: 设定时间后自动重新启用)',
      'radius_input_title': '输入半径',
      'radius_input_range': '30m ~ 500m（10m增量）',
      // 约款页面
      'terms_agreement_title': '服务条款同意（必需）',
      'terms_agree_text': '我已阅读并同意服务条款和退款/订阅政策。',
      'terms_agree_btn': '同意并继续',
      'terms_disagree_btn': '不同意（关闭应用）',
      'terms_save_failed': '保存条款失败。请重试。',
      // 闹钟音设置
      'alarm_sound_setting_title': '闹钟铃声设置',
      'alarm_disabled_label': '闹钟已禁用',
      // add_alarm_page
      'add_alarm_new_title': '新建闹钟',
      'edit_alarm_modify_title': '编辑位置闹钟',
      'location_fixed_text': '此闹钟绑定到该地点',
      'no_place_label': '无地点',
      'required_fields_msg': '请填写所有必填项。',
      'holidays_dialog_title': '替代/临时节假日设置',
      'holidays_sub_off': '替代/临时节假日也关闭',
      // my_places_page
      'delete_confirm_title': '确认删除',
      'delete_locked_msg': '删除此锁定位置？',
      'delete_place_msg': '确定要删除此位置吗？',
      'linked_alarm_delete_warning': '⚠️ 关联的{count}个闹钟也将被删除。',
      'edit_places_menu': '编辑地点',
      'add_alarm_menu': '新建闹钟',
      'add_place_tooltip': '添加新位置',
      // show_alarm_popup_page
      'alarm_end_confirm': '结束闹钟？',
      'no_label': '否',
      'yes_label': '是',
      'snooze_btn': '稍后提醒',
      'alarm_stop_btn': '停止闹钟',
      // snooze/vibration setting
      'snooze_setting_title': '稍后提醒设置',
      'vibration_setting_title': '振动设置',
      // permission
      'permission_setting_title': '权限设置',
      'permission_allow': '允许',
      'battery_opt_title': '关闭电池优化',
      'battery_opt_msg':
          '为了确保闹钟在后台正常运行，需要关闭电池优化。\n请在设置中找到“电池优化”，将Ringinout设为“不优化”。',
      'open_settings_btn': '打开设置',
      'later_btn': '稍后',
      // subscription management
      'subscription_mgmt_title': '订阅管理',
      'subscription_policy_btn': '订阅政策',
      'refund_policy_btn': '退款政策',
      'auto_renew_msg': '每31天自动续费。',
      'agree_auto_pay': '我同意自动付款。',
      'agree_policy': '我已查看订阅/退款政策。',
      'start_auto_subscription': '开始自动订阅',
      'current_plan': '当前套餐',
      'cancel_subscription': '取消',
      'subscribe_btn': '订阅',
      'auto_subscribe_btn': '自动订阅',
      'beta_no_paid_plans': '测试期间不提供付费套餐。测试结束后将公开。',
      'places_5': '5个地点',
      'active_alarms_10': '10个活动闹钟',
      'ad_free_included': '包含去广告',
      'places_alarms_unlimited': '地点/闹钟无限',
      'ad_remove_title': '去广告',
      'in_app_ad_remove': '应用内去广告',
      'price_loading': '价格加载中',
      'duration_1month': '1个月',
      'duration_3months': '3个月',
      'duration_6months': '6个月',
      'duration_12months': '12个月',
      'discount_5': '5%折扣',
      'discount_10': '10%折扣',
      'discount_20': '20%折扣',
      'expiry_date_none': '到期日: -',
      'expiry_date_format': '到期日: {date}',
      'beta_sub_activate_later': '测试结束后订阅将激活。',
      // subscription limit dialog
      'place_limit_title': '地点注册上限',
      'place_limit_msg': '{plan}套餐最多可注册{limit}个地点。\n请删除现有地点或升级。',
      'alarm_limit_title': '闹钟注册上限',
      'alarm_limit_msg': '{plan}套餐最多可设置{limit}个活动闹钟。\n请删除现有闹钟或升级。',
      'close_btn': '关闭',
      // location picker
      'place_name_input_title': '输入地点名称',
      'radius_default_info': '半径: 100m（可以稍后修改）',
      'location_select_title': '选择位置',
      'fetching_location': '正在获取当前位置...',
      'location_saved': '📍 位置已保存！',
      // 登录追加
      'dev_test_mode': '开发者测试模式',
      'test_login_failed': '测试登录失败: {error}',
      // 맵 전환
      'switch_to_google': '切换到Google地图',
      'switch_to_naver': '切换到Naver地图',
      // 免费套餐 地图使用提示 (해외: Google)
      'map_free_limit_exceeded_title': '免费套餐限制',
      'map_free_limit_exceeded_body':
          '本月Google地图打开次数（{limit}次）已全部用完。\n\n'
          'OSM地图可以无限次免费使用。\n'
          '如需无限次使用，请升级到付费套餐。',
      'map_switch_confirm_title': '切换到Google地图',
      'map_switch_confirm_body':
          '免费套餐每月可使用Google地图{limit}次。\n\n'
          '剩余次数: {remaining}/{limit}次\n\n'
          '切换到Google地图将消耗1次。\n'
          'OSM无需消耗，可无限使用。',
      'map_switch_btn_cancel': '取消',
      'map_switch_btn_confirm': '切换',
      // 误触发 / 闹钟界面
      'btn_snooze': '再次响铃',
      'btn_dismiss': '关闭闹钟',
      'btn_false_trigger': '误触发',
      'false_trigger_hint': 'GPS错误导致误触发',
      'snooze_time_title': '选择稍后提醒时间',
      'snooze_min': '{m}分钟后',
      // 误触发 说明
      'false_trigger_info_title': '⚡ 什么是误触发？',
      'false_trigger_info_subtitle': 'GPS误差触发时保持闹钟并退出',
      'false_trigger_dialog_title': '什么是误触发？',
      'false_trigger_dialog_body':
          '闹钟响铃时，除「再次响铃」「关闭闹钟」外，'
          '还会显示「⚡ 误触发」按钮。\n\n'
          '点击「⚡ 误触发」后：\n'
          '  • 铃声和振动立即停止\n'
          '  • 闹钟保持启用状态（不会被禁用）\n'
          '  • 可以从头再次触发\n\n'
          '📍 GPS精度限制\n'
          'GPS只能提供大致位置，即使在屋外也存在数米到数十米的误差。'
          '闹钟可能会稍早或稍晚响铃。\n\n'
          '📡 GPS信号漂移\n'
          '在GPS不稳定环境（地下、高层建筑、信号受阻区域等）中，半径检测误差可能增大。'
          '即使实际在半径内，GPS也可能暂时将您判定为在半径外，反之亦然。\n'
          '遇到这种情况请使用「⚡ 误触发」按钮。'
          '若同样问题频繁发生，请尝试每次将半径增加10m进行测试。\n\n'
          '💡 需要在设定半径边界附近停留或活动时\n'
          '即使点击误触发按钮，闹钟也可能继续响铃。'
          '此时请禁用该闹钟，需要时再重新启用。\n'
          '("Standby"模式 — 如需求较多将考虑引入: 设定时间后自动重新启用)',
      'false_trigger_dialog_ok': '确定',
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
