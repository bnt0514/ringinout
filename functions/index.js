const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();

const db = admin.firestore();
const ADMIN_UIDS = new Set(['IPf2TW0c62et7bwi8B5hZGyKLlc2']);
const ACCOUNT_COLLECTION = 'accounts';
const ACCOUNT_IDENTITY_COLLECTION = 'account_identities';
const ACCOUNT_DELETION_REQUEST_COLLECTION = 'account_deletion_requests';
const INTERNAL_FIREBASE_PROVIDER = 'firebase';
const DEVICE_PROVIDER = 'device';

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
    const decodedToken = await requireDecodedFirebaseToken(req, res);
    return decodedToken?.uid || null;
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

function stripUndefined(value) {
    return Object.fromEntries(
        Object.entries(value).filter(([, entry]) => entry !== undefined)
    );
}

function asArray(value) {
    return Array.isArray(value) ? value : [];
}

function hmacIdentifier(value) {
    const secret = getRequiredConfigValue('app', 'secret', 'APP_SECRET');
    return crypto.createHmac('sha256', secret).update(String(value)).digest('hex');
}

function buildCanonicalAccountId(anonUserId) {
    return `acct_${anonUserId.substring(0, 32)}`;
}

function normalizeProviderId(providerId) {
    const normalized = String(providerId || '').trim().toLowerCase();
    return normalized || INTERNAL_FIREBASE_PROVIDER;
}

function shouldUseProviderSubject(providerId) {
    const normalized = normalizeProviderId(providerId);
    return !!normalized;
}

function buildIdentityKey(providerId, subject) {
    const normalizedProviderId = normalizeProviderId(providerId);
    const subjectText = String(subject || '').trim();
    if (!subjectText) return null;
    const subjectHash = hmacIdentifier(`${normalizedProviderId}:${subjectText}`);
    return {
        identityKey: `v1_${subjectHash}`,
        providerId: normalizedProviderId,
        subjectHash,
    };
}

function buildIdentityLinks(decodedToken, deviceDescriptor = null, options = {}) {
    const includeDeviceIdentity = options.includeDeviceIdentity !== false;
    const links = [];
    const pushLink = (providerId, subject, source) => {
        const normalizedProviderId = normalizeProviderId(providerId);
        if (!shouldUseProviderSubject(normalizedProviderId)) return;
        const identity = buildIdentityKey(normalizedProviderId, subject);
        if (!identity) return;
        links.push({
            ...identity,
            source,
        });
    };

    pushLink(INTERNAL_FIREBASE_PROVIDER, decodedToken.uid, 'firebase_uid');

    if (decodedToken.provider_id && decodedToken.provider_subject) {
        pushLink(decodedToken.provider_id, decodedToken.provider_subject, 'custom_provider_claim');
    }

    if (includeDeviceIdentity && deviceDescriptor?.device_id_hash) {
        pushLink(DEVICE_PROVIDER, deviceDescriptor.device_id_hash, 'device_id');
    }

    const firebaseIdentities = decodedToken.firebase?.identities || {};
    Object.entries(firebaseIdentities).forEach(([providerId, values]) => {
        const identityValues = Array.isArray(values) ? values : [values];
        identityValues.forEach((value) => {
            pushLink(providerId, value, 'firebase_provider_identity');
        });
    });

    const seen = new Set();
    return links.filter((link) => {
        if (seen.has(link.identityKey)) return false;
        seen.add(link.identityKey);
        return true;
    }).slice(0, 10);
}

async function getAccountIdsForIdentityLinks(identityLinks) {
    if (!identityLinks.length) return [];
    const refs = identityLinks.map((link) =>
        db.collection(ACCOUNT_IDENTITY_COLLECTION).doc(link.identityKey)
    );
    const snaps = await Promise.all(refs.map((ref) => ref.get()));
    return Array.from(new Set(
        snaps.map((snap) => getIdentityAccountId(snap.data())).filter(Boolean)
    ));
}

async function getDeviceLinkedAccountId(deviceDescriptor) {
    if (!deviceDescriptor?.device_id_hash) return null;
    const identity = buildIdentityKey(DEVICE_PROVIDER, deviceDescriptor.device_id_hash);
    if (!identity) return null;
    const snap = await db.collection(ACCOUNT_IDENTITY_COLLECTION).doc(identity.identityKey).get();
    return getIdentityAccountId(snap.data());
}

function getIdentityAccountId(identityData) {
    if (['unlinked', 'unlink_requested'].includes(identityData?.status)) return null;
    return identityData?.canonicalAccountId || identityData?.canonical_account_id || null;
}

function getProviderIdsFromLinks(identityLinks, decodedToken) {
    const providerIds = new Set(
        identityLinks
            .map((link) => link.providerId)
            .filter((providerId) => providerId
                && ![INTERNAL_FIREBASE_PROVIDER, DEVICE_PROVIDER].includes(providerId))
    );
    const signInProvider = normalizeProviderId(decodedToken.firebase?.sign_in_provider);
    if (signInProvider && !['anonymous', INTERNAL_FIREBASE_PROVIDER].includes(signInProvider)) {
        providerIds.add(signInProvider === 'password' ? 'email' : signInProvider);
    }
    return Array.from(providerIds);
}

function getBearerToken(req) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return null;
    }
    return authHeader.split('Bearer ')[1];
}

