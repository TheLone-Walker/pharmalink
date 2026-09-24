const router = require('express').Router();
const ctrl = require('../controllers/medication.controller');
const { authenticate } = require('../middleware/auth.middleware');

router.get('/suggestions', authenticate, ctrl.suggestions);
router.get('/search',      authenticate, ctrl.search);
router.get('/:id',         authenticate, ctrl.getById);

module.exports = router;
