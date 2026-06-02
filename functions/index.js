const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();
const ADMIN_UIDS = new Set(['IPf2TW0c62et7bwi8B5hZGyKLlc2']);

// Allowed origins for CORS (restrict in production)
const ALLOWED_ORIGINS = ['https://ringgo-485705.web.app', 'https://ringgo-485705.firebaseapp.com'];
const CORE_SECRETS = ['APP_SECRET', 'APP_ENFORCE_APP_CHECK'];
const coreFunctions = functions.runWith({ secrets: CORE_SECRETS });
const naverNcpFunctions = functions.runWith({
    secrets: [
        ...CORE_SECRETS,
        'NAVER_NCP_CLIENT_ID',
        'NAVER_NCP_CLIENT_SECRET',
        'NAVER_LOCAL_CLIENT_ID',
        'NAVER_LOCAL_CLIENT_SECRET',
    ],
});
const googleMapsFunctions = functions.runWith({
    secrets: [...CORE_SECRETS, 'GOOGLE_MAPS_API_KEY'],
});

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
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Firebase-AppCheck');
}

// Max bug report payload size (500KB)
const MAX_BUG_REPORT_SIZE = 500 * 1024;

// HMAC 익명 ID 생성
function getConfigValue(group, key, envName) {
    return process.env[envName] || functions.config()[group]?.[key];
}

function getRequiredConfigValue(group, key, envName) {
    const value = getConfigValue(group, key, envName);
    if (!value) {
        throw new Error(`Missing config: ${group}.${key} or ${envName}`);
    }
    return value;
}

function parseJsonConfig(group, key, envName, fallback) {
    const raw = getConfigValue(group, key, envName);
    if (!raw) return fallback;
    try {
        return JSON.parse(raw);
    } catch (error) {
        console.warn(`Invalid JSON config ${group}.${key}:`, error.message);
        return fallback;
    }
}

function isAdminUid(firebaseUid) {
    return ADMIN_UIDS.has(firebaseUid);
}

async function requireAppCheck(req, res) {
    const enforce = String(getConfigValue('app', 'enforce_app_check', 'APP_ENFORCE_APP_CHECK') || 'false').toLowerCase() === 'true';
    if (!enforce) return true;

    const appCheckToken = req.header('X-Firebase-AppCheck');
    if (!appCheckToken) {
        res.status(401).json({ error: 'App Check token missing' });
        return false;
    }

    try {
        await admin.appCheck().verifyToken(appCheckToken);
        return true;
    } catch (error) {
        console.error('App Check verification failed:', error);
        res.status(401).json({ error: 'Invalid App Check token' });
        return false;
    }
}

function generateAnonUserId(firebaseUid) {
    const secret = getRequiredConfigValue('app', 'secret', 'APP_SECRET');
    return crypto.createHmac('sha256', secret).update(firebaseUid).digest('hex');
}

async function requireFirebaseUid(req, res) {
    const appCheckOk = await requireAppCheck(req, res);
    if (!appCheckOk) return null;

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Authorization header missing' });
        return null;
    }

    try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        return decodedToken.uid;
    } catch (error) {
        console.error('Token verification failed:', error);
        res.status(401).json({ error: 'Invalid or expired token' });
        return null;
    }
}

function getBillingPackageName() {
    return getConfigValue('billing', 'package_name', 'BILLING_PACKAGE_NAME') || 'com.bnt0514.ringinout';
}

function getProductPlanMap() {
    return parseJsonConfig('billing', 'product_plan_map', 'BILLING_PRODUCT_PLAN_MAP', {
        ringinout_plus_monthly: 'plus',
        plus_monthly: 'plus',
        ringinout_pro_monthly: 'pro',
        pro_monthly: 'pro',
        ringinout_remove_ads: 'plus',
        remove_ads: 'plus',
    });
}

function hashPurchaseToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
}

async function getAndroidPublisher() {
    const { google } = require('googleapis');
    const auth = await google.auth.getClient({
        scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    return google.androidpublisher({ version: 'v3', auth });
}

function toMillis(timeValue) {
    if (!timeValue) return null;
    if (typeof timeValue === 'number') return timeValue;
    const parsed = Date.parse(timeValue);
    return Number.isFinite(parsed) ? parsed : null;
}

function requirePost(req, res) {
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return false;
    }
    if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return false;
    }
    return true;
}

function currentMonthUtc() {
    const now = new Date();
    return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
}

function currentWeekUtc() {
    const now = new Date();
    const day = now.getUTCDay() || 7;
    const monday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    monday.setUTCDate(monday.getUTCDate() - day + 1);
    const startOfYear = Date.UTC(monday.getUTCFullYear(), 0, 1);
    const dayOfYear = Math.floor((monday.getTime() - startOfYear) / 86400000) + 1;
    const weekNum = Math.floor((dayOfYear - 1) / 7) + 1;
    return `${monday.getUTCFullYear()}-W${String(weekNum).padStart(2, '0')}`;
}

