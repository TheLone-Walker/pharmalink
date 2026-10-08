const prisma = require('../config/db');
const notificationService = require('../services/notification.service');
const { generateOTP, otpExpiresAt } = require('../utils/otp');

const getInventory = async (req, res, next) => {
  try {
    const profile = await prisma.pharmacistProfile.findUnique({ where: { userId: req.user.id } });
    if (!profile) throw { status: 404, message: 'Pharmacist profile not found' };
    const meds = await prisma.medication.findMany({
      where: { pharmacyId: profile.id },
      orderBy: { name: 'asc' },
    });
    res.json({ success: true, data: meds });
  } catch (err) { next(err); }
};

const addMedication = async (req, res, next) => {
  try {
    const profile = await prisma.pharmacistProfile.findUnique({ where: { userId: req.user.id } });
    const { name, description, priceFcfa, stockQuantity, category, requiresPrescription } = req.body;
    const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;
    const med = await prisma.medication.create({
      data: {
        pharmacyId: profile.id,
        name,
        description,
        priceFcfa: parseFloat(priceFcfa),
        stockQuantity: parseInt(stockQuantity),
        category,
        requiresPrescription: requiresPrescription === 'true' || requiresPrescription === true,
        imageUrl,
      },
    });
    res.status(201).json({ success: true, data: med });
  } catch (err) { next(err); }
};

const updateMedication = async (req, res, next) => {
  try {
    const { name, description, priceFcfa, stockQuantity, category } = req.body;
    const med = await prisma.medication.update({
      where: { id: req.params.id },
      data: {
        ...(name && { name }),
        ...(description && { description }),
        ...(priceFcfa && { priceFcfa: parseFloat(priceFcfa) }),
        ...(stockQuantity !== undefined && { stockQuantity: parseInt(stockQuantity) }),
        ...(category && { category }),
      },
    });
    res.json({ success: true, data: med });
  } catch (err) { next(err); }
};

const deleteMedication = async (req, res, next) => {
  try {
    await prisma.medication.delete({ where: { id: req.params.id } });
    res.json({ success: true, message: 'Medication deleted' });
  } catch (err) { next(err); }
};

// Get all orders for this pharmacy with rich details
const getOrders = async (req, res, next) => {
  try {
    const profile = await prisma.pharmacistProfile.findUnique({ where: { userId: req.user.id } });
    if (!profile) throw { status: 404, message: 'Pharmacist profile not found' };

    const orders = await prisma.order.findMany({
      where: { pharmacyId: profile.id },
      include: {
        items: { include: { medication: true } },
        patient: {
          select: {
            id: true,
            name: true,
            phone: true,
            email: true,
            profilePhotoUrl: true,
            patientProfile: { select: { address: true, bloodType: true, allergies: true } },
          },
        },
        driver: {
          include: {
            user: { select: { id: true, name: true, phone: true, profilePhotoUrl: true } },
          },
        },
        delivery: {
          include: {
            driver: {
              include: { user: { select: { name: true, phone: true } } },
            },
          },
        },
        transactions: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ success: true, data: orders });
  } catch (err) { next(err); }
};

// Validate / Confirm Order
const confirmOrder = async (req, res, next) => {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: { patient: true, pharmacy: true },
    });
    if (!order) throw { status: 404, message: 'Order not found' };

    const updated = await prisma.order.update({
      where: { id: req.params.id },
      data: { status: 'confirmed' },
      include: { patient: true, pharmacy: true },
    });

    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(order.id, 'order:status_change', { orderId: order.id, status: 'confirmed' });
    emitToUser(order.patientId, 'order:updated', updated);

    await notificationService.send(
      order.patientId,
      'Order Confirmed by Pharmacy',
      `Your order #${order.id.slice(0, 8).toUpperCase()} has been verified & confirmed by ${order.pharmacy?.pharmacyName || 'the pharmacy'}. Preparation is underway.`,
      'order'
    );

    res.json({ success: true, data: updated, message: 'Order validated & confirmed successfully' });
  } catch (err) { next(err); }
};

// Mark Order as Preparing / Ready
const markReady = async (req, res, next) => {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: { patient: true, pharmacy: true },
    });
    if (!order) throw { status: 404, message: 'Order not found' };

    // Orders marked ready are set to 'preparing' (packaged & awaiting counter handover or courier)
    // NEVER automatically mark as 'picked_up' without counter OTP validation!
    const newStatus = 'preparing';
    const updated = await prisma.order.update({
      where: { id: req.params.id },
      data: { status: newStatus },
      include: { patient: true, pharmacy: true },
    });

    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(order.id, 'order:status_change', { orderId: order.id, status: newStatus });
    emitToUser(order.patientId, 'order:updated', updated);

    if (order.orderType === 'pickup') {
      const code = order.pickupCode || (order.otp ? `PK-${order.otp}` : 'your pass code');
      await notificationService.send(
        order.patientId,
        'Medications Ready for Counter Pickup',
        `Your medications are packaged and ready for pickup at ${order.pharmacy?.pharmacyName || 'the pharmacy'}. Please present your pickup code (${code}) at the counter.`,
        'order'
      );
    }

    res.json({
      success: true,
      message: order.orderType === 'pickup'
        ? 'Medications packaged & ready for pickup. Customer notified to present OTP at counter.'
        : 'Order marked as preparing.',
      data: updated,
    });
  } catch (err) { next(err); }
};

