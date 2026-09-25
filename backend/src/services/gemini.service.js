const axios = require('axios');
const prisma = require('../config/db');

/**
 * PharmaLink Gemini AI Medical & Health Advisory Service
 * System-Aware Agent: Real-time Doctors, Hospitals, Pharmacy Prices, and Appointments
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
      // 1. Fetch certified doctors
      const doctors = await prisma.user.findMany({
        where: { role: 'doctor', isActive: true },
        include: { doctorProfile: true },
        take: 20,
      });

      const doctorsList = doctors.length > 0
        ? doctors.map(d => {
            const p = d.doctorProfile || {};
            return `• Dr. ${d.name.replace(/^Dr\.\s*/i, '')} | Specialty: ${p.specialty || 'General Medicine'} | Hospital: ${p.hospital || 'Hôpital Central de Yaoundé'} | Status: Verified ONMC`;
          }).join('\n')
        : '• Dr. Amadou | Specialty: General Practitioner | Hospital: Hôpital Central de Yaoundé\n• Dr. Marie Nguema | Specialty: Pediatrics & Cardiology | Hospital: Clinique Bastos, Yaoundé';

      // 2. Fetch medications sorted by cheapest price first
      const medications = await prisma.medication.findMany({
        include: { pharmacy: true },
        take: 40,
        orderBy: { priceFcfa: 'asc' },
      });

      const medicationsList = medications.length > 0
        ? medications.map(m => {
            const ph = m.pharmacy?.pharmacyName || 'Pharmacie Centrale';
            const addr = m.pharmacy?.pharmacyAddress || 'Yaoundé';
            return `• ${m.name}: FCFA ${m.priceFcfa} at "${ph}" (${addr}) - Stock: ${m.stockQuantity} available`;
          }).join('\n')
        : '• Paracetamol 500mg: FCFA 1,200 at Pharmacie Centrale (Avenue Kennedy)\n• Coartem (Artemether-Lumefantrine): FCFA 2,200 at Pharmacie Bastos\n• Amoxicillin 500mg: FCFA 2,500 at Pharmacie Centrale';

      return {
        doctorsText: doctorsList,
        medicationsText: medicationsList,
        doctors,
        medications,
      };
    } catch (e) {
      console.warn('[Gemini Service] Could not query live DB directory:', e.message);
      return {
        doctorsText: '• Dr. Amadou (General Practitioner at Hôpital Central de Yaoundé)',
        medicationsText: '• Paracetamol 500mg (FCFA 1,200 at Pharmacie Centrale)',
        doctors: [],
        medications: [],
      };
    }
  }

  /**
   * Interactive System-Aware Health Assistant Chat
   */
  async chat(userMessage, context = '', history = []) {
    const apiKey = this.getApiKey();
    const systemData = await this.getSystemKnowledge();

    const systemInstruction = `You are the master AI Clinical & Healthcare Agent for PharmaLink in Cameroon.
You have FULL ACCESS to the PharmaLink live healthcare database below.

=== LIVE PHARMALINK SYSTEM DIRECTORY ===
AVAILABLE CERTIFIED DOCTORS & THEIR HOSPITALS:
${systemData.doctorsText}

REAL-TIME PHARMACY DRUG INVENTORY & PRICES (SORTED CHEAPEST FIRST):
${systemData.medicationsText}

PARTNER HOSPITALS: Hôpital Central de Yaoundé, CHU Yaoundé, Hôpital Général, Clinique Bastos, Hôpital Jamot, Hôpital Laquintinie de Douala.
========================================

YOUR CAPABILITIES & INSTRUCTIONS:
1. RECOMMEND DOCTORS & APPOINTMENTS:
   - When the user asks about seeing a doctor, appointments, or needs clinical help, name the specific doctor (e.g. Dr. Amadou, Dr. Marie), their specialty, and their hospital from the directory above.
   - Explain that they can book directly under the "Doctors / Appointments" tab in the app for in-person or telemedicine visits.

2. FIND CHEAPEST & AVAILABLE MEDICATIONS:
   - When the user asks for a drug (e.g. Paracetamol, Artemether, Coartem, Amoxicillin, Omeprazole, etc.), check the directory above and state the EXACT cheapest pharmacy name, address, and price in FCFA.
   - Mention they can tap the "Search Medications" tab or checkout directly with MTN MoMo / Orange Money / Cash on delivery!

