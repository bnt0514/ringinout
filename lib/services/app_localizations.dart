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
      'nav_alarm': 'Loc. Alarm',
      'nav_my_places': 'My Places',
      'nav_voice': 'Voice',
      'nav_gps': 'GPS',

      // 페이지 타이틀
      'page_title_alarm': 'Location Alarm',
      'page_title_gps': 'GPS',
      'page_title_places': 'My Places',
      'page_title_voice': 'Voice Recognition',
      'page_title_subscription': 'Subscription',

      // 탭 레이블
      'tab_location_alarm': 'Location Alarm',
      'tab_device_alarm': 'Device Alarm',
      'tab_my_places': 'My Places',
      'tab_my_devices': 'My Devices',
      'page_title_my_devices': 'My Devices',
      'page_title_device_alarm': 'Device Alarm',

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
      'no_places_desc': 'Tap the button below to add your first location.',
      'add_place_btn': 'Add Place',
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
      'delete_account': 'Delete Account',
      'delete_account_subtitle': 'Permanently delete all data',
      'delete_account_warning':
          'All your data including alarm settings, location data, and account information will be permanently deleted.\n\nThis action cannot be undone and your data cannot be recovered.',
      'delete_account_confirm': 'Delete',
      'delete_account_final_title': 'Final Confirmation',
      'delete_account_final_warning':
          'Are you absolutely sure?\nYour account and all associated data will be permanently deleted immediately.',
      'delete_account_final_confirm': 'Delete Permanently',
      'delete_account_failed': '❌ Account deletion failed. Please try again.',
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
      'country_DE': 'Germany',
      'country_FR': 'France',
      'country_ES': 'Spain',
      'country_IT': 'Italy',
      'country_NL': 'Netherlands',
      'country_SE': 'Sweden',
      'country_PL': 'Poland',
      'country_GB': 'United Kingdom',

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
      'no_saved_alarms_desc': 'Tap the button below to add your first alarm.',

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
      // 음성 탭
      'voice_tab_location': 'Location Voice',
      'voice_tab_device': 'Device Voice',
      'voice_device_main_title': 'Register device alarms by voice',
      'voice_device_example_phrase': '"Notify me when Galaxy Buds connect"',
      'voice_device_tip_title': '💡 Device Voice Examples',
      'voice_device_tip_examples':
          '• "Notify me when Galaxy Buds connect on Monday"\n'
          '  → Every Monday, on connect\n'
          '• "Alert me when earbuds disconnect on April 12"\n'
          '  → April 12 only, on disconnect\n'
          '• "Ring when Buds connect after 6 on Monday"\n'
          '  → Every Monday, after 6:00, on connect\n'
          '• "Tell me when watch disconnects at 9 on March 13"\n'
          '  → March 13, after 9:00, on disconnect',
      'voice_device_tip_note':
          'Weekdays, dates & times are set automatically\n(Bluetooth state changes are detected in real time)',
      'voice_first_visit_title': '💡 Pro Tip!',
      'voice_first_visit_desc':
          'Add a widget to your home screen\nto start voice alarms\nwithout opening the app!',
      'voice_first_visit_btn': 'See how to add widget',
      'voice_first_visit_later': 'Maybe later',

      // 구독 페이지
      'subscription_tab': 'Subscription',
      'gps_tab': 'GPS',
      // GPS page
      'gps_current_location': 'Current Location',
      'gps_latitude': 'Latitude',
      'gps_longitude': 'Longitude',
      'gps_accuracy': 'Accuracy',
      'gps_accuracy_good': 'Good',
      'gps_accuracy_fair': 'Fair',
      'gps_accuracy_poor': 'Poor',
      'gps_updated_at': 'Updated',
      'gps_no_location': 'No location data',
      'gps_alarm_status': 'Location Alarm Status',
      'gps_stopped': 'Stopped',
      'gps_inside': 'Inside',
      'gps_outside': 'Outside',
      'gps_moving': 'Moving',
      'gps_alarms': 'Alarms',
      'gps_place_status': 'Place Status',
      'gps_place_status_refresh_tooltip': 'Refresh place status',
      'gps_no_tracked_places': 'No tracked places',
      'gps_place_status_updated': '{count} place(s) status refreshed',
      'gps_entry': 'Entry',
      'gps_exit': 'Exit',
      'gps_bug_report': 'Bug Report',
      'gps_bug_report_sending': 'Sending...',
      'gps_bug_report_title': 'Bug Report',
      'gps_refresh_tooltip': 'Refresh GPS',
      'subscription_current_plan': 'Current Plan',
      'subscription_expires': 'Expires: {date}',
      'subscription_free_plan': 'Free Plan',
      'subscription_unlimited': 'Unlimited',
      'subscription_places_n': '{n} places',
      'subscription_alarms_n': '{n} active alarms',
      'subscription_places_unlimited': 'Unlimited places',
      'subscription_alarms_unlimited': 'Unlimited alarms',
      'subscription_map_opens_50': '50 map opens/month',
      'subscription_map_opens_unlimited': 'Unlimited map opens',
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
      'subscription_price_tbd': 'Pricing TBD',
      'subscription_pro_fair_use':
          'Fair use policy: up to 500 map opens per month to prevent abuse.',
      'subscription_map_opens_500': '500 map opens/month',

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
      'auto_renew_msg': 'Auto-renewed according to Google Play policies.',
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

      // Bluetooth device alarm — unintended trigger guide
      'bt_false_trigger_info_title': '⚡ Unintended Alarm?',
      'bt_false_trigger_info_subtitle':
          'Alarm fired without your intent? Here\'s what to do',
      'bt_false_trigger_dialog_title': 'Unintended Alarm?',
      'bt_false_trigger_dialog_body':
          'Bluetooth alarms fire when a connection or disconnection\n'
          'lasts 15 seconds or more. This is by design — but life\n'
          'doesn\'t always go as planned.\n\n'
          'When the alarm fires, tap "⚡ False Trigger" to stop the ringtone\n'
          'while keeping the alarm active for next time.\n\n'
          '💡 Tip: Use day-of-week or time conditions to greatly reduce\n'
          'unwanted triggers during other times of day.',
      'bt_bonded_devices_title': 'Paired Bluetooth Devices',
      'bt_refresh_tooltip': 'Refresh device list',
      'bt_selector_description':
          'Select paired Bluetooth devices to detect for this place.',
      'bt_permission_needed':
          'Bluetooth permission is required.\nPlease allow Bluetooth access in Settings.',
      'bt_no_bonded_devices': 'No paired Bluetooth devices found.',
      'bt_selected_count': '{count} device(s) selected',
      'bt_device_retained': 'Previously saved (not currently paired)',
      'bt_devices_label': 'Bluetooth Devices',
      'bt_none_selected': 'None selected',
      'bt_count_selected': '{count} selected',

      // Device Alarm (independent BT device alarms)
      'device_alarm_empty': 'No device alarms',
      'device_alarm_empty_desc':
          'Add a Bluetooth device alarm to get notified\nwhen a device connects or disconnects.',
      'device_alarm_add': 'Add Device Alarm',
      'device_alarm_delete_confirm': 'Delete this device alarm?',
      'device_alarm_select_device': 'Select Device',
      'device_alarm_name_label': 'Alarm Name',
      'device_alarm_name_hint': 'Enter alarm name',
      'device_alarm_trigger_label': 'Trigger When',
      'device_trigger_connect': 'Connected',
      'device_trigger_disconnect': 'Disconnected',

      // My Devices
      'my_devices_empty': 'No registered devices',
      'my_devices_empty_desc':
          'Bluetooth devices registered to places or\ndevice alarms will appear here.',
      'my_devices_source_place': 'Place',
      'my_devices_source_alarm': 'Alarm',
      'my_devices_add': 'Add Device',
      'my_devices_add_title': 'Add Bluetooth Device',
      'my_devices_custom_name_label': 'Custom Name',
      'my_devices_custom_name_hint': 'Enter a name you can easily remember',
      'my_devices_original_name': 'Bluetooth Name',
      'my_devices_edit_name': 'Edit Name',
      'edit_device_menu': 'Edit Device',
      'add_device_alarm_menu': 'Add New Alarm',
      'my_devices_delete_confirm': 'Remove this device?',
      'my_devices_source_manual': 'Manual',

      // Add alarm (fixed bottom bar)
      'add_alarm_btn': 'Add Alarm',
      'add_device_alarm_btn': 'Add Alarm',

      // Device alarm page
      'device_alarm_page_title': 'Add Device Alarm',
      'device_alarm_edit_title': 'Edit Device Alarm',
      'add_new_device_alarm': 'Add New Device Alarm',
      'select_device_label': 'Select Device',
      'alarm_on_connect_label': 'Alarm on Connect',
      'alarm_on_disconnect_label': 'Alarm on Disconnect',
      'device_condition_hint':
          'Without conditions, the alarm fires on the first connect/disconnect.',
      'device_alarm_voice_section': 'Voice Recognition',
      'device_alarm_voice_msg_label': 'Voice Message',
      'device_alarm_voice_msg_hint': 'Message to announce when alarm triggers',
      'device_alarm_voice_enabled': 'Enable voice notification',
      'device_alarm_sound_section': 'Alarm Sound',
      'device_alarm_save_success': 'Device alarm saved',

      // Wi-Fi
      'wifi_networks_label': 'Wi-Fi Networks',
      'wifi_none_selected': 'None selected',
      'wifi_count_selected': '{count} selected',
      'wifi_rescan_tooltip': 'Rescan',
      'wifi_description':
          'Use Wi-Fi connection for more accurate location detection.',
      'wifi_disabled': 'Wi-Fi is turned off',
      'wifi_disabled_detail':
          'Wi-Fi is turned off. Please enable Wi-Fi and try again.',
      'wifi_scan_failed': 'Wi-Fi scan failed',
      'wifi_no_networks': 'No Wi-Fi networks detected.',
      'wifi_networks_selected': '{count} network(s) selected',
      'wifi_hidden_network': '(Hidden network)',
      'wifi_currently_connected': 'Currently connected',
      'wifi_previously_saved': 'Previously saved (not detected now)',
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
      'nav_alarm': '위치알람',
      'nav_my_places': '내 장소',
      'nav_voice': '음성',
      'nav_gps': 'GPS',

      // 페이지 타이틀
      'page_title_alarm': '위치 알람',
      'page_title_places': '내 장소',
      'page_title_voice': '음성 인식',
      'page_title_gps': 'GPS',
      'page_title_subscription': '구독 관리',

      // 탭 레이블
      'tab_location_alarm': '위치 알람',
      'tab_device_alarm': '기기 알람',
      'tab_my_places': '내 장소',
      'tab_my_devices': '내 기기',
      'page_title_my_devices': '내 기기',
      'page_title_device_alarm': '기기 알람',

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
      'no_places_desc': '아래 버튼을 눌러 첫 번째 장소를 추가하세요.',
      'add_place_btn': '장소 추가',
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
      'delete_account': '회원 탈퇴',
      'delete_account_subtitle': '모든 데이터가 영구 삭제됩니다',
      'delete_account_warning':
          '알람 설정, 위치 데이터, 계정 정보 등 모든 데이터가 영구적으로 삭제됩니다.\n\n이 작업은 취소할 수 없으며, 삭제된 데이터는 복구할 수 없습니다.',
      'delete_account_confirm': '탈퇴하기',
      'delete_account_final_title': '최종 확인',
      'delete_account_final_warning':
          '정말 탈퇴하시겠습니까?\n계정과 모든 관련 데이터가 즉시 영구 삭제됩니다.',
      'delete_account_final_confirm': '영구 삭제',
      'delete_account_failed': '❌ 계정 삭제에 실패했습니다. 다시 시도해 주세요.',
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
      'country_DE': '독일',
      'country_FR': '프랑스',
      'country_ES': '스페인',
      'country_IT': '이탈리아',
      'country_NL': '네덜란드',
      'country_SE': '스웨덴',
      'country_PL': '폴란드',
      'country_GB': '영국',

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
      'no_saved_alarms_desc': '아래 버튼을 눌러 첫 번째 알람을 추가하세요.',

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
      // 음성 탭
      'voice_tab_location': '위치 음성',
      'voice_tab_device': '기기 음성',
      'voice_device_main_title': '말로 기기 알람을 등록하세요',
      'voice_device_example_phrase': '"갤럭시 버즈 연결되면 알려줘"',
      'voice_device_tip_title': '💡 기기 음성 인식 예시',
      'voice_device_tip_examples':
          '• "월요일에 갤럭시 버즈 연결되면 알려줘"\n'
          '  → 매주 월요일, 연결 시\n'
          '• "4월 12일에 이어폰 연결 해제되면 알려줘"\n'
          '  → 4/12 하루, 연결 해제 시\n'
          '• "월요일 6시 이후 버즈 연결되면 알려줘"\n'
          '  → 매주 월요일, 오후 6시 이후 연결 시\n'
          '• "3월 13일 9시에 시계 연결 끊기면 알려줘"\n'
          '  → 3/13, 오전 9시 이후 연결 해제 시',
      'voice_device_tip_note':
          '요일·날짜·시간이 자동으로 설정됩니다\n(블루투스 상태 변화를 실시간으로 감지합니다)',
      'voice_first_visit_title': '💡 꿀팁!',
      'voice_first_visit_desc':
          '홈 화면에 위젯을 추가하면\n앱을 열지 않고도 바로\n음성 알람을 시작할 수 있어요!',
      'voice_first_visit_btn': '위젯 추가 방법 보기',
      'voice_first_visit_later': '나중에 할게요',

      // 구독 페이지
      'subscription_tab': '구독 관리',
      'gps_tab': 'GPS',
      // GPS page
      'gps_current_location': '현재 위치',
      'gps_latitude': '위도',
      'gps_longitude': '경도',
      'gps_accuracy': '정확도',
      'gps_accuracy_good': '좋음',
      'gps_accuracy_fair': '보통',
      'gps_accuracy_poor': '불량',
      'gps_updated_at': '갱신',
      'gps_no_location': '위치 정보 없음',
      'gps_alarm_status': '위치 알람 상태',
      'gps_stopped': '중지됨',
      'gps_inside': '내부',
      'gps_outside': '외부',
      'gps_moving': '이동 중',
      'gps_alarms': '알람',
      'gps_place_status': '장소별 상태',
      'gps_place_status_refresh_tooltip': '장소 상태 새로고침',
      'gps_no_tracked_places': '추적 중인 장소 없음',
      'gps_place_status_updated': '{count}개 장소 상태 갱신 완료',
      'gps_entry': '진입',
      'gps_exit': '진출',
      'gps_bug_report': '버그 리포트',
      'gps_bug_report_sending': '전송 중…',
      'gps_bug_report_title': '버그 리포트',
      'gps_refresh_tooltip': 'GPS 갱신',
      'subscription_current_plan': '현재 플랜',
      'subscription_expires': '만료: {date}',
      'subscription_free_plan': '무료 플랜',
      'subscription_unlimited': '무제한',
      'subscription_places_n': '장소 {n}개',
      'subscription_alarms_n': '활성 알람 {n}개',
      'subscription_places_unlimited': '장소 무제한',
      'subscription_alarms_unlimited': '알람 무제한',
      'subscription_map_opens_50': '맵 오픈 월 50회',
      'subscription_map_opens_unlimited': '맵 오픈 무제한',
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
      'subscription_price_tbd': '가격 추후 안내',
      'subscription_pro_fair_use':
          '공정 사용 정책: 어뷰즈 방지를 위해 월 최대 500회 지도 열기 한도가 있습니다.',
      'subscription_map_opens_500': '맵 오픈 월 500회',

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
      'auto_renew_msg': 'Google Play 정책에 따라 자동 갱신됩니다.',
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

      // 블루투스 기기 알람 — 의도치 않은 발동 안내
      'bt_false_trigger_info_title': '⚡ 의도치 않게 울렸나요?',
      'bt_false_trigger_info_subtitle': '예상치 못한 상황에서 울린 경우, 이렇게 활용하세요',
      'bt_false_trigger_dialog_title': '의도치 않게 울렸나요?',
      'bt_false_trigger_dialog_body':
          '블루투스 알람은 연결·해제 상태가 15초 이상 지속되면 발동합니다.\n'
          '정상 작동이지만, 다양한 변수로 인해 의도치 않은 상황에 발동할 수 있습니다.\n\n'
          '알람이 울릴 때 "⚡ 오발동" 버튼을 누르면\n'
          '벨소리는 바로 멈추고, 알람은 비활성화 없이 유지됩니다.\n\n'
          '💡 팁: 요일·시간 조건으로 의도치 않은 발동을 크게 줄일 수 있습니다.',
      'bt_refresh_tooltip': '기기 목록 새로고침',
      'bt_selector_description': '이 장소에서 감지할 페어링된 블루투스 기기를 선택하세요.',
      'bt_permission_needed': '블루투스 권한이 필요합니다.\n설정에서 블루투스 접근을 허용해주세요.',
      'bt_no_bonded_devices': '페어링된 블루투스 기기가 없습니다.',
      'bt_selected_count': '{count}개 기기 선택됨',
      'bt_device_retained': '이전에 저장됨 (현재 미페어링)',
      'bt_devices_label': '블루투스 기기',
      'bt_none_selected': '선택 안 함',
      'bt_count_selected': '{count}개 선택됨',

      // Device Alarm (독립형 BT 기기 알람)
      'device_alarm_empty': '기기 알람 없음',
      'device_alarm_empty_desc': '블루투스 기기 알람을 추가하면\n기기 연결/해제 시 알림을 받을 수 있습니다.',
      'device_alarm_add': '기기 알람 추가',
      'device_alarm_delete_confirm': '이 기기 알람을 삭제하시겠습니까?',
      'device_alarm_select_device': '기기 선택',
      'device_alarm_name_label': '알람 이름',
      'device_alarm_name_hint': '알람 이름을 입력하세요',
      'device_alarm_trigger_label': '알람 조건',
      'device_trigger_connect': '연결 시',
      'device_trigger_disconnect': '해제 시',

      // 내 기기
      'my_devices_empty': '등록된 기기 없음',
      'my_devices_empty_desc': '장소나 기기 알람에 등록된\n블루투스 기기가 여기에 표시됩니다.',
      'my_devices_source_place': '장소',
      'my_devices_source_alarm': '알람',
      'my_devices_add': '기기 추가',
      'my_devices_add_title': '블루투스 기기 추가',
      'my_devices_custom_name_label': '사용자 이름',
      'my_devices_custom_name_hint': '기억하기 쉬운 이름을 입력하세요',
      'my_devices_original_name': '블루투스 이름',
      'my_devices_edit_name': '이름 수정',
      'edit_device_menu': '내 기기 수정',
      'add_device_alarm_menu': '새 알람 추가',
      'my_devices_delete_confirm': '이 기기를 삭제하시겠습니까?',
      'my_devices_source_manual': '직접 추가',

      // 알람 추가 (고정 하단 바)
      'add_alarm_btn': '알람 추가',
      'add_device_alarm_btn': '알람 추가',

      // 기기 알람 페이지
      'device_alarm_page_title': '기기 알람 추가',
      'device_alarm_edit_title': '기기 알람 수정',
      'add_new_device_alarm': '새 기기알람 추가',
      'select_device_label': '기기 선택',
      'alarm_on_connect_label': '연결 시 알람',
      'alarm_on_disconnect_label': '해제 시 알람',
      'device_condition_hint': '조건 없이 저장하면 최초 연결/해제 시 알람이 울립니다.',
      'device_alarm_voice_section': '음성 인식',
      'device_alarm_voice_msg_label': '음성 메시지',
      'device_alarm_voice_msg_hint': '알람 발동 시 안내할 메시지',
      'device_alarm_voice_enabled': '음성 알림 사용',
      'device_alarm_sound_section': '알람 소리',
      'device_alarm_save_success': '기기 알람이 저장되었습니다',

      // Wi-Fi
      'wifi_networks_label': 'Wi-Fi 네트워크',
      'wifi_none_selected': '선택 안 함',
      'wifi_count_selected': '{count}개 선택됨',
      'wifi_rescan_tooltip': '다시 스캔',
      'wifi_description': 'Wi-Fi 연결로 더 정확한 위치 감지를 할 수 있습니다.',
      'wifi_disabled': 'Wi-Fi가 꺼져 있습니다',
      'wifi_disabled_detail': 'Wi-Fi가 꺼져 있습니다. Wi-Fi를 켜고 다시 시도해주세요.',
      'wifi_scan_failed': 'Wi-Fi 스캔 실패',
      'wifi_no_networks': '감지된 Wi-Fi 네트워크가 없습니다.',
      'wifi_networks_selected': '{count}개 네트워크 선택됨',
      'wifi_hidden_network': '(숨겨진 네트워크)',
      'wifi_currently_connected': '현재 연결됨',
      'wifi_previously_saved': '이전에 저장됨 (현재 감지 안 됨)',
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
      'nav_alarm': '位置アラーム',
      'nav_my_places': 'マイプレイス',
      'nav_voice': '音声',
      'nav_gps': 'GPS',

      // 페이지 타이틀
      'page_title_alarm': '位置アラーム',
      'page_title_places': 'マイプレイス',
      'page_title_voice': '音声認識',
      'page_title_gps': 'GPS',
      'page_title_subscription': 'サブスクリプション',

      // タブラベル
      'tab_location_alarm': '位置アラーム',
      'tab_device_alarm': 'デバイスアラーム',
      'tab_my_places': 'マイプレイス',
      'tab_my_devices': 'マイデバイス',
      'page_title_my_devices': 'マイデバイス',
      'page_title_device_alarm': 'デバイスアラーム',

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
      'no_places_desc': '下のボタンをタップして最初の場所を追加してください。',
      'add_place_btn': '場所を追加',
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
      'delete_account': 'アカウント削除',
      'delete_account_subtitle': 'すべてのデータが完全に削除されます',
      'delete_account_warning':
          'アラーム設定、位置データ、アカウント情報などすべてのデータが完全に削除されます。\n\nこの操作は取り消すことができず、削除されたデータは復元できません。',
      'delete_account_confirm': '削除する',
      'delete_account_final_title': '最終確認',
      'delete_account_final_warning':
          '本当に削除しますか？\nアカウントとすべての関連データが即座に完全削除されます。',
      'delete_account_final_confirm': '完全に削除',
      'delete_account_failed': '❌ アカウントの削除に失敗しました。もう一度お試しください。',
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
      'country_DE': 'ドイツ',
      'country_FR': 'フランス',
      'country_ES': 'スペイン',
      'country_IT': 'イタリア',
      'country_NL': 'オランダ',
      'country_SE': 'スウェーデン',
      'country_PL': 'ポーランド',
      'country_GB': 'イギリス',

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
      'no_saved_alarms_desc': '下のボタンをタップして最初のアラームを追加してください。',

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
      // 音声タブ
      'voice_tab_location': '位置音声',
      'voice_tab_device': 'デバイス音声',
      'voice_device_main_title': '音声でデバイスアラームを登録',
      'voice_device_example_phrase': '「Galaxy Budsが接続したら知らせて」',
      'voice_device_tip_title': '💡 デバイス音声認識の例',
      'voice_device_tip_examples':
          '• 「月曜日にGalaxy Budsが接続したら知らせて」\n'
          '  → 毎週月曜日、接続時\n'
          '• 「4月12日にイヤホンが切断されたら知らせて」\n'
          '  → 4/12のみ、切断時\n'
          '• 「月曜日の6時以降にBudsが接続したら知らせて」\n'
          '  → 毎週月曜日、18時以降、接続時\n'
          '• 「3月13日の9時に時計の接続が切れたら知らせて」\n'
          '  → 3/13、9時以降、切断時',
      'voice_device_tip_note':
          '曜日・日付・時間が自動設定されます\n(Bluetooth状態変化をリアルタイムで検知します)',
      'voice_first_visit_title': '💡 おすすめ！',
      'voice_first_visit_desc':
          'ホーム画面にウィジェットを追加すると\nアプリを開かなくても\n音声アラームを開始できます！',
      'voice_first_visit_btn': 'ウィジェットの追加方法を見る',
      'voice_first_visit_later': 'あとで',

      // サブスクリプションページ
      'subscription_tab': 'サブスクリプション',
      'gps_tab': 'GPS',
      // GPS page
      'gps_current_location': '現在地',
      'gps_latitude': '緯度',
      'gps_longitude': '経度',
      'gps_accuracy': '精度',
      'gps_accuracy_good': '良好',
      'gps_accuracy_fair': '普通',
      'gps_accuracy_poor': '不良',
      'gps_updated_at': '更新',
      'gps_no_location': '位置情報なし',
      'gps_alarm_status': '位置アラーム状態',
      'gps_stopped': '停止中',
      'gps_inside': '内部',
      'gps_outside': '外部',
      'gps_moving': '移動中',
      'gps_alarms': 'アラーム',
      'gps_place_status': '場所別ステータス',
      'gps_place_status_refresh_tooltip': '場所ステータス更新',
      'gps_no_tracked_places': '追跡中の場所なし',
      'gps_place_status_updated': '{count}か所のステータスを更新しました',
      'gps_entry': '入場',
      'gps_exit': '退場',
      'gps_bug_report': 'バグレポート',
      'gps_bug_report_sending': '送信中…',
      'gps_bug_report_title': 'バグレポート',
      'gps_refresh_tooltip': 'GPS更新',
      'subscription_current_plan': '現在のプラン',
      'subscription_expires': '期限: {date}',
      'subscription_free_plan': '無料プラン',
      'subscription_unlimited': '無制限',
      'subscription_places_n': '{n}か所',
      'subscription_alarms_n': 'アクティブアラーム{n}個',
      'subscription_places_unlimited': '場所無制限',
      'subscription_alarms_unlimited': 'アラーム無制限',
      'subscription_map_opens_50': 'マップ表示月50回',
      'subscription_map_opens_unlimited': 'マップ表示無制限',
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
      'subscription_price_tbd': '価格は後日お知らせ',
      'subscription_pro_fair_use': '公正利用ポリシー: 不正利用防止のため月最大500回のマップ表示制限があります。',
      'subscription_map_opens_500': 'マップ表示月500回',

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
      'auto_renew_msg': 'Google Playポリシーに従って自動更新されます。',
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

      // Bluetoothデバイスアラーム — 意図しない発動 案内
      'bt_false_trigger_info_title': '⚡ 意図せず鳴りましたか？',
      'bt_false_trigger_info_subtitle': '予期せぬ状況で鳴った場合の活用法',
      'bt_false_trigger_dialog_title': '意図せず鳴りましたか？',
      'bt_false_trigger_dialog_body':
          'Bluetoothアラームは、接続・切断状態が15秒以上続いた場合に発動します。\n'
          '正常な動作ですが、様々な事情で意図しないタイミングで鳴ることがあります。\n\n'
          'アラームが鳴ったら「⚡ 誤発動」をタップすると\n'
          '音はすぐ止まり、アラームは無効化されずに維持されます。\n\n'
          '💡 ヒント：曜日・時間条件を設定すると、意図しない発動を大幅に減らせます。',
      'bt_refresh_tooltip': 'デバイスリストを更新',
      'bt_selector_description': 'この場所で検出するペアリング済みBluetoothデバイスを選択してください。',
      'bt_permission_needed': 'Bluetooth権限が必要です。\n設定からBluetoothアクセスを許可してください。',
      'bt_no_bonded_devices': 'ペアリング済みBluetoothデバイスが見つかりません。',
      'bt_selected_count': '{count}台選択済み',
      'bt_device_retained': '以前に保存（現在未ペアリング）',
      'bt_devices_label': 'Bluetoothデバイス',
      'bt_none_selected': '未選択',
      'bt_count_selected': '{count}台選択済み',

      // デバイスアラーム（独立型BTデバイスアラーム）
      'device_alarm_empty': 'デバイスアラームなし',
      'device_alarm_empty_desc':
          'Bluetoothデバイスアラームを追加すると\nデバイスの接続・切断時に通知を受け取れます。',
      'device_alarm_add': 'デバイスアラーム追加',
      'device_alarm_delete_confirm': 'このデバイスアラームを削除しますか？',
      'device_alarm_select_device': 'デバイスを選択',
      'device_alarm_name_label': 'アラーム名',
      'device_alarm_name_hint': 'アラーム名を入力',
      'device_alarm_trigger_label': 'トリガー条件',
      'device_trigger_connect': '接続時',
      'device_trigger_disconnect': '切断時',

      // マイデバイス
      'my_devices_empty': '登録済みデバイスなし',
      'my_devices_empty_desc': '場所やデバイスアラームに登録された\nBluetoothデバイスがここに表示されます。',
      'my_devices_source_place': '場所',
      'my_devices_source_alarm': 'アラーム',
      'my_devices_add': 'デバイス追加',
      'my_devices_add_title': 'Bluetoothデバイス追加',
      'my_devices_custom_name_label': 'カスタム名',
      'my_devices_custom_name_hint': '覚えやすい名前を入力してください',
      'my_devices_original_name': 'Bluetooth名',
      'my_devices_edit_name': '名前を編集',
      'edit_device_menu': 'デバイスを編集',
      'add_device_alarm_menu': '新しいアラームを追加',
      'my_devices_delete_confirm': 'このデバイスを削除しますか？',
      'my_devices_source_manual': '手動追加',

      // アラーム追加（固定ボトムバー）
      'add_alarm_btn': 'アラーム追加',
      'add_device_alarm_btn': 'アラーム追加',

      // デバイスアラームページ
      'device_alarm_page_title': 'デバイスアラーム追加',
      'device_alarm_edit_title': 'デバイスアラーム編集',
      'add_new_device_alarm': '新しいデバイスアラームを追加',
      'select_device_label': 'デバイスを選択',
      'alarm_on_connect_label': '接続時アラーム',
      'alarm_on_disconnect_label': '切断時アラーム',
      'device_condition_hint': '条件なしで保存すると、最初の接続/切断時にアラームが鳴ります。',
      'device_alarm_voice_section': '音声認識',
      'device_alarm_voice_msg_label': '音声メッセージ',
      'device_alarm_voice_msg_hint': 'アラーム発動時にアナウンスするメッセージ',
      'device_alarm_voice_enabled': '音声通知を有効にする',
      'device_alarm_sound_section': 'アラーム音',
      'device_alarm_save_success': 'デバイスアラームが保存されました',

      // Wi-Fi
      'wifi_networks_label': 'Wi-Fiネットワーク',
      'wifi_none_selected': '未選択',
      'wifi_count_selected': '{count}件選択済み',
      'wifi_rescan_tooltip': '再スキャン',
      'wifi_description': 'Wi-Fi接続でより正確な位置検出ができます。',
      'wifi_disabled': 'Wi-Fiがオフです',
      'wifi_disabled_detail': 'Wi-Fiがオフです。Wi-Fiをオンにしてもう一度お試しください。',
      'wifi_scan_failed': 'Wi-Fiスキャン失敗',
      'wifi_no_networks': 'Wi-Fiネットワークが検出されませんでした。',
      'wifi_networks_selected': '{count}件ネットワーク選択済み',
      'wifi_hidden_network': '（非公開ネットワーク）',
      'wifi_currently_connected': '接続中',
      'wifi_previously_saved': '以前に保存（現在未検出）',
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
      'nav_alarm': '位置闹钟',
      'nav_my_places': '我的位置',
      'nav_voice': '语音',
      'nav_gps': 'GPS',

      // 페이지 타이틀
      'page_title_alarm': '位置闹钟',
      'page_title_places': '我的位置',
      'page_title_voice': '语音识别',
      'page_title_gps': 'GPS',
      'page_title_subscription': '订阅管理',

      // 标签页
      'tab_location_alarm': '位置闹钟',
      'tab_device_alarm': '设备闹钟',
      'tab_my_places': '我的位置',
      'tab_my_devices': '我的设备',
      'page_title_my_devices': '我的设备',
      'page_title_device_alarm': '设备闹钟',

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
      'no_places_desc': '点击下方按钮添加您的第一个位置。',
      'add_place_btn': '添加位置',
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
      'delete_account': '注销账户',
      'delete_account_subtitle': '所有数据将被永久删除',
      'delete_account_warning':
          '您的所有数据（包括闹钟设置、位置数据、账户信息等）将被永久删除。\n\n此操作不可撤销，删除的数据无法恢复。',
      'delete_account_confirm': '删除',
      'delete_account_final_title': '最终确认',
      'delete_account_final_warning': '您确定要删除吗？\n账户和所有相关数据将立即被永久删除。',
      'delete_account_final_confirm': '永久删除',
      'delete_account_failed': '❌ 账户删除失败，请重试。',
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
      'country_DE': '德国',
      'country_FR': '法国',
      'country_ES': '西班牙',
      'country_IT': '意大利',
      'country_NL': '荷兰',
      'country_SE': '瑞典',
      'country_PL': '波兰',
      'country_GB': '英国',

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
      'no_saved_alarms_desc': '点击下方按钮添加您的第一个闹钟。',

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
      // 语音标签
      'voice_tab_location': '位置语音',
      'voice_tab_device': '设备语音',
      'voice_device_main_title': '用语音注册设备闹钟',
      'voice_device_example_phrase': '"Galaxy Buds连接时提醒我"',
      'voice_device_tip_title': '💡 设备语音识别示例',
      'voice_device_tip_examples':
          '• "周一Galaxy Buds连接时提醒我"\n'
          '  → 每周一，连接时\n'
          '• "4月12日耳机断开时提醒我"\n'
          '  → 仅4/12，断开时\n'
          '• "周一6点后Buds连接时提醒我"\n'
          '  → 每周一，18点后，连接时\n'
          '• "3月13日9点手表断开时提醒我"\n'
          '  → 3/13，9点后，断开时',
      'voice_device_tip_note': '星期、日期和时间会自动设置\n(蓝牙状态变化实时检测)',
      'voice_first_visit_title': '💡 小贴士！',
      'voice_first_visit_desc': '在主屏幕添加小组件\n无需打开应用\n即可开始语音闹钟！',
      'voice_first_visit_btn': '查看添加方法',
      'voice_first_visit_later': '以后再说',

      // 订阅页面
      'subscription_tab': '订阅管理',
      'gps_tab': 'GPS',
      // GPS page
      'gps_current_location': '当前位置',
      'gps_latitude': '纬度',
      'gps_longitude': '经度',
      'gps_accuracy': '精度',
      'gps_accuracy_good': '良好',
      'gps_accuracy_fair': '一般',
      'gps_accuracy_poor': '差',
      'gps_updated_at': '更新',
      'gps_no_location': '无位置信息',
      'gps_alarm_status': '位置闹钟状态',
      'gps_stopped': '已停止',
      'gps_inside': '内部',
      'gps_outside': '外部',
      'gps_moving': '移动中',
      'gps_alarms': '闹钟',
      'gps_place_status': '各地点状态',
      'gps_place_status_refresh_tooltip': '刷新地点状态',
      'gps_no_tracked_places': '无追踪地点',
      'gps_place_status_updated': '已更新{count}个地点状态',
      'gps_entry': '进入',
      'gps_exit': '离开',
      'gps_bug_report': 'Bug报告',
      'gps_bug_report_sending': '发送中…',
      'gps_bug_report_title': 'Bug报告',
      'gps_refresh_tooltip': '刷新GPS',
      'subscription_current_plan': '当前方案',
      'subscription_expires': '到期: {date}',
      'subscription_free_plan': '免费方案',
      'subscription_unlimited': '无限制',
      'subscription_places_n': '{n}个地点',
      'subscription_alarms_n': '{n}个活动闹钟',
      'subscription_places_unlimited': '地点无限制',
      'subscription_alarms_unlimited': '闹钟无限制',
      'subscription_map_opens_50': '地图打开每月50次',
      'subscription_map_opens_unlimited': '地图打开无限制',
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
      'subscription_price_tbd': '价格待定',
      'subscription_pro_fair_use': '公平使用政策: 为防止滥用, 每月最多500次地图打开。',
      'subscription_map_opens_500': '每月500次地图打开',

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
      'auto_renew_msg': '按照Google Play政策自动续费。',
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

      // 蓝牙设备闹钟 — 非预期触发 说明
      'bt_false_trigger_info_title': '⚡ 闹钟意外响起了？',
      'bt_false_trigger_info_subtitle': '非预期情况下响起时的应对方法',
      'bt_false_trigger_dialog_title': '闹钟意外响起了？',
      'bt_false_trigger_dialog_body':
          '蓝牙闹钟在连接或断开状态持续15秒以上时触发。\n'
          '这是正常工作，但各种意外情况可能导致非预期触发。\n\n'
          '闹钟响起时，点击「⚡ 误触发」\n'
          '铃声立即停止，闹钟保持启用状态以备下次使用。\n\n'
          '💡 建议：使用星期/时间条件，可大幅减少非预期触发。',
      'bt_refresh_tooltip': '刷新设备列表',
      'bt_selector_description': '选择要在此位置检测的已配对蓝牙设备。',
      'bt_permission_needed': '需要蓝牙权限。\n请在设置中允许蓝牙访问。',
      'bt_no_bonded_devices': '未找到已配对蓝牙设备。',
      'bt_selected_count': '已选择{count}台设备',
      'bt_device_retained': '之前保存（当前未配对）',
      'bt_devices_label': '蓝牙设备',
      'bt_none_selected': '未选择',
      'bt_count_selected': '已选择{count}个',

      // 设备闹钟（独立型BT设备闹钟）
      'device_alarm_empty': '无设备闹钟',
      'device_alarm_empty_desc': '添加蓝牙设备闹钟后\n可在设备连接或断开时收到通知。',
      'device_alarm_add': '添加设备闹钟',
      'device_alarm_delete_confirm': '确定删除此设备闹钟？',
      'device_alarm_select_device': '选择设备',
      'device_alarm_name_label': '闹钟名称',
      'device_alarm_name_hint': '请输入闹钟名称',
      'device_alarm_trigger_label': '触发条件',
      'device_trigger_connect': '连接时',
      'device_trigger_disconnect': '断开时',

      // 我的设备
      'my_devices_empty': '无已注册设备',
      'my_devices_empty_desc': '注册到位置或设备闹钟的\n蓝牙设备将显示在此处。',
      'my_devices_source_place': '位置',
      'my_devices_source_alarm': '闹钟',
      'my_devices_add': '添加设备',
      'my_devices_add_title': '添加蓝牙设备',
      'my_devices_custom_name_label': '自定义名称',
      'my_devices_custom_name_hint': '输入一个容易记住的名称',
      'my_devices_original_name': '蓝牙名称',
      'my_devices_edit_name': '编辑名称',
      'edit_device_menu': '编辑设备',
      'add_device_alarm_menu': '添加新闹钟',
      'my_devices_delete_confirm': '确定删除此设备？',
      'my_devices_source_manual': '手动添加',

      // 添加闹钟（固定底部栏）
      'add_alarm_btn': '添加闹钟',
      'add_device_alarm_btn': '添加闹钟',

      // 设备闹钟页面
      'device_alarm_page_title': '添加设备闹钟',
      'device_alarm_edit_title': '编辑设备闹钟',
      'add_new_device_alarm': '添加新设备闹钟',
      'select_device_label': '选择设备',
      'alarm_on_connect_label': '连接时闹钟',
      'alarm_on_disconnect_label': '断开时闹钟',
      'device_condition_hint': '不设条件保存时，首次连接/断开时闹钟响起。',
      'device_alarm_voice_section': '语音识别',
      'device_alarm_voice_msg_label': '语音消息',
      'device_alarm_voice_msg_hint': '闹钟触发时播报的消息',
      'device_alarm_voice_enabled': '启用语音通知',
      'device_alarm_sound_section': '闹钟铃声',
      'device_alarm_save_success': '设备闹钟已保存',

      // Wi-Fi
      'wifi_networks_label': 'Wi-Fi网络',
      'wifi_none_selected': '未选择',
      'wifi_count_selected': '已选择{count}个',
      'wifi_rescan_tooltip': '重新扫描',
      'wifi_description': '通过Wi-Fi连接实现更精确的位置检测。',
      'wifi_disabled': 'Wi-Fi已关闭',
      'wifi_disabled_detail': 'Wi-Fi已关闭。请开启Wi-Fi后重试。',
      'wifi_scan_failed': 'Wi-Fi扫描失败',
      'wifi_no_networks': '未检测到Wi-Fi网络。',
      'wifi_networks_selected': '已选择{count}个网络',
      'wifi_hidden_network': '（隐藏网络）',
      'wifi_currently_connected': '当前已连接',
      'wifi_previously_saved': '之前保存（当前未检测到）',
    },

    'de': {
      // Allgemein
      'app_name': 'Ringinout',
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      'delete': 'Löschen',
      'close': 'Schließen',
      'send': 'Senden',
      'confirm': 'Bestätigen',
      'ok': 'OK',
      'yes': 'Ja',
      'no': 'Nein',
      'error': 'Fehler',
      'success': 'Erfolg',
      'loading': 'Laden...',

      // Navigation
      'nav_alarm': 'Standort',
      'nav_my_places': 'Meine Orte',
      'nav_voice': 'Sprache',
      'nav_gps': 'GPS',

      // Seitentitel
      'page_title_alarm': 'Standort-Alarm',
      'page_title_gps': 'GPS',
      'page_title_places': 'Meine Orte',
      'page_title_voice': 'Spracherkennung',
      'page_title_subscription': 'Abonnement',

      // Tabs
      'tab_location_alarm': 'Standort-Alarm',
      'tab_device_alarm': 'Geräte-Alarm',
      'tab_my_places': 'Meine Orte',
      'tab_my_devices': 'Meine Geräte',
      'page_title_my_devices': 'Meine Geräte',
      'page_title_device_alarm': 'Geräte-Alarm',

      // Auswahlmodus
      'select_all': 'Alle auswählen',
      'delete_selected': 'Löschen',

      // Alarmseite
      'alarm_title': 'Ringinout Alarm',
      'location_alarm': 'Standort-Alarm',
      'basic_alarm': 'Basis-Alarm',
      'basic_alarm_page': 'Basis-Alarm Seite',
      'sort_options': 'Sortieroptionen',
      'sort_by_time': 'Nach Alarmzeit',
      'sort_custom': 'Eigene Reihenfolge',
      'sort_place_asc': 'Ort (A → Z)',
      'sort_place_desc': 'Ort (Z → A)',
      'sort_name_asc': 'Alarmname (A → Z)',
      'sort_name_desc': 'Alarmname (Z → A)',
      'no_alarms': 'Noch keine Alarme',
      'add_alarm_hint': 'Fügen Sie einen Standort-Alarm hinzu!',

      // Ortsverwaltung
      'my_places': 'Meine Orte',
      'add_place': 'Ort hinzufügen',
      'edit_place': 'Ort bearbeiten',
      'place_name': 'Ortsname',
      'place_saved': '✅ Ort gespeichert',
      'place_updated': '✅ Ort aktualisiert',
      'place_deleted': '🗑 Ort gelöscht',
      'no_places': 'Keine gespeicherten Orte',
      'no_places_desc':
          'Tippen Sie auf die Schaltfläche, um Ihren ersten Ort hinzuzufügen.',
      'add_place_btn': 'Ort hinzufügen',
      'add_place_hint': 'Fügen Sie Ihre Lieblingsorte hinzu!',
      'search_address': 'Adresse suchen',
      'current_location': 'Aktueller Standort',
      'radius': 'Radius',
      'custom': 'Benutzerdefiniert',
      'custom_radius': 'Benutzerdefinierter Radius',

      // Alarm hinzufügen/bearbeiten
      'add_location_alarm': 'Standort-Alarm hinzufügen',
      'edit_location_alarm': 'Standort-Alarm bearbeiten',
      'alarm_sound': 'Alarmton',
      'vibration': 'Vibration',
      'snooze': 'Schlummern',
      'alarm_enabled': 'Alarm aktiviert',
      'entry_exit': 'Betreten/Verlassen',
      'on_entry': 'Beim Betreten',
      'on_exit': 'Beim Verlassen',
      'both': 'Beides',
      'alarm_saved': '✅ Alarm gespeichert',
      'alarm_deleted': '🗑 Alarm gelöscht',

      // Einstellungen
      'settings': 'Einstellungen',
      'language': 'Sprache',
      'language_select': 'Sprache auswählen',
      'system_default': 'Systemstandard',
      'account': 'Konto',
      'logged_in': 'Angemeldet',
      'logout': 'Abmelden',
      'logout_confirm':
          'Möchten Sie sich wirklich abmelden? Sie werden zum Anmeldebildschirm weitergeleitet.',
      'google_login': 'Mit Google anmelden',
      'login_success': '✅ Anmeldung erfolgreich',
      'login_failed': '❌ Anmeldung fehlgeschlagen',
      'logged_out': 'Abgemeldet',
      'delete_account': 'Konto löschen',
      'delete_account_subtitle': 'Alle Daten dauerhaft löschen',
      'delete_account_warning':
          'Alle Ihre Daten einschließlich Alarmeinstellungen, Standortdaten und Kontoinformationen werden dauerhaft gelöscht.\n\nDiese Aktion kann nicht rückgängig gemacht werden und Ihre Daten können nicht wiederhergestellt werden.',
      'delete_account_confirm': 'Löschen',
      'delete_account_final_title': 'Letzte Bestätigung',
      'delete_account_final_warning':
          'Sind Sie absolut sicher?\nIhr Konto und alle zugehörigen Daten werden sofort dauerhaft gelöscht.',
      'delete_account_final_confirm': 'Endgültig löschen',
      'delete_account_failed':
          '❌ Kontolöschung fehlgeschlagen. Bitte versuchen Sie es erneut.',
      'feedback': 'Feedback senden',
      'feedback_title': 'Feedback senden',
      'feedback_hint': 'Geben Sie Ihr Feedback oder Vorschläge ein',
      'feedback_sent': '✅ Feedback gesendet. Vielen Dank!',
      'app_info': 'App-Info',

      // Anmeldeseite
      'login_app_description':
          'Standortbasierte Alarm-App.\nWerden Sie benachrichtigt, wenn Sie ankommen oder einen Ort verlassen!',
      'login_data_security_title': 'Datensicherheitsversprechen',
      'login_data_security_content':
          'Nur Ihre verschlüsselte Kontokennung und Ihr Zahlungsstatus werden auf unseren Servern gespeichert. Standort- und persönliche Daten werden nur auf Ihrem Gerät verarbeitet.',
      'login_data_deletion_warning':
          'Alle gespeicherten Orte und Alarmeinstellungen werden beim Deinstallieren der App gelöscht.',
      'login_continue_with_google': 'Mit Google fortfahren',
      'login_cancelled': 'Anmeldung abgebrochen',
      'login_not_supported':
          'Google-Anmeldung wird auf diesem Gerät nicht unterstützt',
      'version': 'Version',
      'location_based_alarm': 'Standortbasierte Alarm-App',
      'privacy_policy': 'Datenschutzrichtlinie',

      // Datenschutzrichtlinie
      'privacy_policy_title': 'Datenschutzrichtlinie',
      'privacy_last_updated': 'Zuletzt aktualisiert: Januar 2026',
      'privacy_section_1_title': '1. Informationen, die wir erheben',
      'privacy_section_1_content':
          'Ringinout erhebt keine personenbezogenen Daten.\n\n'
          '• Standortdaten: Werden nur auf Ihrem Gerät für die Alarmfunktion verarbeitet. Werden nicht an externe Server gesendet.\n\n'
          '• Kontoinformationen: Bei der Anmeldung mit Google wird Ihre E-Mail in eine anonymisierte zufällige ID umgewandelt. Die Original-E-Mail wird nicht gespeichert.',
      'privacy_section_2_title': '2. Zweck der anonymisierten ID',
      'privacy_section_2_content':
          'Die anonymisierte ID wird ausschließlich zur Überprüfung des Premium-Abonnementstatus verwendet. '
          'Diese ID kann nicht zur Identifizierung oder Verfolgung von Personen verwendet werden.',
      'privacy_section_3_title': '3. Datenspeicherung',
      'privacy_section_3_content':
          'Alle Alarm- und Standortdaten werden nur auf Ihrem Gerät gespeichert '
          'und nicht an externe Server übertragen.',
      'privacy_section_4_title': '4. Weitergabe an Dritte',
      'privacy_section_4_content':
          'Ringinout gibt keine Benutzerdaten an Dritte weiter.',
      'privacy_section_5_title': '5. Kontakt',
      'privacy_section_5_content':
          'Bei datenschutzbezogenen Anfragen nutzen Sie bitte die Funktion \'Feedback senden\' in der App.',

      // Berechtigungen
      'permission_required': 'Berechtigung erforderlich',
      'location_permission': 'Standortberechtigung',
      'notification_permission': 'Benachrichtigungsberechtigung',
      'background_permission': 'Hintergrund-Standortberechtigung',
      'background_location_desc':
          'Erkennt Ihren Standort auch wenn die App nicht verwendet wird.',
      'overlay_permission': 'Über anderen Apps anzeigen',
      'overlay_permission_desc': 'Erforderlich für Vollbild-Alarme.',
      'grant_permission': 'Berechtigung erteilen',
      'allow': 'Erlauben',
      'permission_settings': 'Berechtigungseinstellungen',
      'setup_complete': 'Einrichtung abgeschlossen! 🎉',
      'grant_all_permissions': 'Bitte alle Berechtigungen erteilen',
      'setup_later': 'Später einrichten',
      'location_permission_desc':
          'Erforderlich zur Erkennung von Alarmstandorten.',
      'battery_opt_warning_title': 'Batterieoptimierung nicht ausgeschlossen',
      'battery_opt_warning_desc':
          'Dieser Hinweis erscheint, weil die Batterieoptimierungsausnahme derzeit deaktiviert ist. '
          'Die App kann weiterhin funktionieren, aber Alarme können auf einigen Geräten verzögert oder verpasst werden. '
          'Wir empfehlen, diese App von der Batterieoptimierung auszuschließen.',

      // GPS-Seite
      'gps_title': 'GPS',
      'geofence_service_status': 'Geofence-Dienststatus',
      'status_running': '✅ Läuft',
      'status_stopped': '❌ Gestoppt',
      'status': 'Status',
      'last_event': 'Letztes Ereignis',
      'last_event_none': 'Keines',
      'settings_interval':
          'Einstellungen: {interval}s Intervall, {accuracy}m Genauigkeit',
      'geofence_status_debug': 'Geofence-Status (Debug)',
      'no_saved_places': 'Keine gespeicherten Orte',
      'distance': 'Entfernung',
      'radius_label': 'Radius',
      'no_location_info': 'Keine Standortinfo',
      'latitude': 'Breitengrad',
      'longitude': 'Längengrad',
      'updated': 'Aktualisiert',
      'active_alarm_distance': 'Aktive Alarm-Entfernungen',
      'no_active_alarms': 'Keine aktiven Alarme oder keine Standortinfo',
      'alarm': 'Alarm',
      'place_unknown': 'Unbekannter Ort',
      'cannot_calculate_distance': 'Entfernung kann nicht berechnet werden',
      'location_permission_required': 'Standortberechtigung ist erforderlich.',
      'inside': 'Innerhalb',
      'outside': 'Außerhalb',

      // Wochentage
      'sun': 'So',
      'mon': 'Mo',
      'tue': 'Di',
      'wed': 'Mi',
      'thu': 'Do',
      'fri': 'Fr',
      'sat': 'Sa',
      'every_week': 'Jeden {days}',
      'first_entry_after_set': 'Erstes Betreten nach Alarmeinstellung',
      'first_exit_after_set': 'Erstes Verlassen nach Alarmeinstellung',
      'no_selection': 'Keine Auswahl',

      // Feiertagseinstellungen
      'holiday_settings': 'Feiertagseinstellungen',
      'turn_off_on_holidays':
          'An Ersatz-/vorübergehenden Feiertagen ausschalten',
      'turn_on_on_holidays':
          'An Ersatz-/vorübergehenden Feiertagen einschalten',

      // Feiertagsland
      'holiday_country': 'Feiertagsland',
      'holiday_country_auto': 'Auto',
      'holiday_country_auto_detected': 'Auto (Erkannt: {country})',
      'holiday_country_auto_detecting': 'Auto (Erkennung...)',
      'country_KR': 'Südkorea',
      'country_US': 'Vereinigte Staaten',
      'country_JP': 'Japan',
      'country_CN': 'China',
      'country_VN': 'Vietnam',
      'country_MY': 'Malaysia',
      'country_TH': 'Thailand',
      'country_CA': 'Kanada',
      'country_BR': 'Brasilien',
      'country_TW': 'Taiwan',
      'country_DE': 'Deutschland',
      'country_FR': 'Frankreich',
      'country_ES': 'Spanien',
      'country_IT': 'Italien',
      'country_NL': 'Niederlande',
      'country_SE': 'Schweden',
      'country_PL': 'Polen',
      'country_GB': 'Großbritannien',

      // Alarm-Gruppierung
      'alarm_count': '{count} Alarme',
      'alarm_count_one': '1 Alarm',
      'other_places': 'Sonstige',

      // Standort-Alarm hinzufügen
      'add_new_location_alarm': 'Neuen Standort-Alarm hinzufügen',
      'done': 'Fertig',
      'alarm_name': 'Alarmname',
      'no_name': 'Kein Name',
      'select_place': 'Ort auswählen',
      'alarm_on_entry': 'Alarm beim Betreten',
      'alarm_on_exit': 'Alarm beim Verlassen',

      // Spracherkennung
      'voice_input': 'Spracheingabe',
      'voice_listening': 'Höre zu...',
      'voice_not_recognized': 'Sprache nicht erkannt',
      'tap_to_speak': 'Tippen zum Sprechen',
      'select_location_on_map': 'Standort auf der Karte auswählen',

      // Alarmbildschirm
      'dismiss': 'Beenden',
      'snooze_minutes': '{minutes} Min. schlummern',
      'alarm_ringing': 'Alarm klingelt!',

      // Batterie-Info
      'battery_info_text_prefix':
          'Aktive Alarme starten automatisch neu, wenn die App geschlossen wird.\nFür zuverlässige Alarme ',
      'battery_info_text_action': 'von Batterieoptimierung ausschließen',
      'battery_info_text_suffix': '.',
      'battery_opt_exclude': 'Von Batterieoptimierung ausschließen',
      'no_saved_alarms': 'Keine gespeicherten Alarme.',
      'no_saved_alarms_desc':
          'Tippen Sie auf die Schaltfläche, um Ihren ersten Alarm hinzuzufügen.',

      // Willkommen
      'get_started': 'Loslegen',

      // Sprachseite
      'voice_main_title': 'Alarme per Sprache registrieren',
      'voice_example_phrase':
          '"Benachrichtige mich, wenn ich bei der Arbeit ankomme"',
      'voice_tap_to_start': 'Tippen zum Starten',
      'voice_widget_title': 'Widget zum Startbildschirm hinzufügen',
      'voice_widget_subtitle': 'Spracherkennung per Widget-Tippen starten!',
      'voice_widget_guide_title': 'Startbildschirm-Widget hinzufügen',
      'voice_widget_guide_subtitle': 'Sprachalarme schneller starten!',
      'voice_widget_step1':
          'Lange auf freie Stelle auf dem Startbildschirm drücken',
      'voice_widget_step2': '"Widgets"-Menü auswählen',
      'voice_widget_step3': '"ringinout" oder "Sprach-Alarm" suchen',
      'voice_widget_step4': 'Widget auf den Startbildschirm ziehen',
      'voice_widget_tip':
          'Mit einem Widget können Sie Sprachalarme\ndirekt vom Startbildschirm starten, ohne die App zu öffnen!',
      'voice_widget_got_it': 'Verstanden!',
      'voice_tip_title': '💡 Beispiele zur Spracherkennung',
      'voice_tip_examples':
          '• "Benachrichtige mich, wenn ich montags bei der Arbeit ankomme"\n'
          '  → Jeden Montag, beim Betreten\n'
          '• "Warne mich, wenn ich am 12. April das Haus verlasse"\n'
          '  → Nur am 12. April, beim Verlassen\n'
          '• "Klingeln, wenn ich montags nach 18 Uhr nach Hause komme"\n'
          '  → Jeden Montag, nach 18:00, beim Betreten\n'
          '• "Erinnere mich, wenn ich am 13. März um 9 Uhr das Haus verlasse"\n'
          '  → 13. März, nach 9:00, beim Verlassen',
      'voice_tip_note':
          'Wochentage, Daten & Uhrzeiten werden automatisch festgelegt\n(GPS-Geofence kann innerhalb von ±Sekunden der Grenze auslösen)',
      // Sprach-Tabs
      'voice_tab_location': 'Standort-Sprache',
      'voice_tab_device': 'Geräte-Sprache',
      'voice_device_main_title': 'Gerätealarme per Sprache registrieren',
      'voice_device_example_phrase':
          '"Benachrichtige mich, wenn Galaxy Buds verbunden werden"',
      'voice_device_tip_title': '💡 Geräte-Sprachbeispiele',
      'voice_device_tip_examples':
          '• "Benachrichtige mich, wenn Galaxy Buds montags verbunden werden"\n'
          '  → Jeden Montag, bei Verbindung\n'
          '• "Warne mich, wenn Kopfhörer am 12. April getrennt werden"\n'
          '  → Nur am 12. April, bei Trennung\n'
          '• "Klingeln, wenn Buds montags nach 18 Uhr verbunden werden"\n'
          '  → Jeden Montag, nach 18:00, bei Verbindung\n'
          '• "Sage mir, wenn die Uhr am 13. März um 9 Uhr getrennt wird"\n'
          '  → 13. März, nach 9:00, bei Trennung',
      'voice_device_tip_note':
          'Wochentage, Daten & Uhrzeiten werden automatisch festgelegt\n(Bluetooth-Statusänderungen werden in Echtzeit erkannt)',
      'voice_first_visit_title': '💡 Profi-Tipp!',
      'voice_first_visit_desc':
          'Fügen Sie ein Widget zu Ihrem Startbildschirm hinzu,\num Sprachalarme zu starten,\nohne die App zu öffnen!',
      'voice_first_visit_btn': 'Erfahren Sie, wie Sie ein Widget hinzufügen',
      'voice_first_visit_later': 'Vielleicht später',

      // Abonnement
      'subscription_tab': 'Abonnement',
      'gps_tab': 'GPS',
      // GPS-Seite
      'gps_current_location': 'Aktueller Standort',
      'gps_latitude': 'Breitengrad',
      'gps_longitude': 'Längengrad',
      'gps_accuracy': 'Genauigkeit',
      'gps_accuracy_good': 'Gut',
      'gps_accuracy_fair': 'Mittel',
      'gps_accuracy_poor': 'Schlecht',
      'gps_updated_at': 'Aktualisiert',
      'gps_no_location': 'Keine Standortdaten',
      'gps_alarm_status': 'Standort-Alarmstatus',
      'gps_stopped': 'Gestoppt',
      'gps_inside': 'Innerhalb',
      'gps_outside': 'Außerhalb',
      'gps_moving': 'In Bewegung',
      'gps_alarms': 'Alarme',
      'gps_place_status': 'Ortstatus',
      'gps_place_status_refresh_tooltip': 'Ortstatus aktualisieren',
      'gps_no_tracked_places': 'Keine verfolgten Orte',
      'gps_place_status_updated': '{count} Ort(e) Status aktualisiert',
      'gps_entry': 'Betreten',
      'gps_exit': 'Verlassen',
      'gps_bug_report': 'Fehlerbericht',
      'gps_bug_report_sending': 'Wird gesendet...',
      'gps_bug_report_title': 'Fehlerbericht',
      'gps_refresh_tooltip': 'GPS aktualisieren',
      'subscription_current_plan': 'Aktueller Plan',
      'subscription_expires': 'Läuft ab: {date}',
      'subscription_free_plan': 'Kostenloser Plan',
      'subscription_unlimited': 'Unbegrenzt',
      'subscription_places_n': '{n} Orte',
      'subscription_alarms_n': '{n} aktive Alarme',
      'subscription_places_unlimited': 'Unbegrenzte Orte',
      'subscription_alarms_unlimited': 'Unbegrenzte Alarme',
      'subscription_map_opens_50': '50 Kartenöffnungen/Monat',
      'subscription_map_opens_unlimited': 'Unbegrenzte Kartenöffnungen',
      'subscription_no_ads': 'Keine Werbung',
      'subscription_all_unlimited': 'Alle Funktionen unbegrenzt',
      'subscription_dev_plan': 'Entwicklerplan - alle Funktionen unbegrenzt',
      'subscription_subscribe': 'Abonnieren',
      'subscription_in_use': 'In Verwendung',
      'subscription_recommended': 'Empfohlen',
      'subscription_coming_soon': 'Abonnement-Funktion kommt bald.',
      'subscription_beta_notice':
          'Kostenpflichtige Pläne sind während der Beta nicht verfügbar. Sie werden nach Ende der Beta verfügbar sein.',
      'subscription_per_month': '/ Monat',
      'subscription_policy': 'Abonnementrichtlinie',
      'subscription_refund_policy': 'Rückerstattungsrichtlinie',
      'subscription_price_tbd': 'Preis folgt',
      'subscription_pro_fair_use':
          'Fair-Use-Richtlinie: max. 500 Kartenöffnungen pro Monat zur Missbrauchsprävention.',
      'subscription_map_opens_500': '500 Kartenöffnungen/Monat',

      // Alarm hinzufügen/bearbeiten - zusätzliche Schlüssel
      'plan_upgrade_needed': 'Plan-Upgrade erforderlich',
      'add_alarm_tooltip': 'Alarm hinzufügen',
      'entry_trigger': 'Betreten',
      'exit_trigger': 'Verlassen',
      'entry_exit_trigger': 'Betreten/Verlassen',
      'am_label': 'VM',
      'pm_label': 'NM',
      'hour_suffix': ':',
      'min_suffix': '',
      'after_suffix': ' danach',
      'first_trigger_immediate': 'Alarm beim ersten {trigger}',
      'first_trigger_condition': '{conditions} erstes {trigger}',
      'monthly_date': '{month}/{day}({weekday})',
      'weekly_prefix': 'Jeden {days}',
      'listening_prompt': '🎙️ Höre zu... Sprechen Sie jetzt!',
      'done_btn': 'Fertig',
      'alarm_name_label': 'Alarmname',
      'no_name_label': 'Kein Name',
      'select_place_label': 'Ort auswählen',
      'alarm_on_entry_label': 'Alarm beim Betreten',
      'alarm_on_exit_label': 'Alarm beim Verlassen',
      'boundary_warning':
          'In der Nähe der Geofence-Grenze kann der Alarm mehrfach klingeln, wenn Sie sich dort aufhalten oder hin und her bewegen. '
          'Verwenden Sie die "Schlummern"-Taste, um den Alarm zu verzögern.',
      'condition_settings': 'Bedingungseinstellungen (Optional)',
      'condition_hint':
          'Ohne Bedingungen klingelt der Alarm beim ersten Betreten/Verlassen nach dem Speichern.',
      'no_date_set': 'Kein Datum festgelegt',
      'time_condition_hint': 'Zeitbedingung (optional)',
      'time_after': '⏰ {time} danach',
      'holidays_off': 'An Feiertagen aus',
      'holidays_sub_on': 'An Ersatz-/vorübergehenden Feiertagen ein',
      'alarm_sound_label': 'Alarmton',
      'alarm_sound_default': 'Geräte-Standardalarmton',
      'alarm_sound_unchangeable': 'Kann nicht geändert werden',
      'save_btn': 'Speichern',
      'delete_btn': 'Löschen',
      'edit_alarm_title': 'Standort-Alarm bearbeiten',
      'select_place_hint': 'Ort auswählen',
      'select_place_required': 'Bitte wählen Sie einen Ort',
      'alarm_save_failed': 'Alarm konnte nicht gespeichert werden: {error}',

      // Ort hinzufügen
      'address_search_result': 'Adresssuchergebnisse',
      'save_place_title': 'Ort speichern',
      'place_name_label': 'Ortsname',
      'place_name_hint': 'z.B. Zuhause, Büro, Fitnessstudio',
      'radius_display': 'Radius: {radius}m',
      'radius_shown_on_map': '(Wird als Kreis auf der Karte angezeigt)',
      'cancel_btn': 'Abbrechen',
      'save_place_btn': 'Speichern',
      'place_saved_msg': '✅ Ort gespeichert',
      'select_on_map': 'Standort auf der Karte auswählen',
      'move_to_current': 'Zum aktuellen Standort bewegen',
      'search_hint': 'Adresse oder Ortsname (z.B. Starbucks)',
      'no_search_result': 'Keine Suchergebnisse',
      'address_label': 'Adresse: {address}',
      'radius_label_prefix': 'Radius: ',
      'custom_input': 'Benutzerdefiniert',
      'save_location_btn': 'Standort speichern',
      'signal_warning':
          '📍 Radius-Einrichtungshilfe\n'
          '• In GPS-instabilen Zonen (Untergrund, hohe Gebäude, signalblockierte Bereiche) können Fehlauslösungen auftreten.\n'
          '  Für einmalige Fehlauslösungen tippen Sie auf die Taste "⚡ Fehlauslösung", um sie schnell zu verwerfen.\n'
          '• Wenn Sie sich in der Nähe einer Zonengrenze aufhalten, kann der Alarm auch nach dem Tippen auf Fehlauslösung weiter klingeln.\n'
          '  Deaktivieren Sie in diesem Fall den Alarm und aktivieren Sie ihn bei Bedarf wieder.\n'
          '• Wenn Fehlauslösungen häufig auftreten, versuchen Sie, den Radius um jeweils 10m zu vergrößern.',
      'radius_guide_btn': '📍 Radius-Einrichtungshilfe  —  Unbedingt lesen!!',
      'radius_guide_dialog_body':
          '📍 GPS-Genauigkeitsgrenzen\n'
          'GPS kann Ihren Standort nur schätzen. Selbst im Freien ist mit einer Fehlertoleranz'
          ' von mehreren bis zehn Metern zu rechnen. Dies ist eine inhärente GPS-Einschränkung.\n\n'
          '📡 GPS-Signalspitzen\n'
          'In GPS-instabilen Umgebungen (Untergrund, hohe Gebäude, signalblockierte Zonen)'
          ' kann der Radiuserkennungsfehler zunehmen. Selbst wenn Sie sich tatsächlich innerhalb des Radius befinden,'
          ' kann GPS Sie vorübergehend als außerhalb lesen — oder umgekehrt.\n'
          'Verwenden Sie in diesen Fällen die Taste "\u26a1 Fehlauslösung".'
          ' Wenn dasselbe Problem wiederholt auftritt, versuchen Sie, Ihren Radius um jeweils 10m zu vergrößern.\n\n'
          '💡 Wenn Sie sich in der Nähe der konfigurierten Radiusgrenze aufhalten oder bewegen müssen\n'
          'Selbst nach dem Tippen auf Fehlauslösung kann der Alarm weiter klingeln.'
          ' Deaktivieren Sie in diesem Fall den Alarm und aktivieren Sie ihn bei Bedarf wieder.\n'
          '("Standby"-Modus — wird bei Nachfrage in Betracht gezogen: automatische Reaktivierung nach einer festgelegten Dauer)',
      'radius_input_range': '30m ~ 500m (10m-Schritte)',

      // Nutzungsbedingungen
      'terms_agreement_title': 'Nutzungsbedingungen (Erforderlich)',
      'terms_agree_text':
          'Ich habe die Nutzungsbedingungen und die Rückerstattungs-/Abonnementrichtlinie gelesen und stimme zu.',
      'terms_agree_btn': 'Zustimmen und fortfahren',
      'terms_disagree_btn': 'Ablehnen (App schließen)',
      'terms_save_failed':
          'Speichern der Bedingungen fehlgeschlagen. Bitte versuchen Sie es erneut.',

      // Alarmton
      'alarm_sound_setting_title': 'Alarmton-Einstellungen',
      'alarm_disabled_label': 'Alarm deaktiviert',

      // add_alarm_page
      'add_alarm_new_title': 'Neuen Alarm hinzufügen',
      'edit_alarm_modify_title': 'Standort-Alarm bearbeiten',
      'location_fixed_text': 'Dieser Alarm ist an diesen Ort gebunden',
      'no_place_label': 'Kein Ort',
      'required_fields_msg': 'Bitte füllen Sie alle Pflichtfelder aus.',
      'holidays_dialog_title': 'Ersatz-/vorübergehende Feiertagseinstellungen',
      'holidays_sub_off': 'An Ersatz-/vorübergehenden Feiertagen ebenfalls aus',

      // my_places_page
      'delete_confirm_title': 'Löschen bestätigen',
      'delete_locked_msg': 'Diesen gesperrten Ort löschen?',
      'delete_place_msg': 'Möchten Sie diesen Ort wirklich löschen?',
      'linked_alarm_delete_warning':
          '⚠️ {count} verknüpfte(r) Alarm(e) werden ebenfalls gelöscht.',
      'edit_places_menu': 'Ort bearbeiten',
      'add_alarm_menu': 'Neuen Alarm hinzufügen',
      'add_place_tooltip': 'Neuen Ort hinzufügen',

      // show_alarm_popup_page
      'alarm_end_confirm': 'Alarm beenden?',
      'no_label': 'Nein',
      'yes_label': 'Ja',
      'snooze_btn': 'Schlummern',
      'alarm_stop_btn': 'Alarm stoppen',

      // Schlummer-/Vibrationseinstellungen
      'snooze_setting_title': 'Schlummereinstellungen',
      'vibration_setting_title': 'Vibrationseinstellungen',

      // Berechtigung
      'permission_setting_title': 'Berechtigungseinstellungen',
      'permission_allow': 'Erlauben',
      'battery_opt_title': 'Batterieoptimierung deaktivieren',
      'battery_opt_msg':
          'Damit Alarme im Hintergrund ordnungsgemäß funktionieren, muss die Batterieoptimierung deaktiviert werden.\nGehen Sie zu den Einstellungen und suchen Sie "Batterieoptimierung" und setzen Sie Ringinout auf "Nicht optimiert".',
      'open_settings_btn': 'Einstellungen öffnen',
      'later_btn': 'Später',

      // Abonnementverwaltung
      'subscription_mgmt_title': 'Abonnementverwaltung',
      'subscription_policy_btn': 'Abonnementrichtlinie',
      'refund_policy_btn': 'Rückerstattungsrichtlinie',
      'auto_renew_msg': 'Automatisch nach Google Play-Richtlinien verlängert.',
      'agree_auto_pay': 'Ich stimme der automatischen Zahlung zu.',
      'agree_policy':
          'Ich habe die Abonnement-/Rückerstattungsrichtlinie geprüft.',
      'start_auto_subscription': 'Automatisches Abonnement starten',
      'current_plan': 'Aktueller Plan',
      'cancel_subscription': 'Kündigen',
      'subscribe_btn': 'Abonnieren',
      'auto_subscribe_btn': 'Automatisch abonnieren',
      'beta_no_paid_plans':
          'Kostenpflichtige Pläne sind während der Beta nicht verfügbar. Sie werden nach Ende der Beta verfügbar sein.',
      'places_5': '5 Orte',
      'active_alarms_10': '10 aktive Alarme',
      'ad_free_included': 'Werbefrei inklusive',
      'places_alarms_unlimited': 'Unbegrenzte Orte/Alarme',
      'ad_remove_title': 'Werbung entfernen',
      'in_app_ad_remove': 'In-App-Werbung entfernen',
      'price_loading': 'Preis wird geladen',
      'duration_1month': '1 Monat',
      'duration_3months': '3 Monate',
      'duration_6months': '6 Monate',
      'duration_12months': '12 Monate',
      'discount_5': '5% Rabatt',
      'discount_10': '10% Rabatt',
      'discount_20': '20% Rabatt',
      'expiry_date_none': 'Ablauf: -',
      'expiry_date_format': 'Ablauf: {date}',
      'beta_sub_activate_later':
          'Abonnements werden nach Ende der Beta aktiviert.',

      // Abonnement-Limitdialog
      'place_limit_title': 'Ort-Registrierungslimit',
      'place_limit_msg':
          'Im {plan}-Plan können Sie bis zu {limit} Orte registrieren.\nBitte löschen Sie bestehende Orte oder upgraden Sie.',
      'alarm_limit_title': 'Alarm-Registrierungslimit',
      'alarm_limit_msg':
          'Im {plan}-Plan können Sie bis zu {limit} aktive Alarme einrichten.\nBitte löschen Sie bestehende Alarme oder upgraden Sie.',
      'close_btn': 'Schließen',

      // Standortauswahl
      'place_name_input_title': 'Ortsnamen eingeben',
      'radius_default_info': 'Radius: 100m (kann später geändert werden)',
      'location_select_title': 'Standort auswählen',
      'fetching_location': 'Aktueller Standort wird abgerufen...',
      'location_saved': '📍 Standort gespeichert!',

      // Anmeldung zusätzlich
      'dev_test_mode': 'Entwickler-Testmodus',
      'test_login_failed': 'Test-Anmeldung fehlgeschlagen: {error}',

      // Kartenwechsel
      'switch_to_google': 'Zu Google Maps wechseln',
      'switch_to_naver': 'Zu Naver Map wechseln',

      // Kostenloser Plan Kartenlimit
      'map_free_limit_exceeded_title': 'Kostenloser Plan Limit',
      'map_free_limit_exceeded_body':
          'Sie haben alle {limit} Google Maps-Öffnungen diesen Monat verbraucht.\n\n'
          'OSM ist immer kostenlos verfügbar.\n'
          'Upgraden Sie auf einen kostenpflichtigen Plan für unbegrenzten Zugang.',
      'map_switch_confirm_title': 'Zu Google Maps wechseln',
      'map_switch_confirm_body':
          'Der kostenlose Plan erlaubt {limit} Google Maps-Öffnungen pro Monat.\n\n'
          'Verbleibend: {remaining}/{limit}\n\n'
          'Der Wechsel zu Google Maps verbraucht 1 Guthaben.\n'
          'OSM ist immer kostenlos und unbegrenzt.',
      'map_switch_btn_cancel': 'Abbrechen',
      'map_switch_btn_confirm': 'Wechseln',

      // Fehlauslösung / Alarmbildschirm
      'btn_snooze': 'Schlummern',
      'btn_dismiss': 'Alarm beenden',
      'btn_false_trigger': 'Fehlauslösung',
      'false_trigger_hint': 'Durch GPS-Fehler ausgelöst',
      'snooze_time_title': 'Schlummerdauer',
      'snooze_min': '{m} Min.',

      // Fehlauslösungs-Info
      'false_trigger_info_title': '⚡ Was ist Fehlauslösung?',
      'false_trigger_info_subtitle':
          'Alarm aktiv halten, wenn durch GPS-Fehler ausgelöst',
      'false_trigger_dialog_title': 'Was ist Fehlauslösung?',
      'false_trigger_dialog_body':
          'Wenn der Alarm klingelt, erscheint eine "⚡ Fehlauslösung"-Taste'
          ' neben "Schlummern" und "Alarm beenden".\n\n'
          'Wenn Sie auf "⚡ Fehlauslösung" tippen:\n'
          '  • Klingelton/Vibration stoppt sofort\n'
          '  • Der Alarm bleibt aktiv (wird nicht deaktiviert)\n'
          '  • Der Alarm kann erneut von vorne auslösen\n\n'
          '📍 GPS-Genauigkeitsgrenzen\n'
          'GPS kann Ihren Standort nur schätzen.'
          ' Selbst im Freien gibt es immer eine Fehlertoleranz von mehreren bis zehn Metern.'
          ' Dies kann dazu führen, dass der Alarm etwas zu früh oder zu spät auslöst.\n\n'
          '📡 GPS-Signalspitzen\n'
          'In GPS-instabilen Umgebungen (Untergrund, hohe Gebäude, signalblockierte Zonen)'
          ' kann der Radiuserkennungsfehler zunehmen. Selbst wenn Sie sich tatsächlich innerhalb des Radius befinden,'
          ' kann GPS Sie vorübergehend als außerhalb lesen — oder umgekehrt.\n'
          'Verwenden Sie in diesen Fällen die "⚡ Fehlauslösung"-Taste.'
          ' Wenn dasselbe Problem wiederholt auftritt, versuchen Sie, Ihren Radius um jeweils 10m zu vergrößern.\n\n'
          '💡 Wenn Sie sich in der Nähe der konfigurierten Radiusgrenze aufhalten oder bewegen müssen\n'
          'Selbst nach dem Tippen auf Fehlauslösung kann der Alarm weiter klingeln.'
          ' Deaktivieren Sie in diesem Fall den Alarm und aktivieren Sie ihn bei Bedarf wieder.\n'
          '("Standby"-Modus — wird bei Nachfrage in Betracht gezogen: automatische Reaktivierung nach einer festgelegten Dauer)',
      'false_trigger_dialog_ok': 'Verstanden',

      // Bluetooth-Geräte-Alarm — unbeabsichtigte Auslösung
      'bt_false_trigger_info_title': '⚡ Unbeabsichtigter Alarm?',
      'bt_false_trigger_info_subtitle':
          'Alarm ohne Ihre Absicht ausgelöst? Hier erfahren Sie, was zu tun ist',
      'bt_false_trigger_dialog_title': 'Unbeabsichtigter Alarm?',
      'bt_false_trigger_dialog_body':
          'Bluetooth-Alarme werden ausgelöst, wenn eine Verbindung oder Trennung\n'
          '15 Sekunden oder länger dauert. Das ist beabsichtigt — aber das Leben\n'
          'läuft nicht immer wie geplant.\n\n'
          'Wenn der Alarm ausgelöst wird, tippen Sie auf "⚡ Fehlauslösung", um den Klingelton zu stoppen\n'
          'und den Alarm für das nächste Mal aktiv zu halten.\n\n'
          '💡 Tipp: Verwenden Sie Wochentag- oder Zeitbedingungen, um unerwünschte\n'
          'Auslösungen zu anderen Tageszeiten erheblich zu reduzieren.',
      'bt_bonded_devices_title': 'Gekoppelte Bluetooth-Geräte',
      'bt_refresh_tooltip': 'Geräteliste aktualisieren',
      'bt_selector_description':
          'Wählen Sie gekoppelte Bluetooth-Geräte zur Erkennung für diesen Ort aus.',
      'bt_permission_needed':
          'Bluetooth-Berechtigung ist erforderlich.\nBitte erlauben Sie den Bluetooth-Zugriff in den Einstellungen.',
      'bt_no_bonded_devices': 'Keine gekoppelten Bluetooth-Geräte gefunden.',
      'bt_selected_count': '{count} Gerät(e) ausgewählt',
      'bt_device_retained': 'Zuvor gespeichert (derzeit nicht gekoppelt)',
      'bt_devices_label': 'Bluetooth-Geräte',
      'bt_none_selected': 'Keine ausgewählt',
      'bt_count_selected': '{count} ausgewählt',

      // Geräte-Alarm
      'device_alarm_empty': 'Keine Geräte-Alarme',
      'device_alarm_empty_desc':
          'Fügen Sie einen Bluetooth-Gerätealarm hinzu,\num benachrichtigt zu werden, wenn ein Gerät verbunden oder getrennt wird.',
      'device_alarm_add': 'Geräte-Alarm hinzufügen',
      'device_alarm_delete_confirm': 'Diesen Gerätealarm löschen?',
      'device_alarm_select_device': 'Gerät auswählen',
      'device_alarm_name_label': 'Alarmname',
      'device_alarm_name_hint': 'Alarmnamen eingeben',
      'device_alarm_trigger_label': 'Auslösen wenn',
      'device_trigger_connect': 'Verbunden',
      'device_trigger_disconnect': 'Getrennt',

      // Meine Geräte
      'my_devices_empty': 'Keine registrierten Geräte',
      'my_devices_empty_desc':
          'Bluetooth-Geräte, die an Orte oder\nGerätealarme gebunden sind, werden hier angezeigt.',
      'my_devices_source_place': 'Ort',
      'my_devices_source_alarm': 'Alarm',
      'my_devices_add': 'Gerät hinzufügen',
      'my_devices_add_title': 'Bluetooth-Gerät hinzufügen',
      'my_devices_custom_name_label': 'Eigener Name',
      'my_devices_custom_name_hint':
          'Geben Sie einen leicht merkbaren Namen ein',
      'my_devices_original_name': 'Bluetooth-Name',
      'my_devices_edit_name': 'Name bearbeiten',
      'edit_device_menu': 'Gerät bearbeiten',
      'add_device_alarm_menu': 'Neuen Alarm hinzufügen',
      'my_devices_delete_confirm': 'Dieses Gerät entfernen?',
      'my_devices_source_manual': 'Manuell',

      // Alarm hinzufügen (feste untere Leiste)
      'add_alarm_btn': 'Alarm hinzufügen',
      'add_device_alarm_btn': 'Alarm hinzufügen',

      // Gerätealarmseite
      'device_alarm_page_title': 'Geräte-Alarm hinzufügen',
      'device_alarm_edit_title': 'Geräte-Alarm bearbeiten',
      'add_new_device_alarm': 'Neuen Geräte-Alarm hinzufügen',
      'select_device_label': 'Gerät auswählen',
      'alarm_on_connect_label': 'Alarm bei Verbindung',
      'alarm_on_disconnect_label': 'Alarm bei Trennung',
      'device_condition_hint':
          'Ohne Bedingungen wird der Alarm bei der ersten Verbindung/Trennung ausgelöst.',
      'device_alarm_voice_section': 'Spracherkennung',
      'device_alarm_voice_msg_label': 'Sprachnachricht',
      'device_alarm_voice_msg_hint':
          'Nachricht, die bei Alarmauslösung angesagt wird',
      'device_alarm_voice_enabled': 'Sprachbenachrichtigung aktivieren',
      'device_alarm_sound_section': 'Alarmton',
      'device_alarm_save_success': 'Geräte-Alarm gespeichert',

      // WLAN
      'wifi_networks_label': 'WLAN-Netzwerke',
      'wifi_none_selected': 'Keine ausgewählt',
      'wifi_count_selected': '{count} ausgewählt',
      'wifi_rescan_tooltip': 'Erneut scannen',
      'wifi_description':
          'Verwenden Sie die WLAN-Verbindung für genauere Standorterkennung.',
      'wifi_disabled': 'WLAN ist ausgeschaltet',
      'wifi_disabled_detail':
          'WLAN ist ausgeschaltet. Bitte aktivieren Sie WLAN und versuchen Sie es erneut.',
      'wifi_scan_failed': 'WLAN-Scan fehlgeschlagen',
      'wifi_no_networks': 'Keine WLAN-Netzwerke erkannt.',
      'wifi_networks_selected': '{count} Netzwerk(e) ausgewählt',
      'wifi_hidden_network': '(Verstecktes Netzwerk)',
      'wifi_currently_connected': 'Derzeit verbunden',
      'wifi_previously_saved': 'Zuvor gespeichert (derzeit nicht erkannt)',
    },

    'fr': {
      // Commun
      'app_name': 'Ringinout',
      'save': 'Enregistrer',
      'cancel': 'Annuler',
      'delete': 'Supprimer',
      'close': 'Fermer',
      'send': 'Envoyer',
      'confirm': 'Confirmer',
      'ok': 'OK',
      'yes': 'Oui',
      'no': 'Non',
      'error': 'Erreur',
      'success': 'Succès',
      'loading': 'Chargement...',

      // Navigation
      'nav_alarm': 'Alarme',
      'nav_my_places': 'Mes lieux',
      'nav_voice': 'Voix',
      'nav_gps': 'GPS',

      // Titres de page
      'page_title_alarm': 'Alarme de lieu',
      'page_title_gps': 'GPS',
      'page_title_places': 'Mes lieux',
      'page_title_voice': 'Reconnaissance vocale',
      'page_title_subscription': 'Abonnement',

      // Onglets
      'tab_location_alarm': 'Alarme de lieu',
      'tab_device_alarm': 'Alarme appareil',
      'tab_my_places': 'Mes lieux',
      'tab_my_devices': 'Mes appareils',
      'page_title_my_devices': 'Mes appareils',
      'page_title_device_alarm': 'Alarme appareil',

      // Mode sélection
      'select_all': 'Tout sélectionner',
      'delete_selected': 'Supprimer',

      // Page d'alarme
      'alarm_title': 'Alarme Ringinout',
      'location_alarm': 'Alarme de lieu',
      'basic_alarm': 'Alarme basique',
      'basic_alarm_page': 'Page d\'alarme basique',
      'sort_options': 'Options de tri',
      'sort_by_time': 'Par heure d\'alarme',
      'sort_custom': 'Ordre personnalisé',
      'sort_place_asc': 'Lieu (A → Z)',
      'sort_place_desc': 'Lieu (Z → A)',
      'sort_name_asc': 'Nom d\'alarme (A → Z)',
      'sort_name_desc': 'Nom d\'alarme (Z → A)',
      'no_alarms': 'Aucune alarme',
      'add_alarm_hint': 'Ajoutez une alarme de lieu !',

      // Gestion des lieux
      'my_places': 'Mes lieux',
      'add_place': 'Ajouter un lieu',
      'edit_place': 'Modifier le lieu',
      'place_name': 'Nom du lieu',
      'place_saved': '✅ Lieu enregistré',
      'place_updated': '✅ Lieu mis à jour',
      'place_deleted': '🗑 Lieu supprimé',
      'no_places': 'Aucun lieu enregistré',
      'no_places_desc':
          'Appuyez sur le bouton pour ajouter votre premier lieu.',
      'add_place_btn': 'Ajouter un lieu',
      'add_place_hint': 'Ajoutez vos lieux favoris !',
      'search_address': 'Rechercher une adresse',
      'current_location': 'Position actuelle',
      'radius': 'Rayon',
      'custom': 'Personnalisé',
      'custom_radius': 'Rayon personnalisé',

      // Ajout/modification d'alarme
      'add_location_alarm': 'Ajouter alarme de lieu',
      'edit_location_alarm': 'Modifier alarme de lieu',
      'alarm_sound': 'Son d\'alarme',
      'vibration': 'Vibration',
      'snooze': 'Répéter',
      'alarm_enabled': 'Alarme activée',
      'entry_exit': 'Entrée/Sortie',
      'on_entry': 'À l\'entrée',
      'on_exit': 'À la sortie',
      'both': 'Les deux',
      'alarm_saved': '✅ Alarme enregistrée',
      'alarm_deleted': '🗑 Alarme supprimée',

      // Paramètres
      'settings': 'Paramètres',
      'language': 'Langue',
      'language_select': 'Sélectionner la langue',
      'system_default': 'Par défaut du système',
      'account': 'Compte',
      'logged_in': 'Connecté',
      'logout': 'Déconnexion',
      'logout_confirm':
          'Êtes-vous sûr de vouloir vous déconnecter ? Vous serez redirigé vers l\'écran de connexion.',
      'google_login': 'Connexion Google',
      'login_success': '✅ Connexion réussie',
      'login_failed': '❌ Échec de la connexion',
      'logged_out': 'Déconnecté',
      'delete_account': 'Supprimer le compte',
      'delete_account_subtitle': 'Supprimer définitivement toutes les données',
      'delete_account_warning':
          'Toutes vos données, y compris les paramètres d\'alarme, les données de localisation et les informations de compte, seront définitivement supprimées.\n\nCette action est irréversible et vos données ne pourront pas être récupérées.',
      'delete_account_confirm': 'Supprimer',
      'delete_account_final_title': 'Confirmation finale',
      'delete_account_final_warning':
          'Êtes-vous absolument sûr ?\nVotre compte et toutes les données associées seront immédiatement supprimés définitivement.',
      'delete_account_final_confirm': 'Supprimer définitivement',
      'delete_account_failed':
          '❌ Échec de la suppression du compte. Veuillez réessayer.',
      'feedback': 'Envoyer un commentaire',
      'feedback_title': 'Envoyer un commentaire',
      'feedback_hint': 'Entrez vos commentaires ou suggestions',
      'feedback_sent': '✅ Commentaire envoyé. Merci !',
      'app_info': 'Info app',

      // Page de connexion
      'login_app_description':
          'Application d\'alarme basée sur la localisation.\nSoyez notifié quand vous arrivez ou quittez un lieu !',
      'login_data_security_title': 'Promesse de sécurité des données',
      'login_data_security_content':
          'Seuls votre identifiant de compte chiffré et votre statut de paiement sont stockés sur nos serveurs. Les informations de localisation et personnelles sont traitées uniquement sur votre appareil.',
      'login_data_deletion_warning':
          'Tous les lieux enregistrés et les paramètres d\'alarme seront supprimés lors de la désinstallation de l\'application.',
      'login_continue_with_google': 'Continuer avec Google',
      'login_cancelled': 'Connexion annulée',
      'login_not_supported':
          'La connexion Google n\'est pas prise en charge sur cet appareil',
      'version': 'Version',
      'location_based_alarm': 'Application d\'alarme basée sur la localisation',
      'privacy_policy': 'Politique de confidentialité',

      // Politique de confidentialité
      'privacy_policy_title': 'Politique de confidentialité',
      'privacy_last_updated': 'Dernière mise à jour : janvier 2026',
      'privacy_section_1_title': '1. Informations que nous collectons',
      'privacy_section_1_content':
          'Ringinout ne collecte pas d\'informations personnelles.\n\n'
          '• Données de localisation : Traitées uniquement sur votre appareil pour la fonctionnalité d\'alarme. Non envoyées à des serveurs externes.\n\n'
          '• Informations de compte : Lors de la connexion avec Google, votre e-mail est converti en un identifiant aléatoire anonymisé. L\'e-mail original n\'est pas stocké.',
      'privacy_section_2_title': '2. Objectif de l\'identifiant anonymisé',
      'privacy_section_2_content':
          'L\'identifiant anonymisé est utilisé uniquement pour vérifier le statut d\'abonnement premium. '
          'Cet identifiant ne peut pas être utilisé pour identifier ou suivre des individus.',
      'privacy_section_3_title': '3. Stockage des données',
      'privacy_section_3_content':
          'Toutes les données d\'alarme et de localisation sont stockées uniquement sur votre appareil '
          'et ne sont pas transmises à des serveurs externes.',
      'privacy_section_4_title': '4. Partage avec des tiers',
      'privacy_section_4_content':
          'Ringinout ne partage aucune information utilisateur avec des tiers.',
      'privacy_section_5_title': '5. Contact',
      'privacy_section_5_content':
          'Pour les demandes liées à la confidentialité, veuillez utiliser la fonction \'Envoyer un commentaire\' dans l\'application.',

      // Autorisations
      'permission_required': 'Autorisation requise',
      'location_permission': 'Autorisation de localisation',
      'notification_permission': 'Autorisation de notification',
      'background_permission': 'Autorisation de localisation en arrière-plan',
      'background_location_desc':
          'Détecte votre position même lorsque l\'application n\'est pas utilisée.',
      'overlay_permission': 'Afficher par-dessus d\'autres applications',
      'overlay_permission_desc':
          'Requis pour afficher les alarmes en plein écran.',
      'grant_permission': 'Accorder l\'autorisation',
      'allow': 'Autoriser',
      'permission_settings': 'Paramètres d\'autorisation',
      'setup_complete': 'Configuration terminée ! 🎉',
      'grant_all_permissions': 'Veuillez accorder toutes les autorisations',
      'setup_later': 'Configurer plus tard',
      'location_permission_desc':
          'Requis pour détecter les emplacements d\'alarme.',
      'battery_opt_warning_title': 'Optimisation de batterie non exclue',
      'battery_opt_warning_desc':
          'Cet avis apparaît car l\'exclusion de l\'optimisation de batterie est actuellement désactivée. '
          'L\'application peut continuer à fonctionner, mais les alarmes peuvent être retardées ou manquées sur certains appareils. '
          'Nous recommandons d\'exclure cette application de l\'optimisation de batterie.',

      // Page GPS
      'gps_title': 'GPS',
      'geofence_service_status': 'État du service Geofence',
      'status_running': '✅ En cours',
      'status_stopped': '❌ Arrêté',
      'status': 'État',
      'last_event': 'Dernier événement',
      'last_event_none': 'Aucun',
      'settings_interval':
          'Paramètres : intervalle {interval}s, précision {accuracy}m',
      'geofence_status_debug': 'État Geofence (Debug)',
      'no_saved_places': 'Aucun lieu enregistré',
      'distance': 'Distance',
      'radius_label': 'Rayon',
      'no_location_info': 'Aucune info de localisation',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'updated': 'Mis à jour',
      'active_alarm_distance': 'Distances des alarmes actives',
      'no_active_alarms': 'Aucune alarme active ou aucune info de localisation',
      'alarm': 'Alarme',
      'place_unknown': 'Lieu inconnu',
      'cannot_calculate_distance': 'Impossible de calculer la distance',
      'location_permission_required':
          'L\'autorisation de localisation est requise.',
      'inside': 'À l\'intérieur',
      'outside': 'À l\'extérieur',

      // Jours de la semaine
      'sun': 'Dim',
      'mon': 'Lun',
      'tue': 'Mar',
      'wed': 'Mer',
      'thu': 'Jeu',
      'fri': 'Ven',
      'sat': 'Sam',
      'every_week': 'Chaque {days}',
      'first_entry_after_set': 'Première entrée après le réglage de l\'alarme',
      'first_exit_after_set': 'Première sortie après le réglage de l\'alarme',
      'no_selection': 'Aucune sélection',

      // Paramètres des jours fériés
      'holiday_settings': 'Paramètres des jours fériés',
      'turn_off_on_holidays':
          'Désactiver les jours fériés de substitution/temporaires',
      'turn_on_on_holidays':
          'Activer les jours fériés de substitution/temporaires',

      // Pays des jours fériés
      'holiday_country': 'Pays des jours fériés',
      'holiday_country_auto': 'Auto',
      'holiday_country_auto_detected': 'Auto (Détecté : {country})',
      'holiday_country_auto_detecting': 'Auto (Détection...)',
      'country_KR': 'Corée du Sud',
      'country_US': 'États-Unis',
      'country_JP': 'Japon',
      'country_CN': 'Chine',
      'country_VN': 'Vietnam',
      'country_MY': 'Malaisie',
      'country_TH': 'Thaïlande',
      'country_CA': 'Canada',
      'country_BR': 'Brésil',
      'country_TW': 'Taïwan',
      'country_DE': 'Allemagne',
      'country_FR': 'France',
      'country_ES': 'Espagne',
      'country_IT': 'Italie',
      'country_NL': 'Pays-Bas',
      'country_SE': 'Suède',
      'country_PL': 'Pologne',
      'country_GB': 'Royaume-Uni',

      // Groupement d'alarmes
      'alarm_count': '{count} alarmes',
      'alarm_count_one': '1 alarme',
      'other_places': 'Autres',

      // Ajout d'alarme de lieu
      'add_new_location_alarm': 'Ajouter une nouvelle alarme de lieu',
      'done': 'Terminé',
      'alarm_name': 'Nom de l\'alarme',
      'no_name': 'Sans nom',
      'select_place': 'Sélectionner un lieu',
      'alarm_on_entry': 'Alarme à l\'entrée',
      'alarm_on_exit': 'Alarme à la sortie',

      // Reconnaissance vocale
      'voice_input': 'Saisie vocale',
      'voice_listening': 'Écoute...',
      'voice_not_recognized': 'Voix non reconnue',
      'tap_to_speak': 'Appuyez pour parler',
      'select_location_on_map': 'Sélectionner un lieu sur la carte',

      // Écran d'alarme
      'dismiss': 'Fermer',
      'snooze_minutes': 'Répéter {minutes} min',
      'alarm_ringing': 'Alarme en cours !',

      // Info batterie
      'battery_info_text_prefix':
          'Les alarmes actives redémarrent automatiquement à la fermeture de l\'application.\nPour des alarmes fiables, ',
      'battery_info_text_action': 'exclure de l\'optimisation de batterie',
      'battery_info_text_suffix': '.',
      'battery_opt_exclude': 'Exclure de l\'optimisation de batterie',
      'no_saved_alarms': 'Aucune alarme enregistrée.',
      'no_saved_alarms_desc':
          'Appuyez sur le bouton pour ajouter votre première alarme.',

      // Bienvenue
      'get_started': 'Commencer',

      // Page vocale
      'voice_main_title': 'Enregistrer des alarmes par la voix',
      'voice_example_phrase': '"Prévenez-moi quand j\'arrive au travail"',
      'voice_tap_to_start': 'Appuyez pour commencer',
      'voice_widget_title': 'Ajouter un widget à l\'écran d\'accueil',
      'voice_widget_subtitle':
          'Lancez la reconnaissance vocale d\'un simple toucher !',
      'voice_widget_guide_title': 'Ajouter un widget à l\'écran d\'accueil',
      'voice_widget_guide_subtitle':
          'Lancez les alarmes vocales plus rapidement !',
      'voice_widget_step1':
          'Appui long sur un espace vide de l\'écran d\'accueil',
      'voice_widget_step2': 'Sélectionnez le menu "Widgets"',
      'voice_widget_step3': 'Cherchez "ringinout" ou "Alarme vocale"',
      'voice_widget_step4': 'Glissez le widget sur l\'écran d\'accueil',
      'voice_widget_tip':
          'Avec un widget, vous pouvez lancer des alarmes vocales\ndirectement depuis votre écran d\'accueil sans ouvrir l\'application !',
      'voice_widget_got_it': 'Compris !',
      'voice_tip_title': '💡 Exemples de reconnaissance vocale',
      'voice_tip_examples':
          '• "Prévenez-moi quand j\'arrive au travail le lundi"\n'
          '  → Chaque lundi, à l\'entrée\n'
          '• "Alertez-moi quand je quitte la maison le 12 avril"\n'
          '  → Le 12 avril uniquement, à la sortie\n'
          '• "Sonnez quand je rentre à la maison après 18h le lundi"\n'
          '  → Chaque lundi, après 18:00, à l\'entrée\n'
          '• "Rappelez-moi quand je quitte la maison à 9h le 13 mars"\n'
          '  → Le 13 mars, après 9:00, à la sortie',
      'voice_tip_note':
          'Jours, dates et heures sont définis automatiquement\n(Le geofence GPS peut se déclencher dans un délai de ±secondes à la limite)',
      // Onglets vocaux
      'voice_tab_location': 'Voix lieu',
      'voice_tab_device': 'Voix appareil',
      'voice_device_main_title':
          'Enregistrer des alarmes d\'appareil par la voix',
      'voice_device_example_phrase':
          '"Prévenez-moi quand les Galaxy Buds se connectent"',
      'voice_device_tip_title': '💡 Exemples vocaux d\'appareil',
      'voice_device_tip_examples':
          '• "Prévenez-moi quand les Galaxy Buds se connectent le lundi"\n'
          '  → Chaque lundi, à la connexion\n'
          '• "Alertez-moi quand les écouteurs se déconnectent le 12 avril"\n'
          '  → Le 12 avril uniquement, à la déconnexion\n'
          '• "Sonnez quand les Buds se connectent après 18h le lundi"\n'
          '  → Chaque lundi, après 18:00, à la connexion\n'
          '• "Dites-moi quand la montre se déconnecte à 9h le 13 mars"\n'
          '  → Le 13 mars, après 9:00, à la déconnexion',
      'voice_device_tip_note':
          'Jours, dates et heures sont définis automatiquement\n(Les changements d\'état Bluetooth sont détectés en temps réel)',
      'voice_first_visit_title': '💡 Astuce pro !',
      'voice_first_visit_desc':
          'Ajoutez un widget à votre écran d\'accueil\npour lancer des alarmes vocales\nsans ouvrir l\'application !',
      'voice_first_visit_btn': 'Voir comment ajouter un widget',
      'voice_first_visit_later': 'Peut-être plus tard',

      // Abonnement
      'subscription_tab': 'Abonnement',
      'gps_tab': 'GPS',
      // Page GPS
      'gps_current_location': 'Position actuelle',
      'gps_latitude': 'Latitude',
      'gps_longitude': 'Longitude',
      'gps_accuracy': 'Précision',
      'gps_accuracy_good': 'Bonne',
      'gps_accuracy_fair': 'Moyenne',
      'gps_accuracy_poor': 'Mauvaise',
      'gps_updated_at': 'Mis à jour',
      'gps_no_location': 'Aucune donnée de localisation',
      'gps_alarm_status': 'État de l\'alarme de lieu',
      'gps_stopped': 'Arrêté',
      'gps_inside': 'À l\'intérieur',
      'gps_outside': 'À l\'extérieur',
      'gps_moving': 'En mouvement',
      'gps_alarms': 'Alarmes',
      'gps_place_status': 'État du lieu',
      'gps_place_status_refresh_tooltip': 'Actualiser l\'état du lieu',
      'gps_no_tracked_places': 'Aucun lieu suivi',
      'gps_place_status_updated': '{count} lieu(x) état actualisé',
      'gps_entry': 'Entrée',
      'gps_exit': 'Sortie',
      'gps_bug_report': 'Rapport de bug',
      'gps_bug_report_sending': 'Envoi...',
      'gps_bug_report_title': 'Rapport de bug',
      'gps_refresh_tooltip': 'Actualiser GPS',
      'subscription_current_plan': 'Plan actuel',
      'subscription_expires': 'Expire : {date}',
      'subscription_free_plan': 'Plan gratuit',
      'subscription_unlimited': 'Illimité',
      'subscription_places_n': '{n} lieux',
      'subscription_alarms_n': '{n} alarmes actives',
      'subscription_places_unlimited': 'Lieux illimités',
      'subscription_alarms_unlimited': 'Alarmes illimitées',
      'subscription_map_opens_50': '50 ouvertures de carte/mois',
      'subscription_map_opens_unlimited': 'Ouvertures de carte illimitées',
      'subscription_no_ads': 'Sans publicité',
      'subscription_all_unlimited': 'Toutes les fonctionnalités illimitées',
      'subscription_dev_plan':
          'Plan développeur - toutes les fonctionnalités illimitées',
      'subscription_subscribe': 'S\'abonner',
      'subscription_in_use': 'En cours d\'utilisation',
      'subscription_recommended': 'Recommandé',
      'subscription_coming_soon': 'Fonction d\'abonnement bientôt disponible.',
      'subscription_beta_notice':
          'Les plans payants ne sont pas disponibles pendant la bêta. Ils seront disponibles après la fin de la bêta.',
      'subscription_per_month': '/ mois',
      'subscription_policy': 'Politique d\'abonnement',
      'subscription_refund_policy': 'Politique de remboursement',
      'subscription_price_tbd': 'Tarif à venir',
      'subscription_pro_fair_use':
          'Politique d\'usage équitable : jusqu\'à 500 ouvertures de carte par mois pour prévenir les abus.',
      'subscription_map_opens_500': '500 ouvertures de carte/mois',

      // Clés supplémentaires ajout/modification d'alarme
      'plan_upgrade_needed': 'Mise à niveau du plan nécessaire',
      'add_alarm_tooltip': 'Ajouter une alarme',
      'entry_trigger': 'Entrée',
      'exit_trigger': 'Sortie',
      'entry_exit_trigger': 'Entrée/Sortie',
      'am_label': 'Matin',
      'pm_label': 'Après-midi',
      'hour_suffix': ':',
      'min_suffix': '',
      'after_suffix': ' après',
      'first_trigger_immediate': 'Alarme au premier {trigger}',
      'first_trigger_condition': '{conditions} premier {trigger}',
      'monthly_date': '{month}/{day}({weekday})',
      'weekly_prefix': 'Chaque {days}',
      'listening_prompt': '🎙️ Écoute... Parlez maintenant !',
      'done_btn': 'Terminé',
      'alarm_name_label': 'Nom de l\'alarme',
      'no_name_label': 'Sans nom',
      'select_place_label': 'Sélectionner un lieu',
      'alarm_on_entry_label': 'Alarme à l\'entrée',
      'alarm_on_exit_label': 'Alarme à la sortie',
      'boundary_warning':
          'Près de la limite du geofence, l\'alarme peut sonner plusieurs fois si vous restez ou faites des allers-retours. '
          'Utilisez le bouton "Répéter" pour retarder l\'alarme.',
      'condition_settings': 'Paramètres de condition (Optionnel)',
      'condition_hint':
          'Sans conditions, l\'alarme sonne à la première entrée/sortie après l\'enregistrement.',
      'no_date_set': 'Aucune date définie',
      'time_condition_hint': 'Condition horaire (optionnel)',
      'time_after': '⏰ {time} après',
      'holidays_off': 'Désactivé les jours fériés',
      'holidays_sub_on': 'Activé les jours fériés de substitution/temporaires',
      'alarm_sound_label': 'Son d\'alarme',
      'alarm_sound_default': 'Son d\'alarme par défaut de l\'appareil',
      'alarm_sound_unchangeable': 'Ne peut pas être modifié',
      'save_btn': 'Enregistrer',
      'delete_btn': 'Supprimer',
      'edit_alarm_title': 'Modifier l\'alarme de lieu',
      'select_place_hint': 'Sélectionner un lieu',
      'select_place_required': 'Veuillez sélectionner un lieu',
      'alarm_save_failed': 'Échec de l\'enregistrement de l\'alarme : {error}',

      // Page d'ajout de lieu
      'address_search_result': 'Résultats de recherche d\'adresse',
      'save_place_title': 'Enregistrer le lieu',
      'place_name_label': 'Nom du lieu',
      'place_name_hint': 'ex. Maison, Bureau, Salle de sport',
      'radius_display': 'Rayon : {radius}m',
      'radius_shown_on_map': '(Affiché en cercle sur la carte)',
      'cancel_btn': 'Annuler',
      'save_place_btn': 'Enregistrer',
      'place_saved_msg': '✅ Lieu enregistré',
      'select_on_map': 'Sélectionner un lieu sur la carte',
      'move_to_current': 'Aller à la position actuelle',
      'search_hint': 'Adresse ou nom de lieu (ex. Starbucks)',
      'no_search_result': 'Aucun résultat de recherche',
      'address_label': 'Adresse : {address}',
      'radius_label_prefix': 'Rayon : ',
      'custom_input': 'Personnalisé',
      'save_location_btn': 'Enregistrer le lieu',
      'signal_warning':
          '📍 Guide de configuration du rayon\n'
          '• Dans les zones instables GPS (souterrain, grands bâtiments, zones sans signal), des faux déclenchements peuvent survenir.\n'
          '  Pour les faux déclenchements ponctuels, appuyez sur le bouton "⚡ Faux déclenchement" pour les ignorer rapidement.\n'
          '• Si vous restez près d\'une limite de zone, l\'alarme peut continuer à sonner même après avoir appuyé sur Faux déclenchement.\n'
          '  Dans ce cas, désactivez l\'alarme et réactivez-la quand nécessaire.\n'
          '• Si les faux déclenchements sont fréquents, essayez d\'augmenter le rayon de 10m à la fois.',
      'radius_guide_btn':
          '📍 Guide de configuration du rayon  —  À lire absolument !!',
      'radius_guide_dialog_body':
          '📍 Limites de précision GPS\n'
          'Le GPS ne peut qu\'estimer votre position. Même en extérieur, attendez-vous à une marge d\'erreur'
          ' de plusieurs à dizaines de mètres. C\'est une limitation inhérente au GPS.\n\n'
          '📡 Pics de signal GPS\n'
          'Dans les environnements GPS instables (souterrain, grands bâtiments, zones sans signal),'
          ' l\'erreur de détection du rayon peut augmenter. Même si vous êtes réellement à l\'intérieur du rayon,'
          ' le GPS peut temporairement vous lire comme étant à l\'extérieur — ou vice versa.\n'
          'Dans ces cas, utilisez le bouton "\u26a1 Faux déclenchement".'
          ' Si le même problème se répète, essayez d\'augmenter votre rayon de 10m à la fois.\n\n'
          '💡 Si vous devez rester ou vous déplacer près de la limite de rayon configurée\n'
          'Même après avoir appuyé sur Faux déclenchement, l\'alarme peut continuer à sonner.'
          ' Dans ce cas, désactivez l\'alarme et réactivez-la quand nécessaire.\n'
          '(Mode "Veille" — à l\'étude si demandé : réactivation automatique après une durée définie)',
      'radius_input_range': '30m ~ 500m (incréments de 10m)',

      // Page des conditions
      'terms_agreement_title': 'Accord des conditions (Requis)',
      'terms_agree_text':
          'J\'ai lu et j\'accepte les Conditions d\'utilisation et la Politique de remboursement/abonnement.',
      'terms_agree_btn': 'Accepter et continuer',
      'terms_disagree_btn': 'Refuser (Fermer l\'application)',
      'terms_save_failed':
          'Échec de l\'enregistrement des conditions. Veuillez réessayer.',

      // Son d'alarme
      'alarm_sound_setting_title': 'Paramètres du son d\'alarme',
      'alarm_disabled_label': 'Alarme désactivée',

      // add_alarm_page
      'add_alarm_new_title': 'Ajouter une nouvelle alarme',
      'edit_alarm_modify_title': 'Modifier l\'alarme de lieu',
      'location_fixed_text': 'Cette alarme est liée à ce lieu',
      'no_place_label': 'Aucun lieu',
      'required_fields_msg': 'Veuillez remplir tous les champs obligatoires.',
      'holidays_dialog_title':
          'Paramètres des jours fériés de substitution/temporaires',
      'holidays_sub_off':
          'Désactivé les jours fériés de substitution/temporaires aussi',

      // my_places_page
      'delete_confirm_title': 'Confirmer la suppression',
      'delete_locked_msg': 'Supprimer ce lieu verrouillé ?',
      'delete_place_msg': 'Êtes-vous sûr de vouloir supprimer ce lieu ?',
      'linked_alarm_delete_warning':
          '⚠️ {count} alarme(s) liée(s) seront également supprimées.',
      'edit_places_menu': 'Modifier le lieu',
      'add_alarm_menu': 'Ajouter une nouvelle alarme',
      'add_place_tooltip': 'Ajouter un nouveau lieu',

      // show_alarm_popup_page
      'alarm_end_confirm': 'Arrêter l\'alarme ?',
      'no_label': 'Non',
      'yes_label': 'Oui',
      'snooze_btn': 'Répéter',
      'alarm_stop_btn': 'Arrêter l\'alarme',

      // Paramètres snooze/vibration
      'snooze_setting_title': 'Paramètres de répétition',
      'vibration_setting_title': 'Paramètres de vibration',

      // Autorisation
      'permission_setting_title': 'Paramètres d\'autorisation',
      'permission_allow': 'Autoriser',
      'battery_opt_title': 'Désactiver l\'optimisation de batterie',
      'battery_opt_msg':
          'Pour que les alarmes fonctionnent correctement en arrière-plan, l\'optimisation de batterie doit être désactivée.\nAllez dans les Paramètres, trouvez "Optimisation de batterie" et définissez Ringinout sur "Non optimisé".',
      'open_settings_btn': 'Ouvrir les paramètres',
      'later_btn': 'Plus tard',

      // Gestion d'abonnement
      'subscription_mgmt_title': 'Gestion de l\'abonnement',
      'subscription_policy_btn': 'Politique d\'abonnement',
      'refund_policy_btn': 'Politique de remboursement',
      'auto_renew_msg':
          'Renouvelé automatiquement selon les politiques de Google Play.',
      'agree_auto_pay': 'J\'accepte le paiement automatique.',
      'agree_policy': 'J\'ai examiné la politique d\'abonnement/remboursement.',
      'start_auto_subscription': 'Démarrer l\'abonnement automatique',
      'current_plan': 'Plan actuel',
      'cancel_subscription': 'Annuler',
      'subscribe_btn': 'S\'abonner',
      'auto_subscribe_btn': 'Abonnement automatique',
      'beta_no_paid_plans':
          'Les plans payants ne sont pas disponibles pendant la bêta. Ils seront disponibles après la fin de la bêta.',
      'places_5': '5 lieux',
      'active_alarms_10': '10 alarmes actives',
      'ad_free_included': 'Sans publicité inclus',
      'places_alarms_unlimited': 'Lieux/Alarmes illimités',
      'ad_remove_title': 'Supprimer les publicités',
      'in_app_ad_remove': 'Suppression des publicités dans l\'application',
      'price_loading': 'Chargement du prix',
      'duration_1month': '1 mois',
      'duration_3months': '3 mois',
      'duration_6months': '6 mois',
      'duration_12months': '12 mois',
      'discount_5': '5% de réduction',
      'discount_10': '10% de réduction',
      'discount_20': '20% de réduction',
      'expiry_date_none': 'Expiration : -',
      'expiry_date_format': 'Expiration : {date}',
      'beta_sub_activate_later':
          'Les abonnements seront activés après la fin de la bêta.',

      // Dialogue de limite d'abonnement
      'place_limit_title': 'Limite d\'enregistrement de lieux',
      'place_limit_msg':
          'Dans le plan {plan}, vous pouvez enregistrer jusqu\'à {limit} lieux.\nVeuillez supprimer des lieux existants ou mettre à niveau.',
      'alarm_limit_title': 'Limite d\'enregistrement d\'alarmes',
      'alarm_limit_msg':
          'Dans le plan {plan}, vous pouvez définir jusqu\'à {limit} alarmes actives.\nVeuillez supprimer des alarmes existantes ou mettre à niveau.',
      'close_btn': 'Fermer',

      // Sélecteur de lieu
      'place_name_input_title': 'Entrer le nom du lieu',
      'radius_default_info': 'Rayon : 100m (peut être modifié plus tard)',
      'location_select_title': 'Sélectionner un lieu',
      'fetching_location': 'Récupération de la position actuelle...',
      'location_saved': '📍 Lieu enregistré !',

      // Connexion supplémentaire
      'dev_test_mode': 'Mode test développeur',
      'test_login_failed': 'Échec de la connexion test : {error}',

      // Changement de carte
      'switch_to_google': 'Passer à Google Maps',
      'switch_to_naver': 'Passer à Naver Map',

      // Limite de carte plan gratuit
      'map_free_limit_exceeded_title': 'Limite du plan gratuit',
      'map_free_limit_exceeded_body':
          'Vous avez utilisé toutes les {limit} ouvertures Google Maps ce mois-ci.\n\n'
          'OSM est toujours disponible gratuitement.\n'
          'Passez à un plan payant pour un accès illimité.',
      'map_switch_confirm_title': 'Passer à Google Maps',
      'map_switch_confirm_body':
          'Le plan gratuit permet {limit} ouvertures Google Maps par mois.\n\n'
          'Restant : {remaining}/{limit}\n\n'
          'Passer à Google Maps utilise 1 crédit.\n'
          'OSM est toujours gratuit et illimité.',
      'map_switch_btn_cancel': 'Annuler',
      'map_switch_btn_confirm': 'Passer',

      // Faux déclenchement / Écran d'alarme
      'btn_snooze': 'Répéter',
      'btn_dismiss': 'Arrêter l\'alarme',
      'btn_false_trigger': 'Faux déclenchement',
      'false_trigger_hint': 'Déclenché par erreur GPS',
      'snooze_time_title': 'Durée de répétition',
      'snooze_min': '{m} min',

      // Info faux déclenchement
      'false_trigger_info_title': '⚡ Qu\'est-ce que le faux déclenchement ?',
      'false_trigger_info_subtitle':
          'Garder l\'alarme active quand déclenchée par erreur GPS',
      'false_trigger_dialog_title': 'Qu\'est-ce que le faux déclenchement ?',
      'false_trigger_dialog_body':
          'Quand l\'alarme sonne, un bouton "⚡ Faux déclenchement" apparaît'
          ' à côté de "Répéter" et "Arrêter l\'alarme".\n\n'
          'Quand vous appuyez sur "⚡ Faux déclenchement" :\n'
          '  • La sonnerie/vibration s\'arrête immédiatement\n'
          '  • L\'alarme reste active (non désactivée)\n'
          '  • L\'alarme peut se déclencher à nouveau\n\n'
          '📍 Limites de précision GPS\n'
          'Le GPS ne peut qu\'estimer votre position.'
          ' Même en extérieur, il y a toujours une marge d\'erreur de plusieurs à dizaines de mètres.'
          ' Cela peut faire sonner l\'alarme un peu trop tôt ou tard.\n\n'
          '📡 Pics de signal GPS\n'
          'Dans les environnements GPS instables (souterrain, grands bâtiments, zones sans signal),'
          ' l\'erreur de détection du rayon peut augmenter. Même si vous êtes réellement à l\'intérieur du rayon,'
          ' le GPS peut temporairement vous lire comme étant à l\'extérieur — ou vice versa.\n'
          'Dans ces cas, utilisez le bouton "⚡ Faux déclenchement".'
          ' Si le même problème se répète, essayez d\'augmenter votre rayon de 10m à la fois.\n\n'
          '💡 Si vous devez rester ou vous déplacer près de la limite de rayon configurée\n'
          'Même après avoir appuyé sur Faux déclenchement, l\'alarme peut continuer à sonner.'
          ' Dans ce cas, désactivez l\'alarme et réactivez-la quand nécessaire.\n'
          '(Mode "Veille" — à l\'étude si demandé : réactivation automatique après une durée définie)',
      'false_trigger_dialog_ok': 'Compris',

      // Alarme Bluetooth — déclenchement non intentionnel
      'bt_false_trigger_info_title': '⚡ Alarme non intentionnelle ?',
      'bt_false_trigger_info_subtitle':
          'L\'alarme s\'est déclenchée sans votre intention ? Voici quoi faire',
      'bt_false_trigger_dialog_title': 'Alarme non intentionnelle ?',
      'bt_false_trigger_dialog_body':
          'Les alarmes Bluetooth se déclenchent quand une connexion ou déconnexion\n'
          'dure 15 secondes ou plus. C\'est voulu — mais la vie\n'
          'ne se passe pas toujours comme prévu.\n\n'
          'Quand l\'alarme se déclenche, appuyez sur "⚡ Faux déclenchement" pour arrêter la sonnerie\n'
          'tout en gardant l\'alarme active pour la prochaine fois.\n\n'
          '💡 Astuce : Utilisez des conditions de jour ou d\'heure pour réduire grandement\n'
          'les déclenchements non souhaités à d\'autres moments de la journée.',
      'bt_bonded_devices_title': 'Appareils Bluetooth jumelés',
      'bt_refresh_tooltip': 'Actualiser la liste des appareils',
      'bt_selector_description':
          'Sélectionnez les appareils Bluetooth jumelés à détecter pour ce lieu.',
      'bt_permission_needed':
          'L\'autorisation Bluetooth est requise.\nVeuillez autoriser l\'accès Bluetooth dans les Paramètres.',
      'bt_no_bonded_devices': 'Aucun appareil Bluetooth jumelé trouvé.',
      'bt_selected_count': '{count} appareil(s) sélectionné(s)',
      'bt_device_retained': 'Précédemment enregistré (non jumelé actuellement)',
      'bt_devices_label': 'Appareils Bluetooth',
      'bt_none_selected': 'Aucun sélectionné',
      'bt_count_selected': '{count} sélectionné(s)',

      // Alarme appareil
      'device_alarm_empty': 'Aucune alarme appareil',
      'device_alarm_empty_desc':
          'Ajoutez une alarme d\'appareil Bluetooth pour être notifié\nquand un appareil se connecte ou se déconnecte.',
      'device_alarm_add': 'Ajouter alarme appareil',
      'device_alarm_delete_confirm': 'Supprimer cette alarme appareil ?',
      'device_alarm_select_device': 'Sélectionner un appareil',
      'device_alarm_name_label': 'Nom de l\'alarme',
      'device_alarm_name_hint': 'Entrez le nom de l\'alarme',
      'device_alarm_trigger_label': 'Déclencher quand',
      'device_trigger_connect': 'Connecté',
      'device_trigger_disconnect': 'Déconnecté',

      // Mes appareils
      'my_devices_empty': 'Aucun appareil enregistré',
      'my_devices_empty_desc':
          'Les appareils Bluetooth enregistrés pour des lieux ou\ndes alarmes d\'appareil apparaîtront ici.',
      'my_devices_source_place': 'Lieu',
      'my_devices_source_alarm': 'Alarme',
      'my_devices_add': 'Ajouter un appareil',
      'my_devices_add_title': 'Ajouter un appareil Bluetooth',
      'my_devices_custom_name_label': 'Nom personnalisé',
      'my_devices_custom_name_hint': 'Entrez un nom facile à retenir',
      'my_devices_original_name': 'Nom Bluetooth',
      'my_devices_edit_name': 'Modifier le nom',
      'edit_device_menu': 'Modifier l\'appareil',
      'add_device_alarm_menu': 'Ajouter une nouvelle alarme',
      'my_devices_delete_confirm': 'Supprimer cet appareil ?',
      'my_devices_source_manual': 'Manuel',

      // Bouton d'ajout d'alarme (barre inférieure fixe)
      'add_alarm_btn': 'Ajouter une alarme',
      'add_device_alarm_btn': 'Ajouter une alarme',

      // Page alarme appareil
      'device_alarm_page_title': 'Ajouter alarme appareil',
      'device_alarm_edit_title': 'Modifier alarme appareil',
      'add_new_device_alarm': 'Ajouter une nouvelle alarme appareil',
      'select_device_label': 'Sélectionner un appareil',
      'alarm_on_connect_label': 'Alarme à la connexion',
      'alarm_on_disconnect_label': 'Alarme à la déconnexion',
      'device_condition_hint':
          'Sans conditions, l\'alarme se déclenche à la première connexion/déconnexion.',
      'device_alarm_voice_section': 'Reconnaissance vocale',
      'device_alarm_voice_msg_label': 'Message vocal',
      'device_alarm_voice_msg_hint':
          'Message à annoncer quand l\'alarme se déclenche',
      'device_alarm_voice_enabled': 'Activer la notification vocale',
      'device_alarm_sound_section': 'Son d\'alarme',
      'device_alarm_save_success': 'Alarme appareil enregistrée',

      // Wi-Fi
      'wifi_networks_label': 'Réseaux Wi-Fi',
      'wifi_none_selected': 'Aucun sélectionné',
      'wifi_count_selected': '{count} sélectionné(s)',
      'wifi_rescan_tooltip': 'Rescanner',
      'wifi_description':
          'Utilisez la connexion Wi-Fi pour une détection de localisation plus précise.',
      'wifi_disabled': 'Le Wi-Fi est désactivé',
      'wifi_disabled_detail':
          'Le Wi-Fi est désactivé. Veuillez activer le Wi-Fi et réessayer.',
      'wifi_scan_failed': 'Échec du scan Wi-Fi',
      'wifi_no_networks': 'Aucun réseau Wi-Fi détecté.',
      'wifi_networks_selected': '{count} réseau(x) sélectionné(s)',
      'wifi_hidden_network': '(Réseau caché)',
      'wifi_currently_connected': 'Actuellement connecté',
      'wifi_previously_saved':
          'Précédemment enregistré (non détecté actuellement)',
    },

    'es': {
      // Común
      'app_name': 'Ringinout',
      'save': 'Guardar',
      'cancel': 'Cancelar',
      'delete': 'Eliminar',
      'close': 'Cerrar',
      'send': 'Enviar',
      'confirm': 'Confirmar',
      'ok': 'OK',
      'yes': 'Sí',
      'no': 'No',
      'error': 'Error',
      'success': 'Éxito',
      'loading': 'Cargando...',

      // Navegación
      'nav_alarm': 'Alarma',
      'nav_my_places': 'Mis lugares',
      'nav_voice': 'Voz',
      'nav_gps': 'GPS',

      // Títulos de página
      'page_title_alarm': 'Alarma de ubicación',
      'page_title_gps': 'GPS',
      'page_title_places': 'Mis lugares',
      'page_title_voice': 'Reconocimiento de voz',
      'page_title_subscription': 'Suscripción',

      // Pestañas
      'tab_location_alarm': 'Alarma de ubicación',
      'tab_device_alarm': 'Alarma de dispositivo',
      'tab_my_places': 'Mis lugares',
      'tab_my_devices': 'Mis dispositivos',
      'page_title_my_devices': 'Mis dispositivos',
      'page_title_device_alarm': 'Alarma de dispositivo',

      // Modo de selección
      'select_all': 'Seleccionar todo',
      'delete_selected': 'Eliminar',

      // Página de alarma
      'alarm_title': 'Alarma Ringinout',
      'location_alarm': 'Alarma de ubicación',
      'basic_alarm': 'Alarma básica',
      'basic_alarm_page': 'Página de alarma básica',
      'sort_options': 'Opciones de orden',
      'sort_by_time': 'Por hora de alarma',
      'sort_custom': 'Orden personalizado',
      'sort_place_asc': 'Lugar (A → Z)',
      'sort_place_desc': 'Lugar (Z → A)',
      'sort_name_asc': 'Nombre de alarma (A → Z)',
      'sort_name_desc': 'Nombre de alarma (Z → A)',
      'no_alarms': 'Sin alarmas',
      'add_alarm_hint': '¡Añade una alarma de ubicación!',

      // Gestión de lugares
      'my_places': 'Mis lugares',
      'add_place': 'Añadir lugar',
      'edit_place': 'Editar lugar',
      'place_name': 'Nombre del lugar',
      'place_saved': '✅ Lugar guardado',
      'place_updated': '✅ Lugar actualizado',
      'place_deleted': '🗑 Lugar eliminado',
      'no_places': 'Sin lugares guardados',
      'no_places_desc': 'Toque el botón para añadir su primer lugar.',
      'add_place_btn': 'Añadir lugar',
      'add_place_hint': '¡Añade tus lugares favoritos!',
      'search_address': 'Buscar dirección',
      'current_location': 'Ubicación actual',
      'radius': 'Radio',
      'custom': 'Personalizado',
      'custom_radius': 'Radio personalizado',

      // Añadir/editar alarma
      'add_location_alarm': 'Añadir alarma de ubicación',
      'edit_location_alarm': 'Editar alarma de ubicación',
      'alarm_sound': 'Sonido de alarma',
      'vibration': 'Vibración',
      'snooze': 'Posponer',
      'alarm_enabled': 'Alarma activada',
      'entry_exit': 'Entrada/Salida',
      'on_entry': 'Al entrar',
      'on_exit': 'Al salir',
      'both': 'Ambos',
      'alarm_saved': '✅ Alarma guardada',
      'alarm_deleted': '🗑 Alarma eliminada',

      // Configuración
      'settings': 'Configuración',
      'language': 'Idioma',
      'language_select': 'Seleccionar idioma',
      'system_default': 'Predeterminado del sistema',
      'account': 'Cuenta',
      'logged_in': 'Conectado',
      'logout': 'Cerrar sesión',
      'logout_confirm':
          '¿Está seguro de que desea cerrar sesión? Será redirigido a la pantalla de inicio de sesión.',
      'google_login': 'Iniciar sesión con Google',
      'login_success': '✅ Inicio de sesión exitoso',
      'login_failed': '❌ Error de inicio de sesión',
      'logged_out': 'Sesión cerrada',
      'delete_account': 'Eliminar cuenta',
      'delete_account_subtitle': 'Eliminar permanentemente todos los datos',
      'delete_account_warning':
          'Todos sus datos, incluyendo configuraciones de alarma, datos de ubicación e información de cuenta, serán eliminados permanentemente.\n\nEsta acción no se puede deshacer y sus datos no se pueden recuperar.',
      'delete_account_confirm': 'Eliminar',
      'delete_account_final_title': 'Confirmación final',
      'delete_account_final_warning':
          '¿Está absolutamente seguro?\nSu cuenta y todos los datos asociados serán eliminados permanentemente de inmediato.',
      'delete_account_final_confirm': 'Eliminar permanentemente',
      'delete_account_failed':
          '❌ Error al eliminar la cuenta. Por favor, inténtelo de nuevo.',
      'feedback': 'Enviar comentario',
      'feedback_title': 'Enviar comentario',
      'feedback_hint': 'Ingrese sus comentarios o sugerencias',
      'feedback_sent': '✅ Comentario enviado. ¡Gracias!',
      'app_info': 'Info de la app',

      // Página de inicio de sesión
      'login_app_description':
          'Aplicación de alarma basada en ubicación.\n¡Reciba notificaciones al llegar o salir de un lugar!',
      'login_data_security_title': 'Promesa de seguridad de datos',
      'login_data_security_content':
          'Solo su identificador de cuenta cifrado y el estado de pago se almacenan en nuestros servidores. La información de ubicación y personal se procesa solo en su dispositivo.',
      'login_data_deletion_warning':
          'Todos los lugares guardados y configuraciones de alarma se eliminarán al desinstalar la aplicación.',
      'login_continue_with_google': 'Continuar con Google',
      'login_cancelled': 'Inicio de sesión cancelado',
      'login_not_supported':
          'El inicio de sesión con Google no es compatible con este dispositivo',
      'version': 'Versión',
      'location_based_alarm': 'Aplicación de alarma basada en ubicación',
      'privacy_policy': 'Política de privacidad',

      // Política de privacidad
      'privacy_policy_title': 'Política de privacidad',
      'privacy_last_updated': 'Última actualización: enero de 2026',
      'privacy_section_1_title': '1. Información que recopilamos',
      'privacy_section_1_content':
          'Ringinout no recopila información personal.\n\n'
          '• Datos de ubicación: Se procesan solo en su dispositivo para la función de alarma. No se envían a servidores externos.\n\n'
          '• Información de cuenta: Al iniciar sesión con Google, su correo electrónico se convierte en un ID aleatorio anonimizado. El correo original no se almacena.',
      'privacy_section_2_title': '2. Propósito del ID anonimizado',
      'privacy_section_2_content':
          'El ID anonimizado se utiliza únicamente para verificar el estado de suscripción premium. '
          'Este ID no puede utilizarse para identificar o rastrear individuos.',
      'privacy_section_3_title': '3. Almacenamiento de datos',
      'privacy_section_3_content':
          'Todos los datos de alarma y ubicación se almacenan solo en su dispositivo '
          'y no se transmiten a servidores externos.',
      'privacy_section_4_title': '4. Compartir con terceros',
      'privacy_section_4_content':
          'Ringinout no comparte ninguna información de usuario con terceros.',
      'privacy_section_5_title': '5. Contacto',
      'privacy_section_5_content':
          'Para consultas relacionadas con la privacidad, utilice la función \'Enviar comentario\' en la aplicación.',

      // Permisos
      'permission_required': 'Permiso requerido',
      'location_permission': 'Permiso de ubicación',
      'notification_permission': 'Permiso de notificación',
      'background_permission': 'Permiso de ubicación en segundo plano',
      'background_location_desc':
          'Detecta su ubicación incluso cuando la aplicación no está en uso.',
      'overlay_permission': 'Mostrar sobre otras aplicaciones',
      'overlay_permission_desc':
          'Requerido para mostrar alarmas de pantalla completa.',
      'grant_permission': 'Conceder permiso',
      'allow': 'Permitir',
      'permission_settings': 'Configuración de permisos',
      'setup_complete': '¡Configuración completada! 🎉',
      'grant_all_permissions': 'Por favor, conceda todos los permisos',
      'setup_later': 'Configurar más tarde',
      'location_permission_desc':
          'Requerido para detectar ubicaciones de alarma.',
      'battery_opt_warning_title': 'Optimización de batería no excluida',
      'battery_opt_warning_desc':
          'Este aviso aparece porque la exclusión de optimización de batería está actualmente desactivada. '
          'La aplicación puede seguir funcionando, pero las alarmas pueden retrasarse o perderse en algunos dispositivos. '
          'Recomendamos excluir esta aplicación de la optimización de batería.',

      // Página GPS
      'gps_title': 'GPS',
      'geofence_service_status': 'Estado del servicio Geofence',
      'status_running': '✅ En ejecución',
      'status_stopped': '❌ Detenido',
      'status': 'Estado',
      'last_event': 'Último evento',
      'last_event_none': 'Ninguno',
      'settings_interval':
          'Configuración: intervalo de {interval}s, precisión de {accuracy}m',
      'geofence_status_debug': 'Estado Geofence (Debug)',
      'no_saved_places': 'Sin lugares guardados',
      'distance': 'Distancia',
      'radius_label': 'Radio',
      'no_location_info': 'Sin información de ubicación',
      'latitude': 'Latitud',
      'longitude': 'Longitud',
      'updated': 'Actualizado',
      'active_alarm_distance': 'Distancias de alarmas activas',
      'no_active_alarms': 'Sin alarmas activas o sin información de ubicación',
      'alarm': 'Alarma',
      'place_unknown': 'Lugar desconocido',
      'cannot_calculate_distance': 'No se puede calcular la distancia',
      'location_permission_required': 'Se requiere permiso de ubicación.',
      'inside': 'Dentro',
      'outside': 'Fuera',

      // Días de la semana
      'sun': 'Dom',
      'mon': 'Lun',
      'tue': 'Mar',
      'wed': 'Mié',
      'thu': 'Jue',
      'fri': 'Vie',
      'sat': 'Sáb',
      'every_week': 'Cada {days}',
      'first_entry_after_set':
          'Primera entrada después de configurar la alarma',
      'first_exit_after_set': 'Primera salida después de configurar la alarma',
      'no_selection': 'Sin selección',

      // Configuración de festivos
      'holiday_settings': 'Configuración de festivos',
      'turn_off_on_holidays': 'Desactivar en festivos sustitutos/temporales',
      'turn_on_on_holidays': 'Activar en festivos sustitutos/temporales',

      // País de festivos
      'holiday_country': 'País de festivos',
      'holiday_country_auto': 'Auto',
      'holiday_country_auto_detected': 'Auto (Detectado: {country})',
      'holiday_country_auto_detecting': 'Auto (Detectando...)',
      'country_KR': 'Corea del Sur',
      'country_US': 'Estados Unidos',
      'country_JP': 'Japón',
      'country_CN': 'China',
      'country_VN': 'Vietnam',
      'country_MY': 'Malasia',
      'country_TH': 'Tailandia',
      'country_CA': 'Canadá',
      'country_BR': 'Brasil',
      'country_TW': 'Taiwán',
      'country_DE': 'Alemania',
      'country_FR': 'Francia',
      'country_ES': 'España',
      'country_IT': 'Italia',
      'country_NL': 'Países Bajos',
      'country_SE': 'Suecia',
      'country_PL': 'Polonia',
      'country_GB': 'Reino Unido',

      // Agrupación de alarmas
      'alarm_count': '{count} alarmas',
      'alarm_count_one': '1 alarma',
      'other_places': 'Otros',

      // Añadir alarma de ubicación
      'add_new_location_alarm': 'Añadir nueva alarma de ubicación',
      'done': 'Listo',
      'alarm_name': 'Nombre de alarma',
      'no_name': 'Sin nombre',
      'select_place': 'Seleccionar lugar',
      'alarm_on_entry': 'Alarma al entrar',
      'alarm_on_exit': 'Alarma al salir',

      // Reconocimiento de voz
      'voice_input': 'Entrada de voz',
      'voice_listening': 'Escuchando...',
      'voice_not_recognized': 'Voz no reconocida',
      'tap_to_speak': 'Toque para hablar',
      'select_location_on_map': 'Seleccionar ubicación en el mapa',

      // Pantalla de alarma
      'dismiss': 'Cerrar',
      'snooze_minutes': 'Posponer {minutes} min',
      'alarm_ringing': '¡Alarma sonando!',

      // Info de batería
      'battery_info_text_prefix':
          'Las alarmas activas se reinician automáticamente al cerrar la aplicación.\nPara alarmas fiables, ',
      'battery_info_text_action': 'excluir de la optimización de batería',
      'battery_info_text_suffix': '.',
      'battery_opt_exclude': 'Excluir de la optimización de batería',
      'no_saved_alarms': 'Sin alarmas guardadas.',
      'no_saved_alarms_desc': 'Toque el botón para añadir su primera alarma.',

      // Bienvenida
      'get_started': 'Comenzar',

      // Página de voz
      'voice_main_title': 'Registrar alarmas por voz',
      'voice_example_phrase': '"Notifícame cuando llegue al trabajo"',
      'voice_tap_to_start': 'Toque para comenzar',
      'voice_widget_title': 'Añadir widget a la pantalla de inicio',
      'voice_widget_subtitle':
          '¡Inicie el reconocimiento de voz con un toque en el widget!',
      'voice_widget_guide_title': 'Añadir widget de pantalla de inicio',
      'voice_widget_guide_subtitle': '¡Inicie alarmas de voz más rápido!',
      'voice_widget_step1':
          'Mantenga presionado un espacio vacío en la pantalla de inicio',
      'voice_widget_step2': 'Seleccione el menú "Widgets"',
      'voice_widget_step3': 'Busque "ringinout" o "Alarma de voz"',
      'voice_widget_step4': 'Arrastre el widget a la pantalla de inicio',
      'voice_widget_tip':
          'Con un widget, puede iniciar alarmas de voz\ndirectamente desde su pantalla de inicio sin abrir la aplicación.',
      'voice_widget_got_it': '¡Entendido!',
      'voice_tip_title': '💡 Ejemplos de reconocimiento de voz',
      'voice_tip_examples':
          '• "Notifícame cuando llegue al trabajo el lunes"\n'
          '  → Cada lunes, al entrar\n'
          '• "Alértame cuando salga de casa el 12 de abril"\n'
          '  → Solo el 12 de abril, al salir\n'
          '• "Suena cuando llegue a casa después de las 6 el lunes"\n'
          '  → Cada lunes, después de las 6:00, al entrar\n'
          '• "Recuérdame cuando salga de casa a las 9 el 13 de marzo"\n'
          '  → 13 de marzo, después de las 9:00, al salir',
      'voice_tip_note':
          'Días, fechas y horas se configuran automáticamente\n(El geofence GPS puede activarse dentro de ±segundos del límite)',
      // Pestañas de voz
      'voice_tab_location': 'Voz ubicación',
      'voice_tab_device': 'Voz dispositivo',
      'voice_device_main_title': 'Registrar alarmas de dispositivo por voz',
      'voice_device_example_phrase':
          '"Notifícame cuando los Galaxy Buds se conecten"',
      'voice_device_tip_title': '💡 Ejemplos de voz de dispositivo',
      'voice_device_tip_examples':
          '• "Notifícame cuando los Galaxy Buds se conecten el lunes"\n'
          '  → Cada lunes, al conectar\n'
          '• "Alértame cuando los auriculares se desconecten el 12 de abril"\n'
          '  → Solo el 12 de abril, al desconectar\n'
          '• "Suena cuando los Buds se conecten después de las 6 el lunes"\n'
          '  → Cada lunes, después de las 6:00, al conectar\n'
          '• "Dime cuando el reloj se desconecte a las 9 el 13 de marzo"\n'
          '  → 13 de marzo, después de las 9:00, al desconectar',
      'voice_device_tip_note':
          'Días, fechas y horas se configuran automáticamente\n(Los cambios de estado Bluetooth se detectan en tiempo real)',
      'voice_first_visit_title': '💡 ¡Consejo profesional!',
      'voice_first_visit_desc':
          'Añada un widget a su pantalla de inicio\npara iniciar alarmas de voz\nsin abrir la aplicación.',
      'voice_first_visit_btn': 'Ver cómo añadir widget',
      'voice_first_visit_later': 'Quizás más tarde',

      // Suscripción
      'subscription_tab': 'Suscripción',
      'gps_tab': 'GPS',
      // Página GPS
      'gps_current_location': 'Ubicación actual',
      'gps_latitude': 'Latitud',
      'gps_longitude': 'Longitud',
      'gps_accuracy': 'Precisión',
      'gps_accuracy_good': 'Buena',
      'gps_accuracy_fair': 'Regular',
      'gps_accuracy_poor': 'Mala',
      'gps_updated_at': 'Actualizado',
      'gps_no_location': 'Sin datos de ubicación',
      'gps_alarm_status': 'Estado de alarma de ubicación',
      'gps_stopped': 'Detenido',
      'gps_inside': 'Dentro',
      'gps_outside': 'Fuera',
      'gps_moving': 'En movimiento',
      'gps_alarms': 'Alarmas',
      'gps_place_status': 'Estado del lugar',
      'gps_place_status_refresh_tooltip': 'Actualizar estado del lugar',
      'gps_no_tracked_places': 'Sin lugares rastreados',
      'gps_place_status_updated': '{count} lugar(es) estado actualizado',
      'gps_entry': 'Entrada',
      'gps_exit': 'Salida',
      'gps_bug_report': 'Informe de error',
      'gps_bug_report_sending': 'Enviando...',
      'gps_bug_report_title': 'Informe de error',
      'gps_refresh_tooltip': 'Actualizar GPS',
      'subscription_current_plan': 'Plan actual',
      'subscription_expires': 'Expira: {date}',
      'subscription_free_plan': 'Plan gratuito',
      'subscription_unlimited': 'Ilimitado',
      'subscription_places_n': '{n} lugares',
      'subscription_alarms_n': '{n} alarmas activas',
      'subscription_places_unlimited': 'Lugares ilimitados',
      'subscription_alarms_unlimited': 'Alarmas ilimitadas',
      'subscription_map_opens_50': '50 aperturas de mapa/mes',
      'subscription_map_opens_unlimited': 'Aperturas de mapa ilimitadas',
      'subscription_no_ads': 'Sin anuncios',
      'subscription_all_unlimited': 'Todas las funciones ilimitadas',
      'subscription_dev_plan':
          'Plan de desarrollador - todas las funciones ilimitadas',
      'subscription_subscribe': 'Suscribirse',
      'subscription_in_use': 'En uso',
      'subscription_recommended': 'Recomendado',
      'subscription_coming_soon': 'Función de suscripción próximamente.',
      'subscription_beta_notice':
          'Los planes de pago no están disponibles durante la beta. Estarán disponibles después de que termine la beta.',
      'subscription_per_month': '/ mes',
      'subscription_policy': 'Política de suscripción',
      'subscription_refund_policy': 'Política de reembolso',
      'subscription_price_tbd': 'Precio por anunciar',
      'subscription_pro_fair_use':
          'Política de uso justo: hasta 500 aperturas de mapa al mes para prevenir abusos.',
      'subscription_map_opens_500': '500 aperturas de mapa/mes',

      // Claves adicionales de añadir/editar alarma
      'plan_upgrade_needed': 'Se necesita actualizar el plan',
      'add_alarm_tooltip': 'Añadir alarma',
      'entry_trigger': 'Entrada',
      'exit_trigger': 'Salida',
      'entry_exit_trigger': 'Entrada/Salida',
      'am_label': 'AM',
      'pm_label': 'PM',
      'hour_suffix': ':',
      'min_suffix': '',
      'after_suffix': ' después',
      'first_trigger_immediate': 'Alarma en la primera {trigger}',
      'first_trigger_condition': '{conditions} primera {trigger}',
      'monthly_date': '{month}/{day}({weekday})',
      'weekly_prefix': 'Cada {days}',
      'listening_prompt': '🎙️ Escuchando... ¡Hable ahora!',
      'done_btn': 'Listo',
      'alarm_name_label': 'Nombre de alarma',
      'no_name_label': 'Sin nombre',
      'select_place_label': 'Seleccionar lugar',
      'alarm_on_entry_label': 'Alarma al entrar',
      'alarm_on_exit_label': 'Alarma al salir',
      'boundary_warning':
          'Cerca del límite del geofence, la alarma puede sonar varias veces si permanece o se mueve de un lado a otro. '
          'Use el botón "Posponer" para retrasar la alarma.',
      'condition_settings': 'Configuración de condiciones (Opcional)',
      'condition_hint':
          'Sin condiciones, la alarma suena en la primera entrada/salida después de guardar.',
      'no_date_set': 'Sin fecha establecida',
      'time_condition_hint': 'Condición de hora (opcional)',
      'time_after': '⏰ {time} después',
      'holidays_off': 'Desactivar en festivos',
      'holidays_sub_on': 'Activar en festivos sustitutos/temporales',
      'alarm_sound_label': 'Sonido de alarma',
      'alarm_sound_default': 'Sonido de alarma predeterminado del dispositivo',
      'alarm_sound_unchangeable': 'No se puede cambiar',
      'save_btn': 'Guardar',
      'delete_btn': 'Eliminar',
      'edit_alarm_title': 'Editar alarma de ubicación',
      'select_place_hint': 'Seleccionar un lugar',
      'select_place_required': 'Por favor, seleccione un lugar',
      'alarm_save_failed': 'Error al guardar la alarma: {error}',

      // Página de añadir lugar
      'address_search_result': 'Resultados de búsqueda de dirección',
      'save_place_title': 'Guardar lugar',
      'place_name_label': 'Nombre del lugar',
      'place_name_hint': 'ej. Casa, Oficina, Gimnasio',
      'radius_display': 'Radio: {radius}m',
      'radius_shown_on_map': '(Mostrado como círculo en el mapa)',
      'cancel_btn': 'Cancelar',
      'save_place_btn': 'Guardar',
      'place_saved_msg': '✅ Lugar guardado',
      'select_on_map': 'Seleccionar ubicación en el mapa',
      'move_to_current': 'Ir a la ubicación actual',
      'search_hint': 'Dirección o nombre del lugar (ej. Starbucks)',
      'no_search_result': 'Sin resultados de búsqueda',
      'address_label': 'Dirección: {address}',
      'radius_label_prefix': 'Radio: ',
      'custom_input': 'Personalizado',
      'save_location_btn': 'Guardar ubicación',
      'signal_warning':
          '📍 Guía de configuración del radio\n'
          '• En zonas con GPS inestable (subterráneos, edificios altos, áreas sin señal), pueden ocurrir falsos disparos.\n'
          '  Para falsos disparos puntuales, toque el botón "⚡ Falso disparo" para descartarlos rápidamente.\n'
          '• Si permanece cerca del límite de una zona, la alarma puede seguir sonando incluso después de tocar Falso disparo.\n'
          '  En ese caso, desactive la alarma y reactívela cuando sea necesario.\n'
          '• Si los falsos disparos son frecuentes, intente aumentar el radio de 10m a la vez.',
      'radius_guide_btn':
          '📍 Guía de configuración del radio  —  ¡¡Lectura obligatoria!!',
      'radius_guide_dialog_body':
          '📍 Límites de precisión GPS\n'
          'El GPS solo puede estimar su ubicación. Incluso al aire libre, espere un margen de error'
          ' de varios a decenas de metros. Esta es una limitación inherente del GPS.\n\n'
          '📡 Picos de señal GPS\n'
          'En entornos con GPS inestable (subterráneos, edificios altos, zonas sin señal),'
          ' el error de detección del radio puede aumentar. Incluso cuando realmente está dentro del radio,'
          ' el GPS puede leerlo temporalmente como fuera — o viceversa.\n'
          'En estos casos, use el botón "\u26a1 Falso disparo".'
          ' Si el mismo problema se repite, intente aumentar su radio de 10m a la vez.\n\n'
          '💡 Si necesita permanecer o moverse cerca del límite del radio configurado\n'
          'Incluso después de tocar Falso disparo, la alarma puede seguir sonando.'
          ' En ese caso, desactive la alarma y reactívela cuando sea necesario.\n'
          '(Modo "Espera" — en consideración si se solicita: reactivación automática después de una duración establecida)',
      'radius_input_range': '30m ~ 500m (incrementos de 10m)',

      // Página de términos
      'terms_agreement_title': 'Acuerdo de términos (Requerido)',
      'terms_agree_text':
          'He leído y acepto los Términos de servicio y la Política de reembolso/suscripción.',
      'terms_agree_btn': 'Aceptar y continuar',
      'terms_disagree_btn': 'Rechazar (Cerrar aplicación)',
      'terms_save_failed':
          'Error al guardar los términos. Por favor, inténtelo de nuevo.',

      // Sonido de alarma
      'alarm_sound_setting_title': 'Configuración de sonido de alarma',
      'alarm_disabled_label': 'Alarma desactivada',

      // add_alarm_page
      'add_alarm_new_title': 'Añadir nueva alarma',
      'edit_alarm_modify_title': 'Editar alarma de ubicación',
      'location_fixed_text': 'Esta alarma está fijada a este lugar',
      'no_place_label': 'Sin lugar',
      'required_fields_msg':
          'Por favor, complete todos los campos obligatorios.',
      'holidays_dialog_title':
          'Configuración de festivos sustitutos/temporales',
      'holidays_sub_off':
          'Desactivar en festivos sustitutos/temporales también',

      // my_places_page
      'delete_confirm_title': 'Confirmar eliminación',
      'delete_locked_msg': '¿Eliminar esta ubicación bloqueada?',
      'delete_place_msg': '¿Está seguro de que desea eliminar esta ubicación?',
      'linked_alarm_delete_warning':
          '⚠️ {count} alarma(s) vinculada(s) también serán eliminadas.',
      'edit_places_menu': 'Editar lugar',
      'add_alarm_menu': 'Añadir nueva alarma',
      'add_place_tooltip': 'Añadir nueva ubicación',

      // show_alarm_popup_page
      'alarm_end_confirm': '¿Detener alarma?',
      'no_label': 'No',
      'yes_label': 'Sí',
      'snooze_btn': 'Posponer',
      'alarm_stop_btn': 'Detener alarma',

      // Configuración de snooze/vibración
      'snooze_setting_title': 'Configuración de posposición',
      'vibration_setting_title': 'Configuración de vibración',

      // Permiso
      'permission_setting_title': 'Configuración de permisos',
      'permission_allow': 'Permitir',
      'battery_opt_title': 'Desactivar optimización de batería',
      'battery_opt_msg':
          'Para que las alarmas funcionen correctamente en segundo plano, la optimización de batería debe estar desactivada.\nVaya a Configuración, busque "Optimización de batería" y configure Ringinout como "No optimizado".',
      'open_settings_btn': 'Abrir configuración',
      'later_btn': 'Más tarde',

      // Gestión de suscripción
      'subscription_mgmt_title': 'Gestión de suscripción',
      'subscription_policy_btn': 'Política de suscripción',
      'refund_policy_btn': 'Política de reembolso',
      'auto_renew_msg':
          'Renovado automáticamente según las políticas de Google Play.',
      'agree_auto_pay': 'Acepto el pago automático.',
      'agree_policy': 'He revisado la política de suscripción/reembolso.',
      'start_auto_subscription': 'Iniciar suscripción automática',
      'current_plan': 'Plan actual',
      'cancel_subscription': 'Cancelar',
      'subscribe_btn': 'Suscribirse',
      'auto_subscribe_btn': 'Suscripción automática',
      'beta_no_paid_plans':
          'Los planes de pago no están disponibles durante la beta. Estarán disponibles después de que termine la beta.',
      'places_5': '5 lugares',
      'active_alarms_10': '10 alarmas activas',
      'ad_free_included': 'Sin anuncios incluido',
      'places_alarms_unlimited': 'Lugares/Alarmas ilimitados',
      'ad_remove_title': 'Eliminar anuncios',
      'in_app_ad_remove': 'Eliminación de anuncios en la aplicación',
      'price_loading': 'Cargando precio',
      'duration_1month': '1 mes',
      'duration_3months': '3 meses',
      'duration_6months': '6 meses',
      'duration_12months': '12 meses',
      'discount_5': '5% de descuento',
      'discount_10': '10% de descuento',
      'discount_20': '20% de descuento',
      'expiry_date_none': 'Vencimiento: -',
      'expiry_date_format': 'Vencimiento: {date}',
      'beta_sub_activate_later':
          'Las suscripciones se activarán después de que termine la beta.',

      // Diálogo de límite de suscripción
      'place_limit_title': 'Límite de registro de lugares',
      'place_limit_msg':
          'En el plan {plan}, puede registrar hasta {limit} lugares.\nPor favor, elimine lugares existentes o actualice.',
      'alarm_limit_title': 'Límite de registro de alarmas',
      'alarm_limit_msg':
          'En el plan {plan}, puede configurar hasta {limit} alarmas activas.\nPor favor, elimine alarmas existentes o actualice.',
      'close_btn': 'Cerrar',

      // Selector de ubicación
      'place_name_input_title': 'Ingresar nombre del lugar',
      'radius_default_info': 'Radio: 100m (se puede cambiar después)',
      'location_select_title': 'Seleccionar ubicación',
      'fetching_location': 'Obteniendo ubicación actual...',
      'location_saved': '📍 ¡Ubicación guardada!',

      // Inicio de sesión adicional
      'dev_test_mode': 'Modo de prueba de desarrollador',
      'test_login_failed': 'Error en inicio de sesión de prueba: {error}',

      // Cambio de mapa
      'switch_to_google': 'Cambiar a Google Maps',
      'switch_to_naver': 'Cambiar a Naver Map',

      // Límite de mapa del plan gratuito
      'map_free_limit_exceeded_title': 'Límite del plan gratuito',
      'map_free_limit_exceeded_body':
          'Ha utilizado todas las {limit} aperturas de Google Maps este mes.\n\n'
          'OSM siempre está disponible de forma gratuita.\n'
          'Actualice a un plan de pago para acceso ilimitado.',
      'map_switch_confirm_title': 'Cambiar a Google Maps',
      'map_switch_confirm_body':
          'El plan gratuito permite {limit} aperturas de Google Maps por mes.\n\n'
          'Restante: {remaining}/{limit}\n\n'
          'Cambiar a Google Maps usa 1 crédito.\n'
          'OSM siempre es gratuito e ilimitado.',
      'map_switch_btn_cancel': 'Cancelar',
      'map_switch_btn_confirm': 'Cambiar',

      // Falso disparo / Pantalla de alarma
      'btn_snooze': 'Posponer',
      'btn_dismiss': 'Detener alarma',
      'btn_false_trigger': 'Falso disparo',
      'false_trigger_hint': 'Activado por error GPS',
      'snooze_time_title': 'Duración de posposición',
      'snooze_min': '{m} min',

      // Info de falso disparo
      'false_trigger_info_title': '⚡ ¿Qué es Falso disparo?',
      'false_trigger_info_subtitle':
          'Mantener la alarma activa cuando se activa por error GPS',
      'false_trigger_dialog_title': '¿Qué es Falso disparo?',
      'false_trigger_dialog_body':
          'Cuando la alarma suena, aparece un botón "⚡ Falso disparo"'
          ' junto a "Posponer" y "Detener alarma".\n\n'
          'Cuando toca "⚡ Falso disparo":\n'
          '  • El tono/vibración se detiene inmediatamente\n'
          '  • La alarma permanece activa (no se desactiva)\n'
          '  • La alarma puede dispararse de nuevo\n\n'
          '📍 Límites de precisión GPS\n'
          'El GPS solo puede estimar su ubicación.'
          ' Incluso al aire libre, siempre hay un margen de error de varios a decenas de metros.'
          ' Esto puede hacer que la alarma suene un poco antes o después.\n\n'
          '📡 Picos de señal GPS\n'
          'En entornos con GPS inestable (subterráneos, edificios altos, zonas sin señal),'
          ' el error de detección del radio puede aumentar. Incluso cuando realmente está dentro del radio,'
          ' el GPS puede leerlo temporalmente como fuera — o viceversa.\n'
          'En estos casos, use el botón "⚡ Falso disparo".'
          ' Si el mismo problema se repite, intente aumentar su radio de 10m a la vez.\n\n'
          '💡 Si necesita permanecer o moverse cerca del límite del radio configurado\n'
          'Incluso después de tocar Falso disparo, la alarma puede seguir sonando.'
          ' En ese caso, desactive la alarma y reactívela cuando sea necesario.\n'
          '(Modo "Espera" — en consideración si se solicita: reactivación automática después de una duración establecida)',
      'false_trigger_dialog_ok': 'Entendido',

      // Alarma Bluetooth — disparo no intencionado
      'bt_false_trigger_info_title': '⚡ ¿Alarma no intencionada?',
      'bt_false_trigger_info_subtitle':
          '¿La alarma se activó sin su intención? Esto es lo que debe hacer',
      'bt_false_trigger_dialog_title': '¿Alarma no intencionada?',
      'bt_false_trigger_dialog_body':
          'Las alarmas Bluetooth se activan cuando una conexión o desconexión\n'
          'dura 15 segundos o más. Esto es por diseño — pero la vida\n'
          'no siempre sale como se planea.\n\n'
          'Cuando la alarma se active, toque "⚡ Falso disparo" para detener el tono\n'
          'manteniendo la alarma activa para la próxima vez.\n\n'
          '💡 Consejo: Use condiciones de día o hora para reducir enormemente\n'
          'los disparos no deseados en otros momentos del día.',
      'bt_bonded_devices_title': 'Dispositivos Bluetooth emparejados',
      'bt_refresh_tooltip': 'Actualizar lista de dispositivos',
      'bt_selector_description':
          'Seleccione dispositivos Bluetooth emparejados para detectar en este lugar.',
      'bt_permission_needed':
          'Se requiere permiso de Bluetooth.\nPor favor, permita el acceso Bluetooth en Configuración.',
      'bt_no_bonded_devices':
          'No se encontraron dispositivos Bluetooth emparejados.',
      'bt_selected_count': '{count} dispositivo(s) seleccionado(s)',
      'bt_device_retained':
          'Guardado anteriormente (no emparejado actualmente)',
      'bt_devices_label': 'Dispositivos Bluetooth',
      'bt_none_selected': 'Ninguno seleccionado',
      'bt_count_selected': '{count} seleccionado(s)',

      // Alarma de dispositivo
      'device_alarm_empty': 'Sin alarmas de dispositivo',
      'device_alarm_empty_desc':
          'Añada una alarma de dispositivo Bluetooth para ser notificado\ncuando un dispositivo se conecte o desconecte.',
      'device_alarm_add': 'Añadir alarma de dispositivo',
      'device_alarm_delete_confirm': '¿Eliminar esta alarma de dispositivo?',
      'device_alarm_select_device': 'Seleccionar dispositivo',
      'device_alarm_name_label': 'Nombre de alarma',
      'device_alarm_name_hint': 'Ingrese nombre de alarma',
      'device_alarm_trigger_label': 'Activar cuando',
      'device_trigger_connect': 'Conectado',
      'device_trigger_disconnect': 'Desconectado',

      // Mis dispositivos
      'my_devices_empty': 'Sin dispositivos registrados',
      'my_devices_empty_desc':
          'Los dispositivos Bluetooth registrados en lugares o\nalarmas de dispositivo aparecerán aquí.',
      'my_devices_source_place': 'Lugar',
      'my_devices_source_alarm': 'Alarma',
      'my_devices_add': 'Añadir dispositivo',
      'my_devices_add_title': 'Añadir dispositivo Bluetooth',
      'my_devices_custom_name_label': 'Nombre personalizado',
      'my_devices_custom_name_hint': 'Ingrese un nombre fácil de recordar',
      'my_devices_original_name': 'Nombre Bluetooth',
      'my_devices_edit_name': 'Editar nombre',
      'edit_device_menu': 'Editar dispositivo',
      'add_device_alarm_menu': 'Añadir nueva alarma',
      'my_devices_delete_confirm': '¿Eliminar este dispositivo?',
      'my_devices_source_manual': 'Manual',

      // Botón de añadir alarma (barra inferior fija)
      'add_alarm_btn': 'Añadir alarma',
      'add_device_alarm_btn': 'Añadir alarma',

      // Página de alarma de dispositivo
      'device_alarm_page_title': 'Añadir alarma de dispositivo',
      'device_alarm_edit_title': 'Editar alarma de dispositivo',
      'add_new_device_alarm': 'Añadir nueva alarma de dispositivo',
      'select_device_label': 'Seleccionar dispositivo',
      'alarm_on_connect_label': 'Alarma al conectar',
      'alarm_on_disconnect_label': 'Alarma al desconectar',
      'device_condition_hint':
          'Sin condiciones, la alarma se activa en la primera conexión/desconexión.',
      'device_alarm_voice_section': 'Reconocimiento de voz',
      'device_alarm_voice_msg_label': 'Mensaje de voz',
      'device_alarm_voice_msg_hint':
          'Mensaje a anunciar cuando se active la alarma',
      'device_alarm_voice_enabled': 'Activar notificación de voz',
      'device_alarm_sound_section': 'Sonido de alarma',
      'device_alarm_save_success': 'Alarma de dispositivo guardada',

      // Wi-Fi
      'wifi_networks_label': 'Redes Wi-Fi',
      'wifi_none_selected': 'Ninguna seleccionada',
      'wifi_count_selected': '{count} seleccionada(s)',
      'wifi_rescan_tooltip': 'Volver a escanear',
      'wifi_description':
          'Use la conexión Wi-Fi para una detección de ubicación más precisa.',
      'wifi_disabled': 'El Wi-Fi está desactivado',
      'wifi_disabled_detail':
          'El Wi-Fi está desactivado. Por favor, active el Wi-Fi e inténtelo de nuevo.',
      'wifi_scan_failed': 'Error en el escaneo Wi-Fi',
      'wifi_no_networks': 'No se detectaron redes Wi-Fi.',
      'wifi_networks_selected': '{count} red(es) seleccionada(s)',
      'wifi_hidden_network': '(Red oculta)',
      'wifi_currently_connected': 'Actualmente conectado',
      'wifi_previously_saved':
          'Guardado anteriormente (no detectado actualmente)',
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
    return [
      'en',
      'ko',
      'ja',
      'zh',
      'de',
      'fr',
      'es',
    ].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
