# 📘 Ringinout 개발일지

Flutter로 개발하는 위치 기반 스마트 알람 앱 “Ringinout”의 개발 일지임. 
음성 인식, GPS 기반 진입/진출 알림으로 간편하게 내가 특정 위치에 도착했거나,
특정 위치를 벗어날 때 챙겨야 할 무언가, 혹은 해야할 일은 잊지 않도록
알려주는 게 목표.
하도 많은 업무로 인해, 혹은 노화로 인해, 혹은 육아로 인해,
혹은 그냥 건망증이 심해서 깜박깜박하는 게 많은 여러분들을 위해 꼭 필요한 앱.

──────────────────────────────────────────────────────────────

## 2025-04-15

- 프로젝트 초기 구상 및 핵심 기능 정의
  - 위치 기반 알람 기능 (장소 진입/진출 시 알림)
  - 음성 인식을 통한 알람 자동 등록 기능
  - 진입/진출 구분, 반복 울림 설정, 알람 해제 시 목표 달성 여부 확인 기능 등 기획
- Flutter 설치 및 VS Code 개발 환경 구성
- 실제 기기에서 테스트 가능한 Android 에뮬레이터 및 USB 디버깅 설정 완료
- 프로젝트 기본 구조 구성 (`main.dart` 생성)

──────────────────────────────────────────────────────────────

## 2025-04-16

- MVP 기준에 맞춘 기초 UI 구성 시작
  - `위치 기반 알람 설정`, `음성 알람 추가`, `알람 목록 보기` 3개의 버튼 구성
- 저장된 위치 관리 기능 구현
  - `Hive` 로컬 데이터베이스 연동
  - `SavedLocationsPage`에서 위치 목록 불러오기 및 표시
  - `FloatingActionButton` 또는 중앙 버튼을 통해 ‘새 위치 추가’ 가능
- 위치 추가 기능 구현
  - 구글 지도 연동 (`google_maps_flutter`)
  - 현재 위치 자동 포커싱
  - 지도에서 특정 위치를 터치하여 위치 저장 가능
  - 주소 입력란 추가 및 수동 위치 이동 기능 구현
  - 저장 시: 장소 이름 팝업 입력 → 반경 100m로 자동 설정 → Hive에 저장
  - 저장 완료 시 Snackbar 표시
- 위치 목록에서 팝업 메뉴 구성
  - ‘새 알람 추가’, ‘기존 알람 수정’, ‘정보 수정’ 항목 구성
- `AddAlarmPage` 첫 화면 UI 구현 시작
  - 다시 울림 설정 (기본값: 5분 후, 3회) UI 설계
  - 벨소리 드롭다운 메뉴 설계 착수

──────────────────────────────────────────────────────────────
# 📅 개발일지 - 2025.04.17 (Ringinout)

## ✅ 주요 작업 내용

### 1. 알람 추가 페이지 (AddAlarmPage) 정비
- 자연어 키워드를 통해 **진입/진출 자동 인식 기능** 구현
  - `entryKeywords`, `exitKeywords` 리스트 구성
  - 알람 이름 입력 시 해당 키워드가 포함되면 자동으로 알람 방향 설정됨
  - 진입/진출은 동시에 선택 불가하며, 마지막 입력된 의미 기준으로 자동 전환
- `TextField.onChanged()` → `_checkAlarmConditionFromName(val)` 호출로 연결
- 디버깅을 위해 `print()` 로그를 통해 키워드 매칭 여부 확인 가능하게 구성

### 2. 알람 토글 UI 개선
- 모든 토글 버튼 위치를 가장 우측에 일관적으로로 정렬**
  - 버튼 우측 세로막대 경계선 포함
  - 활성/비활성 시 색상 및 크기 변화 애니메이션 반영
- 알람음, 진동, 다시 울림 항목은:
  - **우측 버튼** 클릭 시: On/Off 토글
  - **항목 전체(버튼 제외)** 클릭 시: 상세 설정 페이지로 진입 가능 (현재 TODO 상태)

### 3. 저장된 위치 목록 페이지 개선 (`SavedLocationsPage`)
- `AppBar` 제목을 **'위치 기반 알람 설정' → 'Ringinout 설정'** 으로 변경
- 저장된 위치 항목 우측 메뉴에 `"삭제"` 항목 추가
  - 삭제 시 확인 다이얼로그 표시
  - 사용자 확인 시 Hive 데이터 삭제 후 UI 자동 갱신 (`_loadLocations()` 호출)

