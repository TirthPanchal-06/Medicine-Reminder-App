const { GoogleGenerativeAI } = require('@google/generative-ai');
const https = require('https');

// ─── OpenFDA Drug Lookup ────────────────────────────────────────────────────
// Queries the FREE OpenFDA drug label API (no API key required)
// Covers 100,000+ brand and generic medicines
const lookupMedicineOpenFDA = (medicineName) => {
  return new Promise((resolve) => {
    const encoded = encodeURIComponent(medicineName);
    // Search brand name first, then generic name
    const url = `https://api.fda.gov/drug/label.json?search=openfda.brand_name:"${encoded}"+openfda.generic_name:"${encoded}"&limit=1`;

    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (!json.results || json.results.length === 0) {
            // Try a looser search
            const looseUrl = `https://api.fda.gov/drug/label.json?search=openfda.brand_name:${encoded}&limit=1`;
            https.get(looseUrl, (res2) => {
              let data2 = '';
              res2.on('data', (c) => { data2 += c; });
              res2.on('end', () => {
                try {
                  const json2 = JSON.parse(data2);
                  if (!json2.results || json2.results.length === 0) {
                    resolve(null);
                  } else {
                    resolve(extractFDAInfo(json2.results[0], medicineName));
                  }
                } catch { resolve(null); }
              });
            }).on('error', () => resolve(null));
          } else {
            resolve(extractFDAInfo(json.results[0], medicineName));
          }
        } catch { resolve(null); }
      });
    }).on('error', () => resolve(null));
  });
};

// Cleans FDA label text — removes HTML tags, excessive whitespace, bullet symbols
const cleanFDAText = (text) => {
  if (!text) return null;
  return text
    .replace(/<[^>]+>/g, ' ')   // strip HTML tags
    .replace(/•/g, '')
    .replace(/\s{2,}/g, ' ')
    .replace(/(\d+)\s*\.\s+/g, '\n$1. ')
    .trim()
    .slice(0, 600);               // keep it concise
};

// Extracts relevant fields from an OpenFDA label result
const extractFDAInfo = (result, queryName) => {
  const openfda = result.openfda || {};

  const brandNames = openfda.brand_name ? openfda.brand_name.join(', ') : null;
  const genericNames = openfda.generic_name ? openfda.generic_name.join(', ') : null;
  const displayName = brandNames || genericNames || queryName;

  const uses = cleanFDAText(
    (result.indications_and_usage || result.purpose || [])[0]
  );
  const warnings = cleanFDAText(
    (result.warnings || result.warnings_and_cautions || [])[0]
  );
  const dosage = cleanFDAText(
    (result.dosage_and_administration || [])[0]
  );
  const sideEffects = cleanFDAText(
    (result.adverse_reactions || result.side_effects || [])[0]
  );
  const contraindications = cleanFDAText(
    (result.contraindications || [])[0]
  );

  if (!uses && !warnings && !dosage) return null;

  return { displayName, brandNames, genericNames, uses, warnings, dosage, sideEffects, contraindications };
};

// Format OpenFDA result into a readable chatbot response
const formatFDAResponse = (info) => {
  const disclaimers = '\n\n*⚠️ Disclaimer: This information is sourced from official FDA drug labels and is for educational purposes only. Always consult your doctor or pharmacist before taking any medication.*';

  let response = `💊 **${info.displayName}**`;
  if (info.genericNames && info.brandNames && info.genericNames !== info.displayName) {
    response += `\n_Generic: ${info.genericNames}_`;
  }
  response += '\n';

  if (info.uses) {
    response += `\n📋 **Uses & Indications:**\n${info.uses}\n`;
  }
  if (info.sideEffects) {
    response += `\n⚠️ **Adverse Reactions / Side Effects:**\n${info.sideEffects}\n`;
  } else if (info.warnings) {
    response += `\n⚠️ **Warnings:**\n${info.warnings}\n`;
  }
  if (info.dosage) {
    response += `\n💉 **Dosage & Administration:**\n${info.dosage}\n`;
  }
  if (info.contraindications) {
    response += `\n🚫 **Contraindications:**\n${info.contraindications}\n`;
  }

  return response + disclaimers;
};

