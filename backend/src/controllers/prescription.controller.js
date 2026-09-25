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

    const enriched = prescriptions.map(p => {
      let parsed = {};
      try {
        parsed = JSON.parse(p.notes || '{}');
      } catch (_) {
        parsed = { rawNotes: p.notes };
      }

      const validationStatus = parsed.validationStatus || (p.status === 'fulfilled' ? 'approved' : (p.status === 'sent_to_pharmacy' ? 'pending' : (p.status === 'issued' ? 'issued' : p.status)));

      return {
        ...p,
        validationStatus,
        documentUrl: parsed.documentUrl || null,
        doctorName: parsed.doctorName || (p.doctor ? `Dr. ${p.doctor.name}` : 'Attending Physician'),
        hospital: parsed.hospital || p.doctor?.doctorProfile?.hospital || 'Partner Hospital / Clinic',
        rejectionReason: parsed.rejectionReason || null,
        patientNotes: parsed.patientNotes || parsed.clientNotes || null,
        pharmacyDetails: p.pharmacistId ? (pharmacyMap[p.pharmacistId] || null) : null,
      };
    });

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

// ─── Lab Analysis Workflow ──────────────────────────────────────────────────

/**
 * Doctor requests laboratory analysis before issuing prescription
 */
const requestLabAnalysis = async (req, res, next) => {
  try {
    const {
      patientId,
      appointmentId,
      symptoms,
      vitals,
      preliminaryDiagnosis,
      clinicalNotes,
      labTests, // e.g. ['Malaria RDT', 'CBC/NFS', 'Widal Test', 'Fasting Blood Sugar']
      urgency,  // 'routine' | 'urgent' | 'stat'
      instructions,
    } = req.body;

    if (!patientId) {
      return res.status(400).json({ success: false, message: 'patientId is required' });
    }

    if (!labTests || !Array.isArray(labTests) || labTests.length === 0) {
      return res.status(400).json({ success: false, message: 'At least one lab test must be requested' });
    }

    const doctorUser = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { doctorProfile: true },
    });
    const doctorName = doctorUser?.name || 'Dr. Specialist';
    const hospitalName = doctorUser?.doctorProfile?.hospital || 'PharmaLink Partner Clinic';

    const labRequestData = {
      type: 'lab_analysis_request',
      doctorName,
      hospitalName,
      doctorId: req.user.id,
      appointmentId: appointmentId || null,
      symptoms: symptoms || '',
      vitals: vitals || {},
      preliminaryDiagnosis: preliminaryDiagnosis || 'Investigation Pending',
      clinicalNotes: clinicalNotes || '',
      labTests: labTests.map(t => typeof t === 'string' ? { name: t, status: 'pending' } : t),
      urgency: urgency || 'routine',
      instructions: instructions || 'Please visit an accredited medical laboratory or clinic to perform the requested tests and upload your results here.',
      labStatus: 'pending_results',
      requestedAt: new Date().toISOString(),
    };

    const medicalHistory = await prisma.medicalHistory.create({
      data: {
        patientId,
        doctorId: req.user.id,
        diagnosis: `🔬 Lab Investigation Required: ${preliminaryDiagnosis || 'Clinical Assessment'}`,
        notes: JSON.stringify(labRequestData),
        date: new Date(),
      },
    });

    if (appointmentId) {
      await prisma.appointment.update({
        where: { id: appointmentId },
        data: { status: 'confirmed' }, // Keep active/confirmed until lab results return
      }).catch(() => {});
    }

    // Send high-priority notification to patient
    const testsSummary = labTests.map(t => typeof t === 'string' ? t : t.name).slice(0, 3).join(', ');
    await notificationService.send(
      patientId,
      '🔬 Lab Tests Required Before Prescription',
      `Dr. ${doctorName} has ordered lab analyses (${testsSummary}${labTests.length > 3 ? '...' : ''}) to confirm your diagnosis before issuing medications.`,
      'lab_request'
    ).catch(() => {});

    const { emitToUser } = require('../services/socket.service');
    emitToUser(patientId, 'lab:request', { historyId: medicalHistory.id, labRequestData });

    res.status(201).json({
      success: true,
      data: { id: medicalHistory.id, ...labRequestData },
      message: 'Laboratory test request has been sent to the patient.',
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Patient submits laboratory test results
 */
const submitLabResults = async (req, res, next) => {
  try {
    const { historyId } = req.params;
    const { resultsText, labName, testDate, fileUrls, findings } = req.body;

    const record = await prisma.medicalHistory.findUnique({
      where: { id: historyId },
      include: { patient: { select: { name: true, phone: true } } },
    });

    if (!record) {
      return res.status(404).json({ success: false, message: 'Lab request record not found' });
    }

    let parsed = {};
    try {
      parsed = JSON.parse(record.notes || '{}');
    } catch (_) {}

    parsed.labStatus = 'results_submitted';
    parsed.labResults = {
      resultsText: resultsText || findings || '',
      labName: labName || 'Certified Clinical Laboratory',
      testDate: testDate || new Date().toISOString(),
      fileUrls: fileUrls || [],
      submittedAt: new Date().toISOString(),
    };

    const updated = await prisma.medicalHistory.update({
      where: { id: historyId },
      data: {
        diagnosis: `🔬 Lab Results Submitted: ${parsed.preliminaryDiagnosis || 'Review Pending'}`,
        notes: JSON.stringify(parsed),
      },
    });

    // Notify doctor
    if (record.doctorId) {
      const patientName = record.patient?.name || 'Patient';
      await notificationService.send(
        record.doctorId,
        '🔬 Lab Results Submitted by Patient',
        `${patientName} has submitted laboratory test results for your review. You can now finalize their diagnosis and prescription.`,
        'lab_results'
      ).catch(() => {});

      const { emitToUser } = require('../services/socket.service');
      emitToUser(record.doctorId, 'lab:results_submitted', { historyId, updated });
    }

    res.json({
      success: true,
      data: updated,
      message: 'Lab results submitted successfully. Your doctor has been notified.',
    });
  } catch (err) {
    next(err);
  }
};

/**
 * Get Lab Requests (for Doctor and Patient)
 */
const getLabRequests = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;

    const where = role === 'doctor' ? { doctorId: userId } : { patientId: userId };
    const history = await prisma.medicalHistory.findMany({
      where,
      include: {
        patient: { select: { name: true, phone: true, email: true } },
      },
      orderBy: { date: 'desc' },
    });

    const labRequests = [];
    for (const h of history) {
      try {
        const parsed = JSON.parse(h.notes || '{}');
        if (parsed.type === 'lab_analysis_request' || parsed.labTests || parsed.labStatus) {
          labRequests.push({
            historyId: h.id,
            patientId: h.patientId,
            doctorId: h.doctorId,
            patientName: h.patient?.name,
            diagnosis: h.diagnosis,
            date: h.date,
            ...parsed,
          });
        }
      } catch (_) {}
    }

    res.json({ success: true, data: labRequests });
  } catch (err) {
    next(err);
  }
};

