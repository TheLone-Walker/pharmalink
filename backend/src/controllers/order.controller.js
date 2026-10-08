const prisma = require('../config/db');
const { generateOTP, generatePickupCode, otpExpiresAt } = require('../utils/otp');
const notificationService = require('../services/notification.service');
const { emitToOrder } = require('../services/socket.service');

const createOrder = async (req, res, next) => {
  try {
    const { pharmacyId, orderType, items, deliveryAddress, deliveryLat, deliveryLng, prescriptionId, paymentMethod } = req.body;
    const patientId = req.user.id;

    if (!items || !Array.isArray(items) || items.length === 0) {
      throw { status: 400, message: 'Order items are required' };
    }

    // 1. Calculate total and verify stock & prescription status
    let totalFcfa = 0;
    const orderItems = [];
    const prescriptionRequiredMeds = [];

    for (const item of items) {
      const med = await prisma.medication.findUnique({ where: { id: item.medicationId } });
      if (!med) throw { status: 404, message: `Medication not found: ${item.medicationId}` };
      if (med.stockQuantity < item.quantity) {
        throw { status: 400, message: `Insufficient stock for ${med.name} (only ${med.stockQuantity} available)` };
      }
      if (med.requiresPrescription) {
        prescriptionRequiredMeds.push(med.name);
      }
      totalFcfa += parseFloat(med.priceFcfa) * item.quantity;
      orderItems.push({ medicationId: item.medicationId, quantity: item.quantity, unitPriceFcfa: med.priceFcfa });
    }

    // 2. STRICT PRESCRIPTION ENFORCEMENT & MEDICATION MATCHING
    if (prescriptionRequiredMeds.length > 0) {
      if (!prescriptionId) {
        return res.status(400).json({
          success: false,
          code: 'PRESCRIPTION_REQUIRED',
          message: `🚫 Prescription Required: "${prescriptionRequiredMeds.join(', ')}" is classified as a regulated prescription medication. You cannot purchase this medication without an active doctor's prescription. Please attach an issued prescription or book a consultation first.`,
          requiredMeds: prescriptionRequiredMeds,
        });
      }

      // Verify that prescription exists, belongs to patient, and is valid (not cancelled)
      const prescription = await prisma.prescription.findFirst({
        where: {
          id: prescriptionId,
          patientId,
          status: { in: ['issued', 'sent_to_pharmacy', 'fulfilled'] },
        },
        include: { doctor: { select: { name: true } }, items: true },
      });

      if (!prescription) {
        return res.status(400).json({
          success: false,
          code: 'INVALID_PRESCRIPTION',
          message: `The selected prescription is invalid or has not been verified by a certified doctor. Please provide a valid prescription.`,
        });
      }

      // Validate that the prescription actually mentions the medications being ordered!
      const rxItems = (prescription.items || []).map(i => (i.medicationName || '').toLowerCase().trim());
      const rxNotes = (prescription.notes || '').toLowerCase().trim();

      for (const reqMed of prescriptionRequiredMeds) {
        const medNameLower = reqMed.toLowerCase().trim();
        const baseName = medNameLower.split(' ')[0]; // e.g. "amoxicillin", "artemether"

        const isMatched = rxItems.some(item => 
          item.includes(medNameLower) || 
          medNameLower.includes(item) || 
          (baseName.length >= 4 && item.includes(baseName))
        ) || rxNotes.includes(medNameLower) || (baseName.length >= 4 && rxNotes.includes(baseName));

        if (!isMatched) {
          return res.status(400).json({
            success: false,
            code: 'PRESCRIPTION_MED_MISMATCH',
            message: `🚫 Prescription Mismatch: The selected prescription does not mention "${reqMed}". You cannot purchase this drug using an unrelated prescription where it is not prescribed.`,
          });
        }
      }
    }

    const rawOtp = generateOTP(4);
    const pickupCode = orderType === 'pickup' ? `PK-${rawOtp}` : null;
    const orderOtp = rawOtp;

    const order = await prisma.order.create({
      data: {
        patientId,
        pharmacyId,
        orderType,
        totalFcfa,
        deliveryAddress: deliveryAddress || (orderType === 'pickup' ? 'Pharmacy Counter Pickup' : 'Yaoundé, Cameroon'),
        deliveryLat: deliveryLat ? parseFloat(deliveryLat) : null,
        deliveryLng: deliveryLng ? parseFloat(deliveryLng) : null,
        pickupCode,
        otp: orderOtp,
        items: { create: orderItems },
      },
      include: {
        items: { include: { medication: true } },
        pharmacy: { include: { user: { select: { name: true, phone: true } } } },
        patient: { select: { name: true, phone: true, email: true } },
      },
    });

    // Notify pharmacy via socket and database notification
    const pharmacy = await prisma.pharmacistProfile.findUnique({ where: { id: pharmacyId } });
    if (pharmacy) {
      await notificationService.send(
        pharmacy.userId,
        'New Order Received! 📦',
        `New order #${order.id.slice(0, 8).toUpperCase()} from ${req.user.name || 'Patient'} (FCFA ${totalFcfa.toLocaleString()})`,
        'order',
        { orderId: order.id, totalFcfa }
      );
      const { emitToUser, emitToPharmacy, emitToRole } = require('../services/socket.service');
      emitToUser(pharmacy.userId, 'order:new', order);
      emitToPharmacy(pharmacy.id, 'order:new', order);
      emitToRole('pharmacist', 'order:new', order);
    }

    res.status(201).json({
      success: true,
      data: order,
      message: 'Order placed successfully',
    });
  } catch (err) { next(err); }
};

