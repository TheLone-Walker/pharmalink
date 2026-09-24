const prisma = require('../config/db');

const getMe = async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: { patientProfile: true, doctorProfile: true, pharmacistProfile: true, driverProfile: true },
    });
    const { passwordHash, ...safe } = user;
    res.json({ success: true, data: safe });
  } catch (err) { next(err); }
};

const updateMe = async (req, res, next) => {
  try {
    const {
      name,
      email,
      phone,
      // Patient fields
      address,
      bloodType,
      allergies,
      dateOfBirth,
      // Doctor fields
      hospital,
      specialty,
      bio,
      // Pharmacist fields
      pharmacyName,
      pharmacyAddress,
      pharmacyCategory,
      openingHours,
      // Driver fields
      vehicleInfo,
      isOnline,
    } = req.body;

    // Update core User
    await prisma.user.update({
      where: { id: req.user.id },
      data: {
        ...(name && { name }),
        ...(email && { email }),
        ...(phone && { phone }),
      },
    });

    const userRole = req.user.role;

    if (userRole === 'patient') {
      await prisma.patientProfile.upsert({
        where: { userId: req.user.id },
        create: {
          userId: req.user.id,
          ...(address !== undefined && { address }),
          ...(bloodType !== undefined && { bloodType }),
          ...(allergies !== undefined && { allergies }),
          ...(dateOfBirth && { dateOfBirth: new Date(dateOfBirth) }),
        },
        update: {
          ...(address !== undefined && { address }),
          ...(bloodType !== undefined && { bloodType }),
          ...(allergies !== undefined && { allergies }),
          ...(dateOfBirth && { dateOfBirth: new Date(dateOfBirth) }),
        },
      });
    } else if (userRole === 'doctor') {
      await prisma.doctorProfile.upsert({
        where: { userId: req.user.id },
        create: {
          userId: req.user.id,
          ...(hospital !== undefined && { hospital }),
          ...(specialty !== undefined && { specialty }),
          ...(bio !== undefined && { bio }),
        },
        update: {
          ...(hospital !== undefined && { hospital }),
          ...(specialty !== undefined && { specialty }),
          ...(bio !== undefined && { bio }),
        },
      });
    } else if (userRole === 'pharmacist') {
      await prisma.pharmacistProfile.upsert({
        where: { userId: req.user.id },
        create: {
          userId: req.user.id,
          ...(pharmacyName !== undefined && { pharmacyName }),
          ...(pharmacyAddress !== undefined && { pharmacyAddress }),
          ...(pharmacyCategory !== undefined && { pharmacyCategory }),
          ...(openingHours !== undefined && { openingHours }),
        },
        update: {
          ...(pharmacyName !== undefined && { pharmacyName }),
          ...(pharmacyAddress !== undefined && { pharmacyAddress }),
          ...(pharmacyCategory !== undefined && { pharmacyCategory }),
          ...(openingHours !== undefined && { openingHours }),
        },
      });
    } else if (userRole === 'delivery_driver') {
      await prisma.driverProfile.upsert({
        where: { userId: req.user.id },
        create: {
          userId: req.user.id,
          ...(vehicleInfo !== undefined && { vehicleInfo }),
          ...(isOnline !== undefined && { isOnline }),
        },
        update: {
          ...(vehicleInfo !== undefined && { vehicleInfo }),
          ...(isOnline !== undefined && { isOnline }),
        },
      });
    }

    const updatedUser = await prisma.user.findUnique({
      where: { id: req.user.id },
      include: {
        patientProfile: true,
        doctorProfile: true,
        pharmacistProfile: true,
        driverProfile: true,
      },
    });

    const { passwordHash, ...safe } = updatedUser;
    const { emitToUser } = require('../services/socket.service');
    emitToUser(req.user.id, 'user:refresh', { userId: req.user.id });
    res.json({ success: true, data: safe, message: 'Profile updated successfully' });
  } catch (err) { next(err); }
};

const uploadPhoto = async (req, res, next) => {
  try {
    if (!req.file) throw { status: 400, message: 'No file uploaded' };
    const url = `/uploads/${req.file.filename}`;
    await prisma.user.update({ where: { id: req.user.id }, data: { profilePhotoUrl: url } });
    const { emitToUser } = require('../services/socket.service');
    emitToUser(req.user.id, 'user:refresh', { userId: req.user.id });
    res.json({ success: true, data: { profilePhotoUrl: url } });
  } catch (err) { next(err); }
};

// GET /api/users/doctors  — public list of approved doctors
const getDoctors = async (req, res, next) => {
  try {
    const { specialty, search, hospital } = req.query;
    const doctors = await prisma.user.findMany({
      where: {
        role: 'doctor',
        isActive: true,
        doctorProfile: {
          approvalStatus: 'approved',
          ...(hospital && { hospital: { equals: hospital, mode: 'insensitive' } }),
          ...(specialty && { specialty: { contains: specialty, mode: 'insensitive' } }),
        },
        ...(search && { name: { contains: search, mode: 'insensitive' } }),
      },
      select: {
        id: true,
        name: true,
        profilePhotoUrl: true,
        doctorProfile: {
          select: {
            id: true,
            specialty: true,
            bio: true,
            hospital: true,
            approvalStatus: true,
            isOnmcVerified: true,
          },
        },
      },
      orderBy: { name: 'asc' },
    });
    res.json({ success: true, data: doctors });
  } catch (err) { next(err); }
};

// GET /api/users/hospitals  — list of hospitals with doctor counts
const getHospitals = async (req, res, next) => {
  try {
    const doctors = await prisma.doctorProfile.findMany({
      where: {
        approvalStatus: 'approved',
        hospital: { not: null },
        user: { isActive: true },
      },
      select: {
        hospital: true,
        specialty: true,
      },
    });

    const map = {};
    for (const d of doctors) {
      if (!d.hospital) continue;
      if (!map[d.hospital]) {
        map[d.hospital] = { name: d.hospital, doctorCount: 0, specialties: new Set() };
      }
      map[d.hospital].doctorCount++;
      if (d.specialty) map[d.hospital].specialties.add(d.specialty);
    }

    const hospitals = Object.values(map).map(h => ({
      name: h.name,
      doctorCount: h.doctorCount,
      specialties: Array.from(h.specialties),
    })).sort((a, b) => a.name.localeCompare(b.name));

    res.json({ success: true, data: hospitals });
  } catch (err) { next(err); }
};

module.exports = { getMe, updateMe, uploadPhoto, getDoctors, getHospitals };

