# RingInOut 구독 검증 서버

## 목적
Google 로그인으로 사용자 인증을 하고, 서버에는 사용자를 직접 식별할 수 없는 `anon_user_id`만 저장해서 구독 플랜 확인(결제 상태 검증)만 가능하게 합니다.

## 원칙 (필수 준수)
- ⚠️ **서버 DB에 이메일, 이름, 프로필 사진, Google sub, Firebase uid 원문 저장 금지**
- ⚠️ **로그/에러리포트에도 위 값들 남기지 않기**
- ✅ 서버가 보유하는 데이터: `anon_user_id`, 구독 상태/플랜/만료일만
- ✅ 구독 검증 목적 외 사용 금지

## 설치 및 실행

### 1. 의존성 설치
```bash
cd server
npm install
```

### 2. 환경변수 설정
`.env.example`을 복사해서 `.env` 파일 생성:
```bash
cp .env.example .env
```

`.env` 파일 수정:
```env
SERVER_SECRET=your_random_32char_secret_here
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
PORT=3000
```

### 3. Firebase 서비스 계정 키 다운로드
- Firebase Console → 프로젝트 설정 → 서비스 계정
- "새 비공개 키 생성" 클릭
- 다운로드한 JSON 파일을 `server/firebase-service-account.json`으로 저장

### 4. 서버 실행
```bash
npm start          # 프로덕션
npm run dev        # 개발 모드 (nodemon)
```

## API 엔드포인트

### POST /auth/session
Firebase ID Token으로 세션 생성

**Request:**
```json
{
  "idToken": "Firebase_ID_Token_Here"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Session created"
}
```

### GET /billing/status
현재 구독 플랜 조회 (인증 필요)

**Headers:**
```
Authorization: Bearer <Firebase_ID_Token>
```

**Response:**
```json
{
  "plan": "free",
  "status": "active",
  "expires_at": null,
  "last_verified_at": 1707868800000
}
```

### POST /billing/verify
스토어 영수증 검증 후 구독 업데이트 (인증 필요)

**Headers:**
```
Authorization: Bearer <Firebase_ID_Token>
```

**Request:**
```json
{
  "store": "ios",
  "receipt": "base64_encoded_receipt"
}
```

**Response:**
```json
{
  "success": true,
  "plan": "premium",
  "status": "active",
  "expires_at": 1710460800000
}
```

## 데이터베이스 스키마

### users 테이블
| 컬럼          | 타입      | 설명                                     |
| ------------- | --------- | ---------------------------------------- |
| anon_user_id  | TEXT (PK) | HMAC_SHA256(SERVER_SECRET, firebase_uid) |
| created_at    | INTEGER   | 유저 생성 시각 (Unix timestamp)          |
| last_login_at | INTEGER   | 마지막 로그인 시각                       |

### subscriptions 테이블
| 컬럼             | 타입         | 설명                                     |
| ---------------- | ------------ | ---------------------------------------- |
| id               | INTEGER (PK) | Auto increment                           |
| anon_user_id     | TEXT (FK)    | users.anon_user_id                       |
| store            | TEXT         | 'ios', 'android', 'manual'               |
| plan             | TEXT         | 'free', 'basic', 'premium', 'special'    |
| status           | TEXT         | 'active', 'expired', 'canceled', 'grace' |
| expires_at       | INTEGER      | 만료 시각 (Unix timestamp, null=무제한)  |
| last_verified_at | INTEGER      | 마지막 검증 시각                         |

## 보안 체크리스트
- [x] Firebase ID Token 서버 검증
- [x] HMAC 기반 익명 ID 생성
- [x] 이메일/이름/사진 저장 안함
- [x] uid/sub 로그에 안 남김
- [x] 플랜은 서버에서만 결정
- [x] Helmet으로 보안 헤더 설정
- [ ] HTTPS 사용 (프로덕션 배포 시)
- [ ] Rate limiting 추가 (추후)
- [ ] 실제 App Store / Play Store 영수증 검증 구현

## TODO
- [ ] iOS App Store Server API 연동
- [ ] Android Play Developer API 연동
- [ ] 구독 만료 자동 체크 크론잡
- [ ] 로깅 시스템 개선 (민감정보 필터링)
- [ ] 프로덕션 배포 설정
