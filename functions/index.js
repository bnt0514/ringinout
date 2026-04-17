const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();

// Allowed origins for CORS (restrict in production)
const ALLOWED_ORIGINS = ['https://ringgo-485705.web.app', 'https://ringgo-485705.firebaseapp.com'];

function setCors(req, res) {
    const origin = req.headers.origin;
    // Allow any origin in dev, restrict in production
    if (ALLOWED_ORIGINS.includes(origin)) {
        res.set('Access-Control-Allow-Origin', origin);
    } else {
        // Mobile apps don't send Origin header, so allow if no origin
        res.set('Access-Control-Allow-Origin', origin || '*');
    }
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

// Max bug report payload size (500KB)
const MAX_BUG_REPORT_SIZE = 500 * 1024;

// HMAC 익명 ID 생성
function generateAnonUserId(firebaseUid) {
    const secret = functions.config().app?.secret || 'dev_secret_key_for_testing';
    return crypto.createHmac('sha256', secret).update(firebaseUid).digest('hex');
}

// Firestore에서 special 플랜 여부 확인
async function checkSpecialPlan(firebaseUid) {
    try {
        const adminDoc = await admin.firestore()
            .collection('admin_config')
            .doc('special_users')
            .get();

        if (!adminDoc.exists) {
            return false;
        }

        const uids = adminDoc.data().uids || [];
        return uids.includes(firebaseUid);
    } catch (error) {
        console.error('❌ Firestore check failed:', error);
        return false;
    }
}

// ============================================================
// POST /auth/session - 로그인 세션 생성
// ============================================================
exports.createSession = functions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const { idToken } = req.body;

    if (!idToken) {
        return res.status(400).json({ error: 'idToken is required' });
    }

    try {
        // Firebase ID Token 검증
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;

        // HMAC 기반 익명 ID 생성
        const anonUserId = generateAnonUserId(firebaseUid);

        // 사용자 등록 (Firestore 영속 저장)
        const now = Date.now();
        const userRef = db.collection('cf_users').doc(anonUserId);
        const userSnap = await userRef.get();

        if (!userSnap.exists) {
            await userRef.set({ created_at: now, last_login_at: now });

            // Firestore에서 special 플랜 여부 확인
            const isSpecialUser = await checkSpecialPlan(firebaseUid);
            const plan = isSpecialUser ? 'special' : 'free';

            await db.collection('cf_subscriptions').doc(anonUserId).set({
                store: 'manual',
                plan: plan,
                status: 'active',
                expires_at: null,
                last_verified_at: now
            });

            console.log(`👤 신규 사용자 생성: ${plan} 플랜`);
        } else {
            await userRef.update({ last_login_at: now });
        }

        res.json({ success: true, message: 'Session created' });
    } catch (error) {
        console.error('❌ Token verification failed:', error);
        res.status(401).json({ error: 'Invalid or expired token' });
    }
});

// ============================================================
// GET /billing/status - 구독 플랜 조회
// ============================================================
exports.getBillingStatus = functions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authorization header missing' });
    }

    const idToken = authHeader.split('Bearer ')[1];

    try {
        // Firebase ID Token 검증
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;

        // HMAC 기반 익명 ID 생성
        const anonUserId = generateAnonUserId(firebaseUid);

        // 구독 조회 (Firestore)
        const subSnap = await db.collection('cf_subscriptions').doc(anonUserId).get();

        if (!subSnap.exists) {
            return res.status(404).json({ error: 'Subscription not found' });
        }

        const subscription = subSnap.data();

        res.json({
            plan: subscription.plan,
            status: subscription.status,
            expires_at: subscription.expires_at,
            store: subscription.store
        });
    } catch (error) {
        console.error('❌ Token verification failed:', error);
        res.status(401).json({ error: 'Invalid or expired token' });
    }
});

// ============================================================
// POST /billing/verify - 영수증 검증 (향후 구현)
// ============================================================
exports.verifyPurchase = functions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authorization header missing' });
    }

    const { store, receipt, purchaseToken } = req.body;

    if (!store || !receipt) {
        return res.status(400).json({ error: 'store and receipt are required' });
    }

    try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;
        const anonUserId = generateAnonUserId(firebaseUid);

        // TODO: Google Play / App Store 영수증 검증 구현
        console.log('📱 영수증 검증 요청:', { store, anonUserId: anonUserId.substring(0, 8) });

        // 임시 응답
        res.json({
            success: true,
            message: 'Purchase verification not implemented yet',
            plan: 'free'
        });
    } catch (error) {
        console.error('❌ Verification failed:', error);
        res.status(401).json({ error: 'Invalid token' });
    }
});

// ============================================================
// POST /submitBugReport - 버그 리포트 (30분 로그 + 사용자 메모 + 디바이스 정보)
// Firestore > bug_reports 컬렉션에 저장
// ============================================================
exports.submitBugReport = functions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authorization header missing' });
    }

    try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;
        const anonUserId = generateAnonUserId(firebaseUid);

        const { logs, deviceInfo, appVersion, memo } = req.body;

        if (!logs || !Array.isArray(logs)) {
            return res.status(400).json({ error: 'logs array is required' });
        }

        // Payload size guard
        const payloadSize = JSON.stringify(req.body).length;
        if (payloadSize > MAX_BUG_REPORT_SIZE) {
            return res.status(413).json({ error: `Payload too large (${payloadSize} bytes, max ${MAX_BUG_REPORT_SIZE})` });
        }

        // 로그 분석: severity 자동 판단
        const trimmedLogs = logs.slice(0, 1000);
        let errorCount = 0;
        let warnCount = 0;
        trimmedLogs.forEach(line => {
            const lower = (line || '').toLowerCase();
            if (lower.includes('[error]') || lower.includes('❌') || lower.includes('fatal')) errorCount++;
            else if (lower.includes('[warn]') || lower.includes('⚠️') || lower.includes('warning')) warnCount++;
        });

        // severity 등급
        let severity = 'info';
        if (errorCount > 0) severity = 'error';
        else if (warnCount > 0) severity = 'warn';

        // Firestore에 저장
        const reportRef = admin.firestore().collection('bug_reports').doc();
        await reportRef.set({
            // 식별 정보
            anonUserId: anonUserId.substring(0, 16),
            appVersion: appVersion || 'unknown',
            // 사용자 메모
            memo: memo || '',
            hasMemo: !!(memo && memo.trim().length > 0),
            // 디바이스 정보
            deviceInfo: deviceInfo || {},
            // 로그 분석 요약 (Firebase Console 필터용)
            severity,          // 'error' | 'warn' | 'info'
            errorCount,
            warnCount,
            logCount: trimmedLogs.length,
            // 전체 로그 (문자열 배열)
            logs: trimmedLogs,
            // 타임스탬프
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`🐛 버그 리포트 저장: ${reportRef.id} | severity=${severity} | errors=${errorCount} warns=${warnCount} logs=${trimmedLogs.length} | memo="${memo || ''}"`);

        res.json({ success: true, reportId: reportRef.id });
    } catch (error) {
        console.error('❌ Bug report failed:', error);
        res.status(500).json({ error: 'Failed to save bug report' });
    }
});
