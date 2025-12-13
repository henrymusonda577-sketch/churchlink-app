const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

exports.processDonationWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const { event, data } = req.body;

    if (event === 'charge.success') {
      const { tx_ref, amount, currency, customer, flw_ref } = data;

      // Log donation to Firestore
      await admin.firestore().collection('donations').add({
        userId: customer.email, // Assuming email is used as userId or map accordingly
        amount: parseFloat(amount),
        currency,
        paymentMethod: 'Flutterwave',
        purpose: 'General', // Can be parsed from tx_ref if needed
        message: '',
        transactionId: flw_ref,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
      });

      // Send confirmation email or notification
      // You can integrate with Firebase Cloud Messaging or email service here

      console.log('Donation processed successfully:', { tx_ref, amount, currency });
    }

    res.status(200).send('Webhook received');
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).send('Internal server error');
  }
});

exports.verifyPayment = functions.https.onCall(async (data, context) => {
  const { transactionId } = data;

  try {
    const response = await axios.get(`https://api.flutterwave.com/v3/transactions/${transactionId}/verify`, {
      headers: {
        'Authorization': `Bearer ${functions.config().flutterwave.secret_key}`,
      },
    });

    return response.data;
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Payment verification failed');
  }
});

exports.sendDonationConfirmation = functions.firestore
  .document('donations/{donationId}')
  .onCreate(async (snap, context) => {
    const donation = snap.data();

    // Send notification to user
    // This is a placeholder - implement actual notification logic
    console.log('New donation logged:', donation);

    // You can send email, push notification, etc. here
  });

exports.uploadImageToStorage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { base64Image, fileName, path = 'posts' } = data;

  if (!base64Image || !fileName) {
    throw new functions.https.HttpsError('invalid-argument', 'base64Image and fileName are required.');
  }

  try {
    // Decode base64 image (remove data URL prefix if present)
    let imageBuffer;
    if (base64Image.startsWith('data:image')) {
      const base64Data = base64Image.split(',')[1];
      imageBuffer = Buffer.from(base64Data, 'base64');
    } else {
      imageBuffer = Buffer.from(base64Image, 'base64');
    }

    // Check file size (10MB limit)
    if (imageBuffer.length > 10 * 1024 * 1024) {
      throw new functions.https.HttpsError('invalid-argument', 'Image size too large. Maximum 10MB.');
    }

    const userId = context.auth.uid;
    const timestamp = Date.now();
    const fullFileName = `${userId}_${timestamp}_${fileName}`;
    const storagePath = `${path}/${fullFileName}`;

    // Upload to Firebase Storage
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);

    const metadata = {
      contentType: 'image/jpeg',
      metadata: {
        uploadedBy: userId,
      },
    };

    await file.save(imageBuffer, {
      metadata: metadata,
    });

    // Make public
    await file.makePublic();

    // Get download URL
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '03-09-2491',
    });

    return { downloadUrl: url };
  } catch (error) {
    console.error('Upload error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to upload image: ' + error.message);
  }
});

exports.generateVideoUploadUrl = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }

  const { fileName, contentType } = data;

  if (!fileName || !contentType) {
    throw new functions.https.HttpsError('invalid-argument', 'fileName and contentType are required.');
  }

  try {
    const userId = context.auth.uid;
    const timestamp = Date.now();
    const fullFileName = `${userId}_${timestamp}_${fileName}`;
    const storagePath = `videos/${userId}/${fullFileName}`;

    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);

    // Generate signed URL for PUT (upload)
    const [signedUrl] = await file.getSignedUrl({
      action: 'write',
      expires: Date.now() + 15 * 60 * 1000, // 15 minutes
      contentType: contentType,
    });

    // Also generate download URL
    const [downloadUrl] = await file.getSignedUrl({
      action: 'read',
      expires: '03-09-2491',
    });

    return {
      signedUrl: signedUrl,
      downloadUrl: downloadUrl,
      storagePath: storagePath
    };
  } catch (error) {
    console.error('Generate video URL error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to generate upload URL: ' + error.message);
  }
});
