/**
 * Firebase ID Token 인증 미들웨어
 * 
 * 요청 헤더에서 Authorization: Bearer <idToken>을 읽어
 * Firebase Admin SDK로 검증 후 req.anonUserId를 설정
 */

const { admin } = require('../index');
const { generateAnonUserId } = require('../utils/crypto');

async function authenticateToken(req, res, next) {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: 'Authorization header missing or invalid' });
    }

    const idToken = authHeader.split('Bearer ')[1];

    try {
        // Firebase ID Token 검증
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const firebaseUid = decodedToken.uid;

        // ⚠️ uid를 로그에 찍지 않음
        // console.log('✅ 인증 성공:', firebaseUid); // 금지!

        // HMAC 기반 익명 ID 생성
        const anonUserId = generateAnonUserId(firebaseUid);

        // req 객체에 anonUserId만 저장 (uid는 저장하지 않음)
        req.anonUserId = anonUserId;

        next();
    } catch (error) {
        console.error('❌ Token verification failed:', error.message);
        return res.status(401).json({ error: 'Invalid or expired token' });
    }
}

module.exports = { authenticateToken };
