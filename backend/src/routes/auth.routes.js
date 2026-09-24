const router = require('express').Router();
const ctrl = require('../controllers/auth.controller');
const pwCtrl = require('../controllers/password.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.post('/register',         ctrl.register);
router.post('/login',            ctrl.login);
router.post('/refresh-token',    ctrl.refresh);
router.post('/send-otp',         ctrl.sendOtp);
router.post('/verify-otp',       ctrl.verifyOtp);
router.post('/forgot-password',  pwCtrl.forgotPassword);
router.post('/reset-password',   pwCtrl.resetPassword);
router.post('/change-password',  authenticate, pwCtrl.changePassword);

module.exports = router;
