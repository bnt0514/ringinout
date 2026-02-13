/**
 * HMAC 기반 익명 사용자 ID 생성
 * 
 * anon_user_id = HMAC_SHA256(SERVER_SECRET, firebase_uid)
 * 
 * 장점:
 * - uid를 알아도 anon_user_id를 역산할 수 없음
 * - 같은 uid는 항상 같은 anon_user_id 생성 (일관성)
 * - 서버 비밀키 없이는 연결 불가능
 */

const crypto = require('crypto');

function generateAnonUserId(firebaseUid) {
    const secret = process.env.SERVER_SECRET;

    if (!secret || secret === 'CHANGE_ME_TO_RANDOM_SECRET_32CHARS_OR_MORE') {
        throw new Error('⚠️ SERVER_SECRET이 설정되지 않았습니다. .env 파일을 확인하세요.');
    }

    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(firebaseUid);
    return hmac.digest('hex');
}

module.exports = { generateAnonUserId };
