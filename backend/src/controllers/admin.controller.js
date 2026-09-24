const prisma = require('../config/db');
const notificationService = require('../services/notification.service');

const getUsers = async (req, res, next) => {
  try {
    const { role, page = 1, limit = 20 } = req.query;
    const users = await prisma.user.findMany({
      where: { ...(role && { role }) },
      select: { id: true, name: true, email: true, phone: true, role: true, isActive: true, isVerified: true, createdAt: true },
      skip: (parseInt(page) - 1) * parseInt(limit),
      take: parseInt(limit),
      orderBy: { createdAt: 'desc' },
    });
    const total = await prisma.user.count({ where: { ...(role && { role }) } });
    res.json({ success: true, data: { users, total, page: parseInt(page), limit: parseInt(limit) } });
  } catch (err) { next(err); }
};

const setUserActive = async (req, res, next) => {
  try {
    const isActive = req.path.includes('activate');
    const user = await prisma.user.update({ where: { id: req.params.id }, data: { isActive } });
    const { emitToUser } = require('../services/socket.service');
    emitToUser(user.id, 'user:refresh', { userId: user.id });
    res.json({ success: true, data: user, message: `User ${isActive ? 'activated' : 'deactivated'}` });
  } catch (err) { next(err); }
};

const getPendingLicenses = async (req, res, next) => {
  try {
    const rawDoctors = await prisma.doctorProfile.findMany({
      where: { approvalStatus: 'pending' },
      include: {
        user: { select: { id: true, name: true, email: true, phone: true, profilePhotoUrl: true } },
      },
      orderBy: { id: 'desc' },
    });

    const rawPharmacists = await prisma.pharmacistProfile.findMany({
      where: { approvalStatus: 'pending' },
      include: {
        user: { select: { id: true, name: true, email: true, phone: true, profilePhotoUrl: true } },
      },
      orderBy: { id: 'desc' },
    });

    const drivers = await prisma.driverProfile.findMany({
      where: { approvalStatus: 'pending' },
      include: {
        user: { select: { id: true, name: true, email: true, phone: true, profilePhotoUrl: true } },
      },
      orderBy: { id: 'desc' },
    });

    // Cross-check Doctors against ONMC Registry
    const doctors = await Promise.all(
      rawDoctors.map(async (doc) => {
        let registryMatch = null;
        if (doc.licenseNumber) {
          const matched = await prisma.onmcRegistry.findUnique({
            where: { licenseNumber: doc.licenseNumber.trim() },
          });
          if (matched) {
            registryMatch = {
              found: true,
              fullName: matched.fullName,
              specialty: matched.specialty,
              hospital: matched.hospital,
              region: matched.region,
              status: matched.status,
            };
          } else {
            registryMatch = { found: false };
          }
        } else {
          registryMatch = { found: false };
        }
        return { ...doc, registryMatch };
      })
    );

    // Cross-check Pharmacists against ONPC Registry
    const pharmacists = await Promise.all(
      rawPharmacists.map(async (pharm) => {
        let registryMatch = null;
        if (pharm.licenseNumber) {
          const matched = await prisma.onpcRegistry.findUnique({
            where: { licenseNumber: pharm.licenseNumber.trim() },
          });
          if (matched) {
            registryMatch = {
              found: true,
              pharmacyName: matched.pharmacyName,
              titularPharmacist: matched.titularPharmacist,
              address: matched.address,
              region: matched.region,
              status: matched.status,
            };
          } else {
            registryMatch = { found: false };
          }
        } else {
          registryMatch = { found: false };
        }
        return { ...pharm, registryMatch };
      })
    );

    res.json({ success: true, data: { doctors, pharmacists, drivers } });
  } catch (err) { next(err); }
};

