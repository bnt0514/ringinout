const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

// 메모리 DB (간단한 캐시용)
const users = new Map();
const subscriptions = new Map();

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
    // CORS 설정
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

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

        // 사용자 등록
        const now = Date.now();
        if (!users.has(anonUserId)) {
            users.set(anonUserId, { created_at: now, last_login_at: now });

            // Firestore에서 special 플랜 여부 확인
            const isSpecialUser = await checkSpecialPlan(firebaseUid);
            const plan = isSpecialUser ? 'special' : 'free';

            subscriptions.set(anonUserId, {
                store: 'manual',
                plan: plan,
                status: 'active',
                expires_at: null,
                last_verified_at: now
            });

            console.log(`👤 신규 사용자 생성: ${plan} 플랜`);
        } else {
            users.get(anonUserId).last_login_at = now;
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
    // CORS 설정
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

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

        // 구독 조회
        const subscription = subscriptions.get(anonUserId);

        if (!subscription) {
            return res.status(404).json({ error: 'Subscription not found' });
        }

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
    // CORS 설정
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

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