---

## 🛠️ 문제 해결 로그

- 🔍 자연어 인식이 안 되는 문제 → `TextField`의 `onChanged`에 `_checkAlarmConditionFromName()` 누락 여부 확인 → 디버깅 로그 추가로 정상 작동 확인
- ⛔ Flutter 콘솔에 `r` 입력 시 작동 안 되는 현상 → `flutter run`으로 실행했을 때만 `r` 가능, VS Code에서는 `Ctrl + S` 자동 핫리로드 활용으로 전환

---

## 📌 플랫폼 관련 논의

### 📱 위치 기반 알림의 기기별 동작 가능성 분석

| 플랫폼  | 가능 여부 | 설명 |
|---------|-----------|------|
| Android | ✅ 가능    | 포그라운드 서비스 + 배터리 최적화 예외 설정 필요 |
| iOS     | ❌ 제한적 | 진입/진출 감지가 지연되거나 무시됨, 백그라운드 동작 어려움 |

> **결론:** Ringinout의 고정밀 자동 알림 기능은 **안드로이드 우선 개발**이 현실적인 선택

---

## 🔚 다음 작업 예정

- 상세 설정 페이지 (알람음, 진동, 다시 울림) 연결
- 위치 기반 포그라운드 서비스 로직 구체화
- 퀵타일 활성화 상태에 따라 `GeofencingService` 유지 여부 제어

## 2025-04-18

- 알람 리스트 롱프레스 기능 추가
  - 선택 모드 진입 후 다중 선택 가능
  - 선택된 항목 삭제용 FloatingActionButton 추가
- 알람 리스트 항목의 토글 버튼 디자인 통일 (AddAlarmPage와 동일한 스타일로)
- 기본알람 탭 전환 후 다시 돌아올 때 리스트 초기화되는 버그 수정

---

## 2025-04-19

- 불필요한 알람테스트 버튼 완전 제거
  - location_alarm_list.dart, 기본알람 페이지, 선택모드 페이지에서 전부 삭제
- 알람 리스트 숏프레스 시 수정 페이지로 진입하도록 설정
- MyPlaces 페이지에 구분선 추가 (알람 리스트와 UI 통일)

---

## 2025-04-20

- AddLocationAlarmPage 전체 코드 리팩토링
  - 요일 선택 시 순서 강제 정렬 (일~토 순서)
  - 저장 조건 추가: 알람 이름 필수, 진입 or 진출 중 하나 이상 필수
  - MaterialLocalizations 에러 해결 → `GlobalMaterialLocalizations` import 추가 및 supportedLocales 설정
- 저장 시 요일/날짜 선택 없을 경우 "알람 설정 후 최초 진입/진출 시" 문구 저장되도록 개선

---

## 2025-04-21

- EditLocationAlarmPage 생성
  - AddLocationAlarmPage 전체 복사 후 수정 기능 추가
  - 기존 알람 데이터 반영, 저장/삭제 버튼 분리
- LocationAlarmList에서 onTap 시 수정 페이지로 연결되도록 수정
  - pushNamed 방식으로 alarm 데이터와 index 전달
  - routes에 edit_location_alarm 등록 및 import 처리

## 🗓 2025-04-22 (화)

- `AddLocationAlarmPage` 완성
  - 저장 시 요일은 항상 `일~토` 순서로 정렬되도록 수정
  - 요일/날짜 미선택 시 문구 자동 생성:  
    - 진입 알람 → "알람 설정 후 최초 진입 시"  
    - 진출 알람 → "알람 설정 후 최초 진출 시"
- 알람 상세 진입용 수정 페이지 `EditLocationAlarmPage` 초안 작업 시작
  - 기존 `AddLocationAlarmPage`를 기반으로 복사 후 수정 예정
  - 수정 페이지에서는 기존 알람 데이터가 자동으로 불러와지도록 설계
- Notification 클릭 시 전체화면 알람 페이지 띄우기 기능 검토 시작
  - `AlarmFullScreenPage` 기획 논의는 있었으나 실제 구현 시작은 하지 않음
  - Notification intent 처리 흐름, push 방식 검토 중

---