// Patient uploads physical doctor prescription (image/PDF) and sends to pharmacy for validation & order creation
const uploadAndSend = async (req, res, next) => {
  try {
    const patientId = req.user.id;
    let documentUrl = null;

    if (req.file) {
      documentUrl = `/uploads/${req.file.filename}`;
    } else if (req.body.documentUrl) {
      documentUrl = req.body.documentUrl;
    } else if (req.body.documentBase64) {
      const fs = require('fs');
      const path = require('path');
      const base64Data = req.body.documentBase64.replace(/^data:\w+\/\w+;base64,/, '');
      const filename = `rx_${Date.now()}_${patientId.slice(0, 6)}.png`;
      const uploadDir = path.join(__dirname, '../../uploads');
      if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
      fs.writeFileSync(path.join(uploadDir, filename), base64Data, 'base64');
      documentUrl = `/uploads/${filename}`;
    }

    const {
      pharmacyId,
      doctorName = 'External Attending Physician',
      hospital = 'General Hospital / Partner Clinic',
      notes,
      orderType = 'pickup',
      deliveryAddress,
      deliveryLat,
      deliveryLng,
    } = req.body;

    if (!pharmacyId) {
      return res.status(400).json({ success: false, message: 'Target pharmacyId is required' });
    }

    let items = req.body.items;
    if (typeof items === 'string') {
      try { items = JSON.parse(items); } catch (_) { items = [{ medicationName: items }]; }
    }
    if (!items || !Array.isArray(items) || items.length === 0) {
      items = [{ medicationName: 'Prescribed Medications (See attached Rx document)', dosage: 'As directed', instructions: 'Per prescription', durationDays: 7 }];
    }

    // Find pharmacy profile and titular pharmacist user
    const pharmacyProfile = await prisma.pharmacistProfile.findUnique({
      where: { id: pharmacyId },
      include: { user: true, medications: true },
    });

    if (!pharmacyProfile) {
      return res.status(404).json({ success: false, message: 'Selected pharmacy not found' });
    }

    // Doctor reference
    let doctorId = req.body.doctorId;
    if (!doctorId) {
      const firstDoctor = await prisma.user.findFirst({ where: { role: 'doctor' } });
      doctorId = firstDoctor?.id || req.user.id;
    }

    const metadata = {
      documentUrl,
      doctorName,
      hospital,
      validationStatus: 'pending',
      validationReason: null,
      orderType,
      deliveryAddress: deliveryAddress || 'Yaoundé, Cameroon',
      patientNotes: notes || '',
      uploadedAt: new Date().toISOString(),
    };

    // 1. Create the Prescription record
    const prescription = await prisma.prescription.create({
      data: {
        doctorId,
        patientId,
        pharmacistId: pharmacyProfile.userId,
        status: 'sent_to_pharmacy',
        notes: JSON.stringify(metadata),
        items: {
          create: items.map(i => ({
            medicationName: i.medicationName || 'Prescribed Drug',
            dosage: i.dosage || '1 dose',
            instructions: i.instructions || 'Per Doctor Rx',
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

    // 2. Match inventory medications to calculate order total
    let totalFcfa = 0;
    const orderItemsData = [];
    const availableMeds = pharmacyProfile.medications || [];

    for (const pItem of items) {
      const pNameLower = (pItem.medicationName || '').toLowerCase();
      const matched = availableMeds.find(m => m.name.toLowerCase().includes(pNameLower) || pNameLower.includes(m.name.toLowerCase())) || availableMeds[0];

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
    if (totalFcfa === 0) totalFcfa = 2500; // default initial estimate until pharmacist validates

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const pickupCode = orderType === 'pickup' ? `PK-${Math.floor(1000 + Math.random() * 9000)}` : null;

    // 3. Create the linked Order in 'pending' status requiring pharmacist validation
    const order = await prisma.order.create({
      data: {
        patientId,
        pharmacyId: pharmacyProfile.id,
        orderType: orderType === 'delivery' ? 'delivery' : 'pickup',
        status: 'pending',
        totalFcfa,
        deliveryAddress: deliveryAddress || (orderType === 'pickup' ? 'Pharmacy Counter Pickup' : 'Yaoundé, Cameroon'),
        deliveryLat: deliveryLat ? parseFloat(deliveryLat) : (pharmacyProfile.lat || 3.8480),
        deliveryLng: deliveryLng ? parseFloat(deliveryLng) : (pharmacyProfile.lng || 11.5021),
        pickupCode: pickupCode || `OTP-${otp}`,
        otp,
        items: {
          create: orderItemsData.length > 0 ? orderItemsData : (availableMeds[0] ? [{ medicationId: availableMeds[0].id, quantity: 1, unitPriceFcfa: availableMeds[0].priceFcfa }] : []),
        },
      },
      include: {
        items: { include: { medication: true } },
        pharmacy: true,
      },
    });

    // 4. Send high-priority notification to Pharmacist
    await notificationService.send(
      pharmacyProfile.userId,
      '📄 New Prescription Uploaded — Validation Required',
      `Patient ${req.user.name || 'Patient'} uploaded a doctor's prescription for ${pharmacyProfile.pharmacyName}. Please review and validate the document before order fulfillment.`,
      'prescription'
    ).catch(() => {});

    const { emitToUser, emitToRole } = require('../services/socket.service');
    emitToUser(pharmacyProfile.userId, 'prescription:validation_pending', { prescription, order });
    emitToRole('pharmacist', 'prescription:validation_pending', { prescription, order });

    res.status(201).json({
      success: true,
      message: 'Prescription uploaded and sent to pharmacist for validation.',
      data: {
        prescription,
        order,
        validationStatus: 'pending',
        pharmacy: pharmacyProfile,
      },
    });
  } catch (err) {
    next(err);
  }
};

// Pharmacist validates (Approves or Rejects) a prescription
const validatePrescription = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { action, reason, notes: pharmacistNotes } = req.body; // action: 'approve' | 'reject'

    const prescription = await prisma.prescription.findUnique({
      where: { id },
      include: {
        patient: { select: { id: true, name: true, phone: true } },
        items: true,
      },
    });

    if (!prescription) {
      return res.status(404).json({ success: false, message: 'Prescription not found' });
    }

    let parsed = {};
    try {
      parsed = JSON.parse(prescription.notes || '{}');
    } catch (_) {
      parsed = { rawNotes: prescription.notes };
    }

    const pharmacistUser = req.user;
    const pharmacyProfile = await prisma.pharmacistProfile.findUnique({
      where: { userId: pharmacistUser.id },
    });
    const pharmacyName = pharmacyProfile?.pharmacyName || 'Pharmacie';

    if (action === 'approve') {
      parsed.validationStatus = 'approved';
      parsed.validatedAt = new Date().toISOString();
      parsed.validatedBy = pharmacistUser.name || 'Pharmacist';
      parsed.pharmacistNotes = pharmacistNotes || 'Verified & approved by licensed pharmacist';

      const updatedPrescription = await prisma.prescription.update({
        where: { id },
        data: {
          status: 'approved',
          notes: JSON.stringify(parsed),
        },
        include: { items: true, patient: true },
      });

      // Find and confirm any linked pending order
      const pendingOrder = await prisma.order.findFirst({
        where: {
          patientId: prescription.patientId,
          pharmacyId: pharmacyProfile?.id || undefined,
          status: 'pending',
        },
        orderBy: { createdAt: 'desc' },
      });

      let updatedOrder = null;
      if (pendingOrder) {
        updatedOrder = await prisma.order.update({
          where: { id: pendingOrder.id },
          data: { status: 'confirmed' },
          include: { items: { include: { medication: true } }, pharmacy: true },
        });
      }

      // Send high-priority notification to patient
      await notificationService.send(
        prescription.patientId,
        '✅ Prescription Validated by Pharmacist!',
        `${pharmacyName} has verified and APPROVED your prescription. Your medication is approved for payment and preparation.`,
        'prescription'
      ).catch(() => {});

      const { emitToUser } = require('../services/socket.service');
      emitToUser(prescription.patientId, 'prescription:approved', { prescription: updatedPrescription, order: updatedOrder });

      return res.json({
        success: true,
        message: 'Prescription validated and approved successfully.',
        data: {
          prescription: updatedPrescription,
          order: updatedOrder,
          validationStatus: 'approved',
        },
      });
    } else if (action === 'reject') {
      parsed.validationStatus = 'rejected';
      parsed.rejectedAt = new Date().toISOString();
      parsed.rejectedBy = pharmacistUser.name || 'Pharmacist';
      parsed.rejectionReason = reason || 'Prescription document is invalid, illegible, or expired';

      const updatedPrescription = await prisma.prescription.update({
        where: { id },
        data: {
          status: 'cancelled',
          notes: JSON.stringify(parsed),
        },
        include: { items: true, patient: true },
      });

      // Cancel any pending linked order
      const pendingOrder = await prisma.order.findFirst({
        where: {
          patientId: prescription.patientId,
          pharmacyId: pharmacyProfile?.id || undefined,
          status: 'pending',
        },
        orderBy: { createdAt: 'desc' },
      });

      if (pendingOrder) {
        await prisma.order.update({
          where: { id: pendingOrder.id },
          data: { status: 'cancelled' },
        }).catch(() => {});
      }

      // Notify patient with exact reason
      await notificationService.send(
        prescription.patientId,
        '❌ Prescription Verification Failed',
        `${pharmacyName} could not validate your prescription: ${parsed.rejectionReason}. Please upload a clearer document or consult a doctor.`,
        'prescription'
      ).catch(() => {});

      const { emitToUser } = require('../services/socket.service');
      emitToUser(prescription.patientId, 'prescription:rejected', { prescription: updatedPrescription, reason: parsed.rejectionReason });

      return res.json({
        success: true,
        message: 'Prescription has been marked as rejected.',
        data: {
          prescription: updatedPrescription,
          validationStatus: 'rejected',
          reason: parsed.rejectionReason,
        },
      });
    } else {
      return res.status(400).json({ success: false, message: 'Invalid action. Must be "approve" or "reject".' });
    }
  } catch (err) {
    next(err);
  }
};

module.exports = {
  issue,
  getMyPrescriptions,
  sendToPharmacy,
  uploadAndSend,
  validatePrescription,
  fulfill,
  getMedicalHistory,
  requestLabAnalysis,
  submitLabResults,
  getLabRequests,
};


