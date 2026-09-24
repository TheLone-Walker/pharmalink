const router = require('express').Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');

router.post('/', authenticate, async (req, res, next) => {
  try {
    const { medicationName, dosage, frequency, reminderTime } = req.body;
    const reminder = await prisma.reminder.create({ data: { patientId: req.user.id, medicationName, dosage, frequency, reminderTime } });
    res.status(201).json({ success: true, data: reminder });
  } catch (err) { next(err); }
});

router.get('/', authenticate, async (req, res, next) => {
  try {
    const reminders = await prisma.reminder.findMany({ where: { patientId: req.user.id }, orderBy: { createdAt: 'desc' } });
    res.json({ success: true, data: reminders });
  } catch (err) { next(err); }
});

router.patch('/:id', authenticate, async (req, res, next) => {
  try {
    const reminder = await prisma.reminder.update({ where: { id: req.params.id }, data: req.body });
    res.json({ success: true, data: reminder });
  } catch (err) { next(err); }
});

router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    await prisma.reminder.delete({ where: { id: req.params.id } });
    res.json({ success: true, message: 'Reminder deleted' });
  } catch (err) { next(err); }
});

module.exports = router;
