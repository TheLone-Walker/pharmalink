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
        take: 30,
      });

      const doctorsList = doctors.length > 0
        ? doctors.map(d => {
            const p = d.doctorProfile || {};
            return `• Dr. ${d.name.replace(/^Dr\.\s*/i, '')} (ID: ${d.id}) | Specialty: ${p.specialty || 'General Medicine'} | Hospital: ${p.hospital || 'Hôpital Central de Yaoundé'} | Status: Verified ONMC | On-Call / Emergency: ${p.isOnCall ? 'YES 🌙 (24/7 Night Guard)' : 'Regular Clinic'}`;
          }).join('\n')
        : '• Dr. Amadou | Specialty: General Medicine | Hospital: Hôpital Central de Yaoundé';

      const medications = await prisma.medication.findMany({
        include: { pharmacy: true },
        take: 60,
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
   * Helper to accurately parse date and time from user message & history.
   * Never picks a random time.
   */
  parseAppointmentDateTime(text, historyText = '') {
    const combined = (text + ' ' + historyText).toLowerCase();
    
    // Look for hours and time slots
    // Match: "09:00 AM", "9:30", "14:00", "2:30 pm", "10h", "10h30", "11:00 am", "08:30", "slot 1", "slot 2", "slot 3"
    const timeMatch = combined.match(/\b([01]?\d|2[0-3])(?::|\.|\s*h\s*)([0-5]\d)?\s*(am|pm)?\b/i) ||
                      combined.match(/\b([1-9]|1[0-2])\s*(am|pm)\b/i);

    let hour = null;
    let minute = 0;

    if (timeMatch) {
      if (timeMatch[3] !== undefined || timeMatch[2] === 'am' || timeMatch[2] === 'pm') {
        let rawHour = parseInt(timeMatch[1], 10);
        const ampm = (timeMatch[3] || timeMatch[2] || '').toLowerCase();
        if (timeMatch[2] && !isNaN(parseInt(timeMatch[2], 10))) {
          minute = parseInt(timeMatch[2], 10);
        }
        if (ampm === 'pm' && rawHour < 12) rawHour += 12;
        if (ampm === 'am' && rawHour === 12) rawHour = 0;
        hour = rawHour;
      } else {
        hour = parseInt(timeMatch[1], 10);
        if (timeMatch[2] && !isNaN(parseInt(timeMatch[2], 10))) {
          minute = parseInt(timeMatch[2], 10);
        }
      }
    } else if (combined.includes('slot 1') || combined.includes('morning') || combined.includes('matin')) {
      hour = 9;
      minute = 0;
    } else if (combined.includes('slot 2') || combined.includes('midday') || combined.includes('midi')) {
      hour = 11;
      minute = 30;
    } else if (combined.includes('slot 3') || combined.includes('afternoon') || combined.includes('après-midi') || combined.includes('apres midi')) {
      hour = 14;
      minute = 30;
    }

    const now = new Date();
    const targetDate = new Date();

    if (combined.includes('tomorrow') || combined.includes('demain')) {
      targetDate.setDate(now.getDate() + 1);
    } else if (combined.includes('today') || combined.includes("aujourd'hui") || combined.includes('aujourdhui')) {
      // today
    } else {
      const daysOfWeek = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      const frenchDays = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
      
      let foundDayIdx = -1;
      for (let i = 0; i < 7; i++) {
        if (combined.includes(daysOfWeek[i]) || combined.includes(frenchDays[i])) {
          foundDayIdx = i;
          break;
        }
      }

      if (foundDayIdx !== -1) {
        const currentDayIdx = now.getDay();
        let diff = foundDayIdx - currentDayIdx;
        if (diff <= 0) diff += 7;
        targetDate.setDate(now.getDate() + diff);
      } else {
        targetDate.setDate(now.getDate() + 1);
      }
    }

    if (hour !== null) {
      targetDate.setHours(hour, minute, 0, 0);
      return {
        date: targetDate,
        hasExplicitTime: true,
        formatted: targetDate.toLocaleDateString('en-US', {
          weekday: 'short',
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        })
      };
    }

    // Default to tomorrow 09:00 AM only if date was resolved
    targetDate.setHours(9, 0, 0, 0);
    return {
      date: targetDate,
      hasExplicitTime: false,
      formatted: targetDate.toLocaleDateString('en-US', {
        weekday: 'short',
        month: 'short',
        day: 'numeric'
      })
    };
  }

  /**
   * Helper to accurately match doctor and hospital chosen by user.
   */
  resolveDoctor(userMessage, recentHistoryText, doctors = []) {
    const combined = (userMessage + ' ' + recentHistoryText).toLowerCase();

    // 1. Exact or partial Doctor Name matching
    for (const doc of doctors) {
      const cleanName = doc.name.toLowerCase().replace(/^dr\.\s*/i, '').trim();
      const nameParts = cleanName.split(/\s+/);
      
      if (combined.includes(cleanName)) {
        return doc;
      }
      for (const part of nameParts) {
        if (part.length >= 4 && combined.includes(part)) {
          return doc;
        }
      }
    }

    // 2. Specialty matching
    for (const doc of doctors) {
      const specialty = (doc.doctorProfile?.specialty || '').toLowerCase();
      if (specialty && specialty.length >= 4 && combined.includes(specialty)) {
        return doc;
      }
      if (combined.includes('cardio') && specialty.includes('cardio')) return doc;
      if (combined.includes('pediat') && specialty.includes('pediat')) return doc;
      if (combined.includes('derma') && specialty.includes('derma')) return doc;
      if (combined.includes('gynec') && specialty.includes('gynec')) return doc;
    }

    // 3. Hospital matching
    for (const doc of doctors) {
      const hospital = (doc.doctorProfile?.hospital || '').toLowerCase();
      if (hospital) {
        if (combined.includes('laquintinie') && hospital.includes('laquintinie')) return doc;
        if (combined.includes('chu') && hospital.includes('chu')) return doc;
        if (combined.includes('bastos') && hospital.includes('bastos')) return doc;
        if ((combined.includes('général') || combined.includes('general')) && hospital.includes('général')) return doc;
        if (combined.includes('central') && hospital.includes('central')) return doc;
      }
    }

    return doctors.length > 0 ? doctors[0] : null;
  }

  /**
   * Helper to accurately match medication and target pharmacy chosen by user.
   */
  resolveMedicationAndPharmacy(userMessage, recentHistoryText, medications = []) {
    const combined = (userMessage + ' ' + recentHistoryText).toLowerCase();

    // Identify target pharmacy
    let targetPharmacyKeywords = [];
    if (combined.includes('bastos')) targetPharmacyKeywords.push('bastos');
    if (combined.includes('centrale')) targetPharmacyKeywords.push('centrale');
    if (combined.includes('soleil')) targetPharmacyKeywords.push('soleil');
    if (combined.includes('gare')) targetPharmacyKeywords.push('gare');

    // Identify target drug
    let targetDrugKeywords = [];
    if (combined.includes('paracetamol')) targetDrugKeywords.push('paracetamol');
    if (combined.includes('coartem') || combined.includes('artemether')) targetDrugKeywords.push('coartem');
    if (combined.includes('amoxicillin')) targetDrugKeywords.push('amoxicillin');
    if (combined.includes('augmentin')) targetDrugKeywords.push('augmentin');
    if (combined.includes('ibuprofen')) targetDrugKeywords.push('ibuprofen');
    if (combined.includes('metformin')) targetDrugKeywords.push('metformin');
    if (combined.includes('lisinopril')) targetDrugKeywords.push('lisinopril');

    let candidates = medications;

    // Filter by pharmacy first
    if (targetPharmacyKeywords.length > 0) {
      const filteredByPharm = candidates.filter(m => {
        const phName = (m.pharmacy?.pharmacyName || '').toLowerCase();
        return targetPharmacyKeywords.some(kw => phName.includes(kw));
      });
      if (filteredByPharm.length > 0) {
        candidates = filteredByPharm;
      }
    }

    // Filter by drug name
    if (targetDrugKeywords.length > 0) {
      const filteredByDrug = candidates.filter(m => {
        const medName = m.name.toLowerCase();
        return targetDrugKeywords.some(kw => medName.includes(kw));
      });
      if (filteredByDrug.length > 0) {
        candidates = filteredByDrug;
      }
    }

    // Extract quantity
    const qtyMatch = combined.match(/\b(?:qty|quantity|x|boxes|packs|boîtes)?\s*([1-9]|10)\s*(?:boxes|packs|boîtes|units|x)?\b/i);
    let quantity = 1;
    if (qtyMatch && parseInt(qtyMatch[1], 10) > 0) {
      quantity = parseInt(qtyMatch[1], 10);
    }

    // Extract address
    let address = 'Quartier Bastos, Yaoundé';
    if (combined.includes('bastos')) address = 'Quartier Bastos, Yaoundé';
    else if (combined.includes('biyem')) address = 'Biyem-Assi, Yaoundé';
    else if (combined.includes('mendong')) address = 'Mendong, Yaoundé';
    else if (combined.includes('omnisp')) address = 'Omnisport, Yaoundé';
    else if (combined.includes('douala') || combined.includes('bonanjo')) address = 'Bonanjo, Douala';
    else if (combined.includes('akwa')) address = 'Akwa, Douala';

    const targetMed = candidates.length > 0 ? candidates[0] : (medications.length > 0 ? medications[0] : null);

    return { targetMed, quantity, address };
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
      ? history.slice(-6).map(h => (h.text || h.content || '').toLowerCase()).join(' ')
      : '';

    // ─── ACTION 1: EXPLICIT APPOINTMENT CONFIRMATION ────────────────────────────
    const hasPendingAppointmentReview = recentHistoryText.includes('hospital') ||
      recentHistoryText.includes('specialist') ||
      recentHistoryText.includes('confirm this appointment') ||
      recentHistoryText.includes('step 4: review your consultation summary') ||
      recentHistoryText.includes('step 4: review your appointment') ||
      recentHistoryText.includes('rendez-vous');

    if ((isExplicitConfirmation && hasPendingAppointmentReview && userId) ||
        (lower.includes('confirm') && lower.includes('doctor') && userId)) {
      
      const targetDoctor = this.resolveDoctor(userMessage, recentHistoryText, systemData.doctors);

      if (targetDoctor) {
        const timeResult = this.parseAppointmentDateTime(userMessage, recentHistoryText);
        const appointmentDate = timeResult.date;

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
              notes: `Booked via PharmaLink AI Assistant consultation assistant for ${targetDoctor.name} at ${hospitalName}.`,
              hospital: hospitalName,
              status: 'confirmed',
            },
          });

          await notificationService.send(
            targetDoctor.id,
            'New Appointment Confirmed 📅',
            `Confirmed appointment with ${currentUser.name || 'Patient'} on ${timeResult.formatted} at ${hospitalName}.`,
            'appointment'
          ).catch(() => {});

          const docName = `Dr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}`;

          return {
            reply: `🎉 **Appointment Successfully Confirmed & Booked!**\n\nHere are your final consultation details:\n• **Hospital / Facility:** 🏥 **${hospitalName}**\n• **Specialist:** 👨‍⚕️ **${docName}** (${targetDoctor.doctorProfile?.specialty || 'General Medicine'})\n• **Date & Time:** 📅 **${timeResult.formatted}**\n• **Consultation Mode:** ${type === 'telemedicine' ? '📱 Telemedicine Video Call' : '🏥 In-Person at Hospital'}\n• **Dashboard Sync:** Added to your Patient Dashboard upcoming appointments section with automated reminders ✅\n• **Status:** Confirmed ✅\n\n${docName}'s department at ${hospitalName} has received your booking. You can view your full appointment anytime in your Patient Dashboard.`,
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
      
      const { targetMed, quantity, address } = this.resolveMedicationAndPharmacy(userMessage, recentHistoryText, systemData.medications);

      if (targetMed) {
        // ─── STRICT PRESCRIPTION COMPLIANCE CHECK ───
        if (targetMed.requiresPrescription) {
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
              reply: `⚠️ **Prescription Required for ${targetMed.name}**\n\nUnder Cameroon pharmaceutical regulations, **${targetMed.name}** is a regulated prescription drug and **cannot be dispensed without an approved doctor's prescription**.\n\n🛡️ **How to get this medication:**\n1. Book a quick consultation with one of our certified doctors (e.g. Dr. Amadou, Dr. Marie Ngo) to receive a verified digital prescription.\n2. Or upload your physical prescription in the **My Prescriptions** section for pharmacist validation.\n3. Or choose from our wide range of **Over-The-Counter (OTC)** alternatives.\n\n*Would you like me to connect you with a doctor right now to get evaluated?*`,
              action: {
                type: 'appointment',
                title: 'Book Doctor Consultation for Prescription',
              },
            };
          }
        }

        const totalFcfa = parseFloat(targetMed.priceFcfa) * quantity;
        const pharmacyId = targetMed.pharmacyId;
        const isPickup = (lower + ' ' + recentHistoryText).includes('pickup') || (lower + ' ' + recentHistoryText).includes('retrait');
        const orderType = isPickup ? 'pickup' : 'delivery';

        try {
          const order = await prisma.order.create({
            data: {
              patientId: userId,
              pharmacyId,
              orderType,
              totalFcfa,
              deliveryAddress: isPickup ? 'Pharmacy Counter Pickup' : address,
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
            reply: `🎉 **Medication Order Confirmed & Placed!**\n\nYour order has been registered at **${pharmName}**:\n• **Medication:** 💊 **${targetMed.name}** x${quantity} ${targetMed.requiresPrescription ? '(Prescription Verified 📄)' : '(OTC 🟢)'}\n• **Total Amount:** **FCFA ${totalFcfa.toLocaleString()}**\n• **Pharmacy:** 🏪 **${pharmName}**\n• **Fulfillment:** ${isPickup ? '🚶 Pharmacy Counter Pickup' : `🛵 Express Doorstep Courier Delivery (${address})`}\n• **Digital Receipt:** 🧾 Universal digital receipt generated for all payment methods\n• **Status:** Pending Payment / Packaging\n\nTap below to complete payment with **MTN MoMo**, **Orange Money**, **Card**, or **Cash on Delivery** and download your official receipt.`,
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
AVAILABLE CERTIFIED DOCTORS, SPECIALTIES & HOSPITALS:
${systemData.doctorsText}

PARTNER HOSPITALS LIST:
1. 🏥 Hôpital Central de Yaoundé (Dr. Amadou - General Medicine, Dr. Joseph Ebanda - Gynecology & Obstetrics)
2. 🏥 Centre Hospitalier Universitaire (CHU) Yaoundé (Dr. Marie Ngo - Cardiology)
3. 🏥 Clinique Bastos (Yaoundé) (Dr. Marie Ngo - Cardiology)
4. 🏥 Hôpital Général de Yaoundé (Dr. Pierre Kamdem - Pediatrics)
5. 🏥 Hôpital Laquintinie de Douala (Dr. Estelle Fotso - Dermatology)

NIGHT GUARD & 24/7 EMERGENCY SERVICES:
• Pharmacies de Garde (24/7): Pharmacie Bastos (Open 24/7), Pharmacie de la Gare (Open 24/7)
• Emergency On-Call Doctors: Dr. Amadou (Urgent Care), Dr. Joseph Ebanda (Obstetrics Emergency)
• National Emergency Hotlines: SAMU 119, SAMU 15 (Free toll-free medical response in Cameroon)

REAL-TIME PHARMACY DRUG INVENTORY, PRICES & PRESCRIPTION REGULATION:
${systemData.medicationsText}
========================================

CRITICAL DOCTOR, HOSPITAL & TIME ACCURACY RULES:
1. NEVER book with a different doctor or hospital than the one the patient asked for! If the patient asked for Dr. Pierre Kamdem at Hôpital Général, keep Dr. Pierre Kamdem and Hôpital Général.
2. NEVER choose a random appointment date or time. You MUST ask the user which date and time slot they want (e.g. Tomorrow at 09:00 AM, Tomorrow at 02:30 PM, or Friday at 11:30 AM). If they haven't chosen a time, prompt them to pick a time slot first!
3. When summarizing the appointment in Step 4, display the EXACT doctor, hospital, and requested date/time slot.

CRITICAL PHARMACY & MEDICATION ACCURACY RULES:
1. When ordering drugs, keep the EXACT medication and the EXACT pharmacy selected by the user (e.g. Pharmacie Bastos vs Pharmacie Centrale).
2. Medications marked with 📄 [PRESCRIPTION REQUIRED] CANNOT be dispensed without a valid doctor's prescription. Explain this politely if requested.
3. Universal digital receipts are provided for ALL payment methods (MTN MoMo, Orange Money, Card, and Cash).

APPOINTMENT WORKFLOW PROTOCOL:
• STEP 1 (Hospital): Ask which hospital they prefer if not yet known.
• STEP 2 (Doctor & Specialty): Present specialists at that specific hospital.
• STEP 3 (Date & Time Selection): Ask what specific date and time slot they prefer (e.g. Tomorrow 09:00 AM, 11:30 AM, 02:30 PM, In-person vs Telemedicine).
• STEP 4 (Review & Confirmation): Summarize exact Hospital, exact Doctor, exact Date & Time, Mode, and ask:
  "👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**"

MEDICATION ORDER WORKFLOW PROTOCOL:
• STEP 1 (Drug): Ask which medication they need.
• STEP 2 (Pharmacy Comparison & Rx Flag): Compare licensed pharmacies stocking it with prices.
• STEP 3 (Fulfillment & Address): Ask for delivery address or pickup.
• STEP 4 (Review & Confirmation): Summarize exact Drug, exact Pharmacy, exact Price, Address, and ask:
  "👉 **Do you confirm this order? (Please reply 'Yes' or 'Confirm' to place your order)**"

BE EMPATHETIC, ACCURATE, NATURAL, AND METICULOUS AT ALL TIMES.`;

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
    const recentHistoryText = Array.isArray(history)
      ? history.slice(-6).map(h => (h.text || h.content || '').toLowerCase()).join(' ')
      : '';
    const combinedContext = (lower + ' ' + recentHistoryText);

    // ───────────────── 1. GREETINGS & CASUAL CONVERSATION (HIGHEST PRIORITY) ─────
    const isGreeting = /^(hi|hello|hey|salut|bonjour|bonsoir|good morning|good afternoon|good evening|yo|coucou|hola)\b/i.test(lower) ||
      lower === 'hi' || lower === 'hello' || lower === 'bonjour' || lower === 'salut' || lower === 'hey' ||
      lower === 'how are you' || lower === 'how are you doing' || lower === 'ça va' || lower === 'ca va' || lower === 'comment tu vas';

    if (isGreeting) {
      return `Hello there! 👋 How are you feeling today?\n\nI'm your **PharmaLink Clinical & Healthcare Assistant** 🩺. I'm here to assist you naturally with:\n\n• 👨‍⚕️ **Booking an appointment** with certified doctors at your preferred hospital and exact time slot.\n• 💊 **Ordering medications** with real-time pharmacy price comparisons (OTC & prescription).\n• 🌙 **24/7 Night Guard services** (pharmacies de garde & on-call emergency doctors).\n• 🧾 **Universal Digital Receipts** for all payments.\n• 🩺 **Clinical advice & symptom evaluation** for malaria, fevers, aches, and general health.\n\nWhat can I help you with today?`;
    }

    // Casual "how does it work" / "who are you"
    if (lower.includes('who are you') || lower.includes('what can you do') || lower.includes('qui es tu') || lower.includes('que peux tu faire') || lower.includes('help me') || lower === 'help') {
      return `I'm **PharmaLink's AI Health Agent** 🩺, designed specifically for healthcare patients in Cameroon!\n\nHere is how I can make healthcare simple for you:\n1. 🏥 **Find & Book Doctors:** Pick a hospital (Hôpital Central, CHU, Bastos, etc.) and specialist for In-Person or Telemedicine video calls at your preferred time.\n2. 💊 **Compare & Order Drugs:** Compare real-time pharmacy prices and get express courier delivery to your doorstep.\n3. 🌙 **Night Emergency Support:** Access on-call doctors and 24/7 guard pharmacies anytime.\n4. 🧾 **Payment Receipts:** Every order (MTN MoMo, Orange Money, Cash) gets an official digital receipt in your dashboard.\n\nFeel free to ask me any question or tell me what you'd like to do!`;
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
    if (lower.includes('malaria') || lower.includes('palu') || lower.includes('paludisme') || lower.includes('coartem') || lower.includes('artemether') || lower.includes('fever and chills')) {
      return `🦟 **Malaria (Paludisme) Guidance & Treatment**\n\n**Common Symptoms:** High fever, chills, sweating, headaches, fatigue, muscle aches, nausea.\n\n💊 **Standard Recommended Treatment (Cameroon National Protocol):**\n• **First-Line Therapy:** Artemisinin-based Combination Therapy (ACT) such as **Coartem (Artemether-Lumefantrine 20/120mg)**.\n• **Dosage:** 1 course taken with food/milk over 3 days exactly as prescribed.\n• **Fever Management:** **Paracetamol 500mg - 1g** every 6-8 hours (max 4g/day) to bring down high body temperature.\n\n⚠️ **Important Medical Advice:**\n• It is strongly advised to perform a **Malaria Rapid Diagnostic Test (RDT)** or blood smear at a lab or hospital to confirm before taking antimalarials.\n• If symptoms persist after 48 hours or if there is vomiting, consult a doctor immediately.\n\n*Would you like me to compare pharmacy prices for Coartem, or book a consultation with a doctor?*`;
    }

    if (lower.includes('headache') || lower.includes('mal de tete') || lower.includes('mal de tête') || lower.includes('fever') || lower.includes('fièvre') || lower.includes('pain') || lower.includes('douleur') || lower.includes('paracetamol')) {
      return `💊 **Headache, Fever & Pain Guidance**\n\n**First-Line Relief (Over-The-Counter):**\n• **Paracetamol (Acetaminophen) 500mg to 1000mg:**\n  - Adults: 1 to 2 tablets (500mg-1g) every 6 to 8 hours as needed (Maximum 4,000mg / 4g in 24 hours).\n  - Children: Weight-based dosing (10-15 mg/kg per dose).\n• **Hydration & Rest:** Drink plenty of water and rest in a cool, quiet room.\n\n⚠️ **When to Seek Immediate Medical Attention:**\n• Sudden, very severe "thunderclap" headache.\n• High fever accompanied by stiff neck, confusion, or rash.\n• Fever lasting more than 3 consecutive days.\n\n*Would you like to order Paracetamol from a nearby pharmacy or consult a doctor?*`;
    }

    if (lower.includes('antibiotic') || lower.includes('antibiotique') || lower.includes('amoxicillin') || lower.includes('augmentin') || lower.includes('cipro') || lower.includes('prescription')) {
      return `📄 **Prescription Drug Guidelines & Antibiotics Policy**\n\nUnder Cameroon pharmaceutical regulations and WHO clinical safety standards:\n\n• **Prescription Required (📄):** Antibiotics (e.g. *Amoxicillin, Augmentin, Ciprofloxacin*), strong analgesics, hypertension and diabetes medications require a valid doctor's prescription.\n• **Why it's important:** Prevents antibiotic resistance, adverse drug interactions, and ensures you receive the correct diagnosis and therapeutic course.\n• **Over-The-Counter (🟢):** Pain relievers (Paracetamol, Ibuprofen), ACT Antimalarials (Coartem), antacids, and vitamins can be ordered without a prescription.\n\n*Need a prescription? I can help you schedule a quick In-Person or Telemedicine consultation with a certified doctor right now!*`;
    }

    // ───────────────── 5. STEP-BY-STEP APPOINTMENT FLOW ─────────────────────────
    const isAppointmentIntent = lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('consultation') || lower.includes('book doctor') || lower.includes('see doctor') || lower.includes('doctor');
    const mentionsHospital = combinedContext.includes('central') || combinedContext.includes('chu') || combinedContext.includes('général') || combinedContext.includes('general') || combinedContext.includes('bastos') || combinedContext.includes('laquintinie') || combinedContext.includes('jamot') || combinedContext.includes('hopital') || combinedContext.includes('hôpital');
    const mentionsDoctor = combinedContext.includes('amadou') || combinedContext.includes('ngo') || combinedContext.includes('kamdem') || combinedContext.includes('fotso') || combinedContext.includes('ebanda') || combinedContext.includes('cardio') || combinedContext.includes('pediat') || combinedContext.includes('derma') || combinedContext.includes('gynec');
    const timeParsed = this.parseAppointmentDateTime(lower, recentHistoryText);
    const mentionsTime = timeParsed.hasExplicitTime || lower.includes('tomorrow') || lower.includes('demain') || lower.includes('slot') || lower.includes('morning') || lower.includes('afternoon') || lower.includes('am') || lower.includes('pm') || lower.includes('09') || lower.includes('10') || lower.includes('11') || lower.includes('14') || lower.includes('15') || lower.includes('telemedicine') || lower.includes('video') || lower.includes('in-person');

    // Appointment Step 1: User indicates appointment intent without specific hospital/doctor
    if (isAppointmentIntent && !mentionsHospital && !mentionsDoctor) {
      return `🏥 **Step 1 of 4: Choose Your Preferred Hospital / Clinic**\n\nI'd be glad to help you schedule a consultation! Which medical facility would you prefer?\n\n1. 🏥 **Hôpital Central de Yaoundé** (General Medicine, Urgent Care, OB/GYN)\n2. 🏥 **Centre Hospitalier Universitaire (CHU) Yaoundé** (Cardiology & Specialists)\n3. 🏥 **Clinique Bastos (Yaoundé)** (Cardiology & Private Practice)\n4. 🏥 **Hôpital Général de Yaoundé** (Pediatrics & Multidisciplinary)\n5. 🏥 **Hôpital Laquintinie de Douala** (Dermatology & Emergency)\n\n*Please reply with your preferred hospital name or number to see available specialists.*`;
    }

    // Appointment Step 2: Hospital chosen, list doctors
    if ((mentionsHospital && !mentionsDoctor) || (isAppointmentIntent && mentionsHospital && !mentionsDoctor)) {
      let hospitalName = 'Hôpital Central de Yaoundé';
      let doctorsAtHospital = '• **Dr. Amadou** — *General Medicine & Urgent Care (24/7 On-Call)*\n• **Dr. Joseph Ebanda** — *Gynecology & Obstetrics*';

      if (combinedContext.includes('chu')) {
        hospitalName = 'CHU Yaoundé';
        doctorsAtHospital = '• **Dr. Marie Ngo** — *Cardiology & Cardiovascular Health*';
      } else if (combinedContext.includes('bastos')) {
        hospitalName = 'Clinique Bastos';
        doctorsAtHospital = '• **Dr. Marie Ngo** — *Cardiology & Cardiovascular Health*';
      } else if (combinedContext.includes('général') || combinedContext.includes('general')) {
        hospitalName = 'Hôpital Général de Yaoundé';
        doctorsAtHospital = '• **Dr. Pierre Kamdem** — *Pediatrics & Child Health*';
      } else if (combinedContext.includes('laquintinie')) {
        hospitalName = 'Hôpital Laquintinie de Douala';
        doctorsAtHospital = '• **Dr. Estelle Fotso** — *Dermatology & Skin Health*';
      }

      return `👨‍⚕️ **Step 2 of 4: Select a Specialist at ${hospitalName}**\n\nHere are the available certified specialists at this facility:\n\n${doctorsAtHospital}\n\n*Which doctor or specialty would you like to consult with?*`;
    }

    // Appointment Step 3: Doctor chosen, ask for exact date and time slot
    if (mentionsDoctor && !mentionsTime) {
      const targetDoctor = this.resolveDoctor(lower, recentHistoryText, systemData.doctors);
      const docName = targetDoctor ? `Dr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}` : 'Dr. Amadou';
      const specialty = targetDoctor?.doctorProfile?.specialty || 'General Medicine';
      const hospitalName = targetDoctor?.doctorProfile?.hospital || 'Partner Hospital';

      return `📅 **Step 3 of 4: Choose Your Date, Time Slot & Mode**\n\n**${docName}** (${specialty} at ${hospitalName})\n\n**Available Time Slots for Tomorrow & This Week:**\n• **Slot 1:** 09:00 AM\n• **Slot 2:** 11:30 AM\n• **Slot 3:** 02:30 PM\n• *Or tell me any specific date and time that works best for you!*\n\n**Consultation Modes:**\n1. 🏥 **In-Person** (At ${hospitalName})\n2. 📱 **Telemedicine Video Call** (In PharmaLink app)\n\n*What date, specific time slot (e.g. Tomorrow at 09:00 AM, Friday at 02:30 PM), and consultation mode would you prefer?*`;
    }

    // Appointment Step 4: Time slot chosen, review summary
    if (mentionsTime && (mentionsDoctor || mentionsHospital || isAppointmentIntent)) {
      const targetDoctor = this.resolveDoctor(lower, recentHistoryText, systemData.doctors);
      const docName = targetDoctor ? `Dr. ${targetDoctor.name.replace(/^Dr\.\s*/i, '')}` : 'Dr. Amadou';
      const specialty = targetDoctor?.doctorProfile?.specialty || 'General Medicine';
      const hospitalName = targetDoctor?.doctorProfile?.hospital || 'Hôpital Central de Yaoundé';
      const mode = (combinedContext.includes('telemedicine') || combinedContext.includes('video') || combinedContext.includes('en ligne')) ? '📱 Telemedicine Video Call' : '🏥 In-Person at Hospital';
      const formattedTime = timeParsed.formatted;

      return `📋 **Step 4 of 4: Review Your Consultation Summary**\n\n• **Hospital / Clinic:** 🏥 **${hospitalName}**\n• **Specialist:** 👨‍⚕️ **${docName}** (${specialty})\n• **Date & Time:** 📅 **${formattedTime}**\n• **Consultation Mode:** ${mode}\n• **Dashboard Sync:** Automatically visible in your Patient Dashboard upcoming appointments with calendar reminders ✅\n• **Status:** Ready to Confirm\n\n👉 **Do you confirm this appointment? (Please reply 'Yes' or 'Confirm' to finalize your booking)**`;
    }

    // ───────────────── 6. STEP-BY-STEP MEDICATION ORDER FLOW ───────────────────
    const isOrderIntent = lower.includes('order') || lower.includes('buy') || lower.includes('purchase') || lower.includes('commander') || lower.includes('acheter') || lower.includes('médicament') || lower.includes('delivery');
    const mentionsDrug = combinedContext.includes('paracetamol') || combinedContext.includes('coartem') || combinedContext.includes('amoxicillin') || combinedContext.includes('augmentin') || combinedContext.includes('ibuprofen') || combinedContext.includes('metformin') || combinedContext.includes('lisinopril');
    const mentionsPharmacy = combinedContext.includes('centrale') || combinedContext.includes('bastos') || combinedContext.includes('soleil') || combinedContext.includes('gare') || combinedContext.includes('pharmacie') || combinedContext.includes('pharmacy');
    const mentionsDelivery = combinedContext.includes('delivery') || combinedContext.includes('courier') || combinedContext.includes('pickup') || combinedContext.includes('livraison') || combinedContext.includes('domicile') || combinedContext.includes('yaoundé') || combinedContext.includes('douala');

    // Order Step 1: User wants to order but hasn't specified drug
    if (isOrderIntent && !mentionsDrug) {
      return `💊 **Step 1 of 4: What Medication Would You Like to Order?**\n\nI can compare prices across licensed pharmacies for you! Which medication are you looking for?\n\n*Popular in-stock items:*\n• **Paracetamol 500mg / 1g** — 🟢 [Over-the-Counter / OTC]\n• **Coartem (Artemether-Lumefantrine)** — 🟢 [Over-the-Counter / OTC]\n• **Amoxicillin 500mg** — 📄 [Prescription Required]\n• **Augmentin 1g** — 📄 [Prescription Required]\n• **Ibuprofen 400mg** — 🟢 [Over-the-Counter / OTC]\n• **Metformin 500mg** — 📄 [Prescription Required]\n\n*Please tell me the name of the medication you need!*`;
    }

    // Order Step 2: Drug mentioned, compare pharmacy prices
    if (mentionsDrug && !mentionsPharmacy) {
      const { targetMed } = this.resolveMedicationAndPharmacy(lower, recentHistoryText, systemData.medications);
      const drugName = targetMed?.name || 'Paracetamol 500mg';
      const rxStatus = targetMed?.requiresPrescription ? '📄 Prescription Required (Doctor prescription needed)' : '🟢 Over-the-Counter (No prescription needed)';

      return `🏪 **Step 2 of 4: Price Comparison for ${drugName}**\n*Classification:* ${rxStatus}\n\nHere are licensed pharmacies with verified stock (sorted cheapest first):\n\n1. 🏪 **Pharmacie Centrale** (Avenue Kennedy, Bastos)\n   • **Price:** FCFA 1,200 | Stock: 45 available ✅\n\n2. 🏪 **Pharmacie Bastos** (Rond-point Bastos - 24/7 Night Guard 🌙)\n   • **Price:** FCFA 1,350 | Stock: 50 available ✅\n\n3. 🏪 **Pharmacie du Soleil** (Centre-ville)\n   • **Price:** FCFA 1,500 | Stock: 55 available ✅\n\n4. 🏪 **Pharmacie de la Gare** (Avenue de la Gare - 24/7 Night Guard 🌙)\n   • **Price:** FCFA 1,650 | Stock: 60 available ✅\n\n*Which pharmacy would you like to purchase from, and how many boxes (e.g. Pharmacie Bastos, 1 box)?*`;
    }

    // Order Step 3: Pharmacy selected, ask for fulfillment
    if (mentionsPharmacy && !mentionsDelivery) {
      return `🛵 **Step 3 of 4: Choose Delivery or Pickup**\n\nHow would you like to receive your medication?\n\n1. 🛵 **Express Doorstep Courier Delivery** (Direct home delivery with real-time GPS courier tracking)\n2. 🚶 **Pharmacy Counter Pickup** (Prepared in 15 mins with QR pickup code)\n\n*Please share your delivery neighborhood/address (e.g. Quartier Bastos, Yaoundé) or reply 'Pickup'!*`;
    }

    // Order Step 4: Address provided, show order review
    if (mentionsDelivery || (mentionsPharmacy && mentionsDrug)) {
      const { targetMed, quantity, address } = this.resolveMedicationAndPharmacy(lower, recentHistoryText, systemData.medications);
      const medName = targetMed?.name || 'Paracetamol 500mg';
      const pharmName = targetMed?.pharmacy?.pharmacyName || 'Pharmacie Centrale';
      const unitPrice = parseFloat(targetMed?.priceFcfa || 1200);
      const totalPrice = unitPrice * quantity;
      const isPickup = combinedContext.includes('pickup') || combinedContext.includes('retrait');

      return `📋 **Step 4 of 4: Review Your Medication Order Summary**\n\n• **Medication:** 💊 **${medName}** (Qty: ${quantity} box) - ${targetMed?.requiresPrescription ? '📄 [Rx Required]' : '🟢 [OTC Verified]'}\n• **Pharmacy:** 🏪 **${pharmName}**\n• **Medication Price:** FCFA ${totalPrice.toLocaleString()}\n• **Fulfillment:** ${isPickup ? '🚶 Pharmacy Counter Pickup' : `🛵 Express Doorstep Courier (${address})`}\n• **Total to Pay:** 💳 **FCFA ${totalPrice.toLocaleString()}**\n• **Accepted Payments:** MTN MoMo, Orange Money, Credit Card, Cash on Delivery\n• **Digital Receipt:** 🧾 Universal digital receipt generated instantly on confirmation\n\n👉 **Do you confirm this order? (Please reply 'Yes' or 'Confirm' to finalize your order)**`;
    }

    // ───────────────── 7. DEFAULT FRIENDLY CATCH-ALL ───────────────────────────
    return `I'm here to assist you! 🩺\n\nFeel free to ask me about:\n• **Booking an appointment** (With your chosen hospital, doctor, and exact time slot).\n• **Ordering medications** (With live pharmacy price comparisons).\n• **24/7 Night Guard services** (Pharmacies and on-call doctors).\n• **Symptoms or health questions** (Malaria, fevers, aches, prescriptions).\n\nWhat would you like to do?`;
  }
}

module.exports = new GeminiService();


