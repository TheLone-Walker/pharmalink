const router = require('express').Router();
const ctrl = require('../controllers/pharmacist.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { authorize } = require('../middleware/role.middleware');
const upload = require('../middleware/upload.middleware');

router.get('/inventory',                  authenticate, authorize('pharmacist'), ctrl.getInventory);
router.post('/inventory',                 authenticate, authorize('pharmacist'), upload.single('image'), ctrl.addMedication);
router.put('/inventory/:id',              authenticate, authorize('pharmacist'), ctrl.updateMedication);
router.delete('/inventory/:id',           authenticate, authorize('pharmacist'), ctrl.deleteMedication);

router.get('/orders',                     authenticate, authorize('pharmacist'), ctrl.getOrders);
router.patch('/orders/:id/confirm',       authenticate, authorize('pharmacist'), ctrl.confirmOrder);
router.patch('/orders/:id/ready',         authenticate, authorize('pharmacist'), ctrl.markReady);
router.patch('/orders/:id/status',        authenticate, authorize('pharmacist'), ctrl.updateOrderStatus);
router.post('/orders/:id/verify-otp',     authenticate, authorize('pharmacist'), ctrl.verifyPickupOtp);

router.get('/drivers',                    authenticate, authorize('pharmacist'), ctrl.getAvailableDrivers);
router.post('/orders/:id/assign-driver',  authenticate, authorize('pharmacist'), ctrl.assignDriver);

router.get('/analytics',                  authenticate, authorize('pharmacist'), ctrl.getSalesAnalytics);
router.post('/license',                   authenticate, authorize('pharmacist'), upload.single('license'), ctrl.uploadLicense);

module.exports = router;
