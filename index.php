<?php
require 'vendor/autoload.php';

use Google\Cloud\Firestore\FirestoreClient;

// 1. SETUP & SECURITY
// Get the Webhook Secret you set in Razorpay Dashboard (Keep this secure!)
$webhookSecret = getenv('RAZORPAY_WEBHOOK_SECRET'); 

// Receive the raw data
$payload = file_get_contents('php://input');
$receivedSignature = $_SERVER['HTTP_X_RAZORPAY_SIGNATURE'] ?? '';

// Calculate expected signature to verify it's truly from Razorpay
$expectedSignature = hash_hmac('sha256', $payload, $webhookSecret);

if ($receivedSignature !== $expectedSignature) {
    http_response_code(400);
    die("Invalid Signature");
}

// 2. PARSE DATA
$data = json_decode($payload, true);

// Check if this is a "payment.captured" event
if (isset($data['event']) && $data['event'] === 'payment.captured') {
    
    $email = $data['payload']['payment']['entity']['email'];
    $amount = $data['payload']['payment']['entity']['amount']; // Amount is in paise

    // --- MODIFIED LOGIC FOR TESTING ---
    // 1 Rupee = 100 Paise.
    // This allows any payment greater than 1 Rupee (e.g., 102 paise / 1.02 Rs)
    if ($amount <= 100) {
        http_response_code(400);
        die("Amount too low. Minimum 1 Rupee required.");
    }

    // 3. CONNECT TO FIREBASE
    // The path to the json key matches the mount path in Render
    $firestore = new FirestoreClient([
        'keyFilePath' => '/etc/secrets/firebase_credentials.json'
    ]);

    $usersRef = $firestore->collection('users');

    // 4. FIND USER BY EMAIL
    // Query Firestore to find the user document with this email
    $query = $usersRef->where('email', '=', $email);
    $documents = $query->documents();

    $userFound = false;

    foreach ($documents as $document) {
        $userFound = true;
        
        // Calculate 30 Days from now in milliseconds
        $thirtyDaysMillis = (time() + (30 * 24 * 60 * 60)) * 1000;

        // Update the user document with the new expiry date
        $document->reference()->update([
            ['path' => 'subscriptionExpiry', 'value' => $thirtyDaysMillis]
        ]);
        
        // Log for debugging in Render Dashboard
        error_log("SUCCESS: Subscription activated for: " . $email . " | Amount: " . $amount);
    }

    if (!$userFound) {
        error_log("ERROR: Payment received but user email not found in DB: " . $email);
    }
}

echo "Webhook Handled";
?>
