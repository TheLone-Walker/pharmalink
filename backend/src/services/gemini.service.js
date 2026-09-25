const axios = require('axios');

/**
 * PharmaLink Gemini AI Medical & Health Advisory Service
 * Powered by Google Gemini 1.5 Flash (Interactive Multi-Turn)
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
   * Interactive Health Assistant Chat with Multi-Turn Memory
   */
  async chat(userMessage, context = '', history = []) {
    const apiKey = this.getApiKey();

    const systemInstruction = `You are PharmaLink's friendly, highly interactive AI Clinical Health Assistant in Cameroon.
Behavior Guidelines:
- Be interactive, natural, conversational, and direct. Do NOT start every reply with canned robot introductions like "Hello I am PharmaLink AI..." or repetitious repetitive disclaimers.
- Acknowledge what the user said, answer specifically, and ask relevant follow-up clarifying questions when helpful (e.g., symptom duration, age, allergies, fever severity).
- Provide practical dosage advice, medication storage tips, and guidance on consulting registered doctors or ordering from licensed pharmacies on PharmaLink.
- Keep responses clean, well-formatted with markdown bullet points, and concise for mobile screens.
- If symptoms indicate an emergency (e.g. convulsions, high fever >3 days, severe chest pain), concisely urge visiting nearest hospital or calling SAMU 1510.`;

    if (apiKey && apiKey !== 'your_gemini_api_key') {
      try {
        const url = `${this.baseUrl}/${this.model}:generateContent?key=${apiKey}`;

        // Build multi-turn contents from conversation history
        const contents = [];

        // Include previous conversation turns (up to last 10 messages for context)
        if (Array.isArray(history) && history.length > 0) {
          const recentHistory = history.slice(-10);
          for (const item of recentHistory) {
            const role = item.role === 'user' ? 'user' : 'model';
            const text = item.text || item.content || '';
            if (text.trim()) {
              contents.push({ role, parts: [{ text }] });
            }
          }
        }

        // Add current user prompt with clinical system instruction and context
        const currentPrompt = contents.length === 0
          ? `${systemInstruction}\n\nContext: ${context}\n\nUser: ${userMessage}`
          : userMessage;

        contents.push({ role: 'user', parts: [{ text: currentPrompt }] });

        const response = await axios.post(
          url,
          {
            contents,
            generationConfig: {
              temperature: 0.75, // Dynamic & engaging conversation
              maxOutputTokens: 600,
              topP: 0.92,
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

    // Dynamic, interactive fallback response generator
    return this.getInteractiveFallbackResponse(userMessage, history);
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
   * Dynamic Interactive Fallback Engine (Multi-Topic, Context-Aware)
   */
  getInteractiveFallbackResponse(msg, history = []) {
    const lower = (msg || '').toLowerCase().trim();

    // 1. Greetings & Chat Openers
    if (/^(hi|hello|hey|salut|bonjour|good morning|good evening|good afternoon)/.test(lower)) {
      const greetings = [
        "Hello! How are you feeling today? Are you experiencing any symptoms, or do you have questions about a medication?",
        "Hey there! I'm here to help with your health and medication questions. What's on your mind today?",
        "Hello! Looking for advice on symptoms, drug dosages, or finding a licensed pharmacy nearby? How can I assist you?",
      ];
      return greetings[Math.floor(Math.random() * greetings.length)];
    }

    // 2. Malaria & Fevers
    if (lower.includes('malaria') || lower.includes('palu') || lower.includes('paludisme')) {
      if (lower.includes('treatment') || lower.includes('treat') || lower.includes('cure') || lower.includes('medicine')) {
        return `🦟 **Malaria Treatment in Cameroon:**\n\n• **First-Line ACTs:** Artemether-Lumefantrine (*Coartem / Artefan*) or Artesunate-Amodiaquine taken for 3 full days with meals.\n• **Fever Management:** Paracetamol (500mg-1g every 6-8h, max 3g/day).\n• **Crucial Step:** Always take a Rapid Diagnostic Test (RDT) or consultation on PharmaLink to confirm before starting ACTs.\n\nAre you having other symptoms like vomiting or severe chills?`;
      }
      return `🦟 **Malaria Signs & Advice:**\n\nCommon signs include cyclical high fever, shaking chills, profuse sweating, body aches, and headache.\n\n👉 **Recommended next steps:**\n1. Do a blood test (RDT/Goutte Épaisse) at a clinic.\n2. Stay well-hydrated with water and oral electrolytes.\n3. Consult a doctor on PharmaLink to prescribe the correct ACT course.\n\nHow many days have you had these symptoms?`;
    }

    // 3. Headaches & Pain
    if (lower.includes('headache') || lower.includes('mal de tête') || lower.includes('body pain') || lower.includes('fever') || lower.includes('fièvre')) {
      return `💊 **Pain & Fever Relief:**\n\n• **Paracetamol (500mg - 1000mg):** Take 1 tablet every 6 to 8 hours with water. Do not exceed 3000mg in 24 hours.\n• **Rest & Fluids:** Drink at least 2 liters of water and rest in a well-ventilated, shaded area.\n• **Caution:** Avoid taking NSAIDs like Ibuprofen on an empty stomach.\n\nIs the pain localized to your forehead, temples, or neck? Let me know so I can give more specific guidance.`;
    }

    // 4. Antibiotics & Dosage
    if (lower.includes('amoxicillin') || lower.includes('antibiotic') || lower.includes('cipro') || lower.includes('dosage') || lower.includes('dose')) {
      return `🦠 **Antibiotic & Medication Dosage Guide:**\n\n• **Amoxicillin / Augmentin:** Typically taken every 8 or 12 hours. Always complete the entire 5 to 7-day course even if you feel better.\n• **Never skip doses:** Skipping doses promotes bacterial resistance.\n• **Food:** Taking antibiotics with meals prevents gastric upset.\n\nWhich specific medication and strength are you taking?`;
    }

    // 5. Ordering & Delivery on PharmaLink
    if (lower.includes('pharmacy') || lower.includes('order') || lower.includes('buy') || lower.includes('delivery') || lower.includes('livraison')) {
      return `🏪 **Pharmacy & Delivery Services:**\n\n• **Search Medications:** Use the search bar in the PharmaLink app to find pharmacies in Yaoundé, Douala, and other regions with current stock.\n• **Payment:** Pay seamlessly via MTN Mobile Money, Orange Money, or Cash on Delivery.\n• **Express Courier:** Track your delivery driver live on the interactive map!\n\nAre you looking for a specific medication right now?`;
    }

    // 6. Doctor Consultation & Appointments
    if (lower.includes('doctor') || lower.includes('médecin') || lower.includes('appointment') || lower.includes('rendez-vous') || lower.includes('lab')) {
      return `🩺 **Doctor Consultations & Lab Tests:**\n\n• You can book in-person visits or telemedicine consultations with verified ONMC doctors directly from the Doctors tab.\n• Doctors on PharmaLink can order laboratory tests first to confirm your diagnosis before issuing your prescription.\n\nWould you like guidance on selecting a doctor specialty?`;
    }

    // 7. General Contextual Follow-up
    return `I understand. Could you tell me a bit more about your situation or any other symptoms you're noticing? \n\nI can help you with specific medication information, dosage timing, side effects, or finding a licensed pharmacy on PharmaLink.`;
  }
}

module.exports = new GeminiService();
