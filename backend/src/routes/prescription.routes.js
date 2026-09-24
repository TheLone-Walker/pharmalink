const router = require('express').Router();
const ctrl = require('../controllers/prescription.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { authorize } = require('../middleware/role.middleware');

router.post('/',                      authenticate, authorize('doctor'), ctrl.issue);
router.post('/consultation',          authenticate, authorize('doctor'), ctrl.issue);
router.get('/',                       authenticate, ctrl.getMyPrescriptions);
router.patch('/:id/send-to-pharmacy', authenticate, authorize('patient', 'doctor', 'admin'), ctrl.sendToPharmacy);
router.patch('/:id/fulfill',          authenticate, authorize('pharmacist'), ctrl.fulfill);
router.get('/medical-history',        authenticate, ctrl.getMedicalHistory);

module.exports = router;