const reviewLicense = async (req, res, next) => {
  try {
    const { profileType, status, reason, saveToRegistry = true } = req.body;
    const id = req.params.id;
    let updated, userId, notifTitle, notifMsg;

    const isApproved = status === 'approved';

    if (profileType === 'doctor') {
      // Find existing profile to check registry match for hospital & specialty backfill
      const existingProfile = await prisma.doctorProfile.findUnique({
        where: { id },
        include: { user: true },
      });

      let hospitalToSet = existingProfile?.hospital;
      let specialtyToSet = existingProfile?.specialty;

      if (isApproved && existingProfile?.licenseNumber) {
        const onmcMatch = await prisma.onmcRegistry.findUnique({
          where: { licenseNumber: existingProfile.licenseNumber },
        });
        if (onmcMatch) {
          hospitalToSet = hospitalToSet || onmcMatch.hospital;
          specialtyToSet = specialtyToSet || onmcMatch.specialty;
        }
      }

      updated = await prisma.doctorProfile.update({
        where: { id },
        data: {
          approvalStatus: status,
          isOnmcVerified: isApproved,
          ...(hospitalToSet && { hospital: hospitalToSet }),
          ...(specialtyToSet && { specialty: specialtyToSet }),
          rejectionReason: isApproved ? null : (reason || 'License credentials could not be verified with ONMC records'),
        },
        include: { user: true },
      });
      userId = updated.userId;
      
      if (isApproved) {
        await prisma.user.update({ where: { id: userId }, data: { isVerified: true } });
        
        // Ensure default Monday-Friday working hours if not set yet
        const existingAvail = await prisma.doctorAvailability.count({ where: { doctorId: id } });
        if (existingAvail === 0) {
          await prisma.doctorAvailability.createMany({
            data: [0, 1, 2, 3, 4].map((dayOfWeek) => ({
              doctorId: id,
              dayOfWeek,
              startTime: '08:00',
              endTime: '17:00',
              isAvailable: true,
            })),
          });
        }
        
        // Auto-upsert into official ONMC registry if requested
        if (saveToRegistry && updated.licenseNumber) {
          await prisma.onmcRegistry.upsert({
            where: { licenseNumber: updated.licenseNumber },
            create: {
              licenseNumber: updated.licenseNumber,
              fullName: updated.user?.name || 'Dr. Practitioner',
              specialty: updated.specialty || 'General Practitioner',
              hospital: updated.hospital || 'Hôpital Central de Yaoundé',
              region: 'Centre (Yaoundé)',
              status: 'active',
              registeredYear: new Date().getFullYear(),
            },
            update: {
              fullName: updated.user?.name || undefined,
              specialty: updated.specialty || undefined,
              hospital: updated.hospital || undefined,
              status: 'active',
            },
          });
        }

        notifTitle = 'ONMC License Verified & Approved';
        notifMsg = `Congratulations Dr. ${updated.user?.name || ''}! Your ONMC license is verified. You are now active and available for patient consultations at ${updated.hospital || 'your hospital'}.`;
      } else {
        notifTitle = 'ONMC License Verification Rejected';
        notifMsg = `Your medical license could not be approved. Reason: ${reason || 'Document mismatch or invalid registry entry'}. Please check your credentials and re-upload your license.`;
      }
    } else if (profileType === 'pharmacist') {
      updated = await prisma.pharmacistProfile.update({
        where: { id },
        data: {
          approvalStatus: status,
          isOnpcVerified: isApproved,
          rejectionReason: isApproved ? null : (reason || 'Pharmacy license could not be verified with ONPC records'),
        },
        include: { user: true },
      });
      userId = updated.userId;

      if (isApproved) {
        await prisma.user.update({ where: { id: userId }, data: { isVerified: true } });

        // Auto-upsert into official ONPC registry if requested or missing
        if (saveToRegistry && updated.licenseNumber) {
          await prisma.onpcRegistry.upsert({
            where: { licenseNumber: updated.licenseNumber },
            create: {
              licenseNumber: updated.licenseNumber,
              pharmacyName: updated.pharmacyName || 'Authorized Pharmacy',
              titularPharmacist: updated.user?.name || 'Titular Pharmacist',
              address: updated.pharmacyAddress || 'Yaoundé, Cameroon',
              category: updated.pharmacyCategory || 'Officine',
              region: 'Centre (Yaoundé)',
              status: 'active',
              authorizedYear: new Date().getFullYear(),
            },
            update: {
              pharmacyName: updated.pharmacyName || undefined,
              titularPharmacist: updated.user?.name || undefined,
              address: updated.pharmacyAddress || undefined,
              status: 'active',
            },
          });
        }

        notifTitle = 'ONPC License Verified & Approved';
        notifMsg = 'Your pharmacy license has been verified against official ONPC registry records! Your pharmacy is now approved and open on PharmaLink.';
      } else {
        notifTitle = 'ONPC License Verification Rejected';
        notifMsg = `Your pharmacy license could not be approved. Reason: ${reason || 'Document mismatch or invalid registry entry'}. Please review and re-upload your valid license.`;
      }
    } else if (profileType === 'driver') {
      updated = await prisma.driverProfile.update({
        where: { id },
        data: {
          approvalStatus: status,
          rejectionReason: isApproved ? null : (reason || 'Driver documents could not be verified'),
        },
      });
      userId = updated.userId;
      if (isApproved) {
        await prisma.user.update({ where: { id: userId }, data: { isVerified: true } });
        notifTitle = 'Driver Profile Approved';
        notifMsg = 'Your driver license and documents have been verified. You can now go online to receive delivery requests!';
      } else {
        notifTitle = 'Driver Verification Rejected';
        notifMsg = `Your driver documents were not approved. Reason: ${reason || 'Invalid documents'}. Please re-upload your credentials.`;
      }
    } else {
      throw { status: 400, message: 'Invalid profileType. Expected doctor, pharmacist, or driver.' };
    }

    // Send push / in-app notification to the professional
    await notificationService.send(userId, notifTitle, notifMsg, 'admin', {
      profileType,
      approvalStatus: status,
      isApproved,
      rejectionReason: isApproved ? null : reason,
    });

    const { emitToUser } = require('../services/socket.service');
    emitToUser(userId, 'user:refresh', { userId });

    res.json({
      success: true,
      message: `Profile ${status} successfully.`,
      data: updated,
    });
  } catch (err) { next(err); }
};