## 🗓 2025-04-23 (수)

- 알람이 울릴 때 동작 관련 핵심 로직 정리
  - 앱이 종료되었거나 백그라운드에 있어도 반드시 알림이 울리도록 설계 논의
  - 화면이 꺼져 있을 경우 자동으로 켜지도록 구성 예정
  - 첫 울림은 확인 버튼만, 반복 울림은 ‘확인 + 다시 울림’ 버튼 구성 예정
- Notification 클릭 시 전체화면 페이지로 진입하는 방식 구체화 논의
  - "어디든"이 아닌 정확한 파일명과 위치 안내가 필요함을 명시
  - main.dart 또는 알람 초기화 파일 내에서 처리할 예정
- AlarmFullScreenPage 설계 개시 예정 → 실제 코딩은 아직 착수하지 않음

### 2025-04-24 개발일지

**주요 작업:**
1. **기기 위치 트리거에 대한 버그 수정:**
   - 앱 실행 시 위치가 감지되면서 진입/진출 트리거가 잘못 작동하는 문제를 해결. `was in false, is in true` 상태에서 불필요하게 알람이 울리는 현상을 방지.
   - 앱을 처음 실행하거나 업데이트 후 위치를 초기화하는 로직을 수정하여 알람 트리거가 비정상적으로 작동하지 않도록 개선.

2. **백그라운드 위치 추적 강화:**
   - 앱이 백그라운드 상태에서 위치를 지속적으로 추적하도록 설정. 위치가 변동될 때마다 정확한 트리거가 발생하도록 보장.
   - 위치 추적이 꺼졌을 때 처리할 예외사항들을 다뤄, GPS 꺼짐, 통신 장애 등의 상태에서 알람이 울리지 않도록 방지.

**버그 및 문제 해결:**
- **앱 종료 후 위치 감지 문제:** 앱이 종료된 상태에서 이전 위치와 현재 위치를 비교하는 방식으로 트리거를 처리하는 로직을 개선. 이를 통해 앱 실행 후 잘못된 진입/진출 알람이 발생하는 문제를 해결.
- **알람 트리거와 백그라운드 위치 비교:** 앱 실행 시 위치에 대한 트리거가 잘못 작동하는 문제를 수정. 앱이 종료된 상태에서 백그라운드에서 위치를 감지했을 때 잘못된 트리거가 발생하지 않도록 개선.

---

### 2025-04-25 개발일지

**주요 작업:**
1. **알람음 설정 및 리소스 관리 최적화:**
   - 벨소리가 중복되어 울리거나, 알람이 울릴 때 기본 벨소리도 함께 울리는 문제 해결.
   - 알람음의 재생 및 정지를 관리하는 `AlarmSoundPlayer` 클래스를 리팩토링하여, 알람 비활성화 시 불필요한 벨소리 재생을 방지하도록 개선.

2. **알람 기능에 대한 리팩토링 및 테스트:**
   - 백그라운드 상태에서 알람 기능이 정상적으로 동작하는지 테스트.
   - 실제 기기에서 앱을 실행하며 백그라운드 위치 추적 및 알람 트리거 기능을 점검하여, 알람 울림이 정확하게 작동하도록 구현.
   - 앱 업데이트 시, 기존 알람이 그대로 유지되는 문제를 점검하고, 사용자 경험을 개선.

**버그 및 문제 해결:**
- **알람 트리거 미작동 문제:** 사용자가 앱을 종료한 상태에서 알람이 울려야 하는 위치에 도달했을 때, 알람이 울리지 않는 문제를 해결. 앱이 백그라운드 상태에서도 위치를 감지하여 정확한 트리거가 발생하도록 개선.

**기타 작업:**
- **개발일지 업데이트 및 관리:** 4월 24일과 25일의 작업 내용을 깃허브에 기록하여 관리.

# 📅 Ringinout 개발일지  
## 기간: 2025년 4월 26일 ~ 4월 27일 (알람앱7 시작 시점)

---

## ✅ 2025-04-26 (금)

### 📌 주요 작업
- `알람앱7 시작` 선언, GitHub 프로젝트 공유 (`https://github.com/bnt0514/ringinout`)
- 전체 프로젝트 코드 구조 빠르게 리뷰
- 중복 벨소리 재생 이슈 확인
  - 앱 내에서 설정한 mp3 벨소리와 시스템 기본 벨소리가 동시에 재생됨
  - 벨소리 중복으로 앱 튕김 현상 발생 확인
