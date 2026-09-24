const axios = require('axios');

const send = async (phone, message) => {
  const provider = process.env.SMS_PROVIDER || 'africas_talking';
  try {
    if (provider === 'africas_talking') {
      const AfricasTalking = require('africastalking')({
        apiKey: process.env.SMS_API_KEY,
        username: process.env.SMS_USERNAME,
      });
      const sms = AfricasTalking.SMS;
      await sms.send({ to: [phone], message, from: 'PharmaLink' });
    } else if (provider === 'twilio') {
      const accountSid = process.env.TWILIO_ACCOUNT_SID;
      const authToken = process.env.TWILIO_AUTH_TOKEN;
      await axios.post(
        `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
        new URLSearchParams({ To: phone, From: process.env.TWILIO_PHONE, Body: message }),
        { auth: { username: accountSid, password: authToken } }
      );
    } else {
      console.log(`[SMS Mock] To: ${phone} | Message: ${message}`);
    }
  } catch (err) {
    console.error('SMS send error:', err.message);
  }
};

module.exports = { send };
