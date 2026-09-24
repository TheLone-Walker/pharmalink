const prisma = require('../config/db');
const notificationService = require('../services/notification.service');
const { v4: uuidv4 } = require('uuid');

// POST /appointments — Create / Book appointment
const book = async (req, res, next) => {
  try {
    const { doctorId, appointmentDate, type, notes, hospital } = req.body;
    const targetDate = new Date(appointmentDate);

    // 1. Check doctor profile
    const doctorProfile = await prisma.doctorProfile.findUnique({
      where: { userId: doctorId },
    });

    if (doctorProfile) {
      // 2. Check if doctor has personal blocked time during this slot
      const blocked = await prisma.$queryRawUnsafe(
        `SELECT * FROM "public"."doctor_blocked_times" 
         WHERE "doctor_profile_id" = $1 
         AND "start_date" <= $2 AND "end_date" >= $2 LIMIT 1`,
        doctorProfile.id,
        targetDate
      );

      if (blocked && blocked.length > 0) {
        return res.status(400).json({
          success: false,
          message: 'The doctor has blocked this time for personal reasons. Please choose another time.',
        });
      }
    }

    // 3. Check for existing active appointment within 30 minutes of requested time
    const slotStart = new Date(targetDate.getTime() - 29 * 60 * 1000);
    const slotEnd = new Date(targetDate.getTime() + 29 * 60 * 1000);
    const conflict = await prisma.appointment.findFirst({
      where: {
        doctorId,
        status: { in: ['pending', 'confirmed'] },
        appointmentDate: { gte: slotStart, lte: slotEnd },
      },
    });

    if (conflict) {
      return res.status(400).json({
        success: false,
        message: 'This time slot has already been booked. Please pick another available time slot.',
      });
    }

    // 4. Create appointment
    const appointment = await prisma.appointment.create({
      data: {
        patientId: req.user.id,
        doctorId,
        appointmentDate: targetDate,
        type: type || 'in_person',
        notes: notes || null,
        ...(hospital && { hospital }),
      },
      include: {
        doctor: {
          select: {
            name: true,
            profilePhotoUrl: true,
            doctorProfile: { select: { specialty: true, hospital: true } },
          },
        },
        patient: { select: { name: true, profilePhotoUrl: true } },
      },
    });

    await notificationService.send(
      doctorId,
      'New Appointment Request 🩺',
      `${req.user.name} booked an appointment for ${targetDate.toLocaleDateString()} at ${targetDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}.`,
      'appointment',
      { appointmentId: appointment.id }
    );

    const { emitToUser } = require('../services/socket.service');
    emitToUser(doctorId, 'appointment:new', appointment);

    res.status(201).json({ success: true, data: appointment });
  } catch (err) { next(err); }
};

// GET /appointments — View user's appointments (Patient or Doctor)
const getMyAppointments = async (req, res, next) => {
  try {
    const isDoctor = req.user.role === 'doctor';
    const { status } = req.query;

    const appointments = await prisma.appointment.findMany({
      where: {
        ...(isDoctor ? { doctorId: req.user.id } : { patientId: req.user.id }),
        ...(status && { status }),
      },
      include: {
        doctor: {
          select: {
            id: true,
            name: true,
            profilePhotoUrl: true,
            doctorProfile: { select: { specialty: true, hospital: true } },
          },
        },
        patient: {
          select: {
            id: true,
            name: true,
            phone: true,
            profilePhotoUrl: true,
            patientProfile: true,
          },
        },
      },
      orderBy: { appointmentDate: 'desc' },
    });
    res.json({ success: true, data: appointments });
  } catch (err) { next(err); }
};

// PATCH /appointments/:id/status — Confirm, Cancel, or Complete appointment
const updateStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    const appointment = await prisma.appointment.update({
      where: { id: req.params.id },
      data: { status },
      include: {
        doctor: { select: { name: true } },
        patient: { select: { name: true } },
      },
    });

    const { emitToUser } = require('../services/socket.service');
    emitToUser(appointment.patientId, 'appointment:updated', appointment);
    emitToUser(appointment.doctorId, 'appointment:updated', appointment);

    // Notify patient
    const title = status === 'confirmed' ? 'Appointment Confirmed ✅' : `Appointment ${status}`;
    const body = status === 'confirmed'
      ? `Dr. ${appointment.doctor.name} confirmed your appointment.`
      : `Your appointment is now: ${status}.`;

    await notificationService.send(appointment.patientId, title, body, 'appointment');
    res.json({ success: true, data: appointment });
  } catch (err) { next(err); }
};