// Update order status explicitly
const updateOrderStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    const existing = await prisma.order.findUnique({ where: { id: req.params.id } });
    if (!existing) throw { status: 404, message: 'Order not found' };

    if (existing.orderType === 'pickup' && status === 'picked_up') {
      return res.status(400).json({
        success: false,
        message: 'Pickup orders cannot be completed without OTP verification. Please verify the patient\'s counter OTP pass.',
      });
    }

    const order = await prisma.order.update({
      where: { id: req.params.id },
      data: { status },
      include: { patient: true },
    });

    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(order.id, 'order:status_change', { orderId: order.id, status });
    emitToUser(order.patientId, 'order:updated', order);

    await notificationService.send(
      order.patientId,
      'Order Status Update',
      `Your order is now: ${status.replace(/_/g, ' ').toUpperCase()}`,
      'order'
    );

    res.json({ success: true, data: order });
  } catch (err) { next(err); }
};

// Get Available Delivery Drivers with live status and distance
const getAvailableDrivers = async (req, res, next) => {
  try {
    const profile = await prisma.pharmacistProfile.findUnique({ where: { userId: req.user.id } });
    const pharmacyLat = profile?.lat || 3.8480;
    const pharmacyLng = profile?.lng || 11.5021;

    const drivers = await prisma.driverProfile.findMany({
      where: { approvalStatus: 'approved' },
      include: {
        user: { select: { id: true, name: true, phone: true, email: true, profilePhotoUrl: true } },
        _count: { select: { deliveries: true } },
      },
    });

    // Helper for distance in km
    function calcDist(lat1, lon1, lat2, lon2) {
      if (!lat1 || !lon1 || !lat2 || !lon2) return 1.5;
      const R = 6371;
      const dLat = ((lat2 - lat1) * Math.PI) / 180;
      const dLon = ((lon2 - lon1) * Math.PI) / 180;
      const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos((lat1 * Math.PI) / 180) *
          Math.cos((lat2 * Math.PI) / 180) *
          Math.sin(dLon / 2) ** 2;
      return parseFloat((R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(1));
    }

    const formatted = drivers.map(d => {
      const dLat = d.currentLat || pharmacyLat + (Math.random() - 0.5) * 0.03;
      const dLng = d.currentLng || pharmacyLng + (Math.random() - 0.5) * 0.03;
      const distanceKm = calcDist(pharmacyLat, pharmacyLng, dLat, dLng);

      return {
        id: d.id,
        userId: d.userId,
        name: d.user?.name || 'Delivery Driver',
        phone: d.user?.phone || '+237 6xx xxx xxx',
        email: d.user?.email,
        profilePhotoUrl: d.user?.profilePhotoUrl,
        vehicleInfo: d.vehicleInfo || 'Motorbike CG 125',
        isOnline: d.isOnline ?? true,
        currentLat: dLat,
        currentLng: dLng,
        distanceKm,
        totalDeliveries: d._count.deliveries || 0,
        rating: 4.8 + (Math.random() * 0.2),
      };
    });

    // Sort: Online first, then nearest distance
    formatted.sort((a, b) => {
      if (b.isOnline !== a.isOnline) return (b.isOnline ? 1 : 0) - (a.isOnline ? 1 : 0);
      return a.distanceKm - b.distanceKm;
    });

    res.json({ success: true, data: formatted });
  } catch (err) { next(err); }
};

// Pharmacist assigns a chosen delivery driver to the order
const assignDriver = async (req, res, next) => {
  try {
    const { driverProfileId } = req.body;
    const { id: orderId } = req.params;

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: { patient: true, pharmacy: true },
    });
    if (!order) throw { status: 404, message: 'Order not found' };

    const driver = await prisma.driverProfile.findUnique({
      where: { id: driverProfileId },
      include: { user: true },
    });
    if (!driver) throw { status: 404, message: 'Driver not found' };

    // Update Order with driver and status
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        driverProfileId: driver.id,
        status: 'out_for_delivery',
      },
    });

    // Create or update Delivery record
    const delivery = await prisma.delivery.upsert({
      where: { orderId },
      create: {
        orderId,
        driverId: driver.id,
        status: 'assigned',
        pickupLat: order.pharmacy?.lat || 3.8480,
        pickupLng: order.pharmacy?.lng || 11.5021,
        dropoffLat: order.deliveryLat || 3.8480,
        dropoffLng: order.deliveryLng || 11.5021,
        startedAt: new Date(),
      },
      update: {
        driverId: driver.id,
        status: 'assigned',
        startedAt: new Date(),
      },
    });

    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(orderId, 'order:status_change', { orderId, status: 'out_for_delivery' });
    emitToUser(driver.userId, 'delivery:new', { order: updatedOrder, delivery, driver });
    emitToUser(order.patientId, 'order:updated', updatedOrder);

    // Notify Driver
    await notificationService.send(
      driver.userId,
      'New Delivery Assignment',
      `You have been assigned to deliver Order #${order.id.slice(0, 8).toUpperCase()} from ${order.pharmacy?.pharmacyName} to ${order.patient?.name}.`,
      'delivery'
    );

    // Notify Patient
    await notificationService.send(
      order.patientId,
      'Driver Assigned & En Route',
      `Driver ${driver.user?.name} (${driver.vehicleInfo || 'Motorbike'}) has been assigned to pick up and deliver your order.`,
      'order'
    );

    res.json({
      success: true,
      message: `Driver ${driver.user?.name} assigned successfully.`,
      data: { order: updatedOrder, delivery, driver },
    });
  } catch (err) { next(err); }
};