async function verifyFirebaseIdToken(idToken) {
    return admin.auth().verifyIdToken(idToken);
}

async function requireDecodedFirebaseToken(req, res) {
    const appCheckOk = await requireAppCheck(req, res);
    if (!appCheckOk) return null;

    const idToken = getBearerToken(req);
    if (!idToken) {
        res.status(401).json({ error: 'Authorization header missing' });
        return null;
    }

    try {
        return await verifyFirebaseIdToken(idToken);
    } catch (error) {
        console.error('Token verification failed:', error);
        res.status(401).json({ error: 'Invalid or expired token' });
        return null;
    }
}

async function resolveIdentityFromDecodedToken(decodedToken, deviceDescriptor = null, options = {}) {
    const firebaseUid = decodedToken.uid;
    const anonUserId = generateAnonUserId(firebaseUid);
    const preferredCanonicalAccountId = options.preferredCanonicalAccountId || null;
    const allowIdentityReassignment = options.allowIdentityReassignment === true;
    const identityLinks = buildIdentityLinks(decodedToken, deviceDescriptor, {
        includeDeviceIdentity: options.includeDeviceIdentity !== false,
    });
    const identityRefs = identityLinks.map((link) =>
        db.collection(ACCOUNT_IDENTITY_COLLECTION).doc(link.identityKey)
    );

    const resolution = await db.runTransaction(async (tx) => {
        const identitySnaps = await Promise.all(identityRefs.map((ref) => tx.get(ref)));
        const firebaseIndex = identityLinks.findIndex((link) => link.providerId === INTERNAL_FIREBASE_PROVIDER);
        const firebaseMatch = firebaseIndex >= 0
            ? getIdentityAccountId(identitySnaps[firebaseIndex].data())
            : null;
        const matchedAccountIds = identitySnaps
            .map((snap) => getIdentityAccountId(snap.data()))
            .filter(Boolean);
        const uniqueMatchedAccountIds = Array.from(new Set(matchedAccountIds));
        const canonicalAccountId = preferredCanonicalAccountId || firebaseMatch || uniqueMatchedAccountIds[0] || buildCanonicalAccountId(anonUserId);
        const conflictingAccountIds = uniqueMatchedAccountIds.filter((id) => id !== canonicalAccountId);
        const accountRef = db.collection(ACCOUNT_COLLECTION).doc(canonicalAccountId);
        const accountSnap = await tx.get(accountRef);
        const accountData = accountSnap.exists ? accountSnap.data() : {};
        const providerIds = getProviderIdsFromLinks(identityLinks, decodedToken);
        const now = admin.firestore.FieldValue.serverTimestamp();

        const accountPatch = {
            canonicalAccountId,
            canonical_account_id: canonicalAccountId,
            primary_firebase_uid: accountData.primary_firebase_uid || firebaseUid,
            last_firebase_uid: firebaseUid,
            firebase_uids: admin.firestore.FieldValue.arrayUnion(firebaseUid),
            anon_user_ids: admin.firestore.FieldValue.arrayUnion(anonUserId),
            status: accountData.status || 'active',
            identity_version: 1,
            last_sign_in_provider: normalizeProviderId(decodedToken.firebase?.sign_in_provider),
            last_login_at: now,
            updated_at: now,
            linked_provider_ids: providerIds.length
                ? admin.firestore.FieldValue.arrayUnion(...providerIds)
                : undefined,
            identity_conflicts: conflictingAccountIds.length ? conflictingAccountIds : undefined,
            created_at: accountSnap.exists ? undefined : now,
        };
        tx.set(accountRef, stripUndefined(accountPatch), { merge: true });

        identityLinks.forEach((link, index) => {
            const identitySnap = identitySnaps[index];
            const identityData = identitySnap.exists ? identitySnap.data() : {};
            const existingAccountId = getIdentityAccountId(identityData);
            if (existingAccountId && existingAccountId !== canonicalAccountId && !allowIdentityReassignment) return;

            tx.set(identityRefs[index], stripUndefined({
                canonicalAccountId,
                canonical_account_id: canonicalAccountId,
                provider_id: link.providerId,
                subject_hash: link.subjectHash,
                source: link.source,
                status: identityData.status || 'linked',
                firebase_uid_last_seen: firebaseUid,
                anon_user_id_last_seen: anonUserId,
                created_at: identitySnap.exists ? undefined : now,
                linked_at: identityData.linked_at || now,
                reassigned_from: existingAccountId && existingAccountId !== canonicalAccountId
                    ? existingAccountId
                    : undefined,
                reassigned_at: existingAccountId && existingAccountId !== canonicalAccountId
                    ? now
                    : undefined,
                last_seen_at: now,
                updated_at: now,
            }), { merge: true });
        });

        const knownFirebaseUids = Array.from(new Set([...asArray(accountData.firebase_uids), firebaseUid]));
        const knownAnonUserIds = Array.from(new Set([...asArray(accountData.anon_user_ids), anonUserId]));
        return {
            canonicalAccountId,
            providerIds,
            conflictingAccountIds,
            accountData: {
                ...accountData,
                canonicalAccountId,
                canonical_account_id: canonicalAccountId,
                firebase_uids: knownFirebaseUids,
                anon_user_ids: knownAnonUserIds,
            },
        };
    });

    return {
        decodedToken,
        firebaseUid,
        anonUserId,
        canonicalAccountId: resolution.canonicalAccountId,
        providerIds: resolution.providerIds,
        identityLinks,
        accountData: resolution.accountData,
        identityConflicts: resolution.conflictingAccountIds,
    };
}

