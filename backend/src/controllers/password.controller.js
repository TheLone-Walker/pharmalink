const prisma = require('../config/db');
const bcrypt = require('bcryptjs');
const { generateOTP, otpExpiresAt } = require('../utils/otp');
const smsService = require('../services/sms.service');

const forgotPassword = async (req, res, next) => {
  try {
    const { phone } = req.body;
    const user = await prisma.user.findFirst({ where: { phone } });
    if (!user) throw { status: 404, message: 'No account found with this phone number' };

    const otp = generateOTP(6);
    const expires = otpExpiresAt(15);

    // Store OTP temporarily on user record
    await prisma.user.update({
      where: { id: user.id },
      data: { otp, otpExpiresAt: expires },
    });

    await smsService.send(phone, `Your PharmaLink password reset code is: ${otp}. Valid for 15 minutes.`);
    res.json({ success: true, message: 'Reset code sent to your phone' });
  } catch (err) { next(err); }
};

const resetPassword = async (req, res, next) => {
  try {
    const { phone, otp, newPassword } = req.body;
    if (!phone || !otp || !newPassword) throw { status: 400, message: 'All fields are required' };
    if (newPassword.length < 6) throw { status: 400, message: 'Password must be at least 6 characters' };

    const user = await prisma.user.findFirst({ where: { phone } });
    if (!user) throw { status: 404, message: 'User not found' };
    if (user.otp !== otp) throw { status: 400, message: 'Invalid OTP' };
    if (new Date() > new Date(user.otpExpiresAt)) throw { status: 400, message: 'OTP has expired' };

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash, otp: null, otpExpiresAt: null },
    });

    res.json({ success: true, message: 'Password reset successfully' });
  } catch (err) { next(err); }
};

const changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) throw { status: 400, message: 'All fields are required' };
    if (newPassword.length < 6) throw { status: 400, message: 'New password must be at least 6 characters' };

    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) throw { status: 400, message: 'Current password is incorrect' };

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({ where: { id: req.user.id }, data: { passwordHash } });

    res.json({ success: true, message: 'Password changed successfully' });
  } catch (err) { next(err); }
};

module.exports = { forgotPassword, resetPassword, changePassword };
