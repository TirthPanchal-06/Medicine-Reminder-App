const { GoogleGenAI } = require('@google/generative-ai');

// Highly responsive local health assistant chatbot for fallback when Gemini API is unconfigured
const getLocalChatbotResponse = (message) => {
  const msg = message.toLowerCase();
  
  const disclaimers = "\n\n*Disclaimer: I am an AI assistant and this info is for educational purposes. Please consult a healthcare professional for clinical advice.*";

  if (msg.includes('hello') || msg.includes('hi') || msg.includes('hey')) {
    return "Hello! I am your AI Health Assistant. 🌟 How can I help you manage your medications, track your health vitals, or analyze your schedules today?" + disclaimers;
  }
  
  if (msg.includes('side effect') || msg.includes('side-effect')) {
    return "Medication side effects can vary. For common prescriptions like Metformin, minor gastrointestinal issues (nausea, cramping) are common initially. For blood pressure meds like Lisinopril, a dry cough might occur. If you're concerned about a specific medicine, please let me know its name, or verify with your doctor or pharmacist immediately!" + disclaimers;
  }
  
  if (msg.includes('blood pressure') || msg.includes('bp')) {
    return "Managing blood pressure is essential! A normal reading is typically below 120/80 mmHg. Consistent readings above 130/80 are classified as hypertension. Make sure to log your vitals regularly in the Health Tracker, avoid excess sodium, stay active, and take your prescribed antihypertensives on time." + disclaimers;
  }

  if (msg.includes('blood sugar') || msg.includes('glucose') || msg.includes('diabetes')) {
    return "Blood sugar targets depend on whether you are fasting or checking after meals. Fasting levels should ideally be 70-100 mg/dL (non-diabetic) or 80-130 mg/dL (diabetic). Check your levels as scheduled by your doctor, log them in the Health records, and keep a consistent medication routine." + disclaimers;
  }

  if (msg.includes('missed') || msg.includes('forget')) {
    return "If you miss a dose, check the medicine package instructions! Generally, if you remember within a few hours of the scheduled time, take it immediately. However, if it's almost time for your next dose, skip the missed one. **Never double the dose** to catch up!" + disclaimers;
  }

  if (msg.includes('sos') || msg.includes('emergency')) {
    return "If you are experiencing a medical emergency (chest pain, severe shortness of breath, sudden weakness), please click the **SOS floating button** immediately to call your designated emergency contact, or contact emergency services (911 / 112) right away!" + disclaimers;
  }

  if (msg.includes('family') || msg.includes('dependent')) {
    return "Our app supports Family Member management! You can add profiles for your parents, children, or spouse from the 'Family' tab. This lets you track their medication compliance, view their schedules, and ensure they never miss their vital doses." + disclaimers;
  }

  // Default response
  return "That is an interesting health question! Keeping a consistent medication schedule and logging your vitals (blood pressure, blood sugar, heart rate) is a great step toward wellness. If you have specific questions about a drug's dosage, interactions, or side effects, let me know, or consult your health provider." + disclaimers;
};

const getChatResponse = async (chatHistory, newMessage) => {
  const apiKey = process.env.GEMINI_API_KEY;

  if (apiKey) {
    try {
      console.log('Gemini API key detected. Invoking Gemini chatbot model...');
      const genAI = new GoogleGenAI({ apiKey });
      const model = genAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        systemInstruction: "You are a professional, friendly, and expert Smart Medicine Reminder App Health Assistant. Your goal is to help users manage their medication, explain common side effects, provide healthy lifestyle guidelines, and assist with vitals logs. Remember, you must always provide helpful guidance but explicitly state that you are an AI assistant and they should verify important medical advice with a real doctor or healthcare provider."
      });

      // Format history for Google Generative AI chat structure
      const chat = model.startChat({
        history: chatHistory.map(item => ({
          role: item.role === 'user' ? 'user' : 'model',
          parts: [{ text: item.content }]
        }))
      });

      const result = await chat.sendMessage(newMessage);
      return result.response.text();
    } catch (error) {
      console.error('Gemini Chatbot service failed, falling back to local responder:', error.message);
      return getLocalChatbotResponse(newMessage);
    }
  } else {
    console.log('No Gemini API key configured. Executing local health assistant chat responder.');
    return getLocalChatbotResponse(newMessage);
  }
};

module.exports = {
  getChatResponse
};
