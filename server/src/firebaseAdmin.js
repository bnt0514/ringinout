const path = require('path');
const admin = require('firebase-admin');

function initializeFirebaseAdmin() {
    if (admin.apps.length > 0) return admin;

    try {
        const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
            ? path.resolve(process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
            : path.resolve(process.cwd(), 'firebase-service-account.json');
        const serviceAccount = require(serviceAccountPath);

        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });
        console.log('Firebase Admin SDK initialized');
    } catch (error) {
        console.warn('Firebase service account file not found - auth features are limited.');
        console.warn('Running in development mode. ID token verification may fail.');
    }

    return admin;
}

module.exports = {
    admin,
    initializeFirebaseAdmin,
};
