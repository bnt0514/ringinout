require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');

const { admin, initializeFirebaseAdmin } = require('./firebaseAdmin');
const authRoutes = require('./routes/auth');
const billingRoutes = require('./routes/billing');
const db = require('./db/database');

initializeFirebaseAdmin();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
}));
app.use(express.json());

app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.path}`);
    next();
});

app.use('/auth', authRoutes);
app.use('/billing', billingRoutes);

app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use((req, res) => {
    res.status(404).json({ error: 'Not Found' });
});

app.use((err, req, res, next) => {
    console.error('Error:', err.message);
    res.status(err.status || 500).json({
        error: err.message || 'Internal Server Error',
    });
});

db.initialize();

app.listen(PORT, () => {
    console.log(`RingInOut server started: http://localhost:${PORT}`);
    console.log('Use only for subscription verification.');
    console.log('Do not store sensitive profile identifiers.');
});

module.exports = { app, admin };
