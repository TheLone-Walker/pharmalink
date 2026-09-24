const router = require('express').Router();
const ctrl = require('../controllers/admin.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { authorize } = require('../middleware/role.middleware');

const adminOnly = [authenticate, authorize('admin')];

router.get('/users',                   ...adminOnly, ctrl.getUsers);
router.patch('/users/:id/activate',    ...adminOnly, ctrl.setUserActive);
router.patch('/users/:id/deactivate',  ...adminOnly, ctrl.setUserActive);
router.get('/licenses/pending',        ...adminOnly, ctrl.getPendingLicenses);
router.patch('/licenses/:id/review',   ...adminOnly, ctrl.reviewLicense);
router.get('/registry/onmc',           ...adminOnly, ctrl.getOnmcRegistry);
router.post('/registry/onmc',          ...adminOnly, ctrl.addOnmcDoctor);
router.get('/registry/onpc',           ...adminOnly, ctrl.getOnpcRegistry);
router.post('/registry/onpc',          ...adminOnly, ctrl.addOnpcPharmacy);
router.get('/complaints',              ...adminOnly, ctrl.getComplaints);
router.patch('/complaints/:id/respond',...adminOnly, ctrl.respondComplaint);
router.get('/stats',                   ...adminOnly, ctrl.getStats);
router.get('/transactions',            ...adminOnly, ctrl.getAllTransactions);

module.exports = router;
