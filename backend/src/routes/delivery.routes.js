// delivery.routes.js
const router = require('express').Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');

router.get('/route-path', authenticate, async (req, res, next) => {
  try {
    const { originLat, originLng, destLat, destLng } = req.query;
    if (!originLat || !originLng || !destLat || !destLng) {
      return res.status(400).json({ success: false, message: 'Missing origin or destination coordinates' });
    }
    const { getDirections } = require('../services/maps.service');
    const route = await getDirections(originLat, originLng, destLat, destLng);
    res.json({
      success: true,
      data: {
        coordinates: route.coordinates || [],
        distance: route.legs?.[0]?.distance,
        duration: route.legs?.[0]?.duration,
      },
    });
  } catch (err) { next(err); }
});

router.get('/:orderId', authenticate, async (req, res, next) => {
  try {
    let delivery = await prisma.delivery.findFirst({
      where: { orderId: req.params.orderId },
      include: {
        driver: { include: { user: { select: { name: true, phone: true, profilePhotoUrl: true } } } },
        order: true,
      },
    });

    if (!delivery) {
      const order = await prisma.order.findUnique({
        where: { id: req.params.orderId },
      });
      if (!order) throw { status: 404, message: 'Order not found' };

      // Automatically create a pending delivery record for the delivery order
      delivery = await prisma.delivery.create({
        data: {
          orderId: order.id,
          status: 'assigned',
          currentLat: order.deliveryLat || 3.848,
          currentLng: order.deliveryLng || 11.502,
        },
        include: {
          driver: { include: { user: { select: { name: true, phone: true, profilePhotoUrl: true } } } },
          order: true,
        },
      });
    }

    if (delivery && delivery.order) {
      const isPatientOwner = req.user && req.user.id === delivery.order.patientId;
      const isStaffOrAdmin = req.user && (req.user.role === 'admin' || req.user.role === 'pharmacist');
      if (!isPatientOwner && !isStaffOrAdmin) {
        // Driver or third party: strip secret OTP and pickupCode
        delivery = {
          ...delivery,
          order: {
            ...delivery.order,
            otp: undefined,
            pickupCode: undefined,
          },
        };
      }
    }

    res.json({ success: true, data: delivery });
  } catch (err) { next(err); }
});

module.exports = router;
