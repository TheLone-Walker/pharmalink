const nodemailer = require('nodemailer');

class EmailService {
  constructor() {
    this.transporter = null;
    this.init();
  }

  init() {
    const host = process.env.SMTP_HOST;
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;
    const port = parseInt(process.env.SMTP_PORT || '587', 10);
    const secure = process.env.SMTP_SECURE === 'true' || port === 465;

    if (host && user && pass) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure,
        auth: { user, pass },
        tls: { rejectUnauthorized: false },
      });
      console.log(`[SMTP] Configured with host: ${host}:${port}`);
    } else if (process.env.SMTP_SERVICE === 'gmail' && process.env.GMAIL_USER && process.env.GMAIL_APP_PASSWORD) {
      this.transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.GMAIL_USER,
          pass: process.env.GMAIL_APP_PASSWORD,
        },
      });
      console.log('[SMTP] Configured with Gmail service');
    } else {
      console.log('[SMTP] No active SMTP credentials found in .env. Running in simulation/dev logging mode.');
    }
  }

  getFromAddress() {
    return process.env.SMTP_FROM || process.env.SMTP_USER || '"PharmaLink Healthcare" <noreply@pharmalink.cm>';
  }

  async sendMail({ to, subject, html, text }) {
    if (!to) return { success: false, message: 'No recipient specified' };

    if (this.transporter) {
      try {
        const info = await this.transporter.sendMail({
          from: this.getFromAddress(),
          to,
          subject,
          text: text || subject,
          html,
        });
        return { success: true, messageId: info.messageId };
      } catch (error) {
        console.error('[SMTP Error] Failed to send email:', error.message);
        return { success: false, error: error.message };
      }
    } else {
      // Dev mode log
      console.log('──────────────────────────────────────────────────────────');
      console.log(`[SMTP DEV SIMULATION] To: ${to} | Subject: ${subject}`);
      console.log(`[Content Preview]: ${text || '(HTML email formatted)'}`);
      console.log('──────────────────────────────────────────────────────────');
      return { success: true, simulated: true };
    }
  }

  /**
   * Send OTP Verification Email
   */
  async sendOtpEmail(to, otp) {
    const subject = 'Your PharmaLink Verification Code';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; borderRadius: 12px;">
        <h2 style="color: #0D6E48; margin-bottom: 8px;">PharmaLink Verification</h2>
        <p style="color: #475569; font-size: 14px;">Use the following One-Time Password (OTP) to complete your verification:</p>
        <div style="background-color: #ECFDF5; border: 1px dashed #10B981; padding: 16px; text-align: center; border-radius: 8px; margin: 20px 0;">
          <span style="font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #0D6E48;">${otp}</span>
        </div>
        <p style="color: #94A3B8; font-size: 12px;">This code expires in 10 minutes. If you did not request this, please ignore this email.</p>
      </div>
    `;
    return this.sendMail({ to, subject, html, text: `Your PharmaLink OTP code is: ${otp}` });
  }

  /**
   * Send Welcome Email
   */
  async sendWelcomeEmail(to, name, role) {
    const subject = 'Welcome to PharmaLink Healthcare';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; border-radius: 12px;">
        <h2 style="color: #0D6E48;">Welcome to PharmaLink, ${name}!</h2>
        <p style="color: #475569; font-size: 14px;">Your account as a <strong>${role}</strong> has been successfully set up.</p>
        <p style="color: #475569; font-size: 14px;">You can now consult doctors, order medications from licensed pharmacies across Cameroon, and track your deliveries in real-time.</p>
        <div style="margin-top: 24px; padding-top: 16px; border-top: 1px solid #E2E8F0; color: #94A3B8; font-size: 12px;">
          PharmaLink • Modern Digital Healthcare & Pharmacy Delivery
        </div>
      </div>
    `;
    return this.sendMail({ to, subject, html, text: `Welcome to PharmaLink, ${name}!` });
  }

  /**
   * Send Order Confirmation / Receipt
   */
  async sendOrderConfirmationEmail(to, { orderId, amountFcfa, method, items = [] }) {
    const subject = `PharmaLink Order Confirmation #${orderId.slice(0, 8).toUpperCase()}`;
    const itemsList = items.map(i => `<li>${i.name || 'Medication'} x${i.quantity || 1} — FCFA ${(i.priceFcfa || 0) * (i.quantity || 1)}</li>`).join('');

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; border-radius: 12px;">
        <h2 style="color: #0D6E48;">Order Confirmed!</h2>
        <p style="color: #475569; font-size: 14px;">Thank you for your order. Your medications are being prepared by the pharmacy.</p>
        <div style="background-color: #F8FAFC; padding: 14px; border-radius: 8px; margin: 16px 0;">
          <p style="margin: 4px 0; color: #334155;"><strong>Order ID:</strong> ${orderId}</p>
          <p style="margin: 4px 0; color: #334155;"><strong>Payment Method:</strong> ${method}</p>
          <p style="margin: 4px 0; color: #0D6E48; font-size: 16px;"><strong>Total Paid:</strong> FCFA ${amountFcfa}</p>
        </div>
        ${items.length > 0 ? `<ul style="color: #475569; font-size: 14px;">${itemsList}</ul>` : ''}
        <p style="color: #94A3B8; font-size: 12px; margin-top: 20px;">You can track your order status in real-time in the PharmaLink app.</p>
      </div>
    `;
    return this.sendMail({ to, subject, html, text: `Your PharmaLink order #${orderId} for FCFA ${amountFcfa} is confirmed.` });
  }

  /**
   * Send Password Reset Email
   */
  async sendPasswordResetEmail(to, { resetToken, resetUrl }) {
    const subject = 'PharmaLink Password Reset Request';
    const link = resetUrl || `https://pharmalink.cm/reset-password?token=${resetToken}`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 540px; margin: 0 auto; padding: 24px; border: 1px solid #E2E8F0; border-radius: 12px;">
        <h2 style="color: #0D6E48;">Password Reset Request</h2>
        <p style="color: #475569; font-size: 14px;">We received a request to reset your password. Click the button below to set a new password:</p>
        <div style="text-align: center; margin: 24px 0;">
          <a href="${link}" style="background-color: #0D6E48; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: bold; display: inline-block;">Reset Password</a>
        </div>
        <p style="color: #94A3B8; font-size: 12px;">If you did not request this, you can safely ignore this email.</p>
      </div>
    `;
    return this.sendMail({ to, subject, html, text: `Reset your password at: ${link}` });
  }
}

module.exports = new EmailService();