// ─── Medicine Name Detection ────────────────────────────────────────────────
const detectMedicineName = (msg) => {
  const lower = msg.toLowerCase().trim();
  const patterns = [
    /what (?:is|are) (.+?) (?:used for|for|prescribed for|tablet|capsule|drug|medicine)/i,
    /tell me about (.+)/i,
    /(?:uses?|information|info|details?) (?:of|about|on) (.+)/i,
    /what does (.+?) (?:do|treat|help|cure)/i,
    /(?:side effects?|warnings?|dosage|dose) (?:of|for) (.+)/i,
    /(.+?) (?:medicine|tablet|drug|capsule|syrup|injection|cream|ointment|drop)/i,
  ];
  for (const p of patterns) {
    const m = lower.match(p);
    if (m) {
      return m[1].trim().replace(/[^a-z0-9\s\-]/gi, '').trim();
    }
  }
  // If it's 1–3 words with no common non-medicine keywords, treat as medicine name
  const nonMedicineKeywords = /\b(hello|hi|hey|blood|pressure|sugar|glucose|miss|forgot|emergency|sos|what|how|why|when|where|can|should|is|are|the|a|an|my)\b/i;
  const words = lower.replace(/[^a-z0-9\s\-]/g, '').trim().split(/\s+/);
  if (words.length >= 1 && words.length <= 3 && !nonMedicineKeywords.test(lower)) {
    return words.join(' ');
  }
  return null;
};

// ─── Static Local Fallback ──────────────────────────────────────────────────
const localDatabase = {
  paracetamol: { uses: 'Pain relief (headache, toothache, body ache, fever, menstrual cramps). Analgesic and antipyretic.', sideEffects: 'Generally well-tolerated. Rare: liver damage if overdosed. Avoid alcohol.', dosage: '500mg–1000mg every 4–6 hours. Max 4g/day.' },
  acetaminophen: { uses: 'Same as Paracetamol — pain and fever relief.', sideEffects: 'Liver damage in overdose. Avoid alcohol.', dosage: '500mg–1000mg every 4–6 hours.' },
  ibuprofen: { uses: 'Pain, fever, and inflammation — arthritis, headaches, menstrual pain, muscle aches.', sideEffects: 'Stomach upset, heartburn, increased BP, kidney issues. Take with food.', dosage: '200–400mg every 4–6 hours. Max 1200mg/day OTC.' },
  metformin: { uses: 'Type 2 Diabetes — reduces blood sugar, improves insulin sensitivity.', sideEffects: 'Nausea, diarrhea, stomach pain (initially). Rare: Lactic acidosis.', dosage: '500mg–2000mg daily with meals.' },
  amoxicillin: { uses: 'Antibiotic for ear infections, throat, pneumonia, UTI, skin infections.', sideEffects: 'Diarrhea, rash, allergic reaction. Complete full course.', dosage: '250–500mg every 8 hours.' },
  azithromycin: { uses: 'Antibiotic for respiratory, skin, STDs, typhoid, ear infections.', sideEffects: 'Nausea, stomach pain, diarrhea, rarely heart rhythm issues.', dosage: '500mg Day 1, then 250mg Days 2–5.' },
  omeprazole: { uses: 'Acid reflux (GERD), peptic ulcer, heartburn, stomach protection with NSAIDs.', sideEffects: 'Headache, nausea, diarrhea. Long-term: low magnesium.', dosage: '20mg once daily before meals.' },
  amlodipine: { uses: 'High blood pressure and chest pain (angina). Relaxes blood vessels.', sideEffects: 'Ankle swelling, flushing, dizziness, headache.', dosage: '2.5–10mg once daily.' },
  lisinopril: { uses: 'Hypertension, heart failure, post-heart attack, diabetic kidney disease.', sideEffects: 'Dry cough, dizziness, high potassium. Avoid in pregnancy.', dosage: '5–40mg once daily.' },
  aspirin: { uses: 'Pain/fever at high dose. Low dose (75–100mg) — blood thinner for heart attack/stroke prevention.', sideEffects: 'Stomach bleeding, GI upset. Avoid in children.', dosage: '75–100mg (cardiac). 300–600mg (pain).' },
  cetirizine: { uses: 'Antihistamine for allergies — hay fever, hives, itching, runny nose.', sideEffects: 'Mild drowsiness, dry mouth, headache.', dosage: '10mg once daily.' },
  atorvastatin: { uses: 'High cholesterol, prevention of heart attack and stroke.', sideEffects: 'Muscle pain, liver enzyme elevation. Avoid grapefruit juice.', dosage: '10–80mg once daily at night.' },
  metoprolol: { uses: 'High blood pressure, angina, heart failure, heart rate control.', sideEffects: 'Fatigue, cold extremities, dizziness, slow heart rate. Do not stop suddenly.', dosage: '25–200mg once or twice daily.' },
};