const getMyOrders = async (req, res, next) => {
  try {
    const { status } = req.query;
    const orders = await prisma.order.findMany({
      where: { patientId: req.user.id, ...(status && { status }) },
      include: { items: { include: { medication: true } }, pharmacy: true, delivery: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: orders });
  } catch (err) { next(err); }
};

const getOrderById = async (req, res, next) => {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: {
        items: { include: { medication: true } },
        pharmacy: { include: { user: { select: { name: true, phone: true } } } },
        delivery: { include: { driver: { include: { user: { select: { name: true, phone: true, profilePhotoUrl: true } } } } } },
      },
    });
    if (!order) throw { status: 404, message: 'Order not found' };
    res.json({ success: true, data: order });
  } catch (err) { next(err); }
};

const cancelOrder = async (req, res, next) => {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: { pharmacy: true },
    });
    if (!order) throw { status: 404, message: 'Order not found' };
    if (order.patientId !== req.user.id) throw { status: 403, message: 'Forbidden' };
    if (!['pending', 'confirmed'].includes(order.status)) {
      throw { status: 400, message: 'Cannot cancel order at this stage' };
    }
    const updated = await prisma.order.update({
      where: { id: req.params.id },
      data: { status: 'cancelled' },
    });
    
    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(order.id, 'order:status_change', { orderId: order.id, status: 'cancelled' });
    emitToUser(order.patientId, 'order:updated', updated);
    if (order.pharmacy?.userId) {
      emitToUser(order.pharmacy.userId, 'order:updated', updated);
    }

    res.json({ success: true, data: updated, message: 'Order cancelled' });
  } catch (err) { next(err); }
};

const updateStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    const order = await prisma.order.update({
      where: { id: req.params.id },
      data: { status },
      include: { pharmacy: true },
    });
    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(order.id, 'order:status_change', { orderId: order.id, status });
    emitToUser(order.patientId, 'order:updated', order);
    if (order.pharmacy?.userId) {
      emitToUser(order.pharmacy.userId, 'order:updated', order);
    }
    await notificationService.send(order.patientId, 'Order Update', `Your order is now: ${status}`, 'order');
    res.json({ success: true, data: order });
  } catch (err) { next(err); }
};