async function consumeRateLimit(firebaseUid, bucket, minuteLimit, dayLimit) {
    const now = new Date();
    const minuteId = now.toISOString().slice(0, 16).replace(/[-:T]/g, '');
    const dayId = now.toISOString().slice(0, 10).replace(/-/g, '');
    const minuteRef = db.collection('rate_limits').doc(`${bucket}_${firebaseUid}_${minuteId}`);
    const dayRef = db.collection('rate_limits').doc(`${bucket}_${firebaseUid}_${dayId}`);

    return db.runTransaction(async (tx) => {
        const [minuteSnap, daySnap] = await Promise.all([tx.get(minuteRef), tx.get(dayRef)]);
        const minuteCount = minuteSnap.exists ? (minuteSnap.data().count || 0) : 0;
        const dayCount = daySnap.exists ? (daySnap.data().count || 0) : 0;

        if (minuteCount >= minuteLimit || dayCount >= dayLimit) {
            return false;
        }

        const expiresAt = admin.firestore.Timestamp.fromMillis(now.getTime() + 48 * 60 * 60 * 1000);
        tx.set(minuteRef, {
            count: admin.firestore.FieldValue.increment(1),
            bucket,
            expires_at: expiresAt,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.set(dayRef, {
            count: admin.firestore.FieldValue.increment(1),
            bucket,
            expires_at: expiresAt,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
    });
}

function clampCount(value, max) {
    const n = Number(value);
    if (!Number.isFinite(n) || n < 0) return 0;
    return Math.min(Math.floor(n), max);
}

function buildUsageDelta(newData, oldData, keys) {
    const delta = {};
    keys.forEach((key) => {
        delta[key] = (newData[key] || 0) - (oldData?.[key] || 0);
    });
    return delta;
}

function incrementsFromDelta(delta) {
    return Object.fromEntries(
        Object.entries(delta).map(([key, value]) => [key, admin.firestore.FieldValue.increment(value)])
    );
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
exports.createSession = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    if (!(await requireAppCheck(req, res))) return;

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
exports.getBillingStatus = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    if (!(await requireAppCheck(req, res))) return;

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
exports.verifyPurchase = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    if (!(await requireAppCheck(req, res))) return;

    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authorization header missing' });
    }

    const {
        store,
        receipt,
        purchaseToken,
        productId,
        packageName: requestedPackageName,
        purchaseType = 'subscription',
    } = req.body || {};

    if (!store || !receipt || !purchaseToken || !productId) {
        return res.status(400).json({ error: 'store, receipt, purchaseToken, and productId are required' });
    }
    if (!['google_play', 'android'].includes(store)) {
        return res.status(400).json({ error: 'unsupported store' });
    }

    try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;
        const anonUserId = generateAnonUserId(firebaseUid);
        const packageName = requestedPackageName || getBillingPackageName();
        if (packageName !== getBillingPackageName()) {
            return res.status(400).json({ error: 'invalid packageName' });
        }

        const publisher = await getAndroidPublisher();
        const productPlanMap = getProductPlanMap();
        const tokenHash = hashPurchaseToken(purchaseToken);
        let verified = false;
        let plan = 'free';
        let status = 'invalid';
        let expiresAt = null;
        let providerPayload = {};

        if (purchaseType === 'subscription') {
            const result = await publisher.purchases.subscriptionsv2.get({
                packageName,
                token: purchaseToken,
            });
            const subscription = result.data || {};
            const lineItems = Array.isArray(subscription.lineItems) ? subscription.lineItems : [];
            const lineItem = lineItems.find((item) => item.productId === productId) || lineItems[0] || {};
            const state = subscription.subscriptionState || 'SUBSCRIPTION_STATE_UNSPECIFIED';
            expiresAt = toMillis(lineItem.expiryTime);

            const activeStates = new Set([
                'SUBSCRIPTION_STATE_ACTIVE',
                'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
                'SUBSCRIPTION_STATE_CANCELED',
            ]);
            verified = activeStates.has(state) && !!expiresAt && expiresAt > Date.now();
            status = verified ? 'active' : (expiresAt && expiresAt <= Date.now() ? 'expired' : state.toLowerCase());
            plan = verified ? (productPlanMap[productId] || 'plus') : 'free';
            providerPayload = {
                subscriptionState: state,
                orderId: subscription.latestOrderId || null,
                lineItemProductId: lineItem.productId || null,
            };

            if (verified && subscription.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
                try {
                    await publisher.purchases.subscriptions.acknowledge({
                        packageName,
                        subscriptionId: productId,
                        token: purchaseToken,
                        requestBody: {},
                    });
                } catch (ackError) {
                    console.warn('Subscription acknowledge failed:', ackError.message);
                }
            }
        } else if (purchaseType === 'inapp') {
            const result = await publisher.purchases.products.get({
                packageName,
                productId,
                token: purchaseToken,
            });
            const product = result.data || {};
            verified = product.purchaseState === 0;
            status = verified ? 'active' : `purchase_state_${product.purchaseState ?? 'unknown'}`;
            plan = verified ? (productPlanMap[productId] || 'plus') : 'free';
            expiresAt = null;
            providerPayload = {
                orderId: product.orderId || null,
                acknowledgementState: product.acknowledgementState ?? null,
                consumptionState: product.consumptionState ?? null,
            };

            if (verified && product.acknowledgementState === 0) {
                try {
                    await publisher.purchases.products.acknowledge({
                        packageName,
                        productId,
                        token: purchaseToken,
                        requestBody: {},
                    });
                } catch (ackError) {
                    console.warn('Product acknowledge failed:', ackError.message);
                }
            }
        } else {
            return res.status(400).json({ error: 'invalid purchaseType' });
        }

        if (await checkSpecialPlan(firebaseUid)) {
            plan = 'special';
            status = 'active';
            expiresAt = null;
        }

        const subRef = db.collection('cf_subscriptions').doc(anonUserId);
        const tokenRef = db.collection('purchase_tokens').doc(tokenHash);
        await db.runTransaction(async (tx) => {
            const tokenSnap = await tx.get(tokenRef);
            if (tokenSnap.exists) {
                const tokenData = tokenSnap.data() || {};
                if (tokenData.firebaseUid && tokenData.firebaseUid !== firebaseUid) {
                    throw new Error('purchase_token_already_bound');
                }
            }

            tx.set(tokenRef, {
                firebaseUid,
                anonUserId,
                tokenHash,
                store: 'google_play',
                productId,
                packageName,
                purchaseType,
                verified,
                status,
                expires_at: expiresAt,
                providerPayload,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
                created_at: tokenSnap.exists
                    ? (tokenSnap.data().created_at || admin.firestore.FieldValue.serverTimestamp())
                    : admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });

            tx.set(subRef, {
                store: 'google_play',
                plan,
                status,
                product_id: productId,
                purchase_type: purchaseType,
                purchase_token_hash: tokenHash,
                expires_at: expiresAt,
                last_verified_at: Date.now(),
                provider_payload: providerPayload,
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });

        return res.json({
            success: true,
            verified,
            plan,
            status,
            expires_at: expiresAt,
            productId,
            purchaseType,
        });
    } catch (error) {
        console.error('Purchase verification failed:', error);
        const code = error.message === 'purchase_token_already_bound' ? 409 : 500;
        res.status(code).json({ error: error.message || 'purchase_verification_failed' });
    }
});

// ============================================================
// POST /submitBugReport - 버그 리포트 (30분 로그 + 사용자 메모 + 디바이스 정보)
// Firestore > bug_reports 컬렉션에 저장
// ============================================================
exports.submitBugReport = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    if (!(await requireAppCheck(req, res))) return;

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

        // ── 월별 전체 쿼터 확인 (300건/월) ──
        const MONTHLY_REPORT_LIMIT = 300;
        const now = new Date();
        const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
        const quotaRef = admin.firestore().collection('admin_config').doc('bug_report_quota');
        const newCount = await admin.firestore().runTransaction(async (tx) => {
            const snap = await tx.get(quotaRef);
            const data = snap.exists ? snap.data() : {};
            const current = data[monthKey] || 0;
            if (current >= MONTHLY_REPORT_LIMIT) return null;
            tx.set(quotaRef, { [monthKey]: current + 1 }, { merge: true });
            return current + 1;
        });
        if (newCount === null) {
            console.log(`⚠️ 월별 버그 리포트 한도 초과: ${monthKey} (${MONTHLY_REPORT_LIMIT}건)`);
            return res.status(429).json({ error: 'monthly_quota_exceeded' });
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

        // TTL: 30일 후 자동 삭제 (Firestore TTL 정책 필드)
        const expireAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

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
            // TTL: 30일 후 자동 삭제
            expireAt: admin.firestore.Timestamp.fromDate(expireAt),
        });

        console.log(`🐛 버그 리포트 저장: ${reportRef.id} | ${monthKey} ${newCount}/${MONTHLY_REPORT_LIMIT} | severity=${severity} | errors=${errorCount} warns=${warnCount} logs=${trimmedLogs.length} | memo="${memo || ''}"`);

        res.json({ success: true, reportId: reportRef.id });
    } catch (error) {
        console.error('❌ Bug report failed:', error);
        res.status(500).json({ error: 'Failed to save bug report' });
    }
});

