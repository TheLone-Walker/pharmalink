const prisma = require('../config/db');
const notificationService = require('./notification.service');
const { emitToOrder, emitToUser, emitToRole, emitToPharmacy } = require('./socket.service');
const { generateOTP, otpExpiresAt } = require('../utils/otp');

/**
 * Calculates geospatial distance in kilometers using the Haversine formula
 */
function calcDistanceKm(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return 1.5;
  const R = 6371; // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return parseFloat((R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))).toFixed(2));
}

/**
 * Automatically searches for and assigns the nearest online approved driver to an order
 */
async function autoAssignNearestDriver(orderId) {
  try {
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        pharmacy: { include: { user: { select: { id: true, name: true, phone: true } } } },
        patient: { select: { id: true, name: true, phone: true, email: true } },
        items: { include: { medication: true } },
        delivery: true,
      },
    });

    if (!order) return { assigned: false, reason: 'Order not found' };
    if (order.orderType === 'pickup') return { assigned: false, reason: 'Order is pickup, not delivery' };
    if (order.status === 'delivered' || order.status === 'cancelled') {
      return { assigned: false, reason: `Order is already ${order.status}` };
    }

    const pharmacyLat = order.pharmacy?.lat || 3.8480; // Default Yaoundé
    const pharmacyLng = order.pharmacy?.lng || 11.5021;

    // 1. Fetch all online & approved drivers
    const onlineDrivers = await prisma.driverProfile.findMany({
      where: {
        approvalStatus: 'approved',
        isOnline: true,
      },
      include: {
        user: { select: { id: true, name: true, phone: true, profilePhotoUrl: true } },
        _count: { select: { deliveries: true } },
      },
    });

    if (onlineDrivers.length === 0) {
      console.log(`[Dispatch] No online drivers available for order #${orderId.slice(0, 8)}`);
      return { assigned: false, reason: 'No approved drivers are currently online' };
    }

    // 2. Compute distance to each driver and sort closest first
    const rankedDrivers = onlineDrivers.map(d => {
      const dLat = d.currentLat || pharmacyLat;
      const dLng = d.currentLng || pharmacyLng;
      const distanceKm = calcDistanceKm(pharmacyLat, pharmacyLng, dLat, dLng);
      return {
        ...d,
        distanceKm,
      };
    }).sort((a, b) => a.distanceKm - b.distanceKm);

    const nearestDriver = rankedDrivers[0];

    // 3. Generate secure handover OTP
    const otp = generateOTP(4);
    const expires = otpExpiresAt(30);

    // 4. Update Order and Delivery in Database
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        driverProfileId: nearestDriver.id,
        status: 'out_for_delivery',
        otp,
        otpExpiresAt: expires,
      },
      include: {
        pharmacy: true,
        patient: { select: { id: true, name: true, phone: true } },
      },
    });

    const delivery = await prisma.delivery.upsert({
      where: { orderId },
      create: {
        orderId,
        driverId: nearestDriver.id,
        status: 'assigned',
        pickupLat: pharmacyLat,
        pickupLng: pharmacyLng,
        dropoffLat: order.deliveryLat || pharmacyLat,
        dropoffLng: order.deliveryLng || pharmacyLng,
        startedAt: new Date(),
      },
      update: {
        driverId: nearestDriver.id,
        status: 'assigned',
        startedAt: new Date(),
      },
    });

    // 5. Real-time WebSocket Broadcasts
    emitToUser(nearestDriver.userId, 'delivery:new', {
      orderId,
      deliveryId: delivery.id,
      pharmacyName: order.pharmacy?.pharmacyName || 'Pharmacy',
      pharmacyAddress: order.pharmacy?.address || 'Yaoundé',
      deliveryAddress: order.deliveryAddress,
      distanceKm: nearestDriver.distanceKm,
      totalFcfa: order.totalFcfa,
    });

    emitToOrder(orderId, 'order:status_change', {
      orderId,
      status: 'out_for_delivery',
      driver: {
        id: nearestDriver.id,
        name: nearestDriver.user?.name || 'Assigned Driver',
        phone: nearestDriver.user?.phone,
        vehicleInfo: nearestDriver.vehicleInfo,
      },
      otpExpiresAt: expires,
    });

    if (order.pharmacy?.userId) {
      emitToUser(order.pharmacy.userId, 'order:updated', updatedOrder);
    }

    emitToUser(order.patientId, 'order:updated', updatedOrder);

    // 6. Push Notifications
    await notificationService.send(
      nearestDriver.userId,
      '🚴 New Express Delivery Request!',
      `Order #${orderId.slice(0, 8).toUpperCase()} from ${order.pharmacy?.pharmacyName || 'Pharmacy'} (${nearestDriver.distanceKm} km away). Pickup now!`,
      'delivery',
      { orderId, deliveryId: delivery.id }
    ).catch(() => {});

    await notificationService.send(
      order.patientId,
      '🚴 Driver Assigned to Your Order!',
      `${nearestDriver.user?.name || 'A courier'} has been dispatched to pick up your medication from ${order.pharmacy?.pharmacyName || 'the pharmacy'}.`,
      'delivery',
      { orderId }
    ).catch(() => {});

    console.log(`[Dispatch] Successfully auto-assigned Driver ${nearestDriver.user?.name} (${nearestDriver.distanceKm}km away) to Order #${orderId.slice(0, 8)}`);

    return {
      assigned: true,
      driver: {
        id: nearestDriver.id,
        name: nearestDriver.user?.name,
        phone: nearestDriver.user?.phone,
        distanceKm: nearestDriver.distanceKm,
      },
      delivery,
      order: updatedOrder,
    };
  } catch (err) {
    console.error('[Dispatch Error] Failed to auto-assign driver:', err);
    return { assigned: false, error: err.message };
  }
}

module.exports = {
  autoAssignNearestDriver,
  calcDistanceKm,
};
