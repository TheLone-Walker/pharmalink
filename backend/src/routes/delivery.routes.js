// delivery.routes.js
const router = require('express').Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');

router.get('/:orderId', authenticate, async (req, res, next) => {
  try {
    const delivery = await prisma.delivery.findFirst({
      where: { orderId: req.params.orderId },
      include: {
        driver: { include: { user: { select: { name: true, phone: true, profilePhotoUrl: true } } } },
        order: true,
      },
    });
    if (!delivery) throw { status: 404, message: 'Delivery not found' };
    res.json({ success: true, data: delivery });
  } catch (err) { next(err); }
});

module.exports = router;