const generateOrderOtp = async (req, res, next) => {
  try {
    const otp = generateOTP(4);
    const expires = otpExpiresAt(15);
    const order = await prisma.order.update({
      where: { id: req.params.id },
      data: { otp, otpExpiresAt: expires },
    });
    res.json({ success: true, data: { otp, otpExpiresAt: expires } });
  } catch (err) { next(err); }
};

const verifyOrderOtp = async (req, res, next) => {
  try {
    const { otp } = req.body;
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: { delivery: true },
    });
    if (!order) throw { status: 404, message: 'Order not found' };
    if (!order.otp || order.otp !== otp.toString().trim()) {
      throw { status: 400, message: 'Invalid OTP code. Please check with your driver.' };
    }
    if (order.otpExpiresAt && new Date() > new Date(order.otpExpiresAt)) {
      throw { status: 400, message: 'OTP has expired (15-minute limit exceeded). Please ask driver to refresh.' };
    }
    // Clear OTP upon successful match
    await prisma.order.update({
      where: { id: order.id },
      data: { otp: null, otpExpiresAt: null },
    });
    res.json({ success: true, message: 'OTP verified successfully! Please provide your signature to complete delivery.' });
  } catch (err) { next(err); }
};

const uploadSignature = async (req, res, next) => {
  try {
    let url = null;
    if (req.file) {
      url = `/uploads/${req.file.filename}`;
    } else if (req.body.signatureBase64) {
      const fs = require('fs');
      const path = require('path');
      const base64Data = req.body.signatureBase64.replace(/^data:image\/\w+;base64,/, '');
      const filename = `sig_${Date.now()}_${req.params.id.slice(0, 6)}.png`;
      const uploadDir = path.join(__dirname, '../../uploads');
      if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
      fs.writeFileSync(path.join(uploadDir, filename), base64Data, 'base64');
      url = `/uploads/${filename}`;
    } else {
      url = `/uploads/default_signature_${req.params.id}.png`;
    }

    const order = await prisma.order.update({
      where: { id: req.params.id },
      data: { signatureUrl: url, status: 'delivered' },
      include: {
        delivery: { include: { driver: true } },
        pharmacy: true,
        patient: true,
      },
    });

    if (order.delivery) {
      await prisma.delivery.update({
        where: { id: order.delivery.id },
        data: { status: 'delivered', deliveredAt: new Date() },
      });

      // 10% driver commission recorded
      const commissionFcfa = Math.round(parseFloat(order.totalFcfa) * 0.1);
      if (order.delivery.driver) {
        await prisma.transaction.create({
          data: {
            userId: order.delivery.driver.userId,
            orderId: order.id,
            type: 'earning',
            amountFcfa: commissionFcfa,
            method: 'cash',
            status: 'success',
            reference: `DRV-${Date.now()}-${order.id.slice(0, 4)}`,
          },
        }).catch(() => {});

        await notificationService.send(
          order.delivery.driver.userId,
          'Delivery Completed! 💰',
          `Order #${order.id.slice(0, 8).toUpperCase()} delivered and signed. You earned FCFA ${commissionFcfa}!`,
          'delivery'
        ).catch(() => {});
      }
    }

    // Mark Pharmacy Payment as validated / completed
    await prisma.transaction.updateMany({
      where: { orderId: order.id, type: 'payment' },
      data: { status: 'success' },
    }).catch(() => {});

    // Notify Pharmacy Dashboard of validated payment & receipt
    if (order.pharmacy?.userId) {
      await notificationService.send(
        order.pharmacy.userId,
        'Payment Validated & Order Delivered! 💳',
        `Order #${order.id.slice(0, 8).toUpperCase()} has been delivered with verified patient signature. Payment of FCFA ${parseFloat(order.totalFcfa).toLocaleString()} has been validated.`,
        'order',
        { orderId: order.id, totalFcfa: order.totalFcfa, signatureUrl: url }
      ).catch(() => {});

      const { emitToUser } = require('../services/socket.service');
      emitToUser(order.pharmacy.userId, 'order:updated', { ...order, status: 'delivered', signatureUrl: url });
      emitToUser(order.pharmacy.userId, 'order:payment_validated', { orderId: order.id, totalFcfa: order.totalFcfa });
    }

    emitToOrder(order.id, 'order:status_change', { orderId: order.id, status: 'delivered', signatureUrl: url });
    await notificationService.send(order.patientId, 'Order Delivered & Signed! 🎉', 'Your order delivery has been confirmed with your signature. Thank you for using PharmaLink!', 'order').catch(() => {});

    res.json({
      success: true,
      data: { signatureUrl: url, status: 'delivered' },
      message: 'Delivery confirmed and signed successfully! Payment validated on pharmacy dashboard.',
    });
  } catch (err) { next(err); }
};