// ============================================================
// POST /naverGeocode - Naver NCP geocoding proxy
// ============================================================
exports.naverGeocode = naverNcpFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const firebaseUid = await requireFirebaseUid(req, res);
        if (!firebaseUid) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(firebaseUid, 'naver_geocode', 30, 500);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const clientId = getRequiredConfigValue('naver', 'ncp_client_id', 'NAVER_NCP_CLIENT_ID');
        const clientSecret = getRequiredConfigValue('naver', 'ncp_client_secret', 'NAVER_NCP_CLIENT_SECRET');
        const url = new URL('https://maps.apigw.ntruss.com/map-geocode/v2/geocode');
        url.searchParams.set('query', query);
        if (req.body?.lat != null && req.body?.lng != null) {
            const lat = Number(req.body.lat);
            const lng = Number(req.body.lng);
            if (Number.isFinite(lat) && Number.isFinite(lng)) {
                url.searchParams.set('coordinate', `${lng},${lat}`);
            }
        }
        url.searchParams.set('count', '5');

        const upstream = await fetch(url, {
            method: 'GET',
            headers: {
                'x-ncp-apigw-api-key-id': clientId,
                'x-ncp-apigw-api-key': clientSecret,
                'Accept': 'application/json',
            },
        });
        const body = await upstream.text();
        res.status(upstream.status).set('Content-Type', 'application/json; charset=utf-8').send(body);
    } catch (error) {
        console.error('naverGeocode failed:', error);
        res.status(500).json({ error: 'naver_geocode_failed' });
    }
});

