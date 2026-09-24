const router = require('express').Router();
const ctrl = require('../controllers/driver.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { authorize } = require('../middleware/role.middleware');
const upload = require('../middleware/upload.middleware');

router.get('/deliveries',                  authenticate, authorize('delivery_driver'), ctrl.getDeliveries);
router.patch('/deliveries/:id/accept',     authenticate, authorize('delivery_driver'), ctrl.acceptDelivery);
router.patch('/deliveries/:id/pickup',     authenticate, authorize('delivery_driver'), ctrl.confirmPickup);
router.patch('/deliveries/:id/deliver',    authenticate, authorize('delivery_driver'), ctrl.confirmDelivery);
router.post('/deliveries/:id/photo',       authenticate, authorize('delivery_driver'), upload.single('photo'), ctrl.uploadDeliveryPhoto);
router.put('/location',                    authenticate, authorize('delivery_driver'), ctrl.updateLocation);
router.get('/status',                      authenticate, authorize('delivery_driver'), ctrl.getStatus);
router.patch('/status',                    authenticate, authorize('delivery_driver'), ctrl.setOnlineStatus);
router.get('/earnings',                    authenticate, authorize('delivery_driver'), ctrl.getEarnings);
router.post('/documents',                  authenticate, authorize('delivery_driver'),
  upload.fields([{ name: 'driverLicense', maxCount: 1 }, { name: 'nationalId', maxCount: 1 }]),
  ctrl.uploadDocuments
);

module.exports = router;