- `MainActivity.kt` 내 Notification 채널에서 `setSound(null, null)` 설정 확인
- `playRingtoneLoud()` 메서드 확인: 시스템 기본 벨소리 강제 재생 구조 유지

---

## ✅ 2025-04-27 (토)

### 📌 주요 작업

#### 🔧 벨소리 구조 리팩토링
- 전체 벨소리 로직을 **Flutter 내부 asset(mp3)** 기반 → **Native 기본 벨소리** 방식으로 변경
- 모든 페이지에서 `just_audio` 제거 작업 시작
  - `FullScreenAlarmPage`, `LocationMonitorService`, `AlarmPopupManager` 등 수정
  - `soundPath` 인자 제거, MethodChannel을 통한 native 호출 방식 통일

#### 🧹 정리 작업
- `AlarmPopupManager` 삭제 결정
  - ValueListenableBuilder 및 Stack 기반 상단 메시지 UI 제거
  - `builder: (context, child)` 내부 간소화
- Notification 클릭 시 전체화면 진입 로직 점검
  - `.mp3.mp3` 오타 수정
  - `FullScreenAlarmPage`에 더 이상 `soundPath` 넘기지 않도록 정리 예정

---

## 🔄 주요 이슈/논의
- 앱 실행 시 위치 기반 알람이 잘못 울리는 문제 제기
  - 진입/진출 상태 비교(`wasInside`, `isInside`)가 실행 시점에 따라 잘못 감지될 가능성 논의
- 향후 음성 인식 기반 알람 생성이 메인 기능이라는 점 재확인

---

## 📌 TODO (다음 작업)
- `flutter_local_notifications` 관련 코드 전체 리팩토링 (사운드 설정 제거 포함)
- `LocationMonitorService`에서 완전한 just_audio 제거 + MethodChannel 전환
- `AlarmNotificationHelper` 캔버스 코드 정리 (알람앱8에서 이어서)

## 📅 개발일지: 2025.04.27 ~ 2025.04.28

### ✅ 주요 작업 요약

- **전체화면 알람 분기 처리**
  - 포그라운드 상태: Flutter `FullScreenAlarmPage`로 전환
  - 백그라운드 상태: Android Native `AlarmFullscreenActivity` 실행

- **MethodChannel 연결**
  - Flutter → Native: `launchNativeAlarm`
  - Native → Flutter: `navigateToFullScreenAlarm` (포그라운드 진입 시 사용)

- **백그라운드 감시 서비스 확장**
  - `onStart()` 내에서 위치 감지 및 Native 알람 호출 로직 포함
  - showAlarmNotification 병행 호출로 알림도 함께 표시

- **알람 벨소리 처리 변경**
  - 앱 내 mp3 대신 Android 기본 벨소리만 사용
  - `soundPath`는 포맷 유지만 하고 실제로는 사용하지 않음

- **기타 이슈**
  - Notification 클릭 시 전체화면 전환은 정상 작동 확인
  - Flutter 포그라운드 상태에서의 전체화면 진입 실패 → 원인 분석 필요
  - Kotlin 빌드 시 `source 8` 관련 경고 다수 발생 (기능에는 영향 없음)

### 🧪 다음 작업 예정
- 포그라운드 진입 실패 원인 추적 및 해결
- 전체화면 알람 페이지와 알림 간 충돌 여부 검토
- `flutter_background_service` 안정성 테스트

## 📅 2025-04-29 ~ 04-30 개발일지: Bluetooth 기반 위치 감지 기능 구현 시작

### ✅ 주요 개발 내용

- `ringinout_bluetooth_detector` 프로젝트 신규 생성 (경로: `C:/buildapp/`)
- `flutter_blue_plus`, `permission_handler` 의존성 설치 및 충돌 해결
- Android NDK 버전 불일치 및 `<uses-permission>` 위치 오류 해결
- `BluetoothManager` 클래스 설계 및 리팩토링 진행:
  - 이름 기반 매칭 방식으로 간소화
  - 주기적 연결 확인 (`Timer.periodic`) + 앱 시작 시 1회 확인 포함
