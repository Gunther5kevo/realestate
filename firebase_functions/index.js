const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineString } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// ── Load credentials from .env ──────────────────────────────────────────────
const CONSUMER_KEY = defineString("MPESA_CONSUMER_KEY");
const CONSUMER_SECRET = defineString("MPESA_CONSUMER_SECRET");
const SHORTCODE = defineString("MPESA_SHORTCODE");
const PASSKEY = defineString("MPESA_PASSKEY");
const MPESA_ENV = defineString("MPESA_ENV");

// ── Daraja base URL (sandbox vs production) ─────────────────────────────────
const getBaseUrl = () =>
  MPESA_ENV.value() === "production"
    ? "https://api.safaricom.co.ke"
    : "https://sandbox.safaricom.co.ke";

// ── Step 1: Get OAuth token from Daraja ─────────────────────────────────────
const getAccessToken = async () => {
  const auth = Buffer.from(
    `${CONSUMER_KEY.value()}:${CONSUMER_SECRET.value()}`
  ).toString("base64");

  const response = await axios.get(
    `${getBaseUrl()}/oauth/v1/generate?grant_type=client_credentials`,
    {
      headers: { Authorization: `Basic ${auth}` },
    }
  );

  return response.data.access_token;
};

// ── Step 2: Generate password and timestamp ──────────────────────────────────
const getPasswordAndTimestamp = () => {
  const timestamp = new Date()
    .toISOString()
    .replace(/[-T:.Z]/g, "")
    .slice(0, 14); // format: YYYYMMDDHHmmss

  const password = Buffer.from(
    `${SHORTCODE.value()}${PASSKEY.value()}${timestamp}`
  ).toString("base64");

  return { password, timestamp };
};

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 1: initiateMpesaPayment
// Called from Flutter PaymentService.initiateMpesaPayment()
// Sends STK Push to user's phone
// ────────────────────────────────────────────────────────────────────────────
exports.initiateMpesaPayment = onCall(
  {
    invoker: "public",
    enforceAppCheck: false,
  },
  async (request) => {
    const { phone, amount, propertyId, bookingId } = request.data;

    // Basic validation
    if (!phone || !amount || !propertyId) {
      throw new HttpsError("invalid-argument", "Missing required fields.");
    }

    try {
      const token = await getAccessToken();
      const { password, timestamp } = getPasswordAndTimestamp();

      // Your deployed mpesaCallback function URL
      const callbackUrl = `https://us-central1-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/mpesaCallback`;

      const response = await axios.post(
        `${getBaseUrl()}/mpesa/stkpush/v1/processrequest`,
        {
          BusinessShortCode: SHORTCODE.value(),
          Password: password,
          Timestamp: timestamp,
          TransactionType: "CustomerPayBillOnline",
          Amount: Math.ceil(amount), // must be a whole number
          PartyA: phone,             // customer phone e.g. 254712345678
          PartyB: SHORTCODE.value(),
          PhoneNumber: phone,
          CallBackURL: callbackUrl,
          AccountReference: "NyumbaViewing",
          TransactionDesc: "Property Viewing Fee",
        },
        {
          headers: { Authorization: `Bearer ${token}` },
        }
      );

      const { CheckoutRequestID, MerchantRequestID, ResponseCode } =
        response.data;

      if (ResponseCode !== "0") {
        return { success: false, errorMessage: response.data.ResponseDescription };
      }

      // Save pending transaction to Firestore so we can track it
      await db.collection("transactions").add({
        checkoutRequestId: CheckoutRequestID,
        merchantRequestId: MerchantRequestID,
        phone,
        amount,
        propertyId,
        bookingId,
        status: "pending",
        paymentMethod: "mpesa",
        currency: "KES",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        checkoutRequestId: CheckoutRequestID,
        merchantRequestId: MerchantRequestID,
      };
    } catch (error) {
      console.error("STK Push error:", error?.response?.data || error.message);
      throw new HttpsError("internal", "Failed to initiate M-Pesa payment.");
    }
  }
);

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 2: mpesaCallback
// Safaricom calls this URL automatically after the user enters their PIN
// It updates the transaction in Firestore to completed or failed
// ────────────────────────────────────────────────────────────────────────────
exports.mpesaCallback = onRequest(async (req, res) => {
  const callback = req.body?.Body?.stkCallback;

  if (!callback) {
    console.error("Invalid callback payload", req.body);
    return res.status(400).send("Invalid payload");
  }

  const {
    CheckoutRequestID,
    ResultCode,
    ResultDesc,
    CallbackMetadata,
  } = callback;

  const isSuccess = ResultCode === 0;

  // Pull out receipt number and amount from the callback metadata
  let mpesaReceiptNumber = null;
  let paidAmount = null;

  if (isSuccess && CallbackMetadata?.Item) {
    for (const item of CallbackMetadata.Item) {
      if (item.Name === "MpesaReceiptNumber") mpesaReceiptNumber = item.Value;
      if (item.Name === "Amount") paidAmount = item.Value;
    }
  }

  // Find the matching transaction in Firestore by checkoutRequestId
  const snapshot = await db
    .collection("transactions")
    .where("checkoutRequestId", "==", CheckoutRequestID)
    .limit(1)
    .get();

  if (!snapshot.empty) {
    await snapshot.docs[0].ref.update({
      status: isSuccess ? "completed" : "failed",
      resultCode: ResultCode,
      resultDesc: ResultDesc,
      mpesaReceiptNumber: mpesaReceiptNumber ?? null,
      paidAmount: paidAmount ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Safaricom expects a 200 response — always send this
  res.status(200).json({ ResultCode: 0, ResultDesc: "Success" });
});

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 3: checkMpesaPaymentStatus
// Called from Flutter every 5 seconds while waiting screen is shown
// Reads the transaction Firestore doc updated by mpesaCallback above
// ────────────────────────────────────────────────────────────────────────────
exports.checkMpesaPaymentStatus = onCall(
  {
    invoker: "public",
    enforceAppCheck: false,
  },
  async (request) => {
    const { checkoutRequestId } = request.data;

    if (!checkoutRequestId) {
      throw new HttpsError("invalid-argument", "checkoutRequestId is required.");
    }

    const snapshot = await db
      .collection("transactions")
      .where("checkoutRequestId", "==", checkoutRequestId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return { status: "pending" }; // not yet written by callback
    }

    const data = snapshot.docs[0].data();

    return {
      status: data.status,           // "pending" | "completed" | "failed"
      resultCode: data.resultCode ?? null,
      resultDesc: data.resultDesc ?? null,
      mpesaReceiptNumber: data.mpesaReceiptNumber ?? null,
    };
  }
);

// ────────────────────────────────────────────────────────────────────────────
// FUNCTION 4: notifyAgent
// Called from BookingService.createBooking() after payment is confirmed
// ────────────────────────────────────────────────────────────────────────────
exports.notifyAgent = onCall(
  {
    invoker: "public",
    enforceAppCheck: false,
  },
  async (request) => {
    const { bookingId, agentId, message, scheduledDate, timeSlot } = request.data;

    if (!agentId || !bookingId) {
      throw new HttpsError("invalid-argument", "Missing agentId or bookingId.");
    }

    // Get agent's FCM token from Firestore
    const agentDoc = await db.collection("agents").doc(agentId).get();
    const fcmToken = agentDoc.data()?.fcmToken;

    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "New Viewing Request",
          body: message,
        },
        data: {
          bookingId,
          scheduledDate,
          timeSlot: timeSlot ?? "",
          type: "new_booking",
        },
      });
    }

    return { success: true };
  }
);