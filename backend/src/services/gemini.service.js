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
   * Executes autonomous agent actions (Final Confirmation for Appointment or Medication Order)
   */
  async handleAgentActions(userMessage, currentUser, systemData, history = []) {
    const lower = (userMessage || '').toLowerCase().trim();
    const userId = currentUser?.id;

    // ─── ACTION 1: EXPLICIT APPOINTMENT CONFIRMATION ────────────────────────────
    const isExplicitConfirmation = (
      lower === 'yes' || lower === 'oui' || lower === 'confirm' || lower === 'confirmer' ||
      lower === 'confirm appointment' || lower === 'yes confirm' || lower === 'yes please' ||
      lower === 'valider' || lower.startsWith('confirm ') || lower.startsWith('yes, ') ||
      (lower.includes('confirm') && (lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('booking')))
    );

    // Look back in history to see if an appointment review summary was just presented
    const recentHistoryText = Array.isArray(history)
      ? history.slice(-4).map(h => (h.text || h.content || '').toLowerCase()).join(' ')
      : '';

    const hasPendingAppointmentReview = recentHistoryText.includes('hospital') ||
      recentHistoryText.includes('doctor') ||
      recentHistoryText.includes('do you confirm') ||
      recentHistoryText.includes('confirm this appointment') ||
      recentHistoryText.includes('rendez-vous');

    if ((isExplicitConfirmation && hasPendingAppointmentReview && userId) ||
        (lower.includes('confirm') && lower.includes('doctor') && userId)) {
      
      // Extract doctor from history or current message
      let targetDoctor = systemData.doctors.find(d =>
        (lower + ' ' + recentHistoryText).includes(d.name.toLowerCase().replace('dr.', '').trim())
      );
      if (!targetDoctor && systemData.doctors.length > 0) {
        targetDoctor = systemData.doctors[0];
      }

      if (targetDoctor) {
        // Schedule for tomorrow 10:00 AM or parse from context
        const appointmentDate = new Date();
        appointmentDate.setDate(appointmentDate.getDate() + 1);
        appointmentDate.setHours(10, 0, 0, 0);

        const type = (lower + ' ' + recentHistoryText).includes('telemedicine') ||
          (lower + ' ' + recentHistoryText).includes('video') ||
          (lower + ' ' + recentHistoryText).includes('en ligne')
          ? 'telemedicine'
          : 'in_person';

        const hospitalName = targetDoctor.doctorProfile?.hospital || 'Hôpital Central de Yaoundé';

        try {
          const appointment = await prisma.appointment.create({
            data: {
              patientId: userId,
              doctorId: targetDoctor.id,
              appointmentDate,
              type,
              notes: `Booked via PharmaLink AI Assistant step-by-step consultation assistant.`,
              hospital: hospitalName,
              status: 'confirmed',
            },
          });

          // Notify doctor & patient
          await notificationService.send(
            targetDoctor.id,
            'New Appointment Confirmed 📅',
            `Confirmed appointment with ${currentUser.name || 'Patient'} on ${appointmentDate.toLocaleDateString()} at 10:00 AM at ${hospitalName}.`,
            'appointment'
          ).catch(() => {});

          const docName = `Dr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}`;
          const formattedDate = appointmentDate.toLocaleDateString('en-US', {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          });

          return {
            reply: `🎉 **Appointment Successfully Confirmed & Booked!**\n\nHere are your final appointment details:\n• **Hospital / Facility:** 🏥 ${hospitalName}\n• **Specialist:** 👨‍⚕️ **${docName}** (${targetDoctor.doctorProfile?.specialty || 'General Medicine'})\n• **Date & Time:** 📅 ${formattedDate}\n• **Consultation Mode:** ${type === 'telemedicine' ? '📱 Telemedicine Video Call' : '🏥 In-Person at Hospital'}\n• **Status:** Confirmed ✅\n\nDr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}'s office has been notified. You can view, reschedule, or cancel this consultation anytime using the button below.`,
            action: {
              type: 'appointment',
              id: appointment.id,
              title: 'View Confirmed Appointment in Calendar',
              data: appointment,
            },
          };
        } catch (err) {
          console.error('[Gemini Agent] Booking failed:', err.message);
        }
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

    // Check if the user is confirming or executing an action
    const executedAction = await this.handleAgentActions(userMessage, currentUser, systemData, history);
    if (executedAction) {
      return executedAction;
    }

    const systemInstruction = `You are the master AI Clinical & Healthcare Agent for PharmaLink in Cameroon.
You have FULL ACCESS to the PharmaLink live healthcare database below.

=== LIVE PHARMALINK SYSTEM DIRECTORY ===
AVAILABLE CERTIFIED DOCTORS, SPECIALTIES & HOSPITALS:
${systemData.doctorsText}
• Dr. Amadou (General Medicine) - Hôpital Central de Yaoundé | Schedule: Mon-Fri: 08:00-15:30, Sat: 09:00-13:00 | Slots: 09:00 AM, 11:30 AM, 02:30 PM
• Dr. Marie Ngo (Cardiology) - Clinique Bastos & CHU Yaoundé | Schedule: Tue & Thu: 09:00-16:00, Fri: 10:00-14:00 | Slots: 09:30 AM, 11:00 AM, 03:00 PM
• Dr. Pierre Kamdem (Pediatrics) - Hôpital Général de Yaoundé | Schedule: Mon-Fri: 08:30-16:00 | Slots: 09:00 AM, 10:30 AM, 02:00 PM
• Dr. Estelle Fotso (Dermatology) - Hôpital Laquintinie de Douala | Schedule: Mon, Wed, Fri: 09:00-15:00 | Slots: 10:00 AM, 01:30 PM
• Dr. Joseph Ebanda (Gynecology & Obstetrics) - Hôpital Central de Yaoundé | Schedule: Mon-Sat: 08:00-16:00 | Slots: 08:30 AM, 11:00 AM, 02:30 PM

PARTNER HOSPITALS LIST:
1. 🏥 Hôpital Central de Yaoundé
2. 🏥 Centre Hospitalier Universitaire (CHU) Yaoundé
3. 🏥 Hôpital Général de Yaoundé
4. 🏥 Clinique Bastos (Yaoundé)
5. 🏥 Hôpital Laquintinie de Douala
6. 🏥 Hôpital Jamot de Yaoundé

REAL-TIME PHARMACY DRUG INVENTORY & PRICES (SORTED CHEAPEST FIRST):
${systemData.medicationsText}
========================================

MANDATORY APPOINTMENT BOOKING WORKFLOW (STEP-BY-STEP PROTOCOL):
When the user wants to book or make an appointment, you MUST guide them conversationally through these steps:

• STEP 1 (Ask Hospital First):
  If the hospital is not mentioned yet, ask:
  "Which hospital would you like to visit?" and list the partner hospitals clearly with numbers.

• STEP 2 (List Specialists at that Hospital):
  Once the hospital is chosen, list the available specialists and doctors practicing at that hospital (e.g. Dr. Amadou - General Medicine, Dr. Joseph Ebanda - Gynecology at Hôpital Central), and ask them which specialist or doctor they would like to consult.

• STEP 3 (Show Doctor Schedule & Time Slots):
  Once the specialist/doctor is selected:
  Show the doctor's weekly working schedule (e.g. Mon-Fri 08:00 - 15:30) and suggest 2-3 available time slots (e.g. Tomorrow at 09:00 AM, 11:30 AM, or 02:30 PM). Ask them what date and time suits them best, and whether they prefer In-Person or Telemedicine Video.

• STEP 4 (Review & Ask for Confirmation):
  Once they give date/time, summarize the appointment clearly:
  - 🏥 **Hospital:** [Hospital Name]
  - 👨‍⚕️ **Doctor:** [Doctor Name & Specialty]
  - 📅 **Date & Time:** [Date and Time]
  - 📱 **Type:** [In-Person / Telemedicine]
  And ask at the end:
  "👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**"

• STEP 5 (Final Confirmation):
  When they reply "Yes" or "Confirm", acknowledge and confirm the booking!

MEDICATION ORDERS:
If the user asks to order medications (e.g. "Order Paracetamol"), prepare the order from the cheapest pharmacy in stock and present the order details.

BE INTERACTIVE, PROFESSIONAL, AND EMPATHETIC AT ALL TIMES.`;

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
              temperature: 0.65,
              maxOutputTokens: 850,
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
   * System-Knowledge Aware Fallback Step-by-Step State Machine
   */
  getKnowledgeAwareFallback(msg, systemData, history = []) {
    const lower = (msg || '').toLowerCase().trim();
    const historyText = history.map(h => (h.text || '').toLowerCase()).join(' ');

    // Check what step in booking the user might be at
    const mentionsHospital = lower.includes('central') || lower.includes('chu') || lower.includes('général') || lower.includes('bastos') || lower.includes('laquintinie') || lower.includes('jamot');
    const mentionsDoctor = lower.includes('amadou') || lower.includes('ngo') || lower.includes('kamdem') || lower.includes('fotso') || lower.includes('ebanda') || lower.includes('cardio') || lower.includes('pediat') || lower.includes('derma') || lower.includes('gynec') || lower.includes('general');
    const mentionsTime = lower.includes('tomorrow') || lower.includes('demain') || lower.includes('am') || lower.includes('pm') || lower.includes('09') || lower.includes('10') || lower.includes('11') || lower.includes('14') || lower.includes('15') || lower.includes('morning') || lower.includes('afternoon');

    // Step 1: User asks to book an appointment without specifying hospital
    if ((lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('consultation') || lower.includes('doctor')) && !mentionsHospital && !mentionsDoctor) {
      return `🏥 **Step 1: Choose Your Preferred Hospital**\n\nWhich hospital would you like to visit for your consultation?\n\n1. 🏥 **Hôpital Central de Yaoundé**\n2. 🏥 **Centre Hospitalier Universitaire (CHU) Yaoundé**\n3. 🏥 **Clinique Bastos (Yaoundé)**\n4. 🏥 **Hôpital Général de Yaoundé**\n5. 🏥 **Hôpital Laquintinie de Douala**\n\n*Please reply with the hospital name or number to see the available specialists!*`;
    }

    // Step 2: Hospital chosen, show specialists at that hospital
    if (mentionsHospital && !mentionsDoctor) {
      let hospitalName = 'Hôpital Central de Yaoundé';
      if (lower.includes('chu')) hospitalName = 'CHU Yaoundé';
      else if (lower.includes('bastos')) hospitalName = 'Clinique Bastos';
      else if (lower.includes('général')) hospitalName = 'Hôpital Général de Yaoundé';
      else if (lower.includes('laquintinie')) hospitalName = 'Hôpital Laquintinie de Douala';

      return `👨‍⚕️ **Step 2: Choose a Specialist at ${hospitalName}**\n\nHere are the available certified specialists at this facility:\n\n• **Dr. Amadou** — *General Medicine / Consultation Générale*\n• **Dr. Joseph Ebanda** — *Gynecology & Obstetrics*\n• **Dr. Marie Ngo** — *Cardiology & Internal Medicine*\n• **Dr. Pierre Kamdem** — *Pediatrics & Child Health*\n\n*Which doctor or specialty would you like to consult?*`;
    }

    // Step 3: Doctor chosen, show schedule and available slots
    if (mentionsDoctor && !mentionsTime) {
      let docName = 'Dr. Amadou';
      let specialty = 'General Medicine';
      let schedule = 'Monday to Friday: 08:00 AM – 03:30 PM, Saturday: 09:00 AM – 01:00 PM';
      let slots = '• Slot 1: Tomorrow at 09:00 AM\n• Slot 2: Tomorrow at 11:30 AM\n• Slot 3: Tomorrow at 02:30 PM';

      if (lower.includes('ngo') || lower.includes('cardio')) {
        docName = 'Dr. Marie Ngo';
        specialty = 'Cardiology';
        schedule = 'Tuesday & Thursday: 09:00 AM – 04:00 PM, Friday: 10:00 AM – 02:00 PM';
        slots = '• Slot 1: Thursday at 09:30 AM\n• Slot 2: Thursday at 11:00 AM\n• Slot 3: Friday at 10:30 AM';
      } else if (lower.includes('kamdem') || lower.includes('pediat')) {
        docName = 'Dr. Pierre Kamdem';
        specialty = 'Pediatrics';
        schedule = 'Monday to Friday: 08:30 AM – 04:00 PM';
        slots = '• Slot 1: Tomorrow at 09:00 AM\n• Slot 2: Tomorrow at 10:30 AM\n• Slot 3: Tomorrow at 02:00 PM';
      }

      return `📅 **Step 3: Consultation Schedule & Available Time Slots**\n\n**${docName}** (${specialty})\n• **Working Schedule:** ${schedule}\n\n**Upcoming Available Time Slots:**\n${slots}\n\n**Mode:** 🏥 In-Person or 📱 Telemedicine Video Call\n\n*Which date, time slot, and consultation mode do you prefer?*`;
    }

    // Step 4: Time chosen, show summary and ask for confirmation
    if (mentionsTime || (historyText.includes('step 3') && lower.length > 0)) {
      return `📋 **Step 4: Review Your Appointment Summary**\n\n• **Hospital:** 🏥 Hôpital Central de Yaoundé\n• **Doctor:** 👨‍⚕️ **Dr. Amadou** (General Medicine)\n• **Date & Time:** 📅 Tomorrow at 10:00 AM\n• **Consultation Mode:** 🏥 In-Person Consultation\n• **Consultation Fee:** Covered / Standard Rate\n\n👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**`;
    }

    if (/^(hi|hello|hey|salut|bonjour)/.test(lower)) {
      return `Hello! I'm your PharmaLink Autonomous Clinical Agent. 🩺\n\nI can:\n• **Book doctor appointments** step-by-step (Hospital → Specialist → Schedule → Confirmation).\n• **Order medications** from the cheapest pharmacies in stock.\n• Provide clinical symptom and dosage guidance.\n\nWould you like to book an appointment or order medications?`;
    }

    return `I am here to assist you! You can ask me to **book an appointment step-by-step**, **order medications**, or answer your health inquiries.\n\nWhich hospital or health service would you like to explore?`;
  }
}

module.exports = new GeminiService();