// Verify Customer Pickup OTP Code at the Counter
const verifyPickupOtp = async (req, res, next) => {
  try {
    const { otp } = req.body;
    const { id: orderId } = req.params;

    if (!otp || typeof otp !== 'string' || !otp.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Please provide the patient\'s pickup OTP / Pass code.',
      });
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: { patient: true, pharmacy: true },
    });
    if (!order) throw { status: 404, message: 'Order not found' };

    if (order.status === 'picked_up' || order.status === 'delivered') {
      return res.status(400).json({
        success: false,
        message: 'This order has already been verified and handed over.',
      });
    }

    // Normalize codes for flexible matching:
    // Support formats: "4821", "PK-4821", "pk-4821", "OTP-4821", "PL4821"
    const normalize = (v) => (v || '').toString().trim().toUpperCase().replace(/^(PK-|OTP-|PL)/, '');
    const inputClean = normalize(otp);
    const inputRaw = otp.toString().trim().toUpperCase();

    const orderOtpClean = normalize(order.otp);
    const orderCodeClean = normalize(order.pickupCode);
    const orderOtpRaw = (order.otp || '').toString().trim().toUpperCase();
    const orderCodeRaw = (order.pickupCode || '').toString().trim().toUpperCase();

    const matchesRaw = (inputRaw === orderCodeRaw && orderCodeRaw.length > 0) ||
                       (inputRaw === orderOtpRaw && orderOtpRaw.length > 0);
    const matchesClean = (inputClean.length >= 3 && (inputClean === orderOtpClean || inputClean === orderCodeClean));

    if (!matchesRaw && !matchesClean) {
      return res.status(400).json({
        success: false,
        message: `Invalid pickup OTP. The code provided does not match customer ${order.patient?.name || ''}'s pickup pass.`,
      });
    }

    const updated = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: order.orderType === 'pickup' ? 'picked_up' : 'delivered',
      },
      include: { patient: true, pharmacy: true },
    });

    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(orderId, 'order:status_change', { orderId, status: updated.status });
    emitToUser(order.patientId, 'order:updated', updated);

    await notificationService.send(
      order.patientId,
      'Order Handover Completed',
      `Your pickup verification at ${order.pharmacy?.pharmacyName || 'the pharmacy'} succeeded! Medications handed over. Thank you for using PharmaLink!`,
      'order'
    );

    res.json({
      success: true,
      message: 'Patient pickup OTP verified successfully! Order marked as picked up.',
      data: updated,
    });
  } catch (err) { next(err); }
};

