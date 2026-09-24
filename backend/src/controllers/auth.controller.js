const authService = require('../services/auth.service');

const register = async (req, res, next) => {
  try {
    const result = await authService.register(req.body);
    res.status(201).json({ success: true, data: result, message: 'Registration successful' });
  } catch (err) { next(err); }
};

const login = async (req, res, next) => {
  try {
    const { identifier, password } = req.body;
    const result = await authService.login(identifier, password);
    res.json({ success: true, data: result, message: 'Login successful' });
  } catch (err) { next(err); }
};

const refresh = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    const result = await authService.refreshToken(refreshToken);
    res.json({ success: true, data: result });
  } catch (err) { next(err); }
};

const sendOtp = async (req, res, next) => {
  try {
    const result = await authService.sendOtp(req.body.phone);
    res.json({ success: true, data: result });
  } catch (err) { next(err); }
};

const verifyOtp = async (req, res, next) => {
  try {
    const result = await authService.verifyOtp(req.body.phone, req.body.otp);
    res.json({ success: true, data: result });
  } catch (err) { next(err); }
};

module.exports = { register, login, refresh, sendOtp, verifyOtp };
