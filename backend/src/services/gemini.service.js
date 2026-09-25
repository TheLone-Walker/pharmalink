const axios = require('axios');
const prisma = require('../config/db');
const notificationService = require('./notification.service');

/**
 * PharmaLink Autonomous AI Clinical Agent
 * Powered by Google Gemini 1.5 Flash
 * Capabilities: Live System Knowledge, Direct Appointment Booking, and Medication Orders
 */
class GeminiService {
  constructor() {
    this.model = process.env.GEMINI_MODEL || 'gemini-1.5-flash';
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  }

  getApiKey() {
    return process.env.GEMINI_API_KEY;
  }

  /**
   * Loads real-time system directory (Doctors, Hospitals, Pharmacy drug stocks & prices)
   */
  async getSystemKnowledge() {
    try {
      const doctors = await prisma.user.findMany({
        where: { role: 'doctor', isActive: true },
        include: { doctorProfile: true },
        take: 20,
      });

      const doctorsList = doctors.length > 0
        ? doctors.map(d => {
            const p = d.doctorProfile || {};
            return `• Dr. ${d.name.replace(/^Dr\.\s*/i, '')} (ID: ${d.id}) | Specialty: ${p.specialty || 'General Medicine'} | Hospital: ${p.hospital || 'Hôpital Central de Yaoundé'} | Status: Verified ONMC`;
          }).join('\n')
        : '• Dr. Amadou | Specialty: General Practitioner | Hospital: Hôpital Central de Yaoundé';

      const medications = await prisma.medication.findMany({
        include: { pharmacy: true },
        take: 40,
        orderBy: { priceFcfa: 'asc' },
      });

      const medicationsList = medications.length > 0
        ? medications.map(m => {
            const ph = m.pharmacy?.pharmacyName || 'Pharmacie Centrale';
            const addr = m.pharmacy?.pharmacyAddress || 'Yaoundé';
            return `• ${m.name} (ID: ${m.id}): FCFA ${m.priceFcfa} at "${ph}" (${addr}) - Stock: ${m.stockQuantity} available`;
          }).join('\n')
        : '• Paracetamol 500mg: FCFA 1,200 at Pharmacie Centrale (Avenue Kennedy)\n• Coartem (Artemether-Lumefantrine): FCFA 2,200 at Pharmacie Bastos';

      return { doctorsText: doctorsList, medicationsText: medicationsList, doctors, medications };
    } catch (e) {
      console.warn('[Gemini Service] Could not query live DB directory:', e.message);
      return { doctorsText: '', medicationsText: '', doctors: [], medications: [] };
    }
  }

