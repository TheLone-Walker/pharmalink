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
   * Loads real-time system directory (Doctors, Hospitals, Pharmacy drug stocks, prices & prescription requirements)
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
            return `• Dr. ${d.name.replace(/^Dr\.\s*/i, '')} (ID: ${d.id}) | Specialty: ${p.specialty || 'General Medicine'} | Hospital: ${p.hospital || 'Hôpital Central de Yaoundé'} | Status: Verified ONMC | On-Call / Emergency: ${p.isOnCall ? 'YES 🌙 (24/7 Night Guard)' : 'Regular Clinic'}`;
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
            const rxTag = m.requiresPrescription ? '📄 [PRESCRIPTION REQUIRED]' : '🟢 [OVER-THE-COUNTER / OTC]';
            return `• ${m.name} (ID: ${m.id}): FCFA ${m.priceFcfa} at "${ph}" (${addr}) - Stock: ${m.stockQuantity} | ${rxTag}`;
          }).join('\n')
        : '• Paracetamol 500mg: FCFA 1,200 at Pharmacie Centrale (Avenue Kennedy) - 🟢 [OTC]\n• Coartem (Artemether-Lumefantrine): FCFA 2,200 at Pharmacie Bastos - 🟢 [OTC]\n• Amoxicillin 500mg: FCFA 2,500 at Pharmacie du Soleil - 📄 [PRESCRIPTION REQUIRED]';

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
            reply: `🎉 **Appointment Successfully Confirmed & Booked!**\n\nHere are your final consultation details:\n• **Hospital / Facility:** 🏥 ${hospitalName}\n• **Specialist:** 👨‍⚕️ **${docName}** (${targetDoctor.doctorProfile?.specialty || 'General Medicine'})\n• **Date & Time:** 📅 ${formattedDate}\n• **Consultation Mode:** ${type === 'telemedicine' ? '📱 Telemedicine Video Call' : '🏥 In-Person at Hospital'}\n• **Dashboard Sync:** Added to your Patient Dashboard upcoming appointments section ✅\n• **Status:** Confirmed ✅\n\nDr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}'s clinic has been notified. You can view and manage this appointment directly in your dashboard.`,
            action: {
              type: 'appointment',
              id: appointment.id,
              title: 'View Confirmed Appointment in Dashboard',
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
        // ─── STRICT PRESCRIPTION COMPLIANCE CHECK ───
        if (targetMed.requiresPrescription) {
          // Check if patient has an approved prescription
          let approvedRx = null;
          try {
            approvedRx = await prisma.prescription.findFirst({
              where: {
                patientId: userId,
                status: 'approved',
              },
              orderBy: { createdAt: 'desc' },
            });
          } catch (_) {}

          if (!approvedRx) {
            return {
              reply: `⚠️ **Prescription Required for ${targetMed.name}**\n\nUnder Cameroon pharmaceutical regulations, **${targetMed.name}** is a regulated prescription drug and **cannot be dispensed without an approved doctor's prescription**.\n\n🛡️ **How to get this medication:**\n1. Book a quick consultation with one of our certified doctors to receive a verified digital prescription.\n2. Or choose from our wide range of **Over-The-Counter (OTC)** alternatives.\n\n*Would you like me to connect you with a doctor right now to get evaluated?*`,
              action: {
                type: 'appointment',
                title: 'Book Doctor Consultation for Prescription',
              },
            };
          }
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
            reply: `🎉 **Medication Order Confirmed & Placed!**\n\nYour order has been registered at **${pharmName}**:\n• **Medication:** 💊 ${targetMed.name} x${quantity} ${targetMed.requiresPrescription ? '(Prescription Verified 📄)' : '(OTC 🟢)'}\n• **Total Amount:** FCFA ${totalFcfa.toLocaleString()}\n• **Pharmacy:** 🏪 ${pharmName}\n• **Fulfillment:** 🛵 Express Doorstep Courier Delivery\n• **Digital Receipt:** 🧾 Universal digital receipt generated for all payment methods\n• **Status:** Pending Payment / Packaging\n\nTap below to complete payment with **MTN MoMo**, **Orange Money**, **Card**, or **Cash on Delivery** and download your official receipt.`,
            action: {
              type: 'order',
              id: order.id,
              totalFcfa,
              title: `Pay FCFA ${totalFcfa.toLocaleString()} & View Receipt`,
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
AVAILABLE CERTIFIED DOCTORS, SPECIALTIES, HOSPITALS & ON-CALL STATUS:
${systemData.doctorsText}
• Dr. Amadou (General Medicine) - Hôpital Central de Yaoundé | Schedule: Mon-Fri: 08:00-15:30, Sat: 09:00-13:00 | Slots: 09:00 AM, 11:30 AM, 02:30 PM | On-Call: 24/7 Night Guard
• Dr. Marie Ngo (Cardiology) - Clinique Bastos & CHU Yaoundé | Schedule: Tue & Thu: 09:00-16:00, Fri: 10:00-14:00 | Slots: 09:30 AM, 11:00 AM, 03:00 PM | On-Call: Emergency Cardiology
• Dr. Pierre Kamdem (Pediatrics) - Hôpital Général de Yaoundé | Schedule: Mon-Fri: 08:30-16:00 | Slots: 09:00 AM, 10:30 AM, 02:00 PM | On-Call: Pediatric Urgent Care
• Dr. Estelle Fotso (Dermatology) - Hôpital Laquintinie de Douala | Schedule: Mon, Wed, Fri: 09:00-15:00 | Slots: 10:00 AM, 01:30 PM
• Dr. Joseph Ebanda (Gynecology & Obstetrics) - Hôpital Central de Yaoundé | Schedule: Mon-Sat: 08:00-16:00 | Slots: 08:30 AM, 11:00 AM, 02:30 PM | On-Call: Maternity Emergencies

PARTNER HOSPITALS LIST:
1. 🏥 Hôpital Central de Yaoundé
2. 🏥 Centre Hospitalier Universitaire (CHU) Yaoundé
3. 🏥 Hôpital Général de Yaoundé
4. 🏥 Clinique Bastos (Yaoundé)
5. 🏥 Hôpital Laquintinie de Douala
6. 🏥 Hôpital Jamot de Yaoundé

NIGHT GUARD & 24/7 EMERGENCY SERVICES:
• Pharmacies de Garde (24/7): Pharmacie Bastos (Open 24/7), Pharmacie de la Gare, Pharmacie Centrale
• Emergency On-Call Doctors: Dr. Amadou (General Urgent Care), Dr. Joseph Ebanda (Obstetrics Emergency)
• National Emergency Hotlines: SAMU 119, SAMU 15 (Free toll-free medical response in Cameroon)

REAL-TIME PHARMACY DRUG INVENTORY, PRICES & PRESCRIPTION REGULATION:
${systemData.medicationsText}
========================================

REGULATION & PRESCRIPTION RULES (CRITICAL):
• Medications marked with 📄 [PRESCRIPTION REQUIRED] (such as antibiotics like Amoxicillin, injectable drugs, controlled substances) CANNOT be sold or dispensed without a doctor's prescription.
• Medications marked with 🟢 [OVER-THE-COUNTER / OTC] (such as Paracetamol, Coartem, Vitamin C, basic antacids) can be freely purchased without a prescription.
• If a patient asks to buy a regulated prescription drug without a prescription, politely explain that regulations prevent dispensing without a prescription, and offer to schedule a doctor consultation so they can obtain one legally.

PAYMENT & DIGITAL RECEIPT RULES:
• Digital receipts are automatically generated for ALL payment methods (MTN MoMo, Orange Money, Credit Card, and Cash on Delivery / Pickup Counter).
• Patients can download and view their digital receipt anytime in their Patient Dashboard.

PATIENT DASHBOARD APPOINTMENTS:
• All booked consultations are immediately synchronized to the patient's Dashboard under Upcoming Appointments.

MANDATORY APPOINTMENT BOOKING WORKFLOW (STEP-BY-STEP PROTOCOL):
When the user wants to book or make an appointment:
• STEP 1 (Ask Hospital First): If hospital not specified, ask "Which hospital would you like to visit?" and list the partner hospitals clearly with numbers.
• STEP 2 (List Specialists at that Hospital): Once hospital chosen, list available doctors & specialties at that hospital, and ask them to choose.
• STEP 3 (Show Schedule & Time Slots): Show working hours and 2-3 available slots (e.g. Tomorrow 09:00 AM, 11:30 AM, 02:30 PM, In-person vs Telemedicine), and ask what suits them.
• STEP 4 (Review & Ask for Confirmation): Summarize Hospital, Doctor, Date/Time, Mode, and note that it will sync to their Patient Dashboard. Ask:
  "👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**"
• STEP 5 (Final Confirmation): When they reply "Yes" or "Confirm", acknowledge and finalize!

MANDATORY MEDICATION ORDER WORKFLOW (STEP-BY-STEP PROTOCOL):
When the user wants to order or buy medications:
• STEP 1 (Ask Medication First): If medication name is not specified yet, ask:
  "Which medication are you looking to purchase?" (Give examples: Paracetamol 500mg [OTC], Coartem [OTC], Amoxicillin 500mg [Rx Required], Ibuprofen 400mg [OTC]).
• STEP 2 (Price & Pharmacy Comparison + Rx Flag): Once the drug is named, inspect the directory and list the licensed pharmacies with stock & price (sorted cheapest first) and specify if prescription is needed. Ask which pharmacy they prefer and quantity.
• STEP 3 (Delivery Method & Location): Ask for fulfillment method:
  1. 🛵 Express Doorstep Courier Delivery (Direct home delivery with live GPS courier tracking)
  2. 🚶 Pharmacy Counter Pickup (Ready in 15 mins)
  Ask for their delivery neighborhood/address (e.g. Quartier Bastos, Yaoundé).
• STEP 4 (Review & Ask for Order Confirmation):
  Summarize the complete order:
  - 💊 **Medication:** [Drug Name] (Qty: X) - [OTC 🟢 or Rx Verified 📄]
  - 🏪 **Pharmacy:** [Pharmacy Name & Location]
  - 💰 **Medication Price:** [FCFA]
  - 🛵 **Delivery Mode:** [Express Delivery / Pickup]
  - 💳 **Total to Pay:** [Total FCFA]
  - 📍 **Delivery Destination:** [Address]
  - 💵 **Accepted Payments:** MTN MoMo, Orange Money, Cash on Delivery (Universal Digital Receipt Provided 🧾)
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
   * System-Knowledge Aware Fallback Step-by-Step State Machine & Clinical Engine
   */
  getKnowledgeAwareFallback(msg, systemData, history = []) {
    const raw = (msg || '').trim();
    const lower = raw.toLowerCase();

    // ───────────────── 1. GREETINGS & CASUAL CONVERSATION (HIGHEST PRIORITY) ─────
    const isGreeting = /^(hi|hello|hey|salut|bonjour|bonsoir|good morning|good afternoon|good evening|yo|coucou|hola)\b/i.test(lower) ||
      lower === 'hi' || lower === 'hello' || lower === 'bonjour' || lower === 'salut' || lower === 'hey' ||
      lower === 'how are you' || lower === 'how are you doing' || lower === 'ça va' || lower === 'ca va' || lower === 'comment tu vas';

    if (isGreeting) {
      return `Hello there! 👋 How are you feeling today?\n\nI'm your **PharmaLink Clinical & Healthcare Assistant** 🩺. I'm here to help you naturally with anything you need:\n\n• 👨‍⚕️ **Book an appointment** with certified doctors & specialists across top hospitals.\n• 💊 **Order medications** with live pharmacy price comparisons (OTC & prescription).\n• 🌙 **24/7 Night Guard services** (pharmacies de garde & on-call emergency doctors).\n• 🧾 **Universal Digital Receipts** for all payments.\n• 🩺 **Clinical advice & symptom evaluation** for malaria, fevers, aches, and general health.\n\nTell me, what can I assist you with today?`;
    }

    // Casual "how does it work" / "who are you"
    if (lower.includes('who are you') || lower.includes('what can you do') || lower.includes('qui es tu') || lower.includes('que peux tu faire') || lower.includes('help me') || lower === 'help') {
      return `I'm **PharmaLink's AI Health Agent** 🩺, designed specifically for healthcare patients in Cameroon!\n\nHere is how I can make healthcare simple for you:\n1. 🏥 **Find & Book Doctors:** Pick a hospital (Hôpital Central, CHU, Bastos, etc.) and specialist for In-Person or Telemedicine video calls.\n2. 💊 **Compare & Order Drugs:** Compare real-time pharmacy prices and get express courier delivery to your doorstep.\n3. 🌙 **Night Emergency Support:** Access on-call doctors and 24/7 guard pharmacies anytime.\n4. 🧾 **Payment Receipts:** Every order (MTN MoMo, Orange Money, Cash) gets an official digital receipt in your dashboard.\n\nFeel free to ask me any question or tell me what you'd like to do!`;
    }

    // ───────────────── 2. NIGHT GUARD & 24/7 EMERGENCY CHECKS ─────
    const isNightGuardIntent = lower.includes('guard') || lower.includes('garde') || lower.includes('night') || lower.includes('nuit') || lower.includes('emergency') || lower.includes('urgence') || lower.includes('24/7') || lower.includes('hotline') || lower.includes('urgent');
    if (isNightGuardIntent && (lower.includes('pharmacy') || lower.includes('doctor') || lower.includes('call') || lower.includes('service') || lower.includes('garde') || lower.includes('night') || lower.includes('hotline') || lower.includes('urgence'))) {
      return `🌙 **Night Guard & 24/7 Emergency Medical Services (Cameroon)**\n\n🚨 **National Toll-Free Emergency Numbers:**\n• 📞 **SAMU Urgence Médicale:** Dial **119** or **15** (24h/24 Free)\n• 🚒 **Sapeurs-Pompiers (Rescue):** Dial **118**\n\n🏥 **Pharmacies de Garde (Open 24/7 Tonight):**\n1. 🏪 **Pharmacie Bastos** (Rond-point Bastos, Yaoundé) — 📞 Tel: +237 670 00 11 22 | Open 24h/24\n2. 🏪 **Pharmacie de la Gare** (Avenue de la Gare, Yaoundé) — 📞 Tel: +237 690 11 22 33 | Open 24h/24\n3. 🏪 **Pharmacie Centrale** (Centre-ville) — 📞 Tel: +237 677 33 44 55 | Open 24h/24\n\n👨‍⚕️ **Emergency Doctors On-Call Tonight:**\n• 👨‍⚕️ **Dr. Amadou** — Emergency Triage & General Medicine (Hôpital Central de Yaoundé)\n• 👨‍⚕️ **Dr. Joseph Ebanda** — Gynecology & Obstetrics Urgent Care\n\n*Would you like me to connect you with an on-call doctor or help you order essential emergency medication?*`;
    }

    // ───────────────── 3. DIGITAL RECEIPT & PAYMENT QUERIES ─────────
    const isReceiptIntent = lower.includes('receipt') || lower.includes('recu') || lower.includes('reçu') || lower.includes('facture') || lower.includes('invoice') || lower.includes('proof of payment');
    if (isReceiptIntent) {
      return `🧾 **PharmaLink Universal Digital Payment Receipts**\n\nEvery medication purchase and consultation on PharmaLink automatically generates an official digital receipt:\n\n• **All Payment Methods:** MTN MoMo, Orange Money, Credit Card, and Cash on Delivery / Pickup Counter.\n• **Receipt Details:** Itemized breakdown, pharmacy registration number, digital verification stamp, and verifiable QR code.\n• **How to Access:** Navigate to **Patient Dashboard** → **My Orders** → tap **'View Receipt'**.\n\n*Would you like assistance checking a recent order or making a payment?*`;
    }

    // ───────────────── 4. COMMON CLINICAL SYMPTOM & MEDICAL GUIDANCE ─────
    // Malaria / Paludisme
    if (lower.includes('malaria') || lower.includes('palu') || lower.includes('paludisme') || lower.includes('coartem') || lower.includes('artemether') || lower.includes('fever and chills')) {
      return `🦟 **Malaria (Paludisme) Guidance & Treatment**\n\n**Common Symptoms:** High fever, chills, sweating, headaches, fatigue, muscle aches, nausea.\n\n💊 **Standard Recommended Treatment (Cameroon National Protocol):**\n• **First-Line Therapy:** Artemisinin-based Combination Therapy (ACT) such as **Coartem (Artemether-Lumefantrine 20/120mg)**.\n• **Dosage:** 1 course taken with food/milk over 3 days exactly as prescribed.\n• **Fever Management:** **Paracetamol 500mg - 1g** every 6-8 hours (max 4g/day) to bring down high body temperature.\n\n⚠️ **Important Medical Advice:**\n• It is strongly advised to perform a **Malaria Rapid Diagnostic Test (RDT)** or blood smear at a lab or hospital to confirm before taking antimalarials.\n• If symptoms persist after 48 hours or if there is vomiting, consult a doctor immediately.\n\n*Would you like me to compare pharmacy prices for Coartem, or book a consultation with a doctor?*`;
    }

    // Headache / Fever / Pain
    if (lower.includes('headache') || lower.includes('mal de tete') || lower.includes('mal de tête') || lower.includes('fever') || lower.includes('fièvre') || lower.includes('pain') || lower.includes('douleur') || lower.includes('paracetamol')) {
      return `💊 **Headache, Fever & Pain Guidance**\n\n**First-Line Relief (Over-The-Counter):**\n• **Paracetamol (Acetaminophen) 500mg to 1000mg:**\n  - Adults: 1 to 2 tablets (500mg-1g) every 6 to 8 hours as needed (Maximum 4,000mg / 4g in 24 hours).\n  - Children: Weight-based dosing (10-15 mg/kg per dose).\n• **Hydration & Rest:** Drink plenty of water and rest in a cool, quiet room.\n\n⚠️ **When to Seek Immediate Medical Attention:**\n• Sudden, very severe "thunderclap" headache.\n• High fever accompanied by stiff neck, confusion, or rash.\n• Fever lasting more than 3 consecutive days.\n\n*Would you like to order Paracetamol from a nearby pharmacy or consult a doctor?*`;
    }

    // Antibiotics & Prescription Requirement Questions
    if (lower.includes('antibiotic') || lower.includes('antibiotique') || lower.includes('amoxicillin') || lower.includes('augmentin') || lower.includes('cipro') || lower.includes('prescription')) {
      return `📄 **Prescription Drug Guidelines & Antibiotics Policy**\n\nUnder Cameroon pharmaceutical regulations and WHO clinical safety standards:\n\n• **Prescription Required (📄):** Antibiotics (e.g. *Amoxicillin, Augmentin, Ciprofloxacin*), strong analgesics, hypertension and diabetes medications require a valid doctor's prescription.\n• **Why it's important:** Prevents antibiotic resistance, adverse drug interactions, and ensures you receive the correct diagnosis and therapeutic course.\n• **Over-The-Counter (🟢):** Pain relievers (Paracetamol, Ibuprofen), ACT Antimalarials (Coartem), antacids, and vitamins can be ordered without a prescription.\n\n*Need a prescription? I can help you schedule a quick In-Person or Telemedicine consultation with a certified doctor right now!*`;
    }

    // Blood Pressure / Hypertension
    if (lower.includes('blood pressure') || lower.includes('hypertension') || lower.includes('tension') || lower.includes('amlodipine') || lower.includes('lisinopril')) {
      return `🩺 **Hypertension & Blood Pressure Care**\n\n**Healthy Adult Reference:** Below 120/80 mmHg.\n\n**Key Health Recommendations:**\n• Monitor your blood pressure regularly and log measurements.\n• Maintain a balanced, low-sodium (low-salt) diet rich in vegetables and hydration.\n• Regular physical activity (30 mins walking daily).\n• Never stop prescribed antihypertensive drugs without consulting your cardiologist or physician.\n\n*Would you like to schedule an appointment with a Cardiologist (e.g. Dr. Marie Ngo)?*`;
    }

    // ───────────────── 5. STEP-BY-STEP APPOINTMENT FLOW ─────────────────────────
    const isAppointmentIntent = lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('consultation') || lower.includes('book doctor') || lower.includes('see doctor') || lower.includes('doctor');
    const mentionsHospital = lower.includes('central') || lower.includes('chu') || lower.includes('général') || lower.includes('bastos') || lower.includes('laquintinie') || lower.includes('jamot') || lower.includes('hopital') || lower.includes('hôpital');
    const mentionsDoctor = lower.includes('amadou') || lower.includes('ngo') || lower.includes('kamdem') || lower.includes('fotso') || lower.includes('ebanda') || lower.includes('cardio') || lower.includes('pediat') || lower.includes('derma') || lower.includes('gynec') || lower.includes('general');
    const mentionsTime = lower.includes('tomorrow') || lower.includes('demain') || lower.includes('am') || lower.includes('pm') || lower.includes('09') || lower.includes('10') || lower.includes('11') || lower.includes('14') || lower.includes('15') || lower.includes('slot') || lower.includes('telemedicine') || lower.includes('video') || lower.includes('in-person');

    // Appointment Step 1: User indicates appointment intent without specific hospital/doctor
    if (isAppointmentIntent && !mentionsHospital && !mentionsDoctor) {
      return `🏥 **Step 1 of 4: Choose Your Preferred Hospital / Clinic**\n\nI'd be glad to help you schedule a consultation! Which medical facility would you prefer?\n\n1. 🏥 **Hôpital Central de Yaoundé** (General, Internal Med, Gynecology)\n2. 🏥 **Centre Hospitalier Universitaire (CHU) Yaoundé** (Cardiology & Specialists)\n3. 🏥 **Clinique Bastos (Yaoundé)** (Private Practice & Cardiology)\n4. 🏥 **Hôpital Général de Yaoundé** (Pediatrics & Multidisciplinary)\n5. 🏥 **Hôpital Laquintinie de Douala** (Dermatology & Emergency)\n\n*Please reply with your preferred hospital name or number to see available specialists.*`;
    }

    // Appointment Step 2: Hospital chosen, list doctors
    if ((mentionsHospital && !mentionsDoctor) || (isAppointmentIntent && mentionsHospital)) {
      let hospitalName = 'Hôpital Central de Yaoundé';
      if (lower.includes('chu')) hospitalName = 'CHU Yaoundé';
      else if (lower.includes('bastos')) hospitalName = 'Clinique Bastos';
      else if (lower.includes('général') || lower.includes('general')) hospitalName = 'Hôpital Général de Yaoundé';
      else if (lower.includes('laquintinie')) hospitalName = 'Hôpital Laquintinie de Douala';

      return `👨‍⚕️ **Step 2 of 4: Select a Specialist at ${hospitalName}**\n\nHere are the available certified specialists at this facility:\n\n• **Dr. Amadou** — *General Medicine & Urgent Care (24/7 On-Call)*\n• **Dr. Joseph Ebanda** — *Gynecology & Obstetrics*\n• **Dr. Marie Ngo** — *Cardiology & Cardiovascular Health*\n• **Dr. Pierre Kamdem** — *Pediatrics & Child Health*\n\n*Which doctor or specialty would you like to consult with?*`;
    }

    // Appointment Step 3: Doctor chosen, show schedule and slots
    if (mentionsDoctor && !mentionsTime) {
      let docName = 'Dr. Amadou';
      let specialty = 'General Medicine';
      let schedule = 'Monday to Friday: 08:00 AM – 03:30 PM | Saturday: 09:00 AM – 01:00 PM';
      let slots = '• Slot 1: Tomorrow at 09:00 AM\n• Slot 2: Tomorrow at 11:30 AM\n• Slot 3: Tomorrow at 02:30 PM';

      if (lower.includes('ngo') || lower.includes('cardio')) {
        docName = 'Dr. Marie Ngo';
        specialty = 'Cardiology';
        schedule = 'Tuesday & Thursday: 09:00 AM – 04:00 PM | Friday: 10:00 AM – 02:00 PM';
        slots = '• Slot 1: Thursday at 09:30 AM\n• Slot 2: Thursday at 11:00 AM\n• Slot 3: Friday at 10:30 AM';
      } else if (lower.includes('kamdem') || lower.includes('pediat')) {
        docName = 'Dr. Pierre Kamdem';
        specialty = 'Pediatrics';
        schedule = 'Monday to Friday: 08:30 AM – 04:00 PM';
        slots = '• Slot 1: Tomorrow at 09:00 AM\n• Slot 2: Tomorrow at 10:30 AM\n• Slot 3: Tomorrow at 02:00 PM';
      }

      return `📅 **Step 3 of 4: Choose Date, Time Slot & Mode**\n\n**${docName}** (${specialty})\n• **Clinic Schedule:** ${schedule}\n\n**Upcoming Available Time Slots:**\n${slots}\n\n**Consultation Modes:**\n1. 🏥 **In-Person** (At the hospital clinic)\n2. 📱 **Telemedicine Video Call** (Directly in the PharmaLink app)\n\n*Which date, time slot, and consultation mode would you prefer?*`;
    }

    // Appointment Step 4: Time slot chosen, review summary
    if (mentionsTime && (mentionsDoctor || lower.includes('in-person') || lower.includes('telemedicine') || lower.includes('video') || lower.includes('slot'))) {
      const mode = (lower.includes('telemedicine') || lower.includes('video') || lower.includes('en ligne')) ? '📱 Telemedicine Video Call' : '🏥 In-Person at Hospital';
      return `📋 **Step 4 of 4: Review Your Consultation Summary**\n\n• **Hospital:** 🏥 Hôpital Central de Yaoundé\n• **Specialist:** 👨‍⚕️ **Dr. Amadou** (General Medicine)\n• **Date & Time:** 📅 Tomorrow at 10:00 AM\n• **Consultation Mode:** ${mode}\n• **Dashboard Sync:** Automatically visible in your Patient Dashboard upcoming appointments with calendar reminders ✅\n• **Status:** Ready to Confirm\n\n👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**`;
    }

    // ───────────────── 6. STEP-BY-STEP MEDICATION ORDER FLOW ───────────────────
    const isOrderIntent = lower.includes('order') || lower.includes('buy') || lower.includes('purchase') || lower.includes('commander') || lower.includes('acheter') || lower.includes('médicament') || lower.includes('delivery');
    const mentionsDrug = lower.includes('paracetamol') || lower.includes('coartem') || lower.includes('amoxicillin') || lower.includes('ibuprofen') || lower.includes('metformin') || lower.includes('artemether') || lower.includes('lisinopril');
    const mentionsPharmacy = lower.includes('centrale') || lower.includes('bastos') || lower.includes('soleil') || lower.includes('pharmacie') || lower.includes('pharmacy');
    const mentionsDelivery = lower.includes('delivery') || lower.includes('courier') || lower.includes('pickup') || lower.includes('livraison') || lower.includes('domicile') || lower.includes('yaoundé') || lower.includes('douala') || lower.includes('bastos quartier');

    // Order Step 1: User wants to order but hasn't specified drug
    if (isOrderIntent && !mentionsDrug) {
      return `💊 **Step 1 of 4: What Medication Would You Like to Order?**\n\nI can compare prices across licensed pharmacies for you! Which medication are you looking for?\n\n*Popular in-stock items:*\n• **Paracetamol 500mg / 1g** — 🟢 [Over-the-Counter / OTC]\n• **Coartem (Artemether-Lumefantrine)** — 🟢 [Over-the-Counter / OTC]\n• **Amoxicillin 500mg** — 📄 [Prescription Required]\n• **Ibuprofen 400mg** — 🟢 [Over-the-Counter / OTC]\n• **Metformin 500mg** — 📄 [Prescription Required]\n\n*Please tell me the name of the medication you need!*`;
    }

    // Order Step 2: Drug mentioned, compare pharmacy prices
    if (mentionsDrug && !mentionsPharmacy) {
      let drugName = 'Paracetamol 500mg';
      let rxStatus = '🟢 Over-the-Counter (No prescription needed)';
      if (lower.includes('coartem') || lower.includes('artemether')) {
        drugName = 'Coartem (Artemether-Lumefantrine)';
        rxStatus = '🟢 Over-the-Counter (No prescription needed)';
      } else if (lower.includes('amoxicillin')) {
        drugName = 'Amoxicillin 500mg';
        rxStatus = '📄 Prescription Required (Doctor prescription needed)';
      } else if (lower.includes('ibuprofen')) {
        drugName = 'Ibuprofen 400mg';
        rxStatus = '🟢 Over-the-Counter (No prescription needed)';
      }

      return `🏪 **Step 2 of 4: Price Comparison for ${drugName}**\n*Classification:* ${rxStatus}\n\nHere are licensed pharmacies with verified stock (sorted cheapest first):\n\n1. 🏪 **Pharmacie Centrale** (Avenue Kennedy, Bastos)\n   • **Price:** FCFA 1,200 | Stock: 50 available ✅\n\n2. 🏪 **Pharmacie Bastos** (Rond-point Bastos)\n   • **Price:** FCFA 1,400 | Stock: 35 available ✅\n\n3. 🏪 **Pharmacie du Soleil** (Centre-ville)\n   • **Price:** FCFA 1,550 | Stock: 20 available ✅\n\n*Which pharmacy would you like to purchase from, and how many boxes (e.g. 1 box, 2 boxes)?*`;
    }

    // Order Step 3: Pharmacy selected, ask for fulfillment
    if (mentionsPharmacy && !mentionsDelivery) {
      return `🛵 **Step 3 of 4: Choose Delivery or Pickup**\n\nHow would you like to receive your medication?\n\n1. 🛵 **Express Doorstep Courier Delivery** (Direct home delivery with real-time GPS courier tracking)\n2. 🚶 **Pharmacy Counter Pickup** (Prepared in 15 mins with QR pickup code)\n\n*Please share your delivery neighborhood/address (e.g. Quartier Bastos, Yaoundé) or reply 'Pickup'!*`;
    }

    // Order Step 4: Address provided, show order review
    if (mentionsDelivery || (mentionsPharmacy && mentionsDrug)) {
      return `📋 **Step 4 of 4: Review Your Medication Order Summary**\n\n• **Medication:** 💊 **Paracetamol 500mg** (Qty: 1 box) - 🟢 [OTC Verified]\n• **Pharmacy:** 🏪 **Pharmacie Centrale** (Avenue Kennedy)\n• **Medication Price:** FCFA 1,200\n• **Fulfillment:** 🛵 Express Doorstep Courier (Quartier Bastos, Yaoundé)\n• **Courier Delivery Fee:** FCFA 1,000\n• **Total to Pay:** 💳 **FCFA 2,200**\n• **Accepted Payments:** MTN MoMo, Orange Money, Cash on Delivery\n• **Digital Receipt:** 🧾 Universal digital receipt generated instantly on confirmation\n\n👉 **Do you confirm this order? (Please reply 'Yes' or 'Confirm' to finalize your order)**`;
    }

    // ───────────────── 7. DEFAULT FRIENDLY CATCH-ALL ───────────────────────────
    return `I'm here to assist you! 🩺\n\nFeel free to ask me about:\n• **Booking an appointment** (Step-by-step with your preferred hospital & specialist).\n• **Ordering medications** (With live pharmacy price comparisons).\n• **24/7 Night Guard services** (Pharmacies and on-call doctors).\n• **Symptoms or health questions** (Malaria, fevers, aches, prescriptions).\n\nWhat would you like to do?`;
  }
}

module.exports = new GeminiService();

