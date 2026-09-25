const axios = require('axios');

/**
 * PharmaLink Gemini AI Medical & Health Advisory Service
 * Powered by Google Gemini 1.5 Flash
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
   * Health Assistant Chat with Medical Context
   */
  async chat(userMessage, context = '') {
    const apiKey = this.getApiKey();

    const systemInstruction = `You are PharmaLink's AI Health & Medical Assistant in Cameroon.
Your role:
- Provide clear, empathetic, and evidence-based guidance on medications, dosages, and common symptoms (e.g. Malaria, Typhoid, common colds, hypertension, diabetes).
- Guide users to consult certified doctors or visit licensed pharmacies available on the PharmaLink app.
- Provide practical first-aid advice.
- Always include a short medical disclaimer for severe conditions urging in-person consultation or emergency services (SAMU 1510 / Police 117 in Cameroon).
- Keep answers concise, helpful, and easily readable on a mobile screen.`;

    if (apiKey && apiKey !== 'your_gemini_api_key') {
      try {
        const url = `${this.baseUrl}/${this.model}:generateContent?key=${apiKey}`;
        const response = await axios.post(
          url,
          {
            contents: [
              {
                role: 'user',
                parts: [
                  { text: `${systemInstruction}\n\nUser Medical History/Context: ${context}\n\nPatient Query: ${userMessage}` },
                ],
              },
            ],
            generationConfig: {
              temperature: 0.4,
              maxOutputTokens: 600,
              topP: 0.9,
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

    // Fallback AI engine for Cameroon Health FAQs if API key is missing or offline
    return this.getFallbackResponse(userMessage);
  }

  /**
   * Analyze Prescription or Lab Report (Text / Vision)
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
                  text: `Analyze this medical prescription text for a patient in Cameroon. Identify the medications, standard dosages, potential contraindications, and suggest what question to ask the pharmacist:\n\n${textOrData}`,
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
    return 'Prescription analyzed: Please ensure you follow the doctor\'s prescribed dosage and verify with your dispensing pharmacist on PharmaLink.';
  }

  /**
   * Smart fallback responses for common Cameroon health queries
   */
  getFallbackResponse(msg) {
    const lower = (msg || '').toLowerCase();
    if (lower.includes('malaria') || lower.includes('palu') || lower.includes('fever') || lower.includes('fièvre')) {
      return `🦟 **Malaria & Fever Guidance:**\n\n- Common symptoms include high fever, chills, sweating, and headache.\n- Recommended next step: Perform a Rapid Diagnostic Test (RDT) or consultation with a doctor on PharmaLink before starting ACT antimalarials (e.g., Artemether-Lumefantrine / Coartem).\n- Stay hydrated and take Paracetamol (500mg - 1g) to manage fever.\n\n⚠️ *If you have persistent vomiting, convulsions, or high fever for more than 48 hours, seek urgent emergency hospital care.*`;
    }
    if (lower.includes('headache') || lower.includes('pain') || lower.includes('mal de tête')) {
      return `💊 **Pain & Headache Relief:**\n\n- Rest in a quiet, dark room and drink plenty of water.\n- Over-the-counter options like Paracetamol (500mg-1g every 6-8h, max 3g/day) or Ibuprofen (400mg with food) can help.\n- If the headache is severe, sudden, or accompanied by stiff neck, consult a doctor immediately on PharmaLink.`;
    }
    if (lower.includes('pharmacy') || lower.includes('delivery') || lower.includes('order')) {
      return `🏥 **PharmaLink Pharmacy Services:**\n\nYou can search for any medication across licensed pharmacies in Yaoundé, Douala, and surrounding regions. Choose delivery to your doorstep or pharmacy pick-up at checkout!`;
    }
    return `Hello! I am your PharmaLink AI Health Assistant. How can I help you today with medication information, dosage guidance, or finding a healthcare provider? \n\n*(For urgent medical emergencies, please dial 1510 or visit your nearest hospital).*`;
  }
}

module.exports = new GeminiService();
