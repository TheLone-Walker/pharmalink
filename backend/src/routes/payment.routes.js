const router = require('express').Router();
const { authenticate } = require('../middleware/auth.middleware');
const paymentService = require('../services/payment.service');

// 1. Initiate Payment (MTN MoMo, Orange Money, Card, Cash)
router.post('/initiate', authenticate, async (req, res, next) => {
  try {
    const { orderId, appointmentId, method, amountFcfa, phoneNumber, description } = req.body;
    const result = await paymentService.initiatePayment({
      userId: req.user.id,
      orderId,
      appointmentId,
      method,
      amountFcfa,
      phoneNumber: phoneNumber || req.user.phone,
      description,
    });
    res.json({ success: true, data: result, message: result.message });
  } catch (err) {
    next(err);
  }
});

// 2. Verify Payment by Reference
router.get('/verify/:reference', authenticate, async (req, res, next) => {
  try {
    const transaction = await paymentService.verifyPayment(req.params.reference);
    res.json({ success: true, data: transaction });
  } catch (err) {
    next(err);
  }
});

// 3. Webhook / Callback endpoint for Payment Gateway (DigiPay / Campay / CinetPay)
router.post('/webhook', async (req, res, next) => {
  try {
    const result = await paymentService.handleWebhook(req.body);
    res.json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
