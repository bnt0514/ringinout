# 🧪 테스트 계정 로그인 시스템 설정 가이드

다른 Flutter 앱에 동일한 테스트 로그인 기능을 추가하는 방법

---

## 📋 현재 Ringmind 설정값

- **로고 탭 횟수**: 10번
- **테스트 비밀번호**: `rralcuqk8^`
- **계정 종류**: free, basic, premium, special

---

## 🎯 다른 앱에 복사할 때 코파일럿에게 요청하는 방법

### 1️⃣ Flutter 앱 (클라이언트)

코파일럿에게 이렇게 요청하세요:

```
로그인 페이지에 개발자 테스트 모드를 추가해줘.

요구사항:
1. 로고를 10번 탭하면 숨겨진 테스트 로그인 폼이 나타남
2. TextField 2개 필요:
   - username (free, basic, premium, special 중 하나)
   - password (비밀번호 입력)
3. 로그인 버튼 클릭 시 Firebase Functions의 authenticateTestAccount를 호출
4. 성공하면 customToken을 받아서 FirebaseAuth.signInWithCustomToken() 실행
5. 로그인 후 메인 화면으로 이동

코드 예시가 필요하면 이 파일들을 참고해:
- lib/pages/login_page.dart (_handleLogoTap, _signInWithTestAccount 메서드)
- lib/pages/welcome_page.dart (동일한 패턴)
```

### 2️⃣ Firebase Functions (서버)

코파일럿에게 이렇게 요청하세요:

```
Firebase Functions에 테스트 계정 인증 함수를 추가해줘.

요구사항:
1. 함수 이름: authenticateTestAccount
2. 파라미터: username, password
3. 비밀번호가 "rralcuqk8^"인지 검증
4. username이 다음 중 하나인지 확인:
   - free: 기본 플랜
   - basic: 베이직 플랜
   - premium: 프리미엄 플랜
   - special: 개발자 플랜
5. Firebase Admin SDK로 Custom Token 생성
   - UID 형식: test_${username} (예: test_free, test_basic)
   - 사용자가 없으면 자동 생성
6. customToken을 클라이언트에 반환

코드 예시:
```javascript
exports.authenticateTestAccount = functions
    .region('asia-northeast3')
    .https.onCall(async (data, context) => {
        const { username, password } = data;

        if (password !== 'rralcuqk8^') {
            throw new functions.https.HttpsError('permission-denied', '잘못된 비밀번호입니다.');
        }

        const TEST_ACCOUNTS = {
            'free': { plan: 'free' },
            'basic': { plan: 'basic' },
            'premium': { plan: 'premium' },
            'special': { plan: 'special' }
        };

        const testAccount = TEST_ACCOUNTS[username?.toLowerCase()];
        if (!testAccount) {
            throw new functions.https.HttpsError('not-found', '존재하지 않는 테스트 계정입니다.');
        }

        const testUid = `test_${username.toLowerCase()}`;

        try {
            await admin.auth().getUser(testUid);
        } catch (e) {
            if (e.code === 'auth/user-not-found') {
                await admin.auth().createUser({
                    uid: testUid,
                    displayName: `Test ${username}`,
                });
            }
        }

        const customToken = await admin.auth().createCustomToken(testUid, {
            testAccount: true,
            plan: testAccount.plan
        });

        return { success: true, customToken, plan: testAccount.plan };
    });
```

---

## 3️⃣ 서버 측 플랜 체크 로직

코파일럿에게 이렇게 요청하세요:

```
Firebase Functions에서 사용자 플랜을 확인할 때, 테스트 계정을 특별 처리해줘.

요구사항:
1. userId가 "test_"로 시작하면 테스트 계정으로 간주
2. "test_free" → free 플랜
3. "test_basic" → basic 플랜
4. "test_premium" → premium 플랜
5. "test_special" → special 플랜 (무제한)
6. 일반 사용자는 Firestore purchases 컬렉션에서 플랜 조회

코드 예시:
```javascript
let plan = 'free';

// 테스트 계정 확인
if (userId.startsWith('test_')) {
    const planName = userId.replace('test_', '');
    plan = planName; // free, basic, premium, special
    console.log(`🧪 테스트 계정: ${userId} → 플랜: ${plan}`);
}
// 일반 사용자
else {
    const purchaseDoc = await db.collection('purchases').doc(userId).get();
    if (purchaseDoc.exists) {
        plan = purchaseDoc.data().plan || 'free';
    }
}
```

---

## 🔒 보안 주의사항

### Git에 커밋하면 안 되는 것:
- ❌ 테스트 비밀번호 (`rralcuqk8^`)는 소스코드에 하드코딩 가능 (서버 측)
- ✅ 클라이언트는 비밀번호를 저장하지 않음 (사용자가 입력)
- ❌ 실제 사용자 UID나 API 키는 환경 변수로 관리

### 프로덕션 배포 시:
- 테스트 계정 함수는 그대로 배포해도 됨
- 비밀번호를 아는 사람만 테스트 계정 생성 가능
- 테스트 UID는 `test_` 접두사로 쉽게 구분 가능

---

## 📱 사용 방법 (최종 사용자)

1. 앱 실행 후 로그인 화면
2. **로고를 10번 빠르게 탭**
3. 숨겨진 테스트 로그인 폼 등장
4. Username: `special` (또는 free, basic, premium)
5. Password: `rralcuqk8^`
6. 로그인 버튼 클릭
7. 해당 플랜으로 자동 로그인!

---

## 🔄 다른 앱에 적용할 때 변경할 값

| 항목         | 현재 값                    | 변경 방법                                    |
| ------------ | -------------------------- | -------------------------------------------- |
| 로고 탭 횟수 | 10번                       | `_devTapCount >= 10` 부분 수정               |
| 비밀번호     | `rralcuqk8^`               | Functions의 `password !== 'rralcuqk8^'` 수정 |
| 플랜 종류    | free/basic/premium/special | `TEST_ACCOUNTS` 객체 수정                    |
| UID 접두사   | `test_`                    | `startsWith('test_')` 부분 수정              |

---

## ✅ 체크리스트

복사 완료 후 확인:
- [ ] 로고 10번 탭 시 테스트 폼 등장
- [ ] 비밀번호 `rralcuqk8^` 입력 시 로그인 성공
- [ ] Firebase Authentication에 `test_free` 등 계정 생성 확인
- [ ] 서버 로그에 "🧪 테스트 계정" 메시지 출력
- [ ] 각 플랜별 기능 제한이 올바르게 작동
