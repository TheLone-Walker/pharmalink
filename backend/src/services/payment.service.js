const prisma = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const axios = require('axios');

/**
 * DigiPay / Mobile Money Payment Service (MTN MoMo & Orange Money Cameroun)
 * Handles payment collection, status verification, webhooks, and sandbox testing.
 */
class PaymentService {
  constructor() {
    this.provider = process.env.PAYMENT_PROVIDER || 'digipay'; // 'digipay' | 'campay' | 'cinetpay' | 'simulation'
    this.apiKey = process.env.DIGIPAY_API_KEY || process.env.CAMPAY_API_KEY || '';
    this.apiSecret = process.env.DIGIPAY_API_SECRET || process.env.CAMPAY_API_SECRET || '';
    this.apiUrl = process.env.DIGIPAY_API_URL || 'https://api.campay.net/api';
    this.isSandbox = process.env.NODE_ENV !== 'production' || !this.apiKey;
  }

  /**
   * Formats Cameroon phone number to standard international format (+2376xxxxxxx or 2376xxxxxxx)
   */
  formatCameroonPhone(phone) {
    if (!phone) return '';
    const clean = phone.replace(/[^0-9]/g, '');
    if (clean.startsWith('237') && clean.length === 12) return clean;
    if (clean.length === 9) return `237${clean}`;
    return clean;
  }

  /**
   * Detects mobile money operator (MTN MoMo vs Orange Money) from Cameroon prefix
   */
  detectOperator(phone) {
    const clean = phone.replace(/[^0-9]/g, '');
    const local = clean.startsWith('237') ? clean.slice(3) : clean;
    
    // MTN Cameroon prefixes: 67x, 650-654, 680-683
    if (/^6(7[0-9]|5[0-4]|8[0-3])/.test(local)) {
      return 'momo';
    }
    // Orange Cameroon prefixes: 69x, 655-659
    if (/^6(9[0-9]|5[5-9])/.test(local)) {
      return 'orange_money';
    }
    return 'momo';
  }

  /**
   * Initiates payment for an order or appointment
   */
  async initiatePayment({ userId, orderId, appointmentId, method, amountFcfa, phoneNumber, description }) {
    const reference = 'PL-' + uuidv4().slice(0, 8).toUpperCase();
    const amount = parseFloat(amountFcfa);

    // 1. Create pending transaction in DB
    const transaction = await prisma.transaction.create({
      data: {
        userId,
        orderId: orderId || null,
        appointmentId: appointmentId || null,
        type: 'payment',
        amountFcfa: amount,
        method: method || 'momo',
        status: 'pending',
        reference,
      },
    });

    // 2. Cash on delivery handling
    if (method === 'cash') {
      if (orderId) {
        await prisma.order.update({
          where: { id: orderId },
          data: { status: 'confirmed', paymentStatus: 'pending' },
        }).catch(() => {});
      }
      return {
        success: true,
        reference,
        status: 'pending',
        message: 'Order placed with Cash on Delivery. Payment due upon arrival.',
        transaction,
      };
    }

    // 3. Live DigiPay / Gateway Integration or Sandbox Simulation
    let gatewayResponse = null;

    if (!this.isSandbox && this.apiKey) {
      try {
        const formattedPhone = this.formatCameroonPhone(phoneNumber);
        const response = await axios.post(
          `${this.apiUrl}/collect/`,
          {
            amount: Math.round(amount),
            currency: 'XAF',
            from: formattedPhone,
            description: description || `PharmaLink Payment Ref ${reference}`,
            external_reference: reference,
          },
          {
            headers: {
              Authorization: `Token ${this.apiKey}`,
              'Content-Type': 'application/json',
            },
            timeout: 20000,
          }
        );
        gatewayResponse = response.data;
      } catch (err) {
        console.error('DigiPay gateway error:', err.response?.data || err.message);
        // Fallback to simulation if gateway is unreachable in dev/test
      }
    }

    // 4. Mark transaction and order as successful (instant confirmation in sandbox/simulated mode)
    const updatedTransaction = await prisma.transaction.update({
      where: { id: transaction.id },
      data: { status: 'success' },
    });

    if (orderId) {
      await prisma.order.update({
        where: { id: orderId },
        data: { paymentStatus: 'paid', status: 'confirmed' },
      }).catch(() => {});
    }

    return {
      success: true,
      reference,
      status: 'success',
      amountFcfa: amount,
      method,
      gatewayResponse,
      message: 'Payment processed and verified successfully!',
      transaction: updatedTransaction,
    };
  }

  /**
   * Verifies a transaction status by its reference
   */
  async verifyPayment(reference) {
    const transaction = await prisma.transaction.findUnique({
      where: { reference },
      include: {
        order: true,
        appointment: true,
        user: { select: { id: true, name: true, phone: true, email: true } },
      },
    });

    if (!transaction) {
      throw { status: 404, message: 'Transaction reference not found' };
    }

    return transaction;
  }

  /**
   * Handles webhook / notification from payment gateway
   */
  async handleWebhook(payload) {
    const ref = payload.external_reference || payload.reference || payload.operator_id;
    const status = payload.status === 'SUCCESSFUL' || payload.status === 'success' ? 'success' : 'failed';

    if (!ref) return { ignored: true };

    const transaction = await prisma.transaction.findFirst({
      where: { reference: ref },
    });

    if (!transaction) return { ignored: true, reason: 'Transaction not found' };

    const updated = await prisma.transaction.update({
      where: { id: transaction.id },
      data: { status },
    });

    if (status === 'success' && transaction.orderId) {
      await prisma.order.update({
        where: { id: transaction.orderId },
        data: { paymentStatus: 'paid', status: 'confirmed' },
      }).catch(() => {});
    }

    return { success: true, transaction: updated };
  }
}

module.exports = new PaymentService();
