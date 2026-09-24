const prisma = require('../config/db');
const notificationService = require('../services/notification.service');
const { emitToOrder } = require('../services/socket.service');
const { generateOTP, otpExpiresAt } = require('../utils/otp');

const getDeliveries = async (req, res, next) => {
  try {
    const profile = await prisma.driverProfile.findUnique({ where: { userId: req.user.id } });
    if (!profile) {
      return res.json({ success: true, data: [] });
    }
    const { status } = req.query;
    const deliveries = await prisma.delivery.findMany({
      where: { driverId: profile.id, ...(status && { status }) },
      include: {
        order: {
          include: {
            items: { include: { medication: true } },
            patient: { select: { id: true, name: true, phone: true } },
            pharmacy: true,
          },
        },
      },
      orderBy: { order: { createdAt: 'desc' } },
    });
    res.json({ success: true, data: deliveries });
  } catch (err) { next(err); }
};

const acceptDelivery = async (req, res, next) => {
  try {
    const delivery = await prisma.delivery.update({
      where: { id: req.params.id },
      data: { status: 'assigned' },
      include: { order: true },
    });
    res.json({ success: true, data: delivery });
  } catch (err) { next(err); }
};

const confirmPickup = async (req, res, next) => {
  try {
    const otp = generateOTP(4);
    const expires = otpExpiresAt(15);

    const delivery = await prisma.delivery.update({
      where: { id: req.params.id },
      data: { status: 'picked_up', startedAt: new Date() },
    });

    const order = await prisma.order.update({
      where: { id: delivery.orderId },
      data: { status: 'out_for_delivery', otp, otpExpiresAt: expires },
      include: {
        pharmacy: true,
        patient: { select: { id: true, name: true, phone: true } },
      },
    });

    emitToOrder(delivery.orderId, 'order:status_change', {
      orderId: delivery.orderId,
      status: 'out_for_delivery',
      otpExpiresAt: expires,
    });

    await notificationService.send(
      order.patientId,
      'Order On The Way! 🚴',
      `Your medication has been picked up from ${order.pharmacy?.pharmacyName ?? 'the pharmacy'} and is on its way to you.`,
      'delivery'
    ).catch(() => {});

    res.json({
      success: true,
      data: {
        ...delivery,
        order: {
          ...order,
          otp,
          otpExpiresAt: expires,
        },
      },
      message: 'Pickup confirmed! Head to customer.',
    });
  } catch (err) { next(err); }
};

const confirmDelivery = async (req, res, next) => {
  try {
    const delivery = await prisma.delivery.update({
      where: { id: req.params.id },
      data: { status: 'delivered', deliveredAt: new Date() },
    });

    const order = await prisma.order.update({
      where: { id: delivery.orderId },
      data: { status: 'delivered' },
      include: { patient: true },
    });

    emitToOrder(delivery.orderId, 'order:status_change', { orderId: delivery.orderId, status: 'delivered' });
    await notificationService.send(order.patientId, 'Order Delivered! 🎉', 'Your order has been delivered successfully.', 'order').catch(() => {});

    // Driver commission 10%
    const profile = await prisma.driverProfile.findUnique({ where: { userId: req.user.id } });
    const commissionFcfa = Math.round(parseFloat(order.totalFcfa) * 0.1);
    await prisma.transaction.create({
      data: {
        userId: req.user.id,
        orderId: order.id,
        type: 'delivery_fee',
        amountFcfa: commissionFcfa,
        method: 'cash',
        status: 'completed',
        reference: `DRV-${Date.now()}-${order.id.slice(0, 4)}`,
      },
    }).catch(() => {});

    res.json({ success: true, data: delivery, message: 'Delivery completed successfully' });
  } catch (err) { next(err); }
};