// ============================================================
// POST /naverLocalSearch - Naver Local Search first, NCP Geocoding fallback
// ============================================================
exports.naverLocalSearch = naverNcpFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const firebaseUid = await requireFirebaseUid(req, res);
        if (!firebaseUid) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(firebaseUid, 'naver_geocode_place', 30, 500);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const localClientId = getRequiredConfigValue('naver', 'local_client_id', 'NAVER_LOCAL_CLIENT_ID');
        const localClientSecret = getRequiredConfigValue('naver', 'local_client_secret', 'NAVER_LOCAL_CLIENT_SECRET');
        const localUrl = new URL('https://openapi.naver.com/v1/search/local.json');
        localUrl.searchParams.set('query', query);
        localUrl.searchParams.set('display', '5');
        localUrl.searchParams.set('sort', 'random');

        const localUpstream = await fetch(localUrl, {
            method: 'GET',
            headers: {
                'X-Naver-Client-Id': localClientId,
                'X-Naver-Client-Secret': localClientSecret,
                'Accept': 'application/json',
            },
        });

        if (localUpstream.ok) {
            const localData = await localUpstream.json();
            const places = (localData.items || []).map((item) => {
                const lng = Number(item.mapx) / 10000000;
                const lat = Number(item.mapy) / 10000000;
                return {
                    name: stripHtml(item.title || ''),
                    address: item.address || '',
                    roadAddress: item.roadAddress || item.address || '',
                    category: item.category || '',
                    lng: Number.isFinite(lng) ? lng : 0,
                    lat: Number.isFinite(lat) ? lat : 0,
                    coords: Number.isFinite(lng) && Number.isFinite(lat) ? `${lng},${lat}` : '',
                };
            }).filter((item) => item.name && item.lat && item.lng);

            if (places.length > 0) {
                return res.json({ places, source: 'naver_local', rawCount: localData.total || places.length });
            }
        } else {
            console.warn('Naver Local Search failed:', localUpstream.status, await localUpstream.text());
        }

        const clientId = getRequiredConfigValue('naver', 'ncp_client_id', 'NAVER_NCP_CLIENT_ID');
        const clientSecret = getRequiredConfigValue('naver', 'ncp_client_secret', 'NAVER_NCP_CLIENT_SECRET');
        const url = new URL('https://maps.apigw.ntruss.com/map-geocode/v2/geocode');
        url.searchParams.set('query', query);
        url.searchParams.set('count', '10');
        if (req.body?.lat != null && req.body?.lng != null) {
            const lat = Number(req.body.lat);
            const lng = Number(req.body.lng);
            if (Number.isFinite(lat) && Number.isFinite(lng)) {
                url.searchParams.set('coordinate', `${lng},${lat}`);
            }
        }

        const upstream = await fetch(url, {
            method: 'GET',
            headers: {
                'x-ncp-apigw-api-key-id': clientId,
                'x-ncp-apigw-api-key': clientSecret,
                'Accept': 'application/json',
            },
        });
        const body = await upstream.text();
        if (!upstream.ok) {
            return res.status(upstream.status).set('Content-Type', 'application/json; charset=utf-8').send(body);
        }

        const data = JSON.parse(body);
        const rawPlaces = data.addresses || [];
        const places = rawPlaces.map((item) => {
            const roadAddress = item.roadAddress || '';
            const address = item.jibunAddress || roadAddress;
            const buildingName = getNaverAddressElement(item, 'BUILDING_NAME');
            const name = buildingName || roadAddress || address;
            const lng = Number(item.x);
            const lat = Number(item.y);
            const coords = Number.isFinite(lng) && Number.isFinite(lat) ? `${lng},${lat}` : '';
            return {
                name,
                address,
                roadAddress,
                category: buildingName ? 'BUILDING_NAME' : 'ADDRESS',
                lng,
                lat,
                coords,
            };
        }).filter((item) => item.name && item.coords);

        res.json({ places, source: 'naver_geocode', rawCount: rawPlaces.length });
    } catch (error) {
        console.error('naverLocalSearch failed:', error);
        res.status(500).json({ error: 'naver_local_search_failed' });
    }
});

function stripHtml(value) {
    return String(value || '').replace(/<[^>]*>/g, '');
}

function getNaverAddressElement(address, type) {
    const elements = Array.isArray(address.addressElements) ? address.addressElements : [];
    const found = elements.find((element) => Array.isArray(element.types) && element.types.includes(type));
    return found?.longName || found?.shortName || '';
}

