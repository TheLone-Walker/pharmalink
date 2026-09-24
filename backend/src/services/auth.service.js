const bcrypt = require('bcryptjs');
const prisma = require('../config/db');
const { generateAccessToken, generateRefreshToken, verifyRefreshToken } = require('../utils/jwt');
const { generateOTP, otpExpiresAt } = require('../utils/otp');
const smsService = require('./sms.service');

const register = async (data) => {
  const { name, email, phone, password, role, ...profileData } = data;

  if (!email && !phone) throw { status: 400, message: 'Email or phone is required' };
  if (!['patient', 'doctor', 'pharmacist', 'delivery_driver'].includes(role)) {
    throw { status: 400, message: 'Invalid role' };
  }

  const exists = await prisma.user.findFirst({
    where: { OR: [email ? { email } : {}, phone ? { phone } : {}].filter(o => Object.keys(o).length > 0) },
  });
  if (exists) throw { status: 409, message: 'Email or phone already registered' };

  const passwordHash = await bcrypt.hash(password, 12);

  let doctorApprovalStatus = 'pending';
  let isDoctorOnmcVerified = false;
  let doctorSpecialty = profileData.specialty;
  let doctorHospital = profileData.hospital;

  if (role === 'doctor') {
    if (!profileData.licenseNumber) {
      throw { status: 400, message: 'ONMC medical license number is required for doctor registration.' };
    }
    const cleanLic = profileData.licenseNumber.trim();
    const existingDoc = await prisma.doctorProfile.findFirst({
      where: { licenseNumber: cleanLic },
    });
    if (existingDoc) {
      throw { status: 409, message: 'This ONMC medical license number is already registered to another doctor account.' };
    }

    const onmcMatch = await prisma.onmcRegistry.findUnique({
      where: { licenseNumber: cleanLic },
    });
    if (onmcMatch && onmcMatch.status === 'active') {
      doctorApprovalStatus = 'approved';
      isDoctorOnmcVerified = true;
      doctorSpecialty = doctorSpecialty || onmcMatch.specialty;
      doctorHospital = doctorHospital || onmcMatch.hospital;
    }
  }

  let pharmApprovalStatus = 'pending';
  let isPharmOnpcVerified = false;
  let pharmName = profileData.pharmacyName;
  let pharmAddr = profileData.pharmacyAddress;

  if (role === 'pharmacist') {
    if (!profileData.licenseNumber) {
      throw { status: 400, message: 'ONPC pharmacy license number is required for pharmacist registration.' };
    }
    const cleanLic = profileData.licenseNumber.trim();
    const existingPharm = await prisma.pharmacistProfile.findFirst({
      where: { licenseNumber: cleanLic },
    });
    if (existingPharm) {
      throw { status: 409, message: 'This ONPC pharmacy license number is already registered to another pharmacy account.' };
    }

    const onpcMatch = await prisma.onpcRegistry.findUnique({
      where: { licenseNumber: cleanLic },
    });
    if (onpcMatch && onpcMatch.status === 'active') {
      pharmApprovalStatus = 'approved';
      isPharmOnpcVerified = true;
      pharmName = pharmName || onpcMatch.pharmacyName;
      pharmAddr = pharmAddr || onpcMatch.address;
    }
  }

  const isAutoVerified = (role === 'doctor' && isDoctorOnmcVerified) || (role === 'pharmacist' && isPharmOnpcVerified) || role === 'patient';

  const user = await prisma.user.create({
    data: {
      name, email, phone, passwordHash, role,
      isVerified: isAutoVerified,
      ...(role === 'patient' && {
        patientProfile: { create: { dateOfBirth: profileData.dateOfBirth, address: profileData.address } },
      }),
      ...(role === 'doctor' && {
        doctorProfile: {
          create: {
            licenseNumber: profileData.licenseNumber ? profileData.licenseNumber.trim() : null,
            specialty: doctorSpecialty,
            hospital: doctorHospital,
            approvalStatus: doctorApprovalStatus,
            isOnmcVerified: isDoctorOnmcVerified,
          },
        },
      }),
      ...(role === 'pharmacist' && {
        pharmacistProfile: {
          create: {
            pharmacyName: pharmName,
            licenseNumber: profileData.licenseNumber ? profileData.licenseNumber.trim() : null,
            pharmacyAddress: pharmAddr,
            pharmacyCategory: profileData.pharmacyCategory,
            approvalStatus: pharmApprovalStatus,
            isOnpcVerified: isPharmOnpcVerified,
          },
        },
      }),
      ...(role === 'delivery_driver' && {
        driverProfile: { create: { vehicleInfo: profileData.vehicleInfo } },
      }),
    },
    include: { patientProfile: true, doctorProfile: true, pharmacistProfile: true, driverProfile: true },
  });

  const accessToken = generateAccessToken({ id: user.id, role: user.role });
  const refreshToken = generateRefreshToken({ id: user.id, role: user.role });

  const { passwordHash: _, ...userWithoutPassword } = user;
  return { user: userWithoutPassword, accessToken, refreshToken };
};

const login = async (identifier, password) => {
  const user = await prisma.user.findFirst({
    where: { OR: [{ email: identifier }, { phone: identifier }] },
    include: { patientProfile: true, doctorProfile: true, pharmacistProfile: true, driverProfile: true },
  });

  if (!user) throw { status: 401, message: 'Invalid credentials' };
  if (!user.isActive) throw { status: 403, message: 'Account deactivated. Contact support.' };

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) throw { status: 401, message: 'Invalid credentials' };

  const accessToken = generateAccessToken({ id: user.id, role: user.role });
  const refreshToken = generateRefreshToken({ id: user.id, role: user.role });

  const { passwordHash: _, ...userWithoutPassword } = user;
  return { user: userWithoutPassword, accessToken, refreshToken };
};

const refreshToken = async (token) => {
  try {
    const decoded = verifyRefreshToken(token);
    const user = await prisma.user.findUnique({ where: { id: decoded.id } });
    if (!user || !user.isActive) throw { status: 401, message: 'Invalid refresh token' };
    const accessToken = generateAccessToken({ id: user.id, role: user.role });
    return { accessToken };
  } catch {
    throw { status: 401, message: 'Invalid or expired refresh token' };
  }
};

const sendOtp = async (phone) => {
  const otp = generateOTP(6);
  const expires = otpExpiresAt(10);
  await prisma.user.updateMany({
    where: { phone },
    data: { otp, otpExpiresAt: expires },
  });
  await smsService.send(phone, `Your PharmaLink OTP is: ${otp}. Valid for 10 minutes.`);
  return { message: 'OTP sent' };
};

const verifyOtp = async (phone, otp) => {
  const user = await prisma.user.findFirst({ where: { phone } });
  if (!user) throw { status: 404, message: 'User not found' };
  if (user.otp !== otp) throw { status: 400, message: 'Invalid OTP' };
  if (new Date() > new Date(user.otpExpiresAt)) throw { status: 400, message: 'OTP expired' };
  await prisma.user.update({ where: { id: user.id }, data: { isVerified: true, otp: null, otpExpiresAt: null } });
  return { message: 'Phone verified successfully' };
};

module.exports = { register, login, refreshToken, sendOtp, verifyOtp };