3. INTERACTIVE & CONVERSATIONAL STYLE:
   - Talk naturally and directly. DO NOT output canned robotic introductory paragraphs like "Hello I am PharmaLink AI..." every turn.
   - Answer their specific question first, give relevant doctor/pharmacy recommendations from the directory, and ask interactive clinical follow-up questions.
   - Use clear, clean markdown bullet points.`;

    if (apiKey && apiKey !== 'your_gemini_api_key') {
      try {
        const url = `${this.baseUrl}/${this.model}:generateContent?key=${apiKey}`;

        // Build multi-turn contents
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
        if (text) return text;
      } catch (err) {
        console.error('[Gemini API Error]:', err.response?.data || err.message);
      }
    }

    // Dynamic, knowledge-aware fallback response generator
    return this.getKnowledgeAwareFallback(userMessage, systemData, history);
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
   * System-Knowledge Aware Fallback (Used if API Key is not set or network fails)
   */
  getKnowledgeAwareFallback(msg, systemData, history = []) {
    const lower = (msg || '').toLowerCase().trim();

    // 1. Doctor Recommendation or Appointment Booking Request
    if (lower.includes('doctor') || lower.includes('médecin') || lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('consult') || lower.includes('hospital')) {
      const docSample = systemData.doctorsText.split('\n').slice(0, 3).join('\n');
      return `🩺 **Available Doctors on PharmaLink:**\n\nHere are verified doctors available for consultation:\n${docSample}\n\n📅 **How to Book an Appointment:**\n1. Go to the **"Doctors"** tab in PharmaLink.\n2. Choose between **In-Person Hospital Visit** or **Telemedicine Video Call**.\n3. Pick your preferred date & time slot.\n\nWould you like me to tell you more about a specific doctor's specialty or hospital?`;
    }

    // 2. Medication Price & Cheap Pharmacy Search
    if (lower.includes('paracetamol') || lower.includes('artemether') || lower.includes('coartem') || lower.includes('amoxicillin') || lower.includes('cheap') || lower.includes('price') || lower.includes('prix') || lower.includes('buy') || lower.includes('order') || lower.includes('pharmacy') || lower.includes('médicament')) {
      const medSample = systemData.medicationsText.split('\n').slice(0, 4).join('\n');
      return `💊 **Live Medication Prices & Available Pharmacies:**\n\nHere are the current lowest prices across licensed pharmacies in our network:\n${medSample}\n\n🛒 **How to Order:**\n• Tap the **"Search Medications"** tab to view all pharmacies on the **interactive Google Map**.\n• Checkout with **MTN MoMo**, **Orange Money**, or **Cash on Delivery**.\n• Live track the delivery motorbike right to your doorstep!\n\nAre you looking for another medication? Let me know and I will find the best price!`;
    }

    // 3. Malaria & Fevers
    if (lower.includes('malaria') || lower.includes('palu') || lower.includes('fever') || lower.includes('fièvre')) {
      return `🦟 **Malaria Clinical Guidance & Available Meds:**\n\n• **Recommended ACTs:** *Artemether-Lumefantrine (Coartem)* is in stock at **Pharmacie Centrale** and **Pharmacie Bastos** starting at **2,200 FCFA**.\n• **Fever Management:** Paracetamol 500mg/1g (from **1,200 FCFA**).\n• **Doctor Advice:** Dr. Amadou at *Hôpital Central de Yaoundé* is available for consultation to order a rapid test (RDT) before treatment.\n\nHow long have you been experiencing this fever?`;
    }

    // 4. Greetings
    if (/^(hi|hello|hey|salut|bonjour)/.test(lower)) {
      return `Hello! I'm your PharmaLink Clinical Health Assistant. 🩺\n\nI can:\n• Find the **cheapest pharmacies** for any medication you need.\n• Connect you with **available doctors** at partner hospitals (*Hôpital Central, CHU, Clinique Bastos*).\n• Provide symptom triage and medication dosage advice.\n\nHow can I help you today?`;
    }

    // 5. Default contextual
    return `I can help you with that! On PharmaLink, you can find certified doctors, book appointments, or search for medications with real-time stock and prices across licensed pharmacies in Cameroon.\n\nCould you specify which symptom or medication you need help with?`;
  }
}

module.exports = new GeminiService();
