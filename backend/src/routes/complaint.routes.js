// complaint.routes.js
const express = require('express');
const router = express.Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');

router.post('/', authenticate, async (req, res, next) => {
  try {
    const { subject, body } = req.body;
    const complaint = await prisma.complaint.create({ data: { userId: req.user.id, subject, body } });
    res.status(201).json({ success: true, data: complaint });
  } catch (err) { next(err); }
});

router.get('/', authenticate, async (req, res, next) => {
  try {
    const complaints = await prisma.complaint.findMany({ where: { userId: req.user.id }, orderBy: { createdAt: 'desc' } });
    res.json({ success: true, data: complaints });
  } catch (err) { next(err); }
});

module.exports = router;