// ============================================================
// POST /naverReverseGeocode - Naver NCP reverse geocoding proxy
// ============================================================
exports.naverReverseGeocode = naverNcpFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const firebaseUid = await requireFirebaseUid(req, res);
        if (!firebaseUid) return;

        const lat = Number(req.body?.lat);
        const lng = Number(req.body?.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
            return res.status(400).json({ error: 'invalid coordinates' });
        }

        const allowed = await consumeRateLimit(firebaseUid, 'naver_reverse_geocode', 30, 500);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const clientId = getRequiredConfigValue('naver', 'ncp_client_id', 'NAVER_NCP_CLIENT_ID');
        const clientSecret = getRequiredConfigValue('naver', 'ncp_client_secret', 'NAVER_NCP_CLIENT_SECRET');
        const url = new URL('https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc');
        url.searchParams.set('coords', `${lng},${lat}`);
        url.searchParams.set('orders', 'roadaddr,addr');
        url.searchParams.set('output', 'json');

        const upstream = await fetch(url, {
            method: 'GET',
            headers: {
                'x-ncp-apigw-api-key-id': clientId,
                'x-ncp-apigw-api-key': clientSecret,
                'Accept': 'application/json',
            },
        });
        const body = await upstream.text();
        res.status(upstream.status).set('Content-Type', 'application/json; charset=utf-8').send(body);
    } catch (error) {
        console.error('naverReverseGeocode failed:', error);
        res.status(500).json({ error: 'naver_reverse_geocode_failed' });
    }
});

// ============================================================
// POST /googlePlaceSearch - Google Places Text Search proxy
// ============================================================
exports.googlePlaceSearch = googleMapsFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const firebaseUid = await requireFirebaseUid(req, res);
        if (!firebaseUid) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(firebaseUid, 'google_place_search', 30, 500);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const apiKey = getRequiredConfigValue('google', 'maps_api_key', 'GOOGLE_MAPS_API_KEY');
        const language = normalizeGoogleLanguage(req.body?.language);
        const url = new URL('https://maps.googleapis.com/maps/api/place/textsearch/json');
        url.searchParams.set('query', query);
        url.searchParams.set('key', apiKey);
        url.searchParams.set('language', language);
        if (req.body?.lat != null && req.body?.lng != null) {
            const lat = Number(req.body.lat);
            const lng = Number(req.body.lng);
            if (Number.isFinite(lat) && Number.isFinite(lng)) {
                url.searchParams.set('location', `${lat},${lng}`);
                url.searchParams.set('radius', '50000');
            }
        }

        const upstream = await fetch(url);
        const data = await upstream.json();
        if (!upstream.ok || data.status === 'REQUEST_DENIED') {
            return res.status(upstream.ok ? 403 : upstream.status).json({
                error: 'google_place_search_failed',
                status: data.status,
                message: data.error_message || null,
            });
        }

        const places = (data.results || []).slice(0, 5).map((item) => {
            const location = item.geometry?.location || {};
            return {
                name: item.name || '',
                address: item.formatted_address || '',
                roadAddress: item.formatted_address || '',
                category: Array.isArray(item.types) ? item.types.slice(0, 2).join(', ') : '',
                lat: Number(location.lat) || 0,
                lng: Number(location.lng) || 0,
            };
        }).filter((item) => item.name && item.lat && item.lng);

        res.json({ status: data.status, places });
    } catch (error) {
        console.error('googlePlaceSearch failed:', error);
        res.status(500).json({ error: 'google_place_search_failed' });
    }
});

// ============================================================
// POST /googleGeocode - Google Geocoding proxy
// ============================================================
exports.googleGeocode = googleMapsFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const firebaseUid = await requireFirebaseUid(req, res);
        if (!firebaseUid) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(firebaseUid, 'google_geocode', 30, 500);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const apiKey = getRequiredConfigValue('google', 'maps_api_key', 'GOOGLE_MAPS_API_KEY');
        const language = normalizeGoogleLanguage(req.body?.language);
        const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
        url.searchParams.set('address', query);
        url.searchParams.set('key', apiKey);
        url.searchParams.set('language', language);

        const upstream = await fetch(url);
        const data = await upstream.json();
        if (!upstream.ok || data.status === 'REQUEST_DENIED') {
            return res.status(upstream.ok ? 403 : upstream.status).json({
                error: 'google_geocode_failed',
                status: data.status,
                message: data.error_message || null,
            });
        }
        res.json(data);
    } catch (error) {
        console.error('googleGeocode failed:', error);
        res.status(500).json({ error: 'google_geocode_failed' });
    }
});