- `bluetooth_test_page.dart` 생성 및 UI 테스트 구현
  - 블루투스 기기명 입력 → 연결 여부 감지
  - 실제 감지는 안 되는 이슈 발견 → 백엔드 로직 개선 착수
- 실시간 감지를 위한 Stream API 시도 → `connectionState` 미지원 확인
- 최종적으로 `FlutterBluePlus.connectedDevices`를 이용한 30초 단위 확인 로직으로 정리
- 플랫폼 이름(`device.name`)은 `platformName`으로 변경하여 deprecated 경고 제거

---

### 🛠 수정된 주요 파일

- `lib/bluetooth_manager.dart`
- `lib/pages/bluetooth_test_page.dart`
- `pubspec.yaml`
- `main.dart`

---

### 🔁 다음 작업 예정

- `MyPlaces`에서 블루투스 기기명 등록 기능 연동
- 블루투스 기기 자동연결 시 알람 트리거 연결
- 이후 GPS 및 Wi-Fi 감지 방식과 통합 예정

---

### 🧠 기타

- `BluetoothManager`에 `startMonitoring()` / `stopMonitoring()` 완성
- 연결된 블루투스 기기 이름이 매칭되면 콜백 실행되는 구조 설계

## 📆 2025-05-01 ~ 2025-05-02 Bluetooth 감지 기반 알람 기능 개발

### ✅ 주요 작업 내용
- BLE와 클래식 블루투스를 구분하여 감지 로직 분리
  - `BleBluetoothManager` / `ClassicBluetoothManager` 클래스 작성 완료
  - BLE는 `flutter_blue_plus`, 클래식은 `flutter_bluetooth_serial` 사용
- BluetoothTestPage에서 BLE + 클래식 감지 테스트용 UI 구성
  - 연결 시: 🟢 "BLE/클래식 블루투스 연결됨" 상태 표시
  - 끊김 시: 🔴 "클래식 블루투스 끊어짐" 상태 표시
- Android 12 이상 대응을 위한 권한 요청 로직 추가 (`permission_handler`)
  - `BluetoothTestPage`에서 앱 실행 시 권한 자동 요청
  - AndroidManifest에 `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`, `FOREGROUND_SERVICE` 등 권한 명시
- `getBondedDevices()` 및 `device.isConnected` 기반 클래식 연결 여부 탐지 로직 구현
- 디버깅 중 `getBondedDevices()` 결과값이 나오지 않는 문제 확인 → Android 12+ 권한 설정 이슈로 추정, 해결

### ⚙️ 추가 확인 사항
- 사용 기기: Galaxy Z Flip6 (Android 14)
- BLE는 현재 보류, 클래식 블루투스 연결 기반으로 진입/진출 감지 우선 구현 중

# 📅 개발일지 (2025.05.03 ~ 2025.05.04)

## ✅ Geofence 기반 위치 감지 구조 리팩터링
- 기존 Geolocator 기반 감지 로직을 완전히 제거하고 Geofence 기반으로 전환
- `LocationMonitorService`에서 `GeofenceService.instance.addGeofenceStatusChangeListener`를 사용하여 감지 이벤트 처리
- 이벤트 핸들러는 `(Geofence geofence, GeofenceStatus status, Location location)` 형식으로 구현
- `GeofenceStatus.ENTER`, `GeofenceStatus.EXIT` 값을 이용해 진입/진출 트리거 분기
- `navigatorKey`를 사용해 포그라운드에서는 Flutter 페이지 이동, 백그라운드에서는 Native 알람 호출 처리
- `GeofenceEvent`, `GeofenceTransitionType` 등 미사용/오류 타입 제거 후 정상 빌드 완료

## ✅ MyPlaces와 Geofence 연동 설계
- 위치 등록 페이지(`location_picker_page.dart`)를 `add_myplaces_page.dart`로 개편
- 저장 시 Hive 저장과 동시에 Geofence 반경 100m 등록
- 저장된 위치는 `SavedLocationsPage`에서 관리되고, 알람 설정 시 해당 장소 기준으로 트리거 감지 가능

## 🐛 주요 이슈 해결
- Geofence 관련 클래스/이벤트명 오타 및 잘못된 타입 정의로 인한 컴파일 에러 수정
- context 사용 시 async gap 문제 발생 → `if (mounted)` 또는 `Future.microtask` 활용해 해결

---