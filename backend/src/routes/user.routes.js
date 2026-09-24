const router = require('express').Router();
const ctrl = require('../controllers/user.controller');
const { authenticate } = require('../middleware/auth.middleware');
const upload = require('../middleware/upload.middleware');

router.get('/me',        authenticate, ctrl.getMe);
router.put('/me',        authenticate, ctrl.updateMe);
router.post('/me/photo', authenticate, upload.single('photo'), ctrl.uploadPhoto);
router.get('/doctors',   authenticate, ctrl.getDoctors);
router.get('/hospitals', authenticate, ctrl.getHospitals);

module.exports = router;
