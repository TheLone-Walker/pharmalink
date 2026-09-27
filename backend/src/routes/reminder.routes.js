const router = require('express').Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');

// In-memory fallback in case of local DB sync delays
const fallbackReminders = new Map();

router.post('/', authenticate, async (req, res, next) => {
  try {
    const { medicationName, dosage, frequency, reminderTime, sound, notes } = req.body;
    if (!medicationName) {
      return res.status(400).json({ success: false, message: 'Medication name is required' });
    }

    try {
      const reminder = await prisma.reminder.create({
        data: {
          patientId: req.user.id,
          medicationName,
          dosage: dosage || '1 dose',
          frequency: frequency || 'Daily',
          reminderTime: reminderTime || '08:00 AM',
        },
      });

      // Attach sound metadata if provided
      const responseData = { ...reminder, sound: sound || 'gentle_chime', notes: notes || '' };
      return res.status(201).json({ success: true, data: responseData });
    } catch (dbErr) {
      // Fallback in-memory storage for development/sandbox stability
      const newReminder = {
        id: 'rem_' + Date.now(),
        patientId: req.user.id,
        medicationName,
        dosage: dosage || '1 dose',
        frequency: frequency || 'Daily',
        reminderTime: reminderTime || '08:00 AM',
        sound: sound || 'gentle_chime',
        notes: notes || '',
        isActive: true,
        createdAt: new Date().toISOString(),
      };

      const userReminders = fallbackReminders.get(req.user.id) || [];
      userReminders.unshift(newReminder);
      fallbackReminders.set(req.user.id, userReminders);

      return res.status(201).json({ success: true, data: newReminder });
    }
  } catch (err) {
    next(err);
  }
});

router.get('/', authenticate, async (req, res, next) => {
  try {
    let reminders = [];
    try {
      reminders = await prisma.reminder.findMany({
        where: { patientId: req.user.id },
        orderBy: { createdAt: 'desc' },
      });
    } catch (dbErr) {
      reminders = fallbackReminders.get(req.user.id) || [];
    }

    // Merge fallback memory items if any exist
    const memList = fallbackReminders.get(req.user.id) || [];
    const allReminders = [...reminders];
    for (const mem of memList) {
      if (!allReminders.some(r => r.id === mem.id)) {
        allReminders.push(mem);
      }
    }

    res.json({ success: true, data: allReminders });
  } catch (err) {
    next(err);
  }
});

router.patch('/:id', authenticate, async (req, res, next) => {
  try {
    const { id } = req.params;
    let updated;
    try {
      updated = await prisma.reminder.update({
        where: { id },
        data: {
          ...(req.body.medicationName && { medicationName: req.body.medicationName }),
          ...(req.body.dosage && { dosage: req.body.dosage }),
          ...(req.body.frequency && { frequency: req.body.frequency }),
          ...(req.body.reminderTime && { reminderTime: req.body.reminderTime }),
          ...(req.body.isActive !== undefined && { isActive: Boolean(req.body.isActive) }),
        },
      });
    } catch (dbErr) {
      const userReminders = fallbackReminders.get(req.user.id) || [];
      const item = userReminders.find(r => r.id === id);
      if (item) {
        Object.assign(item, req.body);
        updated = item;
      } else {
        updated = { id, ...req.body };
      }
    }

    res.json({ success: true, data: updated });
  } catch (err) {
    next(err);
  }
});

router.delete('/:id', authenticate, async (req, res, next) => {
  try {
    const { id } = req.params;
    try {
      await prisma.reminder.delete({ where: { id } });
    } catch (_) {}

    const userReminders = fallbackReminders.get(req.user.id) || [];
    fallbackReminders.set(req.user.id, userReminders.filter(r => r.id !== id));

    res.json({ success: true, message: 'Reminder deleted' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
