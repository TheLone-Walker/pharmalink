const crypto = require('crypto');

const generateOTP = (length = 4) => {
  const digits = '0123456789';
  let otp = '';
  for (let i = 0; i < length; i++) {
    otp += digits[crypto.randomInt(0, digits.length)];
  }
  return otp;
};

const generatePickupCode = () => {
  return 'PL' + crypto.randomInt(1000, 9999).toString();
};

const otpExpiresAt = (minutes = 10) => {
  return new Date(Date.now() + minutes * 60 * 1000);
};

module.exports = { generateOTP, generatePickupCode, otpExpiresAt };