// ─── ONMC & ONPC Registry Management Controllers ─────────────────────────────
const getOnmcRegistry = async (req, res, next) => {
  try {
    const { q, page = 1, limit = 50 } = req.query;
    const where = q
      ? {
          OR: [
            { licenseNumber: { contains: q, mode: 'insensitive' } },
            { fullName: { contains: q, mode: 'insensitive' } },
            { specialty: { contains: q, mode: 'insensitive' } },
            { hospital: { contains: q, mode: 'insensitive' } },
          ],
        }
      : {};

    const records = await prisma.onmcRegistry.findMany({
      where,
      skip: (parseInt(page) - 1) * parseInt(limit),
      take: parseInt(limit),
      orderBy: { fullName: 'asc' },
    });
    const total = await prisma.onmcRegistry.count({ where });

    res.json({ success: true, data: { records, total, page: parseInt(page), limit: parseInt(limit) } });
  } catch (err) { next(err); }
};

const addOnmcDoctor = async (req, res, next) => {
  try {
    const { licenseNumber, fullName, specialty, hospital, region, status, registeredYear } = req.body;
    if (!licenseNumber || !fullName) throw { status: 400, message: 'License number and Full Name are required' };

    const record = await prisma.onmcRegistry.upsert({
      where: { licenseNumber },
      create: { licenseNumber, fullName, specialty, hospital, region: region || 'Centre (Yaoundé)', status: status || 'active', registeredYear: parseInt(registeredYear) || new Date().getFullYear() },
      update: { fullName, specialty, hospital, region, status, registeredYear: parseInt(registeredYear) || undefined },
    });

    res.status(201).json({ success: true, data: record, message: 'Doctor added to ONMC official registry.' });
  } catch (err) { next(err); }
};

