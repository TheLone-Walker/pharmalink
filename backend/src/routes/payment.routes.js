const router = require('express').Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');
const { v4: uuidv4 } = require('uuid');

router.post('/initiate', authenticate, async (req, res, next) => {
  try {
    const { orderId, appointmentId, method, amountFcfa } = req.body;
    const reference = 'PL-' + uuidv4().slice(0, 8).toUpperCase();
    const transaction = await prisma.transaction.create({
      data: {
        userId: req.user.id,
        orderId: orderId || null,
        appointmentId: appointmentId || null,
        type: 'payment',
        amountFcfa: parseFloat(amountFcfa),
        method,
        status: 'pending',
        reference,
      },
    });
    // TODO: integrate actual Momo/Orange Money SDK here
    // Simulate success for now
    await prisma.transaction.update({ where: { id: transaction.id }, data: { status: 'success' } });
    res.json({ success: true, data: { ...transaction, status: 'success', reference }, message: 'Payment successful' });
  } catch (err) { next(err); }
});

router.get('/verify/:reference', authenticate, async (req, res, next) => {
  try {
    const transaction = await prisma.transaction.findUnique({ where: { reference: req.params.reference } });
    if (!transaction) throw { status: 404, message: 'Transaction not found' };
    res.json({ success: true, data: transaction });
  } catch (err) { next(err); }
});

module.exports = router;