async function resolveIdentityFromIdToken(idToken, deviceDescriptor = null, options = {}) {
    const decodedToken = await verifyFirebaseIdToken(idToken);
    return resolveIdentityFromDecodedToken(decodedToken, deviceDescriptor, options);
}

async function requireAccountContext(req, res) {
    const decodedToken = await requireDecodedFirebaseToken(req, res);
    if (!decodedToken) return null;
    return resolveIdentityFromDecodedToken(decodedToken);
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

async function consumeRateLimit(accountScopeId, bucket, minuteLimit, dayLimit) {
    const now = new Date();
    const minuteId = now.toISOString().slice(0, 16).replace(/[-:T]/g, '');
    const dayId = now.toISOString().slice(0, 10).replace(/-/g, '');
    const minuteRef = db.collection('rate_limits').doc(`${bucket}_${accountScopeId}_${minuteId}`);
    const dayRef = db.collection('rate_limits').doc(`${bucket}_${accountScopeId}_${dayId}`);

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
function valueInConfigList(data, keys, value) {
    if (!value) return false;
    return keys.some((key) => {
        const values = data[key];
        return Array.isArray(values) && values.includes(value);
    });
}

async function checkSpecialPlan(identityOrUid) {
    const firebaseUid = typeof identityOrUid === 'string' ? identityOrUid : identityOrUid?.firebaseUid;
    const canonicalAccountId = typeof identityOrUid === 'string' ? null : identityOrUid?.canonicalAccountId;
    const anonUserId = typeof identityOrUid === 'string' ? null : identityOrUid?.anonUserId;
    try {
        const adminDoc = await admin.firestore()
            .collection('admin_config')
            .doc('special_users')
            .get();

        if (!adminDoc.exists) {
            return false;
        }

        const data = adminDoc.data() || {};
        return valueInConfigList(data, ['canonicalAccountIds', 'canonical_account_ids', 'accountIds', 'account_ids'], canonicalAccountId)
            || valueInConfigList(data, ['anonUserIds', 'anon_user_ids'], anonUserId)
            || valueInConfigList(data, ['uids'], firebaseUid);
    } catch (error) {
        console.error('❌ Firestore check failed:', error);
        return false;
    }
}

// ============================================================
// POST /auth/session - 로그인 세션 생성
// ============================================================
function addAccountFields(identity, patch) {
    return {
        ...patch,
        canonicalAccountId: identity.canonicalAccountId,
        canonical_account_id: identity.canonicalAccountId,
        anonUserId: identity.anonUserId,
        anon_user_id: identity.anonUserId,
        firebaseUid: identity.firebaseUid,
        firebase_uid: identity.firebaseUid,
    };
}

function buildDefaultSubscription(identity, plan, now) {
    return addAccountFields(identity, {
        store: 'manual',
        plan,
        status: 'active',
        expires_at: null,
        last_verified_at: now,
    });
}

function normalizeSubscriptionForAccount(identity, subscription) {
    if (!subscription) return null;
    return addAccountFields(identity, {
        ...subscription,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
}

async function ensureSessionDocuments(identity) {
    const now = Date.now();
    const isSpecialUser = await checkSpecialPlan(identity);
    const defaultPlan = isSpecialUser ? 'special' : 'free';
    const canonicalUserRef = db.collection('cf_users').doc(identity.canonicalAccountId);
    const legacyUserRef = db.collection('cf_users').doc(identity.anonUserId);
    const canonicalSubRef = db.collection('cf_subscriptions').doc(identity.canonicalAccountId);
    const legacySubRef = db.collection('cf_subscriptions').doc(identity.anonUserId);
    const hasSeparateLegacyDocs = identity.canonicalAccountId !== identity.anonUserId;

    return db.runTransaction(async (tx) => {
        const refsToRead = [canonicalUserRef, canonicalSubRef];
        if (hasSeparateLegacyDocs) refsToRead.push(legacyUserRef, legacySubRef);
        const snaps = await Promise.all(refsToRead.map((ref) => tx.get(ref)));
        const canonicalUserSnap = snaps[0];
        const canonicalSubSnap = snaps[1];
        const legacyUserSnap = hasSeparateLegacyDocs ? snaps[2] : canonicalUserSnap;
        const legacySubSnap = hasSeparateLegacyDocs ? snaps[3] : canonicalSubSnap;

        const userPatch = addAccountFields(identity, {
            last_login_at: now,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
            created_at: canonicalUserSnap.exists
                ? undefined
                : (legacyUserSnap.exists ? legacyUserSnap.data().created_at : now),
        });
        tx.set(canonicalUserRef, stripUndefined(userPatch), { merge: true });
        if (hasSeparateLegacyDocs) {
            tx.set(legacyUserRef, stripUndefined({
                ...userPatch,
                legacy_alias: true,
            }), { merge: true });
        }

        const existingSub = canonicalSubSnap.exists
            ? canonicalSubSnap.data()
            : (legacySubSnap.exists ? legacySubSnap.data() : null);
        let subscription = existingSub
            ? normalizeSubscriptionForAccount(identity, existingSub)
            : buildDefaultSubscription(identity, defaultPlan, now);

        if (isSpecialUser) {
            subscription = {
                ...subscription,
                store: 'manual',
                plan: 'special',
                status: 'active',
                expires_at: null,
                last_verified_at: now,
            };
        }

        if (!canonicalSubSnap.exists || isSpecialUser) {
            tx.set(canonicalSubRef, subscription, { merge: true });
        } else {
            tx.set(canonicalSubRef, addAccountFields(identity, {
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
            }), { merge: true });
        }
        if (hasSeparateLegacyDocs) {
            tx.set(legacySubRef, {
                ...subscription,
                legacy_alias: true,
            }, { merge: true });
        }

        return {
            createdUser: !canonicalUserSnap.exists,
            subscription,
            isSpecialUser,
        };
    });
}

async function getEffectiveSubscription(identity) {
    const canonicalSubRef = db.collection('cf_subscriptions').doc(identity.canonicalAccountId);
    const legacySubRef = db.collection('cf_subscriptions').doc(identity.anonUserId);
    const hasSeparateLegacyDocs = identity.canonicalAccountId !== identity.anonUserId;
    const snaps = hasSeparateLegacyDocs
        ? await Promise.all([canonicalSubRef.get(), legacySubRef.get()])
        : [await canonicalSubRef.get(), null];
    const canonicalSnap = snaps[0];
    const legacySnap = snaps[1];
    const now = Date.now();
    let subscription = canonicalSnap.exists
        ? canonicalSnap.data()
        : (legacySnap?.exists ? legacySnap.data() : buildDefaultSubscription(identity, 'free', now));

    if (await checkSpecialPlan(identity)) {
        subscription = {
            ...subscription,
            store: subscription.store || 'manual',
            plan: 'special',
            status: 'active',
            expires_at: null,
        };
    }

    return addAccountFields(identity, subscription);
}

function isPurchaseTokenBoundToDifferentAccount(tokenData, identity) {
    const tokenAccountId = tokenData.canonicalAccountId || tokenData.canonical_account_id;
    if (tokenAccountId && tokenAccountId !== identity.canonicalAccountId) return true;

    const knownFirebaseUids = new Set([...asArray(identity.accountData?.firebase_uids), identity.firebaseUid]);
    const knownAnonUserIds = new Set([...asArray(identity.accountData?.anon_user_ids), identity.anonUserId]);

    if (!tokenAccountId && tokenData.firebaseUid && !knownFirebaseUids.has(tokenData.firebaseUid)) {
        return true;
    }
    if (!tokenAccountId && tokenData.anonUserId && !knownAnonUserIds.has(tokenData.anonUserId)) {
        return true;
    }
    return false;
}

function readDeviceDescriptor(req) {
    const raw = req.body || {};
    const deviceId = String(raw.deviceId || raw.device_id || req.header('X-Device-Id') || '').trim();
    if (!deviceId) return null;
    const deviceIdHash = hmacIdentifier(`device:${deviceId}`);
    return {
        device_id_hash: deviceIdHash,
        device_id_hash_prefix: deviceIdHash.substring(0, 12),
        platform: String(raw.platform || raw.devicePlatform || req.header('X-Device-Platform') || '').trim() || null,
        app_version: String(raw.appVersion || raw.app_version || req.header('X-App-Version') || '').trim() || null,
    };
}

function activeDeviceResponse(activeDevice, requestedDevice) {
    if (!activeDevice?.device_id_hash) {
        return {
            status: requestedDevice ? 'unclaimed' : 'not_provided',
            transferRequired: false,
            transferred: false,
            matches: requestedDevice ? false : null,
        };
    }
    const matches = requestedDevice
        ? activeDevice.device_id_hash === requestedDevice.device_id_hash
        : null;
    return {
        status: matches === false ? 'claimed_by_other_device' : 'active',
        transferRequired: matches === false,
        transferred: false,
        matches,
        deviceIdHashPrefix: activeDevice.device_id_hash_prefix || activeDevice.device_id_hash.substring(0, 12),
        platform: activeDevice.platform || null,
        appVersion: activeDevice.app_version || null,
    };
}

async function claimActiveDevice(identity, req, forceDeviceTransfer = false) {
    const requestedDevice = readDeviceDescriptor(req);
    if (!requestedDevice) {
        return {
            status: 'not_provided',
            transferRequired: false,
            transferred: false,
            matches: null,
        };
    }

    const accountRef = db.collection(ACCOUNT_COLLECTION).doc(identity.canonicalAccountId);
    return db.runTransaction(async (tx) => {
        const accountSnap = await tx.get(accountRef);
        const accountData = accountSnap.exists ? accountSnap.data() : {};
        const currentDevice = accountData.active_device || {};
        const previousHash = currentDevice.device_id_hash || null;
        const transferred = !!previousHash && previousHash !== requestedDevice.device_id_hash;
        if (transferred && !forceDeviceTransfer) {
            return activeDeviceResponse(currentDevice, requestedDevice);
        }

        const now = admin.firestore.FieldValue.serverTimestamp();
        const activeDevice = {
            ...requestedDevice,
            firebase_uid_last_seen: identity.firebaseUid,
            anon_user_id_last_seen: identity.anonUserId,
            claimed_at: transferred || !previousHash ? now : (currentDevice.claimed_at || now),
            last_seen_at: now,
        };

        tx.set(accountRef, {
            active_device: activeDevice,
            active_device_updated_at: now,
            active_device_transfer_count: admin.firestore.FieldValue.increment(transferred ? 1 : 0),
            updated_at: now,
        }, { merge: true });

        return {
            status: transferred ? 'transferred' : 'active',
            transferRequired: false,
            transferred,
            matches: true,
            deviceIdHashPrefix: requestedDevice.device_id_hash_prefix,
            previousDeviceIdHashPrefix: transferred ? previousHash.substring(0, 12) : null,
            previousPlatform: transferred ? currentDevice.platform || null : null,
            previousAppVersion: transferred ? currentDevice.app_version || null : null,
            platform: requestedDevice.platform,
            appVersion: requestedDevice.app_version,
        };
    });
}

exports.createSession = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    if (!(await requireAppCheck(req, res))) return;

    const { idToken, forceDeviceTransfer, allowDeviceAccountLink } = req.body || {};

    if (!idToken) {
        return res.status(400).json({ error: 'idToken is required' });
    }

    try {
        const requestedDevice = readDeviceDescriptor(req);
        const decodedToken = await verifyFirebaseIdToken(idToken);
        const deviceAccountId = await getDeviceLinkedAccountId(requestedDevice);
        const nonDeviceLinks = buildIdentityLinks(decodedToken, null, {
            includeDeviceIdentity: false,
        });
        const providerIds = getProviderIdsFromLinks(nonDeviceLinks, decodedToken);
        if (!providerIds.length) {
            return res.status(401).json({
                error: 'sign_in_provider_required',
                message: 'A linked sign-in provider is required.',
            });
        }
        const nonDeviceAccountIds = await getAccountIdsForIdentityLinks(nonDeviceLinks);
        const alreadyLinkedToDeviceAccount =
            deviceAccountId && nonDeviceAccountIds.includes(deviceAccountId);
        const providerLinkedToDifferentAccount =
            deviceAccountId &&
            nonDeviceAccountIds.length > 0 &&
            !alreadyLinkedToDeviceAccount;

        if (deviceAccountId &&
            !alreadyLinkedToDeviceAccount &&
            allowDeviceAccountLink !== true &&
            allowDeviceAccountLink !== 'true') {
            return res.status(409).json({
                error: 'device_account_link_required',
                message: 'This device already has an app account. Confirm before linking this sign-in method.',
                canonicalAccountId: deviceAccountId,
                matchedAccountIds: nonDeviceAccountIds,
                providerLinkedToDifferentAccount,
            });
        }

        const confirmedDeviceAccountLink =
            allowDeviceAccountLink === true || allowDeviceAccountLink === 'true';
        const identity = await resolveIdentityFromDecodedToken(decodedToken, requestedDevice, {
            includeDeviceIdentity: confirmedDeviceAccountLink ||
                alreadyLinkedToDeviceAccount ||
                !deviceAccountId,
            preferredCanonicalAccountId: confirmedDeviceAccountLink && deviceAccountId
                ? deviceAccountId
                : null,
            allowIdentityReassignment: confirmedDeviceAccountLink && !!deviceAccountId,
        });
        const session = await ensureSessionDocuments(identity);
        const activeDevice = await claimActiveDevice(
            identity,
            req,
            forceDeviceTransfer === true || forceDeviceTransfer === 'true',
        );

        if (session.createdUser) {
            console.log(`Created canonical user: ${identity.canonicalAccountId} (${session.subscription.plan})`);
        }

        return res.json({
            success: true,
            message: 'Session created',
            canonicalAccountId: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
            activeDevice,
            deviceTransferRequired: activeDevice.transferRequired === true,
            identityConflicts: identity.identityConflicts || [],
        });
    } catch (error) {
        console.error('❌ Token verification failed:', error);
        res.status(401).json({ error: 'Invalid or expired token' });
    }
});

exports.signInWithKakao = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);

    if (req.method === 'OPTIONS') {
        return res.status(204).send('');
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    if (!(await requireAppCheck(req, res))) return;

    const accessToken = String(req.body?.accessToken || '').trim();
    if (!accessToken) {
        return res.status(400).json({ error: 'accessToken is required' });
    }

    try {
        const upstream = await fetch('https://kapi.kakao.com/v2/user/me', {
            method: 'GET',
            headers: {
                Authorization: `Bearer ${accessToken}`,
                Accept: 'application/json',
            },
        });

        const kakaoUser = await upstream.json().catch(() => ({}));
        if (!upstream.ok || !kakaoUser.id) {
            console.warn('Kakao user verification failed:', upstream.status, kakaoUser?.code || kakaoUser?.msg || kakaoUser?.error);
            return res.status(401).json({ error: 'Invalid Kakao access token' });
        }

        const kakaoId = String(kakaoUser.id);
        const account = kakaoUser.kakao_account || {};
        const profile = account.profile || {};
        const email = typeof account.email === 'string' ? account.email : undefined;
        const displayName = typeof profile.nickname === 'string' ? profile.nickname : undefined;
        const uid = `kakao:${kakaoId}`;

        const customToken = await admin.auth().createCustomToken(uid, stripUndefined({
            provider_id: 'kakao',
            provider_subject: kakaoId,
            provider_email: email,
            provider_display_name: displayName,
        }));

        return res.json(stripUndefined({
            success: true,
            customToken,
            providerId: 'kakao',
            providerSubject: kakaoId,
            email,
            displayName,
        }));
    } catch (error) {
        console.error('Kakao sign-in failed:', error);
        return res.status(500).json({ error: 'Kakao sign-in failed' });
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

    try {
        const identity = await requireAccountContext(req, res);
        if (!identity) return;
        const subscription = await getEffectiveSubscription(identity);

        res.json({
            plan: subscription.plan,
            status: subscription.status,
            expires_at: subscription.expires_at,
            store: subscription.store,
            canonicalAccountId: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
        });
    } catch (error) {
        console.error('❌ Token verification failed:', error);
        res.status(500).json({ error: 'billing_status_failed' });
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;
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

        if (await checkSpecialPlan(identity)) {
            plan = 'special';
            status = 'active';
            expiresAt = null;
        }

        const subRef = db.collection('cf_subscriptions').doc(identity.canonicalAccountId);
        const legacySubRef = db.collection('cf_subscriptions').doc(identity.anonUserId);
        const hasSeparateLegacySub = identity.canonicalAccountId !== identity.anonUserId;
        const tokenRef = db.collection('purchase_tokens').doc(tokenHash);
        await db.runTransaction(async (tx) => {
            const tokenSnap = await tx.get(tokenRef);
            if (tokenSnap.exists) {
                const tokenData = tokenSnap.data() || {};
                if (isPurchaseTokenBoundToDifferentAccount(tokenData, identity)) {
                    throw new Error('purchase_token_already_bound');
                }
            }

            tx.set(tokenRef, {
                firebaseUid: identity.firebaseUid,
                anonUserId: identity.anonUserId,
                canonicalAccountId: identity.canonicalAccountId,
                canonical_account_id: identity.canonicalAccountId,
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

            const subscriptionPatch = addAccountFields(identity, {
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
            });
            tx.set(subRef, subscriptionPatch, { merge: true });
            if (hasSeparateLegacySub) {
                tx.set(legacySubRef, {
                    ...subscriptionPatch,
                    legacy_alias: true,
                }, { merge: true });
            }
        });

        return res.json({
            success: true,
            verified,
            plan,
            status,
            expires_at: expiresAt,
            productId,
            purchaseType,
            canonicalAccountId: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
        });
    } catch (error) {
        console.error('Purchase verification failed:', error);
        const code = error.message === 'purchase_token_already_bound' ? 409 : 500;
        res.status(code).json({ error: error.message || 'purchase_verification_failed' });
    }
});

async function loadLinkedProviders(identity) {
    const snap = await db.collection(ACCOUNT_IDENTITY_COLLECTION)
        .where('canonical_account_id', '==', identity.canonicalAccountId)
        .get();
    const providers = new Map();
    snap.forEach((doc) => {
        const data = doc.data() || {};
        const providerId = normalizeProviderId(data.provider_id);
        if (!providerId || [INTERNAL_FIREBASE_PROVIDER, DEVICE_PROVIDER].includes(providerId)) return;
        const existing = providers.get(providerId) || {
            providerId,
            status: data.status || 'linked',
            linked: data.status !== 'unlink_requested' && data.status !== 'unlinked',
            linkCount: 0,
        };
        existing.linkCount += 1;
        if (data.status === 'unlink_requested' || data.status === 'unlinked') {
            existing.status = data.status;
            existing.linked = false;
        }
        providers.set(providerId, existing);
    });

    (identity.providerIds || []).forEach((providerId) => {
        if (!providers.has(providerId)) {
            providers.set(providerId, {
                providerId,
                status: 'linked',
                linked: true,
                linkCount: 0,
            });
        }
    });

    return Array.from(providers.values()).sort((a, b) => a.providerId.localeCompare(b.providerId));
}

exports.getAccountLinkedProviders = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

    try {
        const identity = await requireAccountContext(req, res);
        if (!identity) return;
        const providers = await loadLinkedProviders(identity);
        res.json({
            success: true,
            canonicalAccountId: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
            providers,
        });
    } catch (error) {
        console.error('getAccountLinkedProviders failed:', error);
        res.status(500).json({ error: 'linked_providers_failed' });
    }
});

exports.unlinkProvider = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const providerId = normalizeProviderId(req.body?.providerId || req.body?.provider_id);
        if (!providerId || [INTERNAL_FIREBASE_PROVIDER, DEVICE_PROVIDER].includes(providerId)) {
            return res.status(400).json({ error: 'invalid providerId' });
        }

        const snap = await db.collection(ACCOUNT_IDENTITY_COLLECTION)
            .where('canonical_account_id', '==', identity.canonicalAccountId)
            .get();
        const batch = db.batch();
        const now = admin.firestore.FieldValue.serverTimestamp();
        let affectedLinks = 0;
        snap.forEach((doc) => {
            if (normalizeProviderId(doc.data()?.provider_id) !== providerId) return;
            affectedLinks += 1;
            batch.set(doc.ref, {
                status: 'unlink_requested',
                unlink_requested_at: now,
                updated_at: now,
            }, { merge: true });
        });
        batch.set(db.collection(ACCOUNT_COLLECTION).doc(identity.canonicalAccountId), {
            pending_unlink_provider_ids: admin.firestore.FieldValue.arrayUnion(providerId),
            updated_at: now,
        }, { merge: true });
        await batch.commit();

        res.json({
            success: true,
            status: 'unlink_requested',
            providerId,
            affectedLinks,
            canonicalAccountId: identity.canonicalAccountId,
        });
    } catch (error) {
        console.error('unlinkProvider failed:', error);
        res.status(500).json({ error: 'unlink_provider_failed' });
    }
});

