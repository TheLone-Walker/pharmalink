const axios = require('axios');

const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent`;

const chat = async (userMessage, context = '') => {
  const prompt = `You are PharmaLink's AI health assistant. You help users with medication questions, health advice, and navigating the PharmaLink pharmacy platform. Be concise, friendly, and always recommend consulting a doctor for serious symptoms. Context: ${context}\n\nUser: ${userMessage}`;

  const response = await axios.post(
    `${GEMINI_URL}?key=${process.env.GEMINI_API_KEY}`,
    {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 512 },
    }
  );

  const text = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
  return text || 'Sorry, I could not process your request. Please try again.';
};

module.exports = { chat };
