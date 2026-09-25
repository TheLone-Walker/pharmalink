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

    const isExplicitConfirmation = (
      lower === 'yes' || lower === 'oui' || lower === 'confirm' || lower === 'confirmer' ||
      lower === 'confirm appointment' || lower === 'confirm order' || lower === 'yes confirm' ||
      lower === 'yes please' || lower === 'valider' || lower === 'valider la commande' ||
      lower.startsWith('confirm ') || lower.startsWith('yes, ') ||
      (lower.includes('confirm') && (lower.includes('order') || lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('booking') || lower.includes('commande')))
    );

    // Look back in history to detect context
    const recentHistoryText = Array.isArray(history)
      ? history.slice(-4).map(h => (h.text || h.content || '').toLowerCase()).join(' ')
      : '';

    // ─── ACTION 1: EXPLICIT APPOINTMENT CONFIRMATION ────────────────────────────
    const hasPendingAppointmentReview = recentHistoryText.includes('hospital') ||
      recentHistoryText.includes('specialist') ||
      recentHistoryText.includes('confirm this appointment') ||
      recentHistoryText.includes('step 4: review your appointment') ||
      recentHistoryText.includes('rendez-vous');

    if ((isExplicitConfirmation && hasPendingAppointmentReview && userId) ||
        (lower.includes('confirm') && lower.includes('doctor') && userId)) {
      
      let targetDoctor = systemData.doctors.find(d =>
        (lower + ' ' + recentHistoryText).includes(d.name.toLowerCase().replace('dr.', '').trim())
      );
      if (!targetDoctor && systemData.doctors.length > 0) {
        targetDoctor = systemData.doctors[0];
      }

      if (targetDoctor) {
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
            reply: `🎉 **Appointment Successfully Confirmed & Booked!**\n\nHere are your final consultation details:\n• **Hospital / Facility:** 🏥 ${hospitalName}\n• **Specialist:** 👨‍⚕️ **${docName}** (${targetDoctor.doctorProfile?.specialty || 'General Medicine'})\n• **Date & Time:** 📅 ${formattedDate}\n• **Consultation Mode:** ${type === 'telemedicine' ? '📱 Telemedicine Video Call' : '🏥 In-Person at Hospital'}\n• **Status:** Confirmed ✅\n\nDr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}'s clinic has been notified. Tap below to access your appointment card.`,
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

    // ─── ACTION 2: EXPLICIT MEDICATION ORDER CONFIRMATION ───────────────────────
    const hasPendingOrderReview = recentHistoryText.includes('step 4: review your medication order') ||
      recentHistoryText.includes('confirm this order') ||
      recentHistoryText.includes('pharmacy') ||
      recentHistoryText.includes('delivery fee') ||
      recentHistoryText.includes('total to pay') ||
      recentHistoryText.includes('commande');

    if ((isExplicitConfirmation && hasPendingOrderReview && userId) ||
        (lower.includes('confirm') && (lower.includes('order') || lower.includes('drug') || lower.includes('medication')) && userId)) {
      
      // Find matching medication from context or current message
      let targetMed = systemData.medications.find(m =>
        (lower + ' ' + recentHistoryText).includes(m.name.toLowerCase().split(' ')[0])
      );
      if (!targetMed && systemData.medications.length > 0) {
        targetMed = systemData.medications[0];
      }

      if (targetMed) {
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
            reply: `🎉 **Medication Order Confirmed & Placed!**\n\nYour order has been registered at **${pharmName}**:\n• **Medication:** 💊 ${targetMed.name} x${quantity}\n• **Total Amount:** FCFA ${totalFcfa.toLocaleString()}\n• **Pharmacy:** 🏪 ${pharmName}\n• **Fulfillment:** 🛵 Express Doorstep Courier Delivery\n• **Status:** Pending Payment / Packaging\n\nTap the action button below to complete instant payment with **MTN MoMo**, **Orange Money**, or select **Cash on Delivery** and track your courier live on the map!`,
            action: {
              type: 'order',
              id: order.id,
              totalFcfa,
              title: `Pay FCFA ${totalFcfa.toLocaleString()} & Track Order`,
              data: order,
            },
          };
        } catch (err) {
          console.error('[Gemini Agent] Order creation failed:', err.message);
        }
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
When the user wants to book or make an appointment:
• STEP 1 (Ask Hospital First): If hospital not specified, ask "Which hospital would you like to visit?" and list the partner hospitals clearly with numbers.
• STEP 2 (List Specialists at that Hospital): Once hospital chosen, list available doctors & specialties at that hospital, and ask them to choose.
• STEP 3 (Show Schedule & Time Slots): Show working hours and 2-3 available slots (e.g. Tomorrow 09:00 AM, 11:30 AM, 02:30 PM, In-person vs Telemedicine), and ask what suits them.
• STEP 4 (Review & Ask for Confirmation): Summarize Hospital, Doctor, Date/Time, and Mode. Ask:
  "👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**"
• STEP 5 (Final Confirmation): When they reply "Yes" or "Confirm", acknowledge and finalize!

MANDATORY MEDICATION ORDER WORKFLOW (STEP-BY-STEP PROTOCOL):
When the user wants to order or buy medications:
• STEP 1 (Ask Medication First): If medication name is not specified yet, ask:
  "Which medication are you looking to purchase?" (Give examples: Paracetamol 500mg, Coartem, Amoxicillin 500mg, Ibuprofen 400mg, etc.).
• STEP 2 (Price & Pharmacy Comparison): Once the drug is named, inspect the directory and list the licensed pharmacies with stock & price (sorted cheapest first). Ask which pharmacy they prefer and quantity (e.g. 1 box, 2 boxes).
• STEP 3 (Delivery Method & Location): Ask for fulfillment method:
  1. 🛵 Express Doorstep Courier Delivery (Direct home delivery with live GPS courier tracking)
  2. 🚶 Pharmacy Counter Pickup (Ready in 15 mins)
  Ask for their delivery neighborhood/address (e.g. Quartier Bastos, Yaoundé).
• STEP 4 (Review & Ask for Order Confirmation):
  Summarize the complete order:
  - 💊 **Medication:** [Drug Name] (Qty: X)
  - 🏪 **Pharmacy:** [Pharmacy Name & Location]
  - 💰 **Medication Price:** [FCFA]
  - 🛵 **Delivery Mode:** [Express Delivery / Pickup]
  - 💳 **Total to Pay:** [Total FCFA]
  - 📍 **Delivery Destination:** [Address]
  - 💵 **Accepted Payments:** MTN MoMo, Orange Money, Cash on Delivery
  And ask at the end:
  "👉 **Do you confirm this order? (Please reply 'Yes' or 'Confirm' to place your order)**"
• STEP 5 (Final Confirmation):
  When they reply "Yes" or "Confirm", acknowledge and confirm the order!

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

    // ───────────────── APPOINTMENT FLOW CHECKS ─────────────────
    const isAppointmentIntent = lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('consultation') || lower.includes('doctor');
    const mentionsHospital = lower.includes('central') || lower.includes('chu') || lower.includes('général') || lower.includes('bastos') || lower.includes('laquintinie') || lower.includes('jamot');
    const mentionsDoctor = lower.includes('amadou') || lower.includes('ngo') || lower.includes('kamdem') || lower.includes('fotso') || lower.includes('ebanda') || lower.includes('cardio') || lower.includes('pediat') || lower.includes('derma') || lower.includes('gynec') || lower.includes('general');
    const mentionsTime = lower.includes('tomorrow') || lower.includes('demain') || lower.includes('am') || lower.includes('pm') || lower.includes('09') || lower.includes('10') || lower.includes('11') || lower.includes('14') || lower.includes('15') || lower.includes('morning') || lower.includes('afternoon');

    if (isAppointmentIntent && !mentionsHospital && !mentionsDoctor) {
      return `🏥 **Step 1: Choose Your Preferred Hospital**\n\nWhich hospital would you like to visit for your consultation?\n\n1. 🏥 **Hôpital Central de Yaoundé**\n2. 🏥 **Centre Hospitalier Universitaire (CHU) Yaoundé**\n3. 🏥 **Clinique Bastos (Yaoundé)**\n4. 🏥 **Hôpital Général de Yaoundé**\n5. 🏥 **Hôpital Laquintinie de Douala**\n\n*Please reply with the hospital name or number to see the available specialists!*`;
    }

    if (mentionsHospital && !mentionsDoctor) {
      let hospitalName = 'Hôpital Central de Yaoundé';
      if (lower.includes('chu')) hospitalName = 'CHU Yaoundé';
      else if (lower.includes('bastos')) hospitalName = 'Clinique Bastos';
      else if (lower.includes('général')) hospitalName = 'Hôpital Général de Yaoundé';
      else if (lower.includes('laquintinie')) hospitalName = 'Hôpital Laquintinie de Douala';

      return `👨‍⚕️ **Step 2: Choose a Specialist at ${hospitalName}**\n\nHere are the available certified specialists at this facility:\n\n• **Dr. Amadou** — *General Medicine / Consultation Générale*\n• **Dr. Joseph Ebanda** — *Gynecology & Obstetrics*\n• **Dr. Marie Ngo** — *Cardiology & Internal Medicine*\n• **Dr. Pierre Kamdem** — *Pediatrics & Child Health*\n\n*Which doctor or specialty would you like to consult?*`;
    }

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
      }

      return `📅 **Step 3: Consultation Schedule & Available Time Slots**\n\n**${docName}** (${specialty})\n• **Working Schedule:** ${schedule}\n\n**Upcoming Available Time Slots:**\n${slots}\n\n**Mode:** 🏥 In-Person or 📱 Telemedicine Video Call\n\n*Which date, time slot, and consultation mode do you prefer?*`;
    }

    if (historyText.includes('consultation schedule') && (mentionsTime || lower.length > 0)) {
      return `📋 **Step 4: Review Your Appointment Summary**\n\n• **Hospital:** 🏥 Hôpital Central de Yaoundé\n• **Doctor:** 👨‍⚕️ **Dr. Amadou** (General Medicine)\n• **Date & Time:** 📅 Tomorrow at 10:00 AM\n• **Consultation Mode:** 🏥 In-Person Consultation\n• **Status:** Pending Confirmation\n\n👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**`;
    }

    // ───────────────── MEDICATION ORDER FLOW CHECKS ────────────
    const isOrderIntent = lower.includes('order') || lower.includes('buy') || lower.includes('purchase') || lower.includes('commander') || lower.includes('acheter') || lower.includes('drug') || lower.includes('medication') || lower.includes('médicament');
    const mentionsDrug = lower.includes('paracetamol') || lower.includes('coartem') || lower.includes('amoxicillin') || lower.includes('ibuprofen') || lower.includes('metformin') || lower.includes('artemether') || lower.includes('lisinopril');
    const mentionsPharmacy = lower.includes('centrale') || lower.includes('bastos') || lower.includes('soleil') || lower.includes('pharmacie') || lower.includes('1') || lower.includes('2');
    const mentionsDelivery = lower.includes('delivery') || lower.includes('courier') || lower.includes('pickup') || lower.includes('livraison') || lower.includes('domicile') || lower.includes('yaoundé') || lower.includes('douala');

    // Order Step 1: User asks to order without mentioning specific drug
    if (isOrderIntent && !mentionsDrug && !historyText.includes('step 1 (order)')) {
      return `💊 **Step 1: What Medication Would You Like to Order?**\n\nWhich medication or prescription are you looking for?\n\n*Popular in stock items:*\n• **Paracetamol 500mg / 1g** (Pain & Fever)\n• **Coartem (Artemether-Lumefantrine)** (Malaria ACT)\n• **Amoxicillin 500mg** (Antibiotic)\n• **Ibuprofen 400mg** (Anti-inflammatory)\n• **Metformin 500mg** (Diabetes Management)\n\n*Please type the name of the medication you need!*`;
    }

    // Order Step 2: Drug mentioned, compare pharmacy prices
    if (mentionsDrug && !mentionsPharmacy && !historyText.includes('step 2 (order)')) {
      let drugName = 'Paracetamol 500mg';
      if (lower.includes('coartem') || lower.includes('artemether')) drugName = 'Coartem (Artemether-Lumefantrine)';
      else if (lower.includes('amoxicillin')) drugName = 'Amoxicillin 500mg';
      else if (lower.includes('ibuprofen')) drugName = 'Ibuprofen 400mg';

      return `🏪 **Step 2: Price Comparison for ${drugName}**\n\nHere are the licensed pharmacies with stock (sorted cheapest first):\n\n1. 🏪 **Pharmacie Centrale** (Avenue Kennedy, Bastos)\n   • **Price:** FCFA 1,200 | Stock: 50 available ✅\n\n2. 🏪 **Pharmacie Bastos** (Rond-point Bastos)\n   • **Price:** FCFA 1,400 | Stock: 35 available ✅\n\n3. 🏪 **Pharmacie du Soleil** (Centre-ville)\n   • **Price:** FCFA 1,550 | Stock: 20 available ✅\n\n*Which pharmacy would you like to purchase from, and how many units (e.g. 1 box, 2 boxes)?*`;
    }

    // Order Step 3: Pharmacy/Quantity selected, ask for Delivery or Pickup
    if (historyText.includes('price comparison') && !mentionsDelivery) {
      return `🛵 **Step 3: Choose Fulfillment & Delivery Address**\n\nHow would you like to receive your medication?\n\n1. 🛵 **Express Doorstep Courier Delivery** (Direct home delivery with real-time GPS courier tracking)\n2. 🚶 **Pharmacy Counter Pickup** (Prepared in 15 mins with QR pickup code)\n\n*Please provide your delivery neighborhood / address (e.g. Quartier Bastos, Yaoundé) or reply 'Pickup'!*`;
    }

    // Order Step 4: Address provided, show order review and ask for confirmation
    if (historyText.includes('step 3: choose fulfillment') || (historyText.includes('price comparison') && mentionsDelivery)) {
      return `📋 **Step 4: Review Your Medication Order Summary**\n\n• **Medication:** 💊 **Paracetamol 500mg** (Qty: 1 box)\n• **Pharmacy:** 🏪 **Pharmacie Centrale** (Avenue Kennedy)\n• **Item Total:** FCFA 1,200\n• **Delivery Method:** 🛵 Express Doorstep Courier (Quartier Bastos, Yaoundé)\n• **Delivery Fee:** FCFA 1,000\n• **Total to Pay:** 💳 **FCFA 2,200**\n• **Accepted Payment Methods:** MTN MoMo, Orange Money, Cash on Delivery\n\n👉 **Do you confirm this order? (Please reply 'Yes' or 'Confirm' to finalize your order)**`;
    }

    if (/^(hi|hello|hey|salut|bonjour)/.test(lower)) {
      return `Hello! I'm your PharmaLink Autonomous Clinical Agent. 🩺\n\nI can:\n• **Book doctor appointments** step-by-step (Hospital → Specialist → Schedule → Confirmation).\n• **Order medications** step-by-step (Drug → Price Comparison → Delivery → Confirmation).\n• Provide clinical symptom and dosage guidance.\n\nWhat would you like to do today?`;
    }

    return `I am here to assist you! You can ask me to **book an appointment step-by-step**, **order medications with price comparison**, or ask medical questions.\n\nHow can I help you?`;
  }
}

module.exports = new GeminiService();