// DELETE /appointments/:id — Cancel appointment
const cancel = async (req, res, next) => {
  try {
    const apt = await prisma.appointment.findUnique({
      where: { id: req.params.id },
      include: { doctor: { select: { name: true } }, patient: { select: { name: true } } },
    });
    if (!apt) throw { status: 404, message: 'Appointment not found' };

    const updated = await prisma.appointment.update({
      where: { id: req.params.id },
      data: { status: 'cancelled' },
    });

    const isPatient = req.user.id === apt.patientId;
    const targetUserId = isPatient ? apt.doctorId : apt.patientId;

    const { emitToUser } = require('../services/socket.service');
    emitToUser(apt.patientId, 'appointment:updated', updated);
    emitToUser(apt.doctorId, 'appointment:updated', updated);
    const senderName = isPatient ? apt.patient.name : `Dr. ${apt.doctor.name}`;

    await notificationService.send(
      targetUserId,
      'Appointment Cancelled',
      `${senderName} has cancelled the appointment scheduled for ${new Date(apt.appointmentDate).toLocaleDateString()}.`,
      'appointment'
    );

    res.json({ success: true, data: updated });
  } catch (err) { next(err); }
};

// PATCH /appointments/:id/reschedule — Reschedule appointment to a new date/time
const reschedule = async (req, res, next) => {
  try {
    const { appointmentDate, hospital } = req.body;
    if (!appointmentDate) {
      return res.status(400).json({ success: false, message: 'New appointment date is required' });
    }

    const apt = await prisma.appointment.findUnique({
      where: { id: req.params.id },
      include: { doctor: true, patient: true },
    });
    if (!apt) throw { status: 404, message: 'Appointment not found' };

    const targetDate = new Date(appointmentDate);

    // 1. Check doctor personal blocked time
    const doctorProfile = await prisma.doctorProfile.findUnique({
      where: { userId: apt.doctorId },
    });

    if (doctorProfile) {
      const blocked = await prisma.$queryRawUnsafe(
        `SELECT * FROM "public"."doctor_blocked_times" 
         WHERE "doctor_profile_id" = $1 
         AND "start_date" <= $2 AND "end_date" >= $2 LIMIT 1`,
        doctorProfile.id,
        targetDate
      );

      if (blocked && blocked.length > 0) {
        return res.status(400).json({
          success: false,
          message: 'The doctor has blocked this time slot. Please select another slot.',
        });
      }
    }

    // 2. Check conflicts with other appointments (excluding this one)
    const slotStart = new Date(targetDate.getTime() - 29 * 60 * 1000);
    const slotEnd = new Date(targetDate.getTime() + 29 * 60 * 1000);
    const conflict = await prisma.appointment.findFirst({
      where: {
        id: { not: apt.id },
        doctorId: apt.doctorId,
        status: { in: ['pending', 'confirmed'] },
        appointmentDate: { gte: slotStart, lte: slotEnd },
      },
    });

    if (conflict) {
      return res.status(400).json({
        success: false,
        message: 'This time slot is already booked. Please choose another slot.',
      });
    }

    // 3. Update appointment
    const updated = await prisma.appointment.update({
      where: { id: req.params.id },
      data: {
        appointmentDate: targetDate,
        status: req.user.role === 'doctor' ? 'confirmed' : 'pending',
        ...(hospital && { hospital }),
      },
      include: {
        doctor: { select: { name: true } },
        patient: { select: { name: true } },
      },
    });

    // Notify other party
    const isPatient = req.user.id === apt.patientId;
    const targetUserId = isPatient ? apt.doctorId : apt.patientId;
    const notifyName = isPatient ? apt.patient.name : `Dr. ${apt.doctor.name}`;

    await notificationService.send(
      targetUserId,
      'Appointment Rescheduled',
      `${notifyName} rescheduled the appointment to ${targetDate.toLocaleDateString()} at ${targetDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}.`,
      'appointment'
    );

    res.json({ success: true, data: updated });
  } catch (err) { next(err); }
};