const uploadDeliveryPhoto = async (req, res, next) => {
  try {
    if (!req.file) throw { status: 400, message: 'No photo provided' };
    const photoUrl = `/uploads/${req.file.filename}`;
    const delivery = await prisma.delivery.findUnique({ where: { id: req.params.id } });
    if (!delivery) throw { status: 404, message: 'Delivery not found' };

    await prisma.order.update({
      where: { id: delivery.orderId },
      data: { proofPhotoUrl: photoUrl },
    });

    res.json({ success: true, data: { proofPhotoUrl: photoUrl }, message: 'Proof photo uploaded' });
  } catch (err) { next(err); }
};

const updateLocation = async (req, res, next) => {
  try {
    const { lat, lng, orderId } = req.body;
    await prisma.driverProfile.update({
      where: { userId: req.user.id },
      data: { currentLat: parseFloat(lat), currentLng: parseFloat(lng) },
    });
    if (orderId) {
      await prisma.delivery.updateMany({
        where: { orderId },
        data: { currentLat: parseFloat(lat), currentLng: parseFloat(lng) },
      });
      emitToOrder(orderId, 'driver:location', { lat: parseFloat(lat), lng: parseFloat(lng), orderId });
    }
    res.json({ success: true, message: 'Location updated' });
  } catch (err) { next(err); }
};

const setOnlineStatus = async (req, res, next) => {
  try {
    const isOnline = req.body.isOnline === true;
    const profile = await prisma.driverProfile.upsert({
      where: { userId: req.user.id },
      update: { isOnline },
      create: { userId: req.user.id, isOnline },
    });
    res.json({ success: true, data: profile });
  } catch (err) { next(err); }
};

const getStatus = async (req, res, next) => {
  try {
    const profile = await prisma.driverProfile.findUnique({
      where: { userId: req.user.id },
      include: { user: { select: { id: true, name: true, phone: true, email: true } } },
    });
    res.json({ success: true, data: profile });
  } catch (err) { next(err); }
};

const getEarnings = async (req, res, next) => {
  try {
    const profile = await prisma.driverProfile.findUnique({ where: { userId: req.user.id } });
    if (!profile) {
      return res.json({ success: true, data: { totalEarnings: 0, tripCount: 0, todayEarnings: 0, deliveries: [] } });
    }

    const deliveries = await prisma.delivery.findMany({
      where: { driverId: profile.id, status: 'delivered' },
      include: {
        order: {
          select: {
            id: true,
            totalFcfa: true,
            deliveryAddress: true,
            createdAt: true,
            pharmacy: { select: { pharmacyName: true } },
          },
        },
      },
      orderBy: { deliveredAt: 'desc' },
    });

    const totalEarnings = deliveries.reduce((sum, d) => sum + Math.round(parseFloat(d.order?.totalFcfa || 0) * 0.1), 0);

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayDeliveries = deliveries.filter(d => new Date(d.deliveredAt || d.order?.createdAt) >= today);
    const todayEarnings = todayDeliveries.reduce((sum, d) => sum + Math.round(parseFloat(d.order?.totalFcfa || 0) * 0.1), 0);

    res.json({
      success: true,
      data: {
        totalEarnings,
        todayEarnings,
        tripCount: deliveries.length,
        todayTrips: todayDeliveries.length,
        deliveries,
      },
    });
  } catch (err) { next(err); }
};

const uploadDocuments = async (req, res, next) => {
  try {
    const files = req.files;
    const data = {};
    if (files?.driverLicense?.[0]) data.driverLicenseUrl = `/uploads/${files.driverLicense[0].filename}`;
    if (files?.nationalId?.[0]) data.nationalIdUrl = `/uploads/${files.nationalId[0].filename}`;
    data.approvalStatus = 'pending';

    const updated = await prisma.driverProfile.update({
      where: { userId: req.user.id },
      data,
    });
    res.json({ success: true, data: updated, message: 'Documents submitted for verification' });
  } catch (err) { next(err); }
};

module.exports = {
  getDeliveries,
  acceptDelivery,
  confirmPickup,
  confirmDelivery,
  uploadDeliveryPhoto,
  updateLocation,
  setOnlineStatus,
  getStatus,
  getEarnings,
  uploadDocuments,
};