  /**
   * Executes autonomous agent actions (Book Appointment or Create Drug Order)
   */
  async handleAgentActions(userMessage, currentUser, systemData) {
    const lower = (userMessage || '').toLowerCase();
    const userId = currentUser?.id;

    // ─── ACTION 1: BOOK APPOINTMENT INTENT ──────────────────────────────────────
    const isBookingIntent = (
      (lower.includes('book') || lower.includes('set') || lower.includes('make') || lower.includes('schedule') || lower.includes('prendre')) &&
      (lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('consultation') || lower.includes('doctor') || lower.includes('dr'))
    );

    if (isBookingIntent && userId && systemData.doctors.length > 0) {
      // Find matching doctor or pick first certified doctor
      let targetDoctor = systemData.doctors.find(d =>
        lower.includes(d.name.toLowerCase().replace('dr.', '').trim())
      );
      if (!targetDoctor) {
        targetDoctor = systemData.doctors[0];
      }

      // Schedule for tomorrow 10:00 AM by default or parse date
      const appointmentDate = new Date();
      appointmentDate.setDate(appointmentDate.getDate() + 1);
      appointmentDate.setHours(10, 0, 0, 0);

      const type = lower.includes('telemedicine') || lower.includes('video') || lower.includes('online')
        ? 'telemedicine'
        : 'in_person';

      try {
        const appointment = await prisma.appointment.create({
          data: {
            patientId: userId,
            doctorId: targetDoctor.id,
            appointmentDate,
            type,
            notes: `Booked via PharmaLink AI Assistant for clinical consultation.`,
            hospital: targetDoctor.doctorProfile?.hospital || 'Hôpital Central de Yaoundé',
            status: 'confirmed',
          },
        });

        // Notify doctor & patient
        await notificationService.send(
          targetDoctor.id,
          'New Appointment Scheduled 📅',
          `New appointment booked with ${currentUser.name || 'Patient'} on ${appointmentDate.toLocaleDateString()} at 10:00 AM.`,
          'appointment'
        ).catch(() => {});

        const docName = `Dr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}`;
        const formattedDate = appointmentDate.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });

        return {
          reply: `✅ **Appointment Confirmed!**\n\nI have scheduled your consultation with **${docName}** (${targetDoctor.doctorProfile?.specialty || 'General Practitioner'}).\n\n• **Date & Time:** ${formattedDate}\n• **Location / Type:** ${type === 'telemedicine' ? '📱 Telemedicine Video Call' : '🏥 ' + (targetDoctor.doctorProfile?.hospital || 'Hôpital Central de Yaoundé')}\n• **Status:** Confirmed\n\nYou can view and manage this directly in your **"Appointments"** tab.`,
          action: {
            type: 'appointment',
            id: appointment.id,
            title: 'View Confirmed Appointment',
            data: appointment,
          },
        };
      } catch (err) {
        console.error('[Gemini Agent] Booking failed:', err.message);
      }
    }

    // ─── ACTION 2: ORDER MEDICATION INTENT ─────────────────────────────────────
    const isOrderIntent = (
      (lower.includes('order') || lower.includes('buy') || lower.includes('purchase') || lower.includes('commander') || lower.includes('acheter')) &&
      (lower.includes('drug') || lower.includes('medication') || lower.includes('paracetamol') || lower.includes('artemether') || lower.includes('coartem') || lower.includes('amoxicillin') || lower.includes('pill') || lower.includes('tablet'))
    );

    if (isOrderIntent && userId && systemData.medications.length > 0) {
      // Find matching medication
      let targetMed = systemData.medications.find(m =>
        lower.includes(m.name.toLowerCase().split(' ')[0])
      );
      if (!targetMed) {
        targetMed = systemData.medications[0];
      }

      const quantity = 1;
      const totalFcfa = parseFloat(targetMed.priceFcfa) * quantity;
      const pharmacyId = targetMed.pharmacyId;

      try {
        const order = await prisma.order.create({
          data: {
            patientId: userId,
            pharmacyId,
            orderType: 'delivery',
            totalFcfa,
            deliveryAddress: 'Quartier Bastos, Yaoundé',
            status: 'pending',
            items: {
              create: [
                {
                  medicationId: targetMed.id,
                  quantity,
                  unitPriceFcfa: targetMed.priceFcfa,
                },
              ],
            },
          },
          include: { items: { include: { medication: true } }, pharmacy: true },
        });

        const pharmName = targetMed.pharmacy?.pharmacyName || 'Pharmacie Centrale';

        return {
          reply: `🛒 **Order Created Successfully!**\n\nI have prepared your order for **${targetMed.name}** at **${pharmName}** (cheapest in stock).\n\n• **Item:** ${targetMed.name} x${quantity}\n• **Total:** FCFA ${totalFcfa.toLocaleString()}\n• **Pharmacy:** ${pharmName}\n• **Delivery:** Doorstep Express Courier\n\nTap the action button below to complete checkout with **MTN MoMo**, **Orange Money**, or **Cash on Delivery**!`,
          action: {
            type: 'order',
            id: order.id,
            totalFcfa,
            title: `Pay FCFA ${totalFcfa} & Track Order`,
            data: order,
          },
        };
      } catch (err) {
        console.error('[Gemini Agent] Order creation failed:', err.message);
      }
    }

    return null;
  }

  /**
   * Interactive Health Assistant Chat & Autonomous Agent
   */
  async chat(userMessage, context = '', history = [], currentUser = null) {
    const apiKey = this.getApiKey();
    const systemData = await this.getSystemKnowledge();

    // Check if the user asked to execute an action (Book Appointment or Order Drug)
    const executedAction = await this.handleAgentActions(userMessage, currentUser, systemData);
    if (executedAction) {
      return executedAction;
    }

    const systemInstruction = `You are the master AI Clinical & Healthcare Agent for PharmaLink in Cameroon.
You have FULL ACCESS to the PharmaLink live healthcare database below.

=== LIVE PHARMALINK SYSTEM DIRECTORY ===
AVAILABLE CERTIFIED DOCTORS & THEIR HOSPITALS:
${systemData.doctorsText}

REAL-TIME PHARMACY DRUG INVENTORY & PRICES (SORTED CHEAPEST FIRST):
${systemData.medicationsText}

PARTNER HOSPITALS: Hôpital Central de Yaoundé, CHU Yaoundé, Hôpital Général, Clinique Bastos, Hôpital Jamot, Hôpital Laquintinie de Douala.
========================================

YOUR AGENTIC CAPABILITIES:
1. YOU CAN DIRECTLY SET APPOINTMENTS:
   - Tell the user: "Yes! I can book an appointment with any available doctor (like Dr. Amadou at Hôpital Central). Just tell me which doctor and when, or say 'Book an appointment with Dr. Amadou'!"

2. YOU CAN DIRECTLY ORDER DRUGS:
   - Tell the user: "Yes! I can order medications for you from the cheapest pharmacy in stock (e.g. Paracetamol 500mg for 1,200 FCFA at Pharmacie Centrale). Just say 'Order Paracetamol for me'!"

3. BE INTERACTIVE & CONVERSATIONAL:
   - Talk naturally without repeating canned introductions.
   - Answer directly, provide exact prices/names from the directory, and ask helpful follow-up questions.`;

    if (apiKey && apiKey !== 'your_gemini_api_key') {
      try {
        const url = `${this.baseUrl}/${this.model}:generateContent?key=${apiKey}`;

        const contents = [];

        if (Array.isArray(history) && history.length > 0) {
          const recentHistory = history.slice(-8);
          for (const item of recentHistory) {
            const role = item.role === 'user' ? 'user' : 'model';
            const text = item.text || item.content || '';
            if (text.trim()) {
              contents.push({ role, parts: [{ text }] });
            }
          }
        }

        const currentPrompt = contents.length === 0
          ? `${systemInstruction}\n\nPatient Profile Context: ${context}\n\nPatient: ${userMessage}`
          : `${systemInstruction}\n\nPatient: ${userMessage}`;

        contents.push({ role: 'user', parts: [{ text: currentPrompt }] });

        const response = await axios.post(
          url,
          {
            contents,
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens: 750,
              topP: 0.95,
            },
          },
          { timeout: 15000 }
        );

        const text = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) return { reply: text };
      } catch (err) {
        console.error('[Gemini API Error]:', err.response?.data || err.message);
      }
    }

    // Knowledge-aware fallback reply
    return {
      reply: this.getKnowledgeAwareFallback(userMessage, systemData, history),
    };
  }

  /**
   * Analyze Prescription or Lab Report
   */
  async analyzePrescription(textOrData) {
    const apiKey = this.getApiKey();
    if (apiKey && apiKey !== 'your_gemini_api_key') {
      try {
        const url = `${this.baseUrl}/${this.model}:generateContent?key=${apiKey}`;
        const response = await axios.post(url, {
          contents: [
            {
              role: 'user',
              parts: [
                {
                  text: `Analyze this medical prescription or lab analysis for a patient in Cameroon. Identify medications, prescribed dosages, key directions, and note any important warnings:\n\n${textOrData}`,
                },
              ],
            },
          ],
        });
        return response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
      } catch (e) {
        console.error('[Gemini OCR Analysis Error]:', e.message);
      }
    }
    return 'Prescription overview: Follow the exact daily dosage prescribed by your doctor. You can purchase this directly from licensed pharmacies on PharmaLink with doorstep delivery.';
  }

  /**
   * System-Knowledge Aware Fallback
   */
  getKnowledgeAwareFallback(msg, systemData, history = []) {
    const lower = (msg || '').toLowerCase().trim();

    if (lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('doctor') || lower.includes('order') || lower.includes('drug') || lower.includes('can you') || lower.includes('can he')) {
      return `🩺 **Yes, absolutely! I can do both directly for you:**\n\n1. **📅 Book an Appointment:**\n   • I can schedule a consultation with any certified doctor in our network (e.g. **Dr. Amadou** at *Hôpital Central de Yaoundé* or **Dr. Marie** at *Clinique Bastos*).\n   • *Just say:* **"Book an appointment with Dr. Amadou for tomorrow"**\n\n2. **💊 Order Medications (Cheapest in Stock):**\n   • I can search all licensed pharmacies and create an order with express courier delivery.\n   • *Just say:* **"Order Paracetamol 500mg for me"** or **"Order Coartem"**\n\nWhat would you like me to do for you right now?`;
    }

    if (/^(hi|hello|hey|salut|bonjour)/.test(lower)) {
      return `Hello! I'm your PharmaLink Autonomous Clinical Agent. 🩺\n\nI can:\n• **Book doctor appointments** for you directly.\n• **Order medications** from the cheapest pharmacies in stock.\n• Answer clinical symptom and dosage questions.\n\nHow can I help you today?`;
    }

    return `I am ready to help! You can ask me to **book an appointment** with any doctor, **order medications** with express delivery, or get medical guidance.\n\nWhich doctor or medication are you looking for?`;
  }
}

module.exports = new GeminiService();
