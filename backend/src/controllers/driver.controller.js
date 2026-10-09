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

    // SECURITY: Driver must NEVER receive the patient's secret OTP or pickup pass!
    // The driver must obtain the OTP directly from the patient at their doorstep.
    const sanitizedDeliveries = deliveries.map(d => {
      if (d.order) {
        const { otp, pickupCode, ...safeOrder } = d.order;
        return { ...d, order: safeOrder };
      }
      return d;
    });

    res.json({ success: true, data: sanitizedDeliveries });
  } catch (err) { next(err); }
};

const acceptDelivery = async (req, res, next) => {
  try {
    const delivery = await prisma.delivery.update({
      where: { id: req.params.id },
      data: { status: 'assigned' },
      include: { order: true },
    });
    if (delivery.order) {
      delete delivery.order.otp;
      delete delivery.order.pickupCode;
    }
    res.json({ success: true, data: delivery });
  } catch (err) { next(err); }
};

const confirmPickup = async (req, res, next) => {
  try {
    const otp = generateOTP(4);
    const expires = otpExpiresAt(30); // 30 minutes validity

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

    // Send secret OTP EXCLUSIVELY to the patient (via push/in-app notification)
    await notificationService.send(
      order.patientId,
      'Order On The Way! 🚴',
      `Your medication has been picked up from ${order.pharmacy?.pharmacyName ?? 'the pharmacy'}. Your confidential delivery verification OTP is: ${otp}. Please provide this code to the driver upon delivery to verify handover.`,
      'delivery'
    ).catch(() => {});

    // For the driver response: NEVER return the OTP!
    const { otp: _hiddenOtp, pickupCode: _hiddenCode, ...safeOrder } = order;

    res.json({
      success: true,
      data: {
        ...delivery,
        order: safeOrder,
      },
      message: 'Pickup confirmed! Head to customer address and ask for their 4-digit verification OTP on arrival.',
    });
  } catch (err) { next(err); }
};

const confirmDelivery = async (req, res, next) => {
  try {
    const { otp } = req.body;
    if (!otp || typeof otp !== 'string' || !otp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Delivery verification OTP is required. Ask the customer for the 4-digit code shown on their PharmaLink app.',
      });
    }

    const delivery = await prisma.delivery.findUnique({
      where: { id: req.params.id },
      include: { order: true },
    });
    if (!delivery) throw { status: 404, message: 'Delivery not found' };

    if (delivery.status === 'delivered') {
      return res.status(400).json({ success: false, message: 'This delivery has already been completed.' });
    }

    const normalize = (v) => (v || '').toString().trim().toUpperCase().replace(/^(PK-|OTP-|PL)/, '');
    const cleanInput = normalize(otp);
    const cleanExpected = normalize(delivery.order?.otp);
    const rawInput = otp.toString().trim();
    const rawExpected = (delivery.order?.otp || '').toString().trim();

    const isMatch = (rawInput && rawInput === rawExpected) || (cleanInput && cleanInput === cleanExpected);

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: 'Invalid delivery OTP! The code entered does not match the customer\'s secret verification code. Please ask the customer to check their PharmaLink app.',
      });
    }

    const updatedDelivery = await prisma.delivery.update({
      where: { id: req.params.id },
      data: { status: 'delivered', deliveredAt: new Date() },
    });

    const order = await prisma.order.update({
      where: { id: delivery.orderId },
      data: { status: 'delivered' },
      include: { patient: true },
    });

    emitToOrder(delivery.orderId, 'order:status_change', { orderId: delivery.orderId, status: 'delivered' });
    await notificationService.send(
      order.patientId,
      'Order Delivered! 🎉',
      'Your order has been verified with your secret OTP and delivered successfully. Thank you for using PharmaLink!',
      'order'
    ).catch(() => {});

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

    res.json({ success: true, data: updatedDelivery, message: 'OTP verified! Delivery completed successfully.' });
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

const verifyDeliveryCode = async (req, res, next) => {
  try {
    const { code, otp } = req.body;
    const inputCode = (code || otp || '').toString().trim();
    if (!inputCode) {
      return res.status(400).json({
        success: false,
        message: 'Please provide either the 4-digit OTP or scanned QR code data.',
      });
    }

    const delivery = await prisma.delivery.findUnique({
      where: { id: req.params.id },
      include: { order: true },
    });
    if (!delivery) throw { status: 404, message: 'Delivery not found' };

    if (delivery.status === 'delivered') {
      return res.status(400).json({
        success: false,
        message: 'This delivery has already been completed.',
      });
    }

    const expectedOtp = (delivery.order?.otp || '').toString().trim();
    const expectedOrderId = (delivery.orderId || '').toString().trim();

    let extractedOtp = inputCode;
    if (inputCode.includes(':')) {
      const parts = inputCode.split(':');
      if (parts.length >= 4 && parts[3]) {
        extractedOtp = parts[3].trim();
      } else if (parts.length >= 2 && parts[1] && parts[1].trim() === expectedOrderId && expectedOtp) {
        extractedOtp = expectedOtp;
      }
    }

    const normalize = (v) => (v || '').toString().trim().toUpperCase().replace(/^(PK-|OTP-|PL)/, '');
    const cleanInput = normalize(extractedOtp);
    const cleanExpected = normalize(expectedOtp);

    const isMatch = (extractedOtp && extractedOtp === expectedOtp) ||
                    (cleanInput && cleanInput === cleanExpected) ||
                    (inputCode === `PHARMALINK_DELIVERY:${expectedOrderId}:${delivery.order?.patientId}:${expectedOtp}`);

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: 'Invalid OTP or QR code! Code does not match the patient\'s secret pass. Please ask the patient to check their PharmaLink app.',
      });
    }

    res.json({
      success: true,
      message: 'Code verified successfully! Proceed to digital signature.',
      data: {
        verified: true,
        orderId: delivery.orderId,
        deliveryId: delivery.id,
        otp: expectedOtp,
      },
    });
  } catch (err) { next(err); }
};

module.exports = {
  getDeliveries,
  acceptDelivery,
  confirmPickup,
  confirmDelivery,
  verifyDeliveryCode,
  uploadDeliveryPhoto,
  updateLocation,
  setOnlineStatus,
  getStatus,
  getEarnings,
  uploadDocuments,
};