// Comprehensive Sales Analytics
const getSalesAnalytics = async (req, res, next) => {
  try {
    const profile = await prisma.pharmacistProfile.findUnique({ where: { userId: req.user.id } });
    if (!profile) throw { status: 404, message: 'Pharmacist profile not found' };

    const { range = 'month' } = req.query;
    const now = new Date();
    let startDate = new Date();

    if (range === 'today') {
      startDate.setHours(0, 0, 0, 0);
    } else if (range === 'week') {
      startDate.setDate(now.getDate() - 7);
    } else if (range === 'month') {
      startDate.setMonth(now.getMonth() - 1);
    } else {
      startDate.setFullYear(now.getFullYear() - 1);
    }

    const allOrders = await prisma.order.findMany({
      where: {
        pharmacyId: profile.id,
        createdAt: { gte: startDate },
      },
      include: {
        items: { include: { medication: true } },
        transactions: true,
        patient: { select: { name: true, phone: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const completedOrders = allOrders.filter(o => ['delivered', 'picked_up', 'confirmed', 'preparing', 'out_for_delivery'].includes(o.status));
    const totalSales = completedOrders.reduce((sum, o) => sum + parseFloat(o.totalFcfa || 0), 0);
    const avgOrderValue = completedOrders.length > 0 ? Math.round(totalSales / completedOrders.length) : 0;

    // Delivery vs Pickup breakdown
    const pickupCount = completedOrders.filter(o => o.orderType === 'pickup').length;
    const deliveryCount = completedOrders.filter(o => o.orderType === 'delivery').length;

    // Payment methods breakdown
    const paymentMethods = { momo: 0, orange_money: 0, card: 0, cash: 0 };
    completedOrders.forEach(o => {
      if (o.transactions && o.transactions.length > 0) {
        const method = o.transactions[0].method || 'momo';
        paymentMethods[method] = (paymentMethods[method] || 0) + parseFloat(o.totalFcfa || 0);
      } else {
        paymentMethods['cash'] = (paymentMethods['cash'] || 0) + parseFloat(o.totalFcfa || 0);
      }
    });

    // Top selling medications
    const productStats = {};
    completedOrders.forEach(o => {
      o.items.forEach(i => {
        const name = i.medication?.name || 'Medication';
        if (!productStats[name]) {
          productStats[name] = { name, unitsSold: 0, revenueFcfa: 0, category: i.medication?.category || 'General' };
        }
        productStats[name].unitsSold += i.quantity;
        productStats[name].revenueFcfa += parseFloat(i.unitPriceFcfa || 0) * i.quantity;
      });
    });

    const topProducts = Object.values(productStats)
      .sort((a, b) => b.unitsSold - a.unitsSold)
      .slice(0, 8);

    res.json({
      success: true,
      data: {
        totalSales,
        orderCount: completedOrders.length,
        totalOrdersPlaced: allOrders.length,
        avgOrderValue,
        pickupCount,
        deliveryCount,
        paymentMethods,
        topProducts,
        recentOrders: allOrders.slice(0, 10),
      },
    });
  } catch (err) { next(err); }
};

const uploadLicense = async (req, res, next) => {
  try {
    const { licenseNumber, pharmacyName, pharmacyAddress, pharmacyCategory } = req.body;
    if (!req.file && !licenseNumber) {
      throw { status: 400, message: 'Please provide either an ONPC license number or upload a license document.' };
    }
    const url = req.file ? `/uploads/${req.file.filename}` : undefined;

    const cleanLic = licenseNumber ? licenseNumber.trim() : undefined;
    if (cleanLic) {
      const existing = await prisma.pharmacistProfile.findFirst({
        where: {
          licenseNumber: cleanLic,
          userId: { not: req.user.id },
        },
      });
      if (existing) {
        throw { status: 409, message: 'This ONPC pharmacy license number is already registered to another pharmacy account.' };
      }
    }

    const updated = await prisma.pharmacistProfile.update({
      where: { userId: req.user.id },
      data: {
        ...(url && { licenseDocUrl: url }),
        ...(cleanLic && { licenseNumber: cleanLic }),
        ...(pharmacyName && { pharmacyName }),
        ...(pharmacyAddress && { pharmacyAddress }),
        ...(pharmacyCategory && { pharmacyCategory }),
        approvalStatus: 'pending',
        isOnpcVerified: false,
        rejectionReason: null,
      },
      include: { user: true },
    });

    // Notify admins of new pending pharmacist/pharmacy verification
    const admins = await prisma.user.findMany({ where: { role: 'admin' }, select: { id: true } });
    if (admins.length > 0) {
      await notificationService.sendToMany(
        admins.map(a => a.id),
        'Pharmacist ONPC License Pending Verification',
        `Pharmacy ${updated.pharmacyName || updated.user?.name || 'Pharmacy'} uploaded license (${updated.licenseNumber || 'License attached'}). Cross-check with ONPC records to review.`,
        'admin'
      );
    }

    res.json({ success: true, message: 'Pharmacy license uploaded successfully. Pending admin review.', data: updated });
  } catch (err) { next(err); }
};

module.exports = {
  getInventory,
  addMedication,
  updateMedication,
  deleteMedication,
  getOrders,
  confirmOrder,
  markReady,
  updateOrderStatus,
  getAvailableDrivers,
  assignDriver,
  verifyPickupOtp,
  getSalesAnalytics,
  uploadLicense,
};