const getOnpcRegistry = async (req, res, next) => {
  try {
    const { q, page = 1, limit = 50 } = req.query;
    const where = q
      ? {
          OR: [
            { licenseNumber: { contains: q, mode: 'insensitive' } },
            { pharmacyName: { contains: q, mode: 'insensitive' } },
            { titularPharmacist: { contains: q, mode: 'insensitive' } },
            { address: { contains: q, mode: 'insensitive' } },
          ],
        }
      : {};

    const records = await prisma.onpcRegistry.findMany({
      where,
      skip: (parseInt(page) - 1) * parseInt(limit),
      take: parseInt(limit),
      orderBy: { pharmacyName: 'asc' },
    });
    const total = await prisma.onpcRegistry.count({ where });

    res.json({ success: true, data: { records, total, page: parseInt(page), limit: parseInt(limit) } });
  } catch (err) { next(err); }
};

const addOnpcPharmacy = async (req, res, next) => {
  try {
    const { licenseNumber, pharmacyName, titularPharmacist, address, category, region, status, authorizedYear } = req.body;
    if (!licenseNumber || !pharmacyName) throw { status: 400, message: 'License number and Pharmacy Name are required' };

    const record = await prisma.onpcRegistry.upsert({
      where: { licenseNumber },
      create: { licenseNumber, pharmacyName, titularPharmacist: titularPharmacist || 'Pharmacien Titulaire', address: address || 'Yaoundé', category: category || 'Officine', region: region || 'Centre (Yaoundé)', status: status || 'active', authorizedYear: parseInt(authorizedYear) || new Date().getFullYear() },
      update: { pharmacyName, titularPharmacist, address, category, region, status, authorizedYear: parseInt(authorizedYear) || undefined },
    });

    res.status(201).json({ success: true, data: record, message: 'Pharmacy added to ONPC official registry.' });
  } catch (err) { next(err); }
};

const getComplaints = async (req, res, next) => {
  try {
    const complaints = await prisma.complaint.findMany({
      include: { user: { select: { name: true, email: true, role: true } } },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ success: true, data: complaints });
  } catch (err) { next(err); }
};

const respondComplaint = async (req, res, next) => {
  try {
    const { adminResponse, status } = req.body;
    const complaint = await prisma.complaint.update({
      where: { id: req.params.id },
      data: { adminResponse, status: status || 'in_review' },
    });
    await notificationService.send(complaint.userId, 'Complaint Update', `Your complaint has been ${status || 'reviewed'}.`, 'admin');
    res.json({ success: true, data: complaint });
  } catch (err) { next(err); }
};

const getStats = async (req, res, next) => {
  try {
    const [users, orders, deliveries, revenue, onmcCount, onpcCount] = await Promise.all([
      prisma.user.count(),
      prisma.order.count(),
      prisma.delivery.count({ where: { status: 'delivered' } }),
      prisma.order.aggregate({ where: { status: { in: ['delivered', 'picked_up'] } }, _sum: { totalFcfa: true } }),
      prisma.onmcRegistry.count(),
      prisma.onpcRegistry.count(),
    ]);
    res.json({ success: true, data: { users, orders, deliveries, revenue: revenue._sum.totalFcfa || 0, onmcCount, onpcCount } });
  } catch (err) { next(err); }
};

const getAllTransactions = async (req, res, next) => {
  try {
    const transactions = await prisma.transaction.findMany({
      include: { user: { select: { name: true, role: true } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json({ success: true, data: transactions });
  } catch (err) { next(err); }
};

module.exports = {
  getUsers,
  setUserActive,
  getPendingLicenses,
  reviewLicense,
  getOnmcRegistry,
  addOnmcDoctor,
  getOnpcRegistry,
  addOnpcPharmacy,
  getComplaints,
  respondComplaint,
  getStats,
  getAllTransactions,
};
