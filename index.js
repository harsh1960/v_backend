const express = require('express');
const admin = require('firebase-admin');
const crypto = require('crypto');
const fs = require('fs');

const app = express();

// 1. SETUP FIREBASE
// We load the credentials from the secret file you uploaded to Render
const serviceAccountPath = '/etc/secrets/firebase_credentials.json';

if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
} else {
    console.error("CRITICAL: Firebase Secret file not found at " + serviceAccountPath);
}

const db = admin.firestore();

// 2. MIDDLEWARE TO GET RAW BODY (Crucial for Razorpay Security)
// We need the raw text to verify the signature
app.use(express.json({
    verify: (req, res, buf) => {
        req.rawBody = buf;
    }
}));

// 3. THE WEBHOOK ROUTE
app.post('/', async (req, res) => {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    const shasum = crypto.createHmac('sha256', secret);
    shasum.update(req.rawBody);
    const digest = shasum.digest('hex');

    // A. Verify Signature
    if (digest !== req.headers['x-razorpay-signature']) {
        console.error("Invalid Signature");
        return res.status(400).json({ status: 'error', message: 'Invalid signature' });
    }

    const event = req.body;

    // B. Check Event Type
    if (event.event === 'payment.captured') {
        const payment = event.payload.payment.entity;
        const email = payment.email;
        const amount = payment.amount; // In paise

        console.log(`Payment received for: ${email}, Amount: ${amount}`);

        // --- TESTING LOGIC (Allow > 1 Rs) ---
        if (amount <= 100) {
            return res.status(400).send("Amount too low");
        }

        try {
            // C. Find User in Firestore
            const usersRef = db.collection('users');
            const snapshot = await usersRef.where('email', '==', email).get();

            if (snapshot.empty) {
                console.log('No matching user found for email:', email);
                return res.status(404).send("User not found");
            }

            // D. Update Subscription
            const thirtyDaysMillis = Date.now() + (30 * 24 * 60 * 60 * 1000);
            
            const batch = db.batch();
            snapshot.forEach(doc => {
                batch.update(doc.ref, { subscriptionExpiry: thirtyDaysMillis });
            });
            
            await batch.commit();
            console.log(`SUCCESS: Subscription updated for ${email}`);

        } catch (error) {
            console.error("Error updating database:", error);
            return res.status(500).send("Database error");
        }
    }

    res.json({ status: 'ok' });
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
