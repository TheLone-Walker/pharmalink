const router = require('express').Router();
const ctrl = require('../controllers/order.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { authorize } = require('../middleware/role.middleware');
const upload = require('../middleware/upload.middleware');

router.post('/',                        authenticate, authorize('patient'), ctrl.createOrder);
router.get('/',                         authenticate, ctrl.getMyOrders);
router.get('/:id',                      authenticate, ctrl.getOrderById);
router.get('/:id/receipt',              authenticate, ctrl.getOrderReceipt);
router.patch('/:id/cancel',             authenticate, authorize('patient'), ctrl.cancelOrder);
router.patch('/:id/status',             authenticate, ctrl.updateStatus);
router.post('/:id/otp/generate',        authenticate, ctrl.generateOrderOtp);
router.post('/:id/otp/verify',          authenticate, ctrl.verifyOrderOtp);
router.post('/:id/signature',           authenticate, upload.single('signature'), ctrl.uploadSignature);

module.exports = router;
