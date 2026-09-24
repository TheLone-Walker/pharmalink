const router = require('express').Router();
const { authenticate } = require('../middleware/auth.middleware');
const { registerToken } = require('../services/push.service');

// Register FCM push token from the Flutter app
router.post('/fcm-token', authenticate, async (req, res, next) => {
  try {
    const { token } = req.body;
    if (!token) throw { status: 400, message: 'FCM token is required' };
    await registerToken(req.user.id, token);
    res.json({ success: true, message: 'FCM token registered' });
  } catch (err) { next(err); }
});

module.exports = router;