// GET /orders/:id/receipt — Generate official itemized digital receipt for all payment methods
const getOrderReceipt = async (req, res, next) => {
  try {
    const order = await prisma.order.findUnique({
      where: { id: req.params.id },
      include: {
        items: { include: { medication: true } },
        pharmacy: { include: { user: { select: { name: true, phone: true, email: true } } } },
        patient: { select: { id: true, name: true, phone: true, email: true } },
        transactions: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });

    if (!order) throw { status: 404, message: 'Order not found' };

    // Security check: only order patient, pharmacy, or admin can access receipt
    if (req.user.role === 'patient' && order.patientId !== req.user.id) {
      throw { status: 403, message: 'Unauthorized to view this receipt' };
    }

    const latestTx = order.transactions?.[0] || null;
    const paymentMethod = latestTx?.method || (order.orderType === 'pickup' ? 'cash_pickup' : 'cash');
    const paymentStatus = latestTx?.status === 'success' ? 'PAID' : (order.status === 'delivered' ? 'PAID' : 'CONFIRMED');

    const receiptNumber = `REC-${order.createdAt.getFullYear()}${String(order.createdAt.getMonth() + 1).padStart(2, '0')}-${order.id.slice(0, 6).toUpperCase()}`;

    // Itemized lines
    const itemsFormatted = order.items.map(item => ({
      name: item.medication?.name || 'Medication',
      quantity: item.quantity,
      unitPriceFcfa: parseFloat(item.unitPriceFcfa),
      subtotalFcfa: parseFloat(item.unitPriceFcfa) * item.quantity,
      requiresPrescription: item.medication?.requiresPrescription || false,
    }));

    const itemsSubtotal = itemsFormatted.reduce((acc, curr) => acc + curr.subtotalFcfa, 0);
    const deliveryFee = order.orderType === 'delivery' ? 1000 : 0;
    const totalFcfa = parseFloat(order.totalFcfa);

    const receipt = {
      receiptNumber,
      orderId: order.id,
      orderStatus: order.status,
      pickupCode: order.pickupCode || (order.otp ? `OTP-${order.otp}` : `PK-${order.id.slice(0, 4).toUpperCase()}`),
      issuedAt: order.createdAt.toISOString(),
      orderType: order.orderType,
      patient: {
        name: order.patient?.name || 'Patient',
        phone: order.patient?.phone || 'N/A',
        email: order.patient?.email || 'N/A',
      },
      pharmacy: {
        name: order.pharmacy?.pharmacyName || 'Pharmacie Centrale',
        address: order.pharmacy?.pharmacyAddress || 'Yaoundé, Cameroon',
        licenseNumber: order.pharmacy?.licenseNumber || 'ONPC-VERIFIED',
        phone: order.pharmacy?.user?.phone || '+237 6xx xxx xxx',
      },
      items: itemsFormatted,
      financials: {
        itemsSubtotal,
        deliveryFee,
        totalFcfa,
        currency: 'XAF / FCFA',
      },
      payment: {
        method: paymentMethod,
        methodLabel: paymentMethod === 'momo' ? 'MTN Mobile Money' : (paymentMethod === 'orange_money' ? 'Orange Money Cameroun' : (paymentMethod === 'card' ? 'Visa / Mastercard' : 'Cash (COD / Counter)')),
        status: paymentStatus,
        transactionReference: latestTx?.reference || `PL-${order.id.slice(0, 8).toUpperCase()}`,
        paidAt: latestTx?.createdAt ? latestTx.createdAt.toISOString() : order.createdAt.toISOString(),
      },
      security: {
        isOfficial: true,
        authority: 'PharmaLink National Digital Health Network (Cameroon)',
        verificationCode: `PL-CERT-${order.id.slice(0, 10)}-ONPC`,
        qrPayload: `PHARMALINK-RECEIPT:${receiptNumber}:${order.id}:${totalFcfa}:XAF:${paymentStatus}`,
      },
    };

    res.json({ success: true, data: receipt });
  } catch (err) { next(err); }
};

// PATCH /orders/:id/switch-to-pickup — Instant Switch to Counter Pickup Pass
const switchToPickup = async (req, res, next) => {
  try {
    const { id } = req.params;
    const order = await prisma.order.findUnique({
      where: { id },
      include: {
        pharmacy: true,
        patient: { select: { id: true, name: true, phone: true } },
        delivery: true,
      },
    });

    if (!order) throw { status: 404, message: 'Order not found' };
    if (order.status === 'delivered') {
      throw { status: 400, message: 'Order has already been delivered.' };
    }

    const pickupCode = order.pickupCode || generatePickupCode();

    // If a delivery was assigned but not yet delivered, cancel driver delivery
    if (order.delivery && order.delivery.status !== 'delivered') {
      await prisma.delivery.update({
        where: { id: order.delivery.id },
        data: { status: 'cancelled' },
      }).catch(() => {});
    }

    const updatedOrder = await prisma.order.update({
      where: { id },
      data: {
        orderType: 'pickup',
        pickupCode,
        driverProfileId: null,
      },
      include: {
        pharmacy: true,
        patient: { select: { id: true, name: true, phone: true } },
      },
    });

    // Notify pharmacy and patient via WebSocket
    const { emitToUser, emitToOrder } = require('../services/socket.service');
    emitToOrder(order.id, 'order:status_change', {
      orderId: order.id,
      orderType: 'pickup',
      pickupCode,
      message: 'Order switched to Counter Pickup Pass',
    });

    if (order.pharmacy?.userId) {
      emitToUser(order.pharmacy.userId, 'order:updated', updatedOrder);
      await notificationService.send(
        order.pharmacy.userId,
        '🏪 Switched to Counter Pickup',
        `Patient ${order.patient?.name || ''} switched Order #${order.id.slice(0, 8).toUpperCase()} to Instant In-Person Pickup. Pickup Pass: ${pickupCode}.`,
        'order',
        { orderId: order.id, pickupCode }
      ).catch(() => {});
    }

    emitToUser(order.patientId, 'order:updated', updatedOrder);

    await notificationService.send(
      order.patientId,
      '🏪 Counter Pickup Pass Activated!',
      `Your order is ready for instant counter collection with Pickup Pass: ${pickupCode}. Present your QR code at the counter.`,
      'order',
      { orderId: order.id, pickupCode }
    ).catch(() => {});

    res.json({
      success: true,
      data: {
        order: updatedOrder,
        pickupCode,
      },
      message: 'Switched to Instant Counter Pickup Pass! Present your QR pass at the pharmacy.',
    });
  } catch (err) { next(err); }
};

// POST /orders/:id/auto-assign — Auto-dispatch to nearest online courier
const autoAssignDriver = async (req, res, next) => {
  try {
    const { autoAssignNearestDriver } = require('../services/dispatch.service');
    const result = await autoAssignNearestDriver(req.params.id);
    res.json({
      success: true,
      data: result,
      message: result.assigned ? 'Nearest online driver dispatched!' : (result.reason || 'No drivers available'),
    });
  } catch (err) { next(err); }
};

module.exports = {
  createOrder,
  getMyOrders,
  getOrderById,
  getOrderReceipt,
  cancelOrder,
  updateStatus,
  generateOrderOtp,
  verifyOrderOtp,
  uploadSignature,
  switchToPickup,
  autoAssignDriver,
};

