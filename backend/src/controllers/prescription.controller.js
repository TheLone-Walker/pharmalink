const prisma = require('../config/db');
const notificationService = require('../services/notification.service');

// Issue Consultation & Prescription
const issue = async (req, res, next) => {
  try {
    const {
      patientId,
      appointmentId,
      symptoms,
      vitals,
      diagnosis,
      clinicalNotes,
      recommendations,
      pharmacistId,
      notes,
      items,
    } = req.body;

    if (!patientId) {
      return res.status(400).json({ success: false, message: 'patientId is required' });
    }

    const doctorUser = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { doctorProfile: true },
    });
    const doctorName = doctorUser?.name || 'Your Doctor';
    const hospitalName = doctorUser?.doctorProfile?.hospital || 'Clinic';

    // 1. Format consultation details for MedicalHistory
    const consultationDetails = {
      doctorName,
      hospitalName,
      symptoms: symptoms || '',
      vitals: vitals || {}, // { bp, temp, pulse, respRate, weight, height, bloodSugar }
      diagnosis: diagnosis || 'General Consultation',
      clinicalNotes: clinicalNotes || notes || '',
      recommendations: recommendations || '',
      prescribedMedications: (items || []).map(i => ({
        name: i.medicationName,
        dosage: i.dosage || '',
        instructions: i.instructions || '',
        durationDays: i.durationDays || 7,
      })),
      timestamp: new Date().toISOString(),
    };

    // 2. Save MedicalHistory for the patient
    const medicalHistory = await prisma.medicalHistory.create({
      data: {
        patientId,
        doctorId: req.user.id,
        diagnosis: diagnosis || 'General Medical Consultation',
        notes: JSON.stringify(consultationDetails),
        date: new Date(),
      },
    });

    // 3. Save Prescription (if medication items provided)
    let prescription = null;
    if (items && Array.isArray(items) && items.length > 0) {
      prescription = await prisma.prescription.create({
        data: {
          doctorId: req.user.id,
          patientId,
          pharmacistId: pharmacistId || null,
          notes: notes || clinicalNotes || diagnosis || 'Take as directed',
          status: pharmacistId ? 'sent_to_pharmacy' : 'issued',
          items: {
            create: items.map(i => ({
              medicationName: i.medicationName,
              dosage: i.dosage || '',
              instructions: i.instructions || '',
              durationDays: parseInt(i.durationDays, 10) || 7,
            })),
          },
        },
        include: {
          items: true,
          patient: { select: { name: true, phone: true, email: true } },
          doctor: { select: { name: true, phone: true } },
        },
      });

      // Automatically create active Medication Reminders for patient directly from Doctor prescription
      for (const item of items) {
        let reminderTime = item.reminderTime || item.reminderTimes || '';
        let frequency = item.frequency || item.period || '';
        const durationDays = parseInt(item.durationDays, 10) || 7;
        const mealTiming = item.mealTiming || '';

        if (!reminderTime) {
          const instr = ((item.instructions || '') + ' ' + (item.period || '')).toLowerCase();
          if (instr.includes('3 times') || instr.includes('3x') || instr.includes('tid') || instr.includes('8 hour') || instr.includes('three times') || instr.includes('noon') || instr.includes('afternoon')) {
            reminderTime = '08:00 AM, 01:00 PM, 08:00 PM';
            frequency = frequency || '3 Times Daily';
          } else if (instr.includes('4 times') || instr.includes('4x') || instr.includes('qid') || instr.includes('6 hour')) {
            reminderTime = '08:00 AM, 12:00 PM, 04:00 PM, 08:00 PM';
            frequency = frequency || '4 Times Daily';
          } else if (instr.includes('night') || instr.includes('bedtime') || instr.includes('evening') || instr.includes('hs')) {
            reminderTime = '09:00 PM';
            frequency = frequency || 'Once Daily (Night)';
          } else if (instr.includes('once') || instr.includes('1x') || instr.includes('morning') || instr.includes('daily') || instr.includes('qd')) {
            reminderTime = '08:00 AM';
            frequency = frequency || 'Once Daily (Morning)';
          } else {
            reminderTime = '08:00 AM, 08:00 PM';
            frequency = frequency || 'Twice Daily (Morning & Evening)';
          }
        }

        const fullFrequency = `${frequency}${mealTiming ? ' • ' + mealTiming : ''} • ${durationDays} Days Treatment`;

        try {
          await prisma.reminder.create({
            data: {
              patientId,
              medicationName: item.medicationName,
              dosage: item.dosage || '1 dose',
              frequency: fullFrequency,
              reminderTime: reminderTime,
              isActive: true,
            },
          });
        } catch (_) {}
      }

      // Notify patient about new prescription & auto-configured reminders
      await notificationService.send(
        patientId,
        'Prescription & Medication Reminders Configured ⏰',
        `Dr. ${doctorName} issued your prescription. Pill reminders have been directly synced to your Drug Reminder schedule for ${items.length} medication(s).`,
        'prescription'
      ).catch(() => {});

      const { emitToUser } = require('../services/socket.service');
      emitToUser(patientId, 'prescription:new', prescription);
      if (pharmacistId) {
        emitToUser(pharmacistId, 'prescription:new', prescription);
      }
    }

    // 4. If an appointment was linked, mark it as completed
    if (appointmentId) {
      await prisma.appointment.update({
        where: { id: appointmentId },
        data: { status: 'completed' },
      }).catch(() => {});
      const { emitToUser } = require('../services/socket.service');
      emitToUser(patientId, 'appointment:updated', { id: appointmentId, status: 'completed' });
      emitToUser(req.user.id, 'appointment:updated', { id: appointmentId, status: 'completed' });
    }

    // 5. Send consultation notification to patient
    await notificationService.send(
      patientId,
      'Consultation Completed',
      `Dr. ${doctorName} at ${hospitalName} has completed your consultation and updated your medical history.`,
      'consultation'
    );

    const { emitToUser } = require('../services/socket.service');
    emitToUser(patientId, 'medical_history:new', medicalHistory);

    res.status(201).json({
      success: true,
      message: 'Consultation recorded and prescription issued successfully',
      data: {
        medicalHistory,
        prescription,
      },
    });
  } catch (err) {
    next(err);
  }
};