// ============================================================
// POST /googleReverseGeocode - Google reverse geocoding proxy
// ============================================================
exports.googleReverseGeocode = googleMapsFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const firebaseUid = await requireFirebaseUid(req, res);
        if (!firebaseUid) return;

        const lat = Number(req.body?.lat);
        const lng = Number(req.body?.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
            return res.status(400).json({ error: 'invalid coordinates' });
        }

        const allowed = await consumeRateLimit(firebaseUid, 'google_reverse_geocode', 30, 500);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const apiKey = getRequiredConfigValue('google', 'maps_api_key', 'GOOGLE_MAPS_API_KEY');
        const language = normalizeGoogleLanguage(req.body?.language);
        const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
        url.searchParams.set('latlng', `${lat},${lng}`);
        url.searchParams.set('key', apiKey);
        url.searchParams.set('language', language);

        const upstream = await fetch(url);
        const data = await upstream.json();
        if (!upstream.ok || data.status === 'REQUEST_DENIED') {
            return res.status(upstream.ok ? 403 : upstream.status).json({
                error: 'google_reverse_geocode_failed',
                status: data.status,
                message: data.error_message || null,
            });
        }
        res.json(data);
    } catch (error) {
        console.error('googleReverseGeocode failed:', error);
        res.status(500).json({ error: 'google_reverse_geocode_failed' });
    }
});

function normalizeGoogleLanguage(language) {
    const normalized = String(language || 'ko').toLowerCase().split(/[-_]/)[0];
    return new Set(['ko', 'en', 'ja', 'zh', 'de', 'fr', 'es']).has(normalized) ? normalized : 'en';
}

// ============================================================
// POST /uploadMapUsage - trusted server-side map usage write
// ============================================================
exports.uploadMapUsage = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const firebaseUid = await requireFirebaseUid(req, res);
        if (!firebaseUid) return;

        const allowed = await consumeRateLimit(firebaseUid, 'map_usage_upload', 10, 100);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const maxMapLoads = 2000;
        const maxGeocodeCalls = 500;
        const raw = req.body || {};
        const data = {
            google: clampCount(raw.google, maxMapLoads),
            naver: clampCount(raw.naver, maxMapLoads),
            geo_google_fwd: clampCount(raw.geo_google_fwd, maxGeocodeCalls),
            geo_google_rev: clampCount(raw.geo_google_rev, maxGeocodeCalls),
            geo_google_place: clampCount(raw.geo_google_place, maxGeocodeCalls),
            geo_naver_fwd: clampCount(raw.geo_naver_fwd, maxGeocodeCalls),
            geo_naver_rev: clampCount(raw.geo_naver_rev, maxGeocodeCalls),
            geo_naver_place: clampCount(raw.geo_naver_place, maxGeocodeCalls),
        };
        const suspicious = Object.entries(data).some(([key, value]) => {
            const limit = key.startsWith('geo_') ? maxGeocodeCalls : maxMapLoads;
            return Number(raw[key]) > limit || Number(raw[key]) < 0;
        });

        const month = currentMonthUtc();
        const week = currentWeekUtc();
        const usageKeys = Object.keys(data);
        const patch = {
            ...data,
            uid: firebaseUid,
            suspicious,
            last_updated: admin.firestore.FieldValue.serverTimestamp(),
        };

        const monthAggRef = db.collection('map_usage').doc(month);
        const weekAggRef = db.collection('map_usage_weekly').doc(week);
        const monthRef = db.collection('map_usage').doc(month).collection('devices').doc(firebaseUid);
        const weekRef = db.collection('map_usage_weekly').doc(week).collection('devices').doc(firebaseUid);
        await db.runTransaction(async (tx) => {
            const [oldMonthSnap, oldWeekSnap] = await Promise.all([
                tx.get(monthRef),
                tx.get(weekRef),
            ]);
            const monthDelta = buildUsageDelta(data, oldMonthSnap.exists ? oldMonthSnap.data() : {}, usageKeys);
            const weekDelta = buildUsageDelta(data, oldWeekSnap.exists ? oldWeekSnap.data() : {}, usageKeys);

            tx.set(monthRef, patch);
            tx.set(weekRef, { ...patch, month });
            tx.set(monthAggRef, {
                totals: incrementsFromDelta(monthDelta),
                device_count: admin.firestore.FieldValue.increment(oldMonthSnap.exists ? 0 : 1),
                suspicious_count: admin.firestore.FieldValue.increment(suspicious ? 1 : 0),
                last_updated: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            tx.set(weekAggRef, {
                totals: incrementsFromDelta(weekDelta),
                device_count: admin.firestore.FieldValue.increment(oldWeekSnap.exists ? 0 : 1),
                suspicious_count: admin.firestore.FieldValue.increment(suspicious ? 1 : 0),
                month,
                last_updated: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });

        res.json({ success: true, month, week, suspicious });
    } catch (error) {
        console.error('uploadMapUsage failed:', error);
        res.status(500).json({ error: 'Failed to upload map usage' });
    }
});

// ============================================================
// POST /incrementQuota - 서버측 쿼터 증분 (위조 방지)
// body: { category: 'search'|'alarm', kind: 'used'|'reward' }
// - Firebase ID Token 검증
// - 플랜 조회 → cap 초과 시 403
// - FieldValue.increment로 원자적 증가
// ============================================================
exports.incrementQuota = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
    if (!(await requireAppCheck(req, res))) return;

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authorization header missing' });
    }

    try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;
        const allowed = await consumeRateLimit(firebaseUid, 'quota_increment', 120, 5000);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const { category, kind } = req.body || {};
        if (!['search', 'alarm'].includes(category)) {
            return res.status(400).json({ error: 'invalid category' });
        }
        if (!['used', 'reward'].includes(kind)) {
            return res.status(400).json({ error: 'invalid kind' });
        }

        // 플랜 조회 (cf_subscriptions는 anonUserId 기반이므로 변환)
        const anonUserId = generateAnonUserId(firebaseUid);
        const subSnap = await db.collection('cf_subscriptions').doc(anonUserId).get();
        const plan = subSnap.exists ? (subSnap.data().plan || 'free') : 'free';

        // 플랜별 absolute cap (Flutter SubscriptionService와 동기화)
        // 베타 기간에는 무료 플랜 검색/알람 제한을 내부 안전 상한 수준으로 완화한다.
        const CAPS = {
            search: { free: 100000, plus: 50, pro: 150, special: 100000 },
            alarm: { free: 100000, plus: 200, pro: 500, special: 100000 },
        };
        const cap = CAPS[category][plan] ?? CAPS[category].free;

        const now = new Date();
        const month = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
        const userRef = db.collection('quotas').doc(firebaseUid).collection('months').doc(month);
        const poolRef = db.collection('pools').doc(month);

        const usedField = category === 'search' ? 'search_used' : 'alarm_used';
        const rewardField = category === 'search' ? 'search_reward' : 'alarm_reward';
        const totalField = category === 'search' ? 'search_total' : 'alarm_total';

        // 트랜잭션: 현재 used 확인 후 cap 검증 → increment
        const result = await db.runTransaction(async (tx) => {
            const snap = await tx.get(userRef);
            const data = snap.exists ? snap.data() : {};
            const curUsed = (data[usedField] || 0);
            const curReward = (data[rewardField] || 0);

            if (kind === 'used' && curUsed >= cap) {
                return { ok: false, reason: 'capped', used: curUsed, cap };
            }
            if (kind === 'reward' && curReward >= cap) {
                return { ok: false, reason: 'reward_capped', reward: curReward, cap };
            }

            const patch = {
                plan_snapshot: plan,
                uid: firebaseUid,
                last_updated: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (kind === 'used') {
                patch[usedField] = admin.firestore.FieldValue.increment(1);
            } else {
                patch[rewardField] = admin.firestore.FieldValue.increment(1);
            }
            tx.set(userRef, patch, { merge: true });

            if (kind === 'used') {
                tx.set(poolRef, {
                    [totalField]: admin.firestore.FieldValue.increment(1),
                    last_updated: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
            return {
                ok: true,
                used: kind === 'used' ? curUsed + 1 : curUsed,
                reward: kind === 'reward' ? curReward + 1 : curReward,
                cap,
            };
        });

        if (!result.ok) {
            return res.status(403).json({ error: 'quota_capped', ...result });
        }
        res.json({ success: true, ...result });
    } catch (error) {
        console.error('❌ incrementQuota failed:', error);
        res.status(500).json({ error: 'Failed to increment quota' });
    }
});

async function sendOpsWebhook(alert) {
    const webhookUrl = getConfigValue('ops', 'webhook_url', 'OPS_WEBHOOK_URL');
    if (!webhookUrl) return;
    try {
        await fetch(webhookUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                text: `[${alert.severity}] ${alert.title}\n${alert.message}`,
                alert,
            }),
        });
    } catch (error) {
        console.error('ops webhook failed:', error);
    }
}