exports.deleteAccount = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (!requirePost(req, res)) return;

    try {
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const now = admin.firestore.FieldValue.serverTimestamp();
        const accountRef = db.collection(ACCOUNT_COLLECTION).doc(identity.canonicalAccountId);
        await Promise.all([
            accountRef.set({
                status: 'delete_requested',
                delete_requested_at: now,
                delete_requested_by_firebase_uid: identity.firebaseUid,
                updated_at: now,
            }, { merge: true }),
            db.collection(ACCOUNT_DELETION_REQUEST_COLLECTION).doc(identity.canonicalAccountId).set({
                canonicalAccountId: identity.canonicalAccountId,
                canonical_account_id: identity.canonicalAccountId,
                anonUserId: identity.anonUserId,
                anon_user_id: identity.anonUserId,
                firebaseUid: identity.firebaseUid,
                firebase_uid: identity.firebaseUid,
                status: 'pending',
                requested_at: now,
            }, { merge: true }),
        ]);

        res.json({
            success: true,
            status: 'delete_requested',
            canonicalAccountId: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
            requiresClientFirebaseDelete: true,
        });
    } catch (error) {
        console.error('deleteAccount failed:', error);
        res.status(500).json({ error: 'delete_account_failed' });
    }
});

exports.getActiveDeviceStatus = coreFunctions.https.onRequest(async (req, res) => {
    setCors(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (!['GET', 'POST'].includes(req.method)) {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    try {
        const identity = await requireAccountContext(req, res);
        if (!identity) return;
        const accountSnap = await db.collection(ACCOUNT_COLLECTION).doc(identity.canonicalAccountId).get();
        const accountData = accountSnap.exists ? accountSnap.data() : {};
        const requestedDevice = readDeviceDescriptor(req);
        res.json({
            success: true,
            canonicalAccountId: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
            activeDevice: activeDeviceResponse(accountData.active_device, requestedDevice),
        });
    } catch (error) {
        console.error('getActiveDeviceStatus failed:', error);
        res.status(500).json({ error: 'active_device_status_failed' });
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'naver_geocode', 30, 500);
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'naver_geocode_place', 30, 500);
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const lat = Number(req.body?.lat);
        const lng = Number(req.body?.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
            return res.status(400).json({ error: 'invalid coordinates' });
        }

        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'naver_reverse_geocode', 30, 500);
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'google_place_search', 30, 500);
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const query = String(req.body?.query || '').trim();
        if (query.length < 2 || query.length > 120) {
            return res.status(400).json({ error: 'invalid query' });
        }

        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'google_geocode', 30, 500);
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const lat = Number(req.body?.lat);
        const lng = Number(req.body?.lng);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
            return res.status(400).json({ error: 'invalid coordinates' });
        }

        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'google_reverse_geocode', 30, 500);
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
        const identity = await requireAccountContext(req, res);
        if (!identity) return;

        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'map_usage_upload', 10, 100);
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
            uid: identity.canonicalAccountId,
            legacy_uid: identity.firebaseUid,
            canonicalAccountId: identity.canonicalAccountId,
            canonical_account_id: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
            anon_user_id: identity.anonUserId,
            suspicious,
            last_updated: admin.firestore.FieldValue.serverTimestamp(),
        };

        const monthAggRef = db.collection('map_usage').doc(month);
        const weekAggRef = db.collection('map_usage_weekly').doc(week);
        const monthRef = db.collection('map_usage').doc(month).collection('devices').doc(identity.canonicalAccountId);
        const weekRef = db.collection('map_usage_weekly').doc(week).collection('devices').doc(identity.canonicalAccountId);
        const legacyMonthRef = db.collection('map_usage').doc(month).collection('devices').doc(identity.firebaseUid);
        const legacyWeekRef = db.collection('map_usage_weekly').doc(week).collection('devices').doc(identity.firebaseUid);
        const hasSeparateLegacyDocs = identity.canonicalAccountId !== identity.firebaseUid;
        await db.runTransaction(async (tx) => {
            const reads = [
                tx.get(monthRef),
                tx.get(weekRef),
            ];
            if (hasSeparateLegacyDocs) {
                reads.push(tx.get(legacyMonthRef), tx.get(legacyWeekRef));
            }
            const snaps = await Promise.all(reads);
            const oldMonthSnap = snaps[0];
            const oldWeekSnap = snaps[1];
            const legacyMonthSnap = hasSeparateLegacyDocs ? snaps[2] : oldMonthSnap;
            const legacyWeekSnap = hasSeparateLegacyDocs ? snaps[3] : oldWeekSnap;
            const oldMonthData = oldMonthSnap.exists
                ? oldMonthSnap.data()
                : (legacyMonthSnap.exists ? legacyMonthSnap.data() : {});
            const oldWeekData = oldWeekSnap.exists
                ? oldWeekSnap.data()
                : (legacyWeekSnap.exists ? legacyWeekSnap.data() : {});
            const monthDelta = buildUsageDelta(data, oldMonthData, usageKeys);
            const weekDelta = buildUsageDelta(data, oldWeekData, usageKeys);

            tx.set(monthRef, patch);
            tx.set(weekRef, { ...patch, month });
            if (hasSeparateLegacyDocs && legacyMonthSnap.exists) {
                tx.set(legacyMonthRef, {
                    ...patch,
                    uid: identity.firebaseUid,
                    canonical_alias: true,
                });
            }
            if (hasSeparateLegacyDocs && legacyWeekSnap.exists) {
                tx.set(legacyWeekRef, {
                    ...patch,
                    uid: identity.firebaseUid,
                    month,
                    canonical_alias: true,
                });
            }
            tx.set(monthAggRef, {
                totals: incrementsFromDelta(monthDelta),
                device_count: admin.firestore.FieldValue.increment(oldMonthSnap.exists || legacyMonthSnap.exists ? 0 : 1),
                suspicious_count: admin.firestore.FieldValue.increment(suspicious ? 1 : 0),
                last_updated: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            tx.set(weekAggRef, {
                totals: incrementsFromDelta(weekDelta),
                device_count: admin.firestore.FieldValue.increment(oldWeekSnap.exists || legacyWeekSnap.exists ? 0 : 1),
                suspicious_count: admin.firestore.FieldValue.increment(suspicious ? 1 : 0),
                month,
                last_updated: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        });

        res.json({
            success: true,
            month,
            week,
            suspicious,
            canonicalAccountId: identity.canonicalAccountId,
            anonUserId: identity.anonUserId,
        });
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

    try {
        const identity = await requireAccountContext(req, res);
        if (!identity) return;
        const allowed = await consumeRateLimit(identity.canonicalAccountId, 'quota_increment', 120, 5000);
        if (!allowed) return res.status(429).json({ error: 'rate_limited' });

        const { category, kind } = req.body || {};
        if (!['search', 'alarm'].includes(category)) {
            return res.status(400).json({ error: 'invalid category' });
        }
        if (!['used', 'reward'].includes(kind)) {
            return res.status(400).json({ error: 'invalid kind' });
        }

        const subscription = await getEffectiveSubscription(identity);
        const plan = subscription.plan || 'free';

        // 플랜별 absolute cap (Flutter SubscriptionService와 동기화)
        // 베타 기간에는 무료 플랜 검색/알람 제한을 내부 안전 상한 수준으로 완화한다.
        const CAPS = {
            search: { free: 100000, plus: 50, pro: 150, special: 100000 },
            alarm: { free: 100000, plus: 200, pro: 500, special: 100000 },
        };
        const cap = CAPS[category][plan] ?? CAPS[category].free;

        const now = new Date();
        const month = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
        const userRef = db.collection('quotas').doc(identity.canonicalAccountId).collection('months').doc(month);
        const legacyUserRef = db.collection('quotas').doc(identity.firebaseUid).collection('months').doc(month);
        const hasSeparateLegacyDocs = identity.canonicalAccountId !== identity.firebaseUid;
        const poolRef = db.collection('pools').doc(month);

        const usedField = category === 'search' ? 'search_used' : 'alarm_used';
        const rewardField = category === 'search' ? 'search_reward' : 'alarm_reward';
        const totalField = category === 'search' ? 'search_total' : 'alarm_total';

        const quotaFields = ['search_used', 'search_reward', 'alarm_used', 'alarm_reward'];

        // 트랜잭션: 현재 used 확인 후 cap 검증 → increment
        const result = await db.runTransaction(async (tx) => {
            const reads = [tx.get(userRef)];
            if (hasSeparateLegacyDocs) reads.push(tx.get(legacyUserRef));
            const snaps = await Promise.all(reads);
            const snap = snaps[0];
            const legacySnap = hasSeparateLegacyDocs ? snaps[1] : snap;
            const data = snap.exists
                ? snap.data()
                : (legacySnap.exists ? legacySnap.data() : {});
            const curUsed = Number(data[usedField] || 0);
            const curReward = Number(data[rewardField] || 0);

            if (kind === 'used' && curUsed >= cap) {
                return { ok: false, reason: 'capped', used: curUsed, cap, canonicalAccountId: identity.canonicalAccountId, anonUserId: identity.anonUserId };
            }
            if (kind === 'reward' && curReward >= cap) {
                return { ok: false, reason: 'reward_capped', reward: curReward, cap, canonicalAccountId: identity.canonicalAccountId, anonUserId: identity.anonUserId };
            }

            const nextCounts = {};
            quotaFields.forEach((field) => {
                nextCounts[field] = Number(data[field] || 0);
            });
            if (kind === 'used') {
                nextCounts[usedField] = curUsed + 1;
            } else {
                nextCounts[rewardField] = curReward + 1;
            }

            const patch = {
                ...nextCounts,
                plan_snapshot: plan,
                uid: identity.canonicalAccountId,
                legacy_uid: identity.firebaseUid,
                canonicalAccountId: identity.canonicalAccountId,
                canonical_account_id: identity.canonicalAccountId,
                anonUserId: identity.anonUserId,
                anon_user_id: identity.anonUserId,
                last_updated: admin.firestore.FieldValue.serverTimestamp(),
            };
            tx.set(userRef, patch, { merge: true });
            if (hasSeparateLegacyDocs) {
                tx.set(legacyUserRef, {
                    ...patch,
                    uid: identity.firebaseUid,
                    canonical_alias: true,
                }, { merge: true });
            }

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
                canonicalAccountId: identity.canonicalAccountId,
                anonUserId: identity.anonUserId,
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