// GET /appointments/schedule/:doctorId — View complete doctor schedule, booked slots, and blocked personal time
const getDoctorSchedule = async (req, res, next) => {
  try {
    const { doctorId } = req.params;
    const { date } = req.query; // optional YYYY-MM-DD

    const profile = await prisma.doctorProfile.findUnique({
      where: { userId: doctorId },
      include: { availability: true },
    });
    if (!profile) throw { status: 404, message: 'Doctor not found' };

    let dateFilter = {};
    if (date) {
      const d = new Date(date);
      const startOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
      const endOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59);
      dateFilter = { gte: startOfDay, lte: endOfDay };
    } else {
      // Default to next 30 days
      const now = new Date();
      const in30 = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
      dateFilter = { gte: now, lte: in30 };
    }

    // 1. Booked appointments
    const bookedAppointments = await prisma.appointment.findMany({
      where: {
        doctorId,
        status: { in: ['pending', 'confirmed'] },
        appointmentDate: dateFilter,
      },
      select: {
        id: true,
        appointmentDate: true,
        status: true,
        type: true,
      },
    });

    // 2. Blocked personal times
    const blockedTimes = await prisma.$queryRawUnsafe(
      `SELECT id, start_date as "startDate", end_date as "endDate", reason 
       FROM "public"."doctor_blocked_times" 
       WHERE "doctor_profile_id" = $1 ORDER BY "start_date" ASC`,
      profile.id
    );

    res.json({
      success: true,
      data: {
        availability: profile.availability,
        bookedAppointments,
        blockedTimes,
      },
    });
  } catch (err) { next(err); }
};

// POST /appointments/block-time — Doctor blocks personal time
const blockPersonalTime = async (req, res, next) => {
  try {
    const { startDate, endDate, reason } = req.body;
    if (!startDate || !endDate) {
      return res.status(400).json({ success: false, message: 'Start date and end date are required' });
    }

    const profile = await prisma.doctorProfile.findUnique({
      where: { userId: req.user.id },
    });
    if (!profile) throw { status: 403, message: 'Only doctors can block personal time' };

    const id = uuidv4();
    const start = new Date(startDate);
    const end = new Date(endDate);

    await prisma.$executeRawUnsafe(
      `INSERT INTO "public"."doctor_blocked_times" (id, doctor_profile_id, start_date, end_date, reason, created_at)
       VALUES ($1, $2, $3, $4, $5, NOW())`,
      id,
      profile.id,
      start,
      end,
      reason || 'Personal Time'
    );

    res.status(201).json({
      success: true,
      data: { id, startDate: start, endDate: end, reason: reason || 'Personal Time' },
    });
  } catch (err) { next(err); }
};

// GET /appointments/blocked-times — Doctor retrieves their personal blocked times
const getBlockedTimes = async (req, res, next) => {
  try {
    const profile = await prisma.doctorProfile.findUnique({
      where: { userId: req.user.id },
    });
    if (!profile) throw { status: 403, message: 'Only doctors have blocked times' };

    const rows = await prisma.$queryRawUnsafe(
      `SELECT id, start_date as "startDate", end_date as "endDate", reason, created_at as "createdAt"
       FROM "public"."doctor_blocked_times"
       WHERE "doctor_profile_id" = $1
       ORDER BY "start_date" ASC`,
      profile.id
    );

    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
};

// DELETE /appointments/blocked-times/:id — Doctor removes a personal blocked time
const unblockPersonalTime = async (req, res, next) => {
  try {
    const profile = await prisma.doctorProfile.findUnique({
      where: { userId: req.user.id },
    });
    if (!profile) throw { status: 403, message: 'Only doctors can unblock personal time' };

    await prisma.$executeRawUnsafe(
      `DELETE FROM "public"."doctor_blocked_times" WHERE id = $1 AND doctor_profile_id = $2`,
      req.params.id,
      profile.id
    );

    res.json({ success: true, message: 'Time unblocked successfully' });
  } catch (err) { next(err); }
};

// GET /appointments/availability/:doctorId — Weekly availability
const getAvailability = async (req, res, next) => {
  try {
    const { doctorId } = req.params;
    const profile = await prisma.doctorProfile.findUnique({ where: { userId: doctorId } });
    if (!profile) throw { status: 404, message: 'Doctor not found' };
    const availability = await prisma.doctorAvailability.findMany({ where: { doctorId: profile.id } });
    res.json({ success: true, data: availability });
  } catch (err) { next(err); }
};

module.exports = {
  book,
  getMyAppointments,
  updateStatus,
  cancel,
  reschedule,
  getDoctorSchedule,
  blockPersonalTime,
  getBlockedTimes,
  unblockPersonalTime,
  getAvailability,
};