async function createOpsAlert(key, severity, title, message, metrics) {
    const dayId = new Date().toISOString().slice(0, 10);
    const ref = db.collection('ops_alerts').doc(`${dayId}_${key}`);
    const snap = await ref.get();
    if (snap.exists) {
        await ref.set({
            last_seen_at: admin.firestore.FieldValue.serverTimestamp(),
            occurrences: admin.firestore.FieldValue.increment(1),
            metrics,
        }, { merge: true });
        return null;
    }

    const alert = {
        key,
        severity,
        title,
        message,
        metrics,
        status: 'open',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        last_seen_at: admin.firestore.FieldValue.serverTimestamp(),
        occurrences: 1,
    };
    await ref.set(alert);
    await sendOpsWebhook({ ...alert, created_at: new Date().toISOString() });
    return { key, severity, title, message, metrics };
}

async function loadOpsThresholds() {
    const snap = await db.collection('admin_config').doc('ops_thresholds').get();
    const data = snap.exists ? snap.data() : {};
    return {
        googleRatioWarn: Number(data.googleRatioWarn ?? 0.8),
        naverRatioWarn: Number(data.naverRatioWarn ?? 0.8),
        suspiciousWarn: Number(data.suspiciousWarn ?? 1),
        bugErrorWarn: Number(data.bugErrorWarn ?? 10),
        bugWarnWarn: Number(data.bugWarnWarn ?? 30),
    };
}