const getLocalResponse = (medicineName) => {
  if (!medicineName) return null;
  const key = medicineName.toLowerCase().replace(/[^a-z]/g, '');
  const med = localDatabase[key];
  if (!med) return null;
  const displayName = medicineName.charAt(0).toUpperCase() + medicineName.slice(1);
  const disclaimers = '\n\n*⚠️ Disclaimer: For educational purposes only. Consult your doctor or pharmacist for personalized advice.*';
  return `💊 **${displayName}**\n\n📋 **Uses:**\n${med.uses}\n\n⚠️ **Common Side Effects:**\n${med.sideEffects}\n\n💉 **Typical Dosage:**\n${med.dosage}` + disclaimers;
};

// ─── General Health Response Fallback ─────────────────────────────────────
const getGeneralHealthResponse = (msg) => {
  const disclaimers = '\n\n*⚠️ Disclaimer: For educational purposes only. Consult your doctor or pharmacist for personalized advice.*';
  const lower = msg.toLowerCase();

  if (lower.match(/hello|hi\b|hey\b/)) {
    return '👋 Hello! I am your **AI Medicine Assistant** 💊\n\nAsk me about **any medicine** and I\'ll tell you:\n✅ What it\'s used for\n✅ Side effects & warnings\n✅ Dosage information\n\n**Try asking:**\n• *"What is Paracetamol used for?"*\n• *"Tell me about Amoxicillin"*\n• *"Metformin"* — just type the name!\n\nOr ask general health questions!' + disclaimers;
  }
  if (lower.match(/blood pressure|hypertension|\bbp\b/)) {
    return 'A normal blood pressure is **below 120/80 mmHg**. Above 130/80 is hypertension.\n\n💊 Common BP medicines: Amlodipine, Lisinopril, Losartan, Metoprolol.\n\nAsk me about any of these for full details!' + disclaimers;
  }
  if (lower.match(/blood sugar|glucose|diabetes/)) {
    return 'Fasting blood sugar: **70–100 mg/dL** (normal), **80–130 mg/dL** (diabetic target).\n\n💊 Common diabetes medicines: Metformin, Insulin, Glipizide, Sitagliptin.\n\nAsk me about any of these!' + disclaimers;
  }
  if (lower.match(/miss|forgot|skip.*dose/)) {
    return 'If you miss a dose:\n1. Take it as soon as you remember.\n2. If your next dose is soon, **skip** the missed one.\n3. **Never double-up** doses!\n\nFor insulin or blood thinners, contact your doctor immediately.' + disclaimers;
  }
  if (lower.match(/sos|emergency/)) {
    return '🚨 If this is a medical emergency (chest pain, difficulty breathing), use the **SOS button** in the app or call emergency services immediately!' + disclaimers;
  }
  return null;
};