// Get My Prescriptions (with full doctor and pharmacy profile details)
const getMyPrescriptions = async (req, res, next) => {
  try {
    const role = req.user.role;
    let whereClause = {};

    if (role === 'patient') {
      whereClause = { patientId: req.user.id };
    } else if (role === 'doctor') {
      whereClause = { doctorId: req.user.id };
    } else if (role === 'pharmacist') {
      whereClause = {
        OR: [
          { pharmacistId: req.user.id },
          { status: 'sent_to_pharmacy' }, // allow pharmacy to see pending fulfillments if needed
        ],
      };
    }

    const prescriptions = await prisma.prescription.findMany({
      where: whereClause,
      include: {
        items: true,
        doctor: {
          select: {
            id: true,
            name: true,
            phone: true,
            email: true,
            doctorProfile: { select: { hospital: true, specialty: true } },
          },
        },
        patient: {
          select: {
            id: true,
            name: true,
            phone: true,
            email: true,
            patientProfile: { select: { bloodType: true, address: true, allergies: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Attach pharmacy details if pharmacistId exists
    const pharmacistIds = prescriptions.map(p => p.pharmacistId).filter(Boolean);
    let pharmacyMap = {};
    if (pharmacistIds.length > 0) {
      const profiles = await prisma.pharmacistProfile.findMany({
        where: {
          OR: [
            { userId: { in: pharmacistIds } },
            { id: { in: pharmacistIds } },
          ],
        },
        include: { user: { select: { name: true, phone: true } } },
      });
      for (const p of profiles) {
        pharmacyMap[p.userId] = p;
        pharmacyMap[p.id] = p;
      }
    }

    const enriched = prescriptions.map(p => ({
      ...p,
      pharmacyDetails: p.pharmacistId ? (pharmacyMap[p.pharmacistId] || null) : null,
    }));

    res.json({ success: true, data: enriched });
  } catch (err) {
    next(err);
  }
};

// Patient sends prescription to pharmacy of their choice
const sendToPharmacy = async (req, res, next) => {
  try {
    const { id } = req.params;
    const {
      pharmacyId,
      pharmacistUserId,
      orderType = 'pickup', // 'pickup' | 'delivery'
      paymentMethod = 'cash', // 'momo' | 'orange_money' | 'card' | 'cash'
      deliveryAddress,
      deliveryLat,
      deliveryLng,
      notes,
    } = req.body;

    const prescription = await prisma.prescription.findUnique({
      where: { id },
      include: { patient: true, items: true },
    });

    if (!prescription) {
      return res.status(404).json({ success: false, message: 'Prescription not found' });
    }

    // Identify target pharmacist & pharmacy profile
    let targetUserId = pharmacistUserId;
    let pharmacyProfile = null;

    if (pharmacyId) {
      pharmacyProfile = await prisma.pharmacistProfile.findUnique({
        where: { id: pharmacyId },
        include: { user: true, medications: true },
      });
      if (pharmacyProfile) {
        targetUserId = pharmacyProfile.userId;
      }
    } else if (pharmacistUserId) {
      pharmacyProfile = await prisma.pharmacistProfile.findUnique({
        where: { userId: pharmacistUserId },
        include: { user: true, medications: true },
      });
    }

    if (!pharmacyProfile) {
      pharmacyProfile = await prisma.pharmacistProfile.findFirst({
        include: { user: true, medications: true },
      });
      targetUserId = pharmacyProfile?.userId;
    }

    // Update prescription
    const updatedPrescription = await prisma.prescription.update({
      where: { id },
      data: {
        pharmacistId: targetUserId,
        status: 'sent_to_pharmacy',
        notes: notes ? `${prescription.notes || ''} | Note: ${notes}` : prescription.notes,
      },
      include: {
        items: true,
        doctor: { select: { name: true } },
        patient: { select: { name: true, phone: true } },
      },
    });

    // Calculate order total and match inventory medication items
    let totalFcfa = 0;
    const orderItemsData = [];

    const availableMeds = pharmacyProfile?.medications || [];
    for (const pItem of prescription.items) {
      const pNameLower = pItem.medicationName.toLowerCase();
      // Find matching inventory med
      const matched = availableMeds.find(m => m.name.toLowerCase().includes(pNameLower) || pNameLower.includes(m.name.toLowerCase()))
        || availableMeds[0];

      if (matched) {
        const unitPrice = parseFloat(matched.priceFcfa || 1500);
        totalFcfa += unitPrice;
        orderItemsData.push({
          medicationId: matched.id,
          quantity: 1,
          unitPriceFcfa: unitPrice,
        });
      }
    }

    // Generate 4-digit OTP for verification / validation
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const pickupCode = orderType === 'pickup' ? `PK-${Math.floor(1000 + Math.random() * 9000)}` : null;
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h validity

    // Create the official Order
    const order = await prisma.order.create({
      data: {
        patientId: prescription.patientId,
        pharmacyId: pharmacyProfile.id,
        orderType: orderType === 'delivery' ? 'delivery' : 'pickup',
        status: 'pending',
        totalFcfa,
        deliveryAddress: deliveryAddress || prescription.patient?.patientProfile?.address || 'Yaoundé, Cameroon',
        deliveryLat: deliveryLat ? parseFloat(deliveryLat) : (pharmacyProfile.lat || 3.8480),
        deliveryLng: deliveryLng ? parseFloat(deliveryLng) : (pharmacyProfile.lng || 11.5021),
        pickupCode: pickupCode || `OTP-${otp}`,
        otp,
        otpExpiresAt: expiresAt,
        items: {
          create: orderItemsData,
        },
      },
      include: {
        items: { include: { medication: true } },
        pharmacy: true,
        patient: { select: { name: true, phone: true } },
      },
    });

    // Create payment transaction
    const isOnlinePaid = ['momo', 'orange_money', 'card'].includes(paymentMethod);
    await prisma.transaction.create({
      data: {
        userId: prescription.patientId,
        orderId: order.id,
        type: 'payment',
        amountFcfa: totalFcfa,
        method: paymentMethod === 'orange_money' ? 'orange_money' : paymentMethod === 'card' ? 'card' : paymentMethod === 'momo' ? 'momo' : 'cash',
        status: isOnlinePaid ? 'success' : 'pending',
        reference: `PAY-RX-${order.id.slice(0, 8).toUpperCase()}-${Date.now().toString().slice(-4)}`,
      },
    });

    const pharmacyName = pharmacyProfile?.pharmacyName || 'Selected Pharmacy';
    const fulfillmentLabel = orderType === 'delivery' ? 'Home Delivery (Pay on Delivery / Online)' : 'Pickup at Pharmacy';

    // Notify Pharmacist with new Order alert
    if (targetUserId) {
      await notificationService.send(
        targetUserId,
        `New Order #${order.id.slice(0, 8).toUpperCase()} from Prescription`,
        `Patient ${prescription.patient?.name} sent an Rx order (${prescription.items.length} meds, ${totalFcfa} FCFA). Fulfillment: ${fulfillmentLabel}.`,
        'order'
      );
    }

    // Notify Patient with OTP verification details
    await notificationService.send(
      prescription.patientId,
      'Order & Prescription Sent to Pharmacy',
      `Order placed at ${pharmacyName}! Verification OTP: ${otp}. Total: ${totalFcfa} FCFA. ${fulfillmentLabel}.`,
      'order'
    );

    res.json({
      success: true,
      message: `Prescription & Order sent to ${pharmacyName} successfully`,
      data: {
        prescription: updatedPrescription,
        order,
        otp,
        pickupCode: order.pickupCode,
        totalFcfa,
        pharmacyDetails: pharmacyProfile,
      },
    });
  } catch (err) {
    next(err);
  }
};

// Pharmacist fulfills prescription
const fulfill = async (req, res, next) => {
  try {
    const prescription = await prisma.prescription.update({
      where: { id: req.params.id },
      data: { status: 'fulfilled' },
    });
    await notificationService.send(
      prescription.patientId,
      'Prescription Ready / Fulfilled',
      'Your prescription has been fulfilled by the pharmacy and is ready for pickup or delivery.',
      'prescription'
    );
    res.json({ success: true, data: prescription });
  } catch (err) {
    next(err);
  }
};

// Get Medical History (for patient or doctor)
const getMedicalHistory = async (req, res, next) => {
  try {
    const role = req.user.role;
    let targetPatientId = req.user.id;

    if (role === 'doctor' || role === 'admin') {
      if (req.query.patientId) {
        targetPatientId = req.query.patientId;
      }
    }

    const history = await prisma.medicalHistory.findMany({
      where: { patientId: targetPatientId },
      include: {
        patient: { select: { name: true, phone: true, email: true, patientProfile: true } },
      },
      orderBy: { date: 'desc' },
    });

    // Also get doctor names if doctorId exists
    const doctorIds = history.map(h => h.doctorId).filter(Boolean);
    let doctorMap = {};
    if (doctorIds.length > 0) {
      const doctors = await prisma.user.findMany({
        where: { id: { in: doctorIds } },
        include: { doctorProfile: true },
      });
      for (const d of doctors) {
        doctorMap[d.id] = {
          name: d.name,
          hospital: d.doctorProfile?.hospital || 'Yaoundé Central Hospital',
          specialty: d.doctorProfile?.specialty || 'General Medicine',
          phone: d.phone,
        };
      }
    }

    const parsedHistory = history.map(h => {
      let parsedNotes = {};
      try {
        parsedNotes = JSON.parse(h.notes || '{}');
      } catch (_) {
        parsedNotes = { rawText: h.notes };
      }

      return {
        id: h.id,
        patientId: h.patientId,
        doctorId: h.doctorId,
        doctor: h.doctorId ? doctorMap[h.doctorId] || null : null,
        diagnosis: h.diagnosis,
        notes: h.notes,
        consultationData: parsedNotes,
        date: h.date,
        patient: h.patient,
      };
    });

    res.json({ success: true, data: parsedHistory });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  issue,
  getMyPrescriptions,
  sendToPharmacy,
  fulfill,
  getMedicalHistory,
};
