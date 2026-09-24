const router = require('express').Router();
const ctrl = require('../controllers/appointment.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.post('/',                          authenticate, ctrl.book);
router.get('/',                           authenticate, ctrl.getMyAppointments);
router.patch('/:id/status',               authenticate, ctrl.updateStatus);
router.patch('/:id/reschedule',           authenticate, ctrl.reschedule);
router.delete('/:id',                     authenticate, ctrl.cancel);
router.get('/availability/:doctorId',     authenticate, ctrl.getAvailability);
router.get('/schedule/:doctorId',         authenticate, ctrl.getDoctorSchedule);
router.post('/block-time',                authenticate, ctrl.blockPersonalTime);
router.get('/blocked-times',              authenticate, ctrl.getBlockedTimes);
router.delete('/blocked-times/:id',       authenticate, ctrl.unblockPersonalTime);

module.exports = router;
