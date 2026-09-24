const router = require('express').Router();
const ctrl = require('../controllers/doctor.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { authorize } = require('../middleware/role.middleware');
const upload = require('../middleware/upload.middleware');

router.get('/patients',          authenticate, authorize('doctor'), ctrl.getPatients);
router.get('/patients/:id',      authenticate, authorize('doctor'), ctrl.getPatientDetail);
router.put('/availability',      authenticate, authorize('doctor'), ctrl.setAvailability);
router.post('/license',          authenticate, authorize('doctor'), upload.single('license'), ctrl.uploadLicense);

module.exports = router;
