const prisma = require('../config/db');
const notificationService = require('../services/notification.service');

const getPatients = async (req, res, next) => {
  try {
    const appointments = await prisma.appointment.findMany({
      where: { doctorId: req.user.id },
      select: { patient: { include: { patientProfile: true } } },
      distinct: ['patientId'],
    });
    const patients = appointments.map(a => a.patient);
    res.json({ success: true, data: patients });
  } catch (err) { next(err); }
};

const getPatientDetail = async (req, res, next) => {
  try {
    const patient = await prisma.user.findUnique({
      where: { id: req.params.id },
      include: {
        patientProfile: true,
        patientPrescriptions: { include: { items: true }, orderBy: { createdAt: 'desc' } },
        medicalHistories: { orderBy: { date: 'desc' } },
      },
    });
    if (!patient) throw { status: 404, message: 'Patient not found' };
    const { passwordHash, ...safe } = patient;
    res.json({ success: true, data: safe });
  } catch (err) { next(err); }
};

const setAvailability = async (req, res, next) => {
  try {
    const profile = await prisma.doctorProfile.findUnique({ where: { userId: req.user.id } });
    if (!profile) throw { status: 404, message: 'Doctor profile not found' };
    await prisma.doctorAvailability.deleteMany({ where: { doctorId: profile.id } });
    const slots = req.body.slots || [];
    const created = await prisma.doctorAvailability.createMany({
      data: slots.map(s => ({ doctorId: profile.id, dayOfWeek: s.dayOfWeek, startTime: s.startTime, endTime: s.endTime, isAvailable: s.isAvailable ?? true })),
    });
    res.json({ success: true, data: created });
  } catch (err) { next(err); }
};

const uploadLicense = async (req, res, next) => {
  try {
    const { licenseNumber, specialty, hospital } = req.body;
    if (!req.file && !licenseNumber) {
      throw { status: 400, message: 'Please provide either an ONMC license number or upload a license document.' };
    }
    const url = req.file ? `/uploads/${req.file.filename}` : undefined;

    const cleanLic = licenseNumber ? licenseNumber.trim() : undefined;
    if (cleanLic) {
      const existing = await prisma.doctorProfile.findFirst({
        where: {
          licenseNumber: cleanLic,
          userId: { not: req.user.id },
        },
      });
      if (existing) {
        throw { status: 409, message: 'This ONMC license number is already registered to another doctor account.' };
      }
    }

    const updated = await prisma.doctorProfile.update({
      where: { userId: req.user.id },
      data: {
        ...(url && { licenseDocUrl: url }),
        ...(cleanLic && { licenseNumber: cleanLic }),
        ...(specialty && { specialty }),
        ...(hospital && { hospital }),
        approvalStatus: 'pending',
        isOnmcVerified: false,
        rejectionReason: null,
      },
      include: { user: true },
    });

    // Notify admins of new pending doctor verification
    const admins = await prisma.user.findMany({ where: { role: 'admin' }, select: { id: true } });
    if (admins.length > 0) {
      await notificationService.sendToMany(
        admins.map(a => a.id),
        'Doctor ONMC License Pending Verification',
        `Doctor ${updated.user?.name || 'User'} has uploaded their license (${updated.licenseNumber || 'License attached'}). Cross-check with ONMC records to review.`,
        'admin'
      );
    }

    res.json({ success: true, message: 'License uploaded successfully. Pending admin review.', data: updated });
  } catch (err) { next(err); }
};

module.exports = { getPatients, getPatientDetail, setAvailability, uploadLicense };
