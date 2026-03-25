/**
 * 메모리 기반 데이터베이스 (개발용)
 * 
 * 스키마:
 * - users: Map<anon_user_id, {created_at, last_login_at}>
 * - subscriptions: Map<anon_user_id, {store, plan, status, expires_at, last_verified_at}>
 */

// 메모리 저장소
const users = new Map();
const subscriptions = new Map();

// DB 초기화
function initialize() {
    console.log('🗄️  메모리 DB 초기화 중...');
    users.clear();
    subscriptions.clear();
    console.log('✅ 메모리 DB 초기화 완료');
}

// 사용자 생성 또는 업데이트
function upsertUser(anonUserId) {
    const now = Date.now();

    if (users.has(anonUserId)) {
        const user = users.get(anonUserId);
        user.last_login_at = now;
    } else {
        users.set(anonUserId, {
            created_at: now,
            last_login_at: now
        });

        // 신규 사용자는 free 플랜 자동 부여
        subscriptions.set(anonUserId, {
            store: 'manual',
            plan: 'free',
            status: 'active',
            expires_at: null,
            last_verified_at: now
        });

        console.log(`👤 신규 사용자 생성: ${anonUserId.substring(0, 8)}...`);
    }
}

// 구독 생성 또는 업데이트
function upsertSubscription({ anonUserId, store, plan, status, expiresAt }) {
    const now = Date.now();

    subscriptions.set(anonUserId, {
        store,
        plan,
        status,
        expires_at: expiresAt || null,
        last_verified_at: now
    });

    console.log(`💳 구독 업데이트: ${anonUserId.substring(0, 8)}... → ${plan} (${status})`);
}

// 구독 조회
function getSubscription(anonUserId) {
    return subscriptions.get(anonUserId) || null;
}

// 구독 삭제
function deleteSubscription(anonUserId) {
    subscriptions.delete(anonUserId);
}

// 통계 조회 (디버깅용)
function getStats() {
    return {
        totalUsers: users.size,
        totalSubscriptions: subscriptions.size,
        plans: Array.from(subscriptions.values()).reduce((acc, sub) => {
            acc[sub.plan] = (acc[sub.plan] || 0) + 1;
            return acc;
        }, {})
    };
}

module.exports = {
    initialize,
    upsertUser,
    upsertSubscription,
    getSubscription,
    deleteSubscription,
    getStats
};