async function runOpsHealthCheck(manual = false) {
    const thresholds = await loadOpsThresholds();
    const month = currentMonthUtc();
    const week = currentWeekUtc();
    const [monthSnap, weekSnap, poolSnap] = await Promise.all([
        db.collection('map_usage').doc(month).get(),
        db.collection('map_usage_weekly').doc(week).get(),
        db.collection('pools').doc(month).get(),
    ]);

    const monthData = monthSnap.exists ? monthSnap.data() : {};
    const weekData = weekSnap.exists ? weekSnap.data() : {};
    const poolData = poolSnap.exists ? poolSnap.data() : {};
    const totals = monthData.totals || {};
    const weeklyTotals = weekData.totals || {};
    const bugSince = admin.firestore.Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
    const bugSnap = await db.collection('bug_reports').where('createdAt', '>=', bugSince).get();
    let bugErrors24h = 0;
    let bugWarns24h = 0;
    bugSnap.forEach((doc) => {
        const data = doc.data();
        if (data.severity === 'error') bugErrors24h++;
        if (data.severity === 'warn') bugWarns24h++;
    });

    const metrics = {
        month,
        week,
        google: Number(totals.google || 0),
        naver: Number(totals.naver || 0),
        geo_google_fwd: Number(totals.geo_google_fwd || 0),
        geo_google_rev: Number(totals.geo_google_rev || 0),
        geo_google_place: Number(totals.geo_google_place || 0),
        geo_naver_fwd: Number(totals.geo_naver_fwd || 0),
        geo_naver_rev: Number(totals.geo_naver_rev || 0),
        geo_naver_place: Number(totals.geo_naver_place || 0),
        weeklyGoogle: Number(weeklyTotals.google || 0),
        weeklyNaver: Number(weeklyTotals.naver || 0),
        suspiciousCount: Number(monthData.suspicious_count || 0),
        deviceCount: Number(monthData.device_count || 0),
        searchTotal: Number(poolData.search_total || 0),
        alarmTotal: Number(poolData.alarm_total || 0),
        bugErrors24h,
        bugWarns24h,
    };
    metrics.googleUsageRatio = metrics.google / 28571;
    metrics.naverUsageRatio = metrics.naver / 6000000;

    const alerts = [];
    if (metrics.googleUsageRatio >= thresholds.googleRatioWarn) {
        alerts.push(await createOpsAlert(
            'google_usage_high',
            metrics.googleUsageRatio >= 0.95 ? 'critical' : 'warning',
            'Google Maps usage is high',
            `Google usage is ${(metrics.googleUsageRatio * 100).toFixed(1)}% of the configured free threshold.`,
            metrics,
        ));
    }
    if (metrics.naverUsageRatio >= thresholds.naverRatioWarn) {
        alerts.push(await createOpsAlert(
            'naver_usage_high',
            metrics.naverUsageRatio >= 0.95 ? 'critical' : 'warning',
            'Naver Maps usage is high',
            `Naver usage is ${(metrics.naverUsageRatio * 100).toFixed(1)}% of the configured free threshold.`,
            metrics,
        ));
    }
    if (metrics.suspiciousCount >= thresholds.suspiciousWarn) {
        alerts.push(await createOpsAlert(
            'suspicious_usage_upload',
            'critical',
            'Suspicious usage upload detected',
            `${metrics.suspiciousCount} suspicious map usage upload(s) were recorded this month.`,
            metrics,
        ));
    }
    if (metrics.bugErrors24h >= thresholds.bugErrorWarn) {
        alerts.push(await createOpsAlert(
            'bug_error_spike',
            'warning',
            'Bug report error spike',
            `${metrics.bugErrors24h} error bug reports were received in the last 24 hours.`,
            metrics,
        ));
    }
    if (metrics.bugWarns24h >= thresholds.bugWarnWarn) {
        alerts.push(await createOpsAlert(
            'bug_warn_spike',
            'warning',
            'Bug report warning spike',
            `${metrics.bugWarns24h} warning bug reports were received in the last 24 hours.`,
            metrics,
        ));
    }

    const reportId = new Date().toISOString().slice(0, 13).replace(/[-T]/g, '');
    await db.collection('ops_reports').doc(reportId).set({
        manual,
        metrics,
        thresholds,
        alert_count: alerts.filter(Boolean).length,
        checked_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { metrics, thresholds, alerts: alerts.filter(Boolean) };
}

exports.opsHealthCheck = functions.pubsub
    .schedule('every 60 minutes')
    .timeZone('Asia/Seoul')
    .onRun(() => runOpsHealthCheck(false));

exports.runOpsHealthCheckNow = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;
    const firebaseUid = await requireFirebaseUid(req, res);
    if (!firebaseUid) return;
    if (!isAdminUid(firebaseUid)) {
        return res.status(403).json({ error: 'admin only' });
    }

    try {
        const result = await runOpsHealthCheck(true);
        res.json({ success: true, ...result });
    } catch (error) {
        console.error('runOpsHealthCheckNow failed:', error);
        res.status(500).json({ error: 'ops_health_check_failed' });
    }
});