// ─── Main Chat Response ─────────────────────────────────────────────────────
const getChatResponse = async (chatHistory, newMessage) => {
  const apiKey = process.env.GEMINI_API_KEY;
  const disclaimers = '\n\n*⚠️ Disclaimer: For educational purposes only. Consult your doctor or pharmacist for personalized advice.*';

  // 1. Try Gemini AI first (most powerful — knows about ALL medicines)
  if (apiKey) {
    try {
      console.log('Gemini API key detected. Invoking Gemini chatbot model...');
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: 'gemini-1.5-flash',
        systemInstruction: `You are a professional Medicine Information and Health Assistant for a Medicine Reminder App.

Your PRIMARY job is to provide medicine information. Rules:

1. WHEN USER MENTIONS A MEDICINE NAME (e.g. "Paracetamol", "Metformin", "What is Dolo 650?", "Tell me about Azithromycin"):
   Respond with this exact structured format:
   
   💊 **[Medicine Name]**
   _Generic: [generic name if different]_
   
   📋 **Uses & Indications:**
   [What conditions it treats and brief mechanism]
   
   ⚠️ **Common Side Effects:**
   [Most important side effects to be aware of]
   
   💉 **Dosage & Administration:**
   [Standard adult dosage and timing]
   
   🔄 **Important Notes:**
   [Key precautions, interactions, or warnings]
   
   *⚠️ Disclaimer: For educational purposes only. Consult your doctor or pharmacist for personalized advice.*

2. For GENERAL health questions: Give helpful, concise guidance.
3. Keep responses readable with emojis and bold headers.
4. If completely unsure about a medicine, say so honestly.`
      });

      const chat = model.startChat({
        history: chatHistory.map(item => ({
          role: item.role === 'user' ? 'user' : 'model',
          parts: [{ text: item.content }]
        }))
      });
      const result = await chat.sendMessage(newMessage);
      return result.response.text();
    } catch (error) {
      console.error('Gemini Chatbot failed, trying OpenFDA...', error.message);
    }
  }

  // 2. Try OpenFDA API for dynamic medicine lookup (free, no key, 100k+ medicines)
  const medicineName = detectMedicineName(newMessage);
  if (medicineName) {
    console.log(`Detected medicine query: "${medicineName}". Querying OpenFDA...`);
    try {
      const fdaInfo = await lookupMedicineOpenFDA(medicineName);
      if (fdaInfo) {
        console.log(`OpenFDA found info for: ${fdaInfo.displayName}`);
        return formatFDAResponse(fdaInfo);
      }
    } catch (err) {
      console.error('OpenFDA lookup failed:', err.message);
    }

    // 3. Try local static database as next fallback
    const localResp = getLocalResponse(medicineName);
    if (localResp) {
      console.log(`Found "${medicineName}" in local database.`);
      return localResp;
    }

    // 4. Medicine not found anywhere
    console.log(`Medicine "${medicineName}" not found in any source.`);
    return `I searched for **${medicineName}** but couldn't find detailed information.\n\n📌 **What you can do:**\n1. Check the spelling — try the generic name (e.g., "Paracetamol" instead of "Calpol").\n2. Ask your pharmacist — they have access to full drug databases.\n3. Visit [Drugs.com](https://www.drugs.com) or [MedlinePlus](https://medlineplus.gov) for comprehensive info.\n\n💡 I can look up most medicines — just try typing the name again!` + disclaimers;
  }

  // 5. General health response
  const generalResp = getGeneralHealthResponse(newMessage);
  if (generalResp) return generalResp;

  // 6. Ultimate fallback
  return `I'm your **Medicine Information Assistant** 💊\n\nAsk me about **any medicine** to get:\n✅ What it's used for\n✅ Side effects & warnings\n✅ Dosage information\n\n**Try:**\n• *"What is Paracetamol used for?"*\n• *"Tell me about Azithromycin"*\n• *"Dolo 650"* — just type a medicine name!\n\nOr ask: blood pressure, diabetes, missed doses, etc.` + disclaimers;
};

module.exports = { getChatResponse };
