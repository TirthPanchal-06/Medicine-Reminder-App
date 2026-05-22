const Tesseract = require('tesseract.js');
const { GoogleGenAI } = require('@google/generative-ai');

// Local fallback regex parser to extract structured information when Gemini API is unavailable
const parseTextLocally = (text) => {
  console.log('Running local regex parser on OCR output...');
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  const medicines = [];
  
  // Common medicine dosage terms
  const dosageRegex = /(\d+\s*(?:mg|g|ml|mcg|tab|capsule|pill|puff|drop|unit)s?)/i;
  // Common instructions
  const instructionsList = [
    { key: 'before food', regex: /before\s*food|empty\s*stomach|a\.c\./i },
    { key: 'after food', regex: /after\s*food|p\.c\./i },
    { key: 'with water', regex: /with\s*water/i },
    { key: 'at bedtime', regex: /bedtime|night|h\.s\./i }
  ];
  
  lines.forEach((line) => {
    // Check if the line looks like a prescription instruction
    // Often lists names like "Amoxicillin 500mg", "Metformin 850mg", "Paracetamol"
    const dosageMatch = line.match(dosageRegex);
    
    // We treat line as a potential medicine if it has alphabetical characters and is relatively short
    if (line.length > 3 && line.length < 60 && /[a-zA-Z]/.test(line)) {
      // Clean up common noise
      let cleanName = line.replace(/[^a-zA-Z0-9\s.\-]/g, '').trim();
      
      let dosage = '1 pill';
      if (dosageMatch) {
        dosage = dosageMatch[0];
        cleanName = cleanName.replace(dosage, '').trim();
      }

      // Check frequency
      let frequency = 'daily';
      let times = ['08:00'];
      
      if (/twice|bid|b\.i\.d\.|2x/i.test(line)) {
        times = ['08:00', '20:00'];
      } else if (/thrice|three\s*times|tid|t\.i\.d\.|3x/i.test(line)) {
        times = ['08:00', '13:00', '20:00'];
      } else if (/four\s*times|qid|q\.i\.d\.|4x/i.test(line)) {
        times = ['08:00', '12:00', '16:00', '20:00'];
      } else if (/once|qd|q\.d\.|1x/i.test(line)) {
        times = ['08:00'];
      }

      // Extract instructions
      let instructions = 'Take as directed';
      for (const inst of instructionsList) {
        if (inst.regex.test(line)) {
          instructions = inst.key;
          break;
        }
      }

      // Avoid pushing metadata lines
      if (!/doctor|prescription|patient|date|hospital|clinic|rx|name/i.test(cleanName)) {
        medicines.push({
          name: cleanName.split(' ')[0] || cleanName, // Extract first word or full name
          dosage: dosage,
          frequency: frequency,
          times: times,
          instructions: instructions
        });
      }
    }
  });

  return medicines.length > 0 ? medicines : [
    {
      name: 'Extracted Medicine',
      dosage: '1 pill',
      frequency: 'daily',
      times: ['08:00'],
      instructions: 'Please verify with your prescription'
    }
  ];
};

const scanPrescription = async (filePath) => {
  try {
    console.log(`Starting Tesseract OCR on file: ${filePath}`);
    // Run optical character recognition locally using tesseract
    const { data: { text } } = await Tesseract.recognize(filePath, 'eng', {
      logger: m => console.log(`[Tesseract] ${m.status}: ${Math.round(m.progress * 100)}%`)
    });
    
    console.log('OCR Complete. Extracted Raw Text length:', text.length);

    const apiKey = process.env.GEMINI_API_KEY;

    if (apiKey) {
      try {
        console.log('Gemini API key detected. Querying Gemini to extract structured schedule details...');
        // Initialize Gemini model
        const genAI = new GoogleGenAI({ apiKey });
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        const prompt = `
          You are a professional medical data extraction assistant.
          Below is a raw text transcript extracted via OCR from a doctor's medical prescription.
          Please analyze this text and extract all medications mentioned.
          For each medication, return a JSON object with:
          - "name": The clear brand or generic name of the medicine.
          - "dosage": The dosage string (e.g. "500 mg", "1 tablet", "10 ml").
          - "frequency": The schedule type, strictly from: "daily", "weekly", "specific_days", "interval".
          - "times": Array of 24h formatted times ("HH:MM") when the dose should be taken. E.g. twice a day -> ["08:00", "20:00"].
          - "instructions": Standard intake instructions (e.g., "before food", "after food", "at bedtime", "with milk"). If none found, write "Take as directed".

          Return only a valid JSON array of objects representing these medications. Do not wrap in markdown blocks, just return raw JSON text.
          If no medications are found, return a default mock object array.

          OCR TEXT:
          """
          ${text}
          """
        `;

        const result = await model.generateContent(prompt);
        const responseText = result.response.text().trim();
        
        // Clean JSON formatting if Gemini wrapped it in markdown code block
        const cleanJSON = responseText.replace(/^```json\s*/i, '').replace(/```$/, '').trim();
        const medicines = JSON.parse(cleanJSON);
        return { text, medicines };
      } catch (geminiError) {
        console.error('Gemini OCR extraction failed, falling back to local extraction:', geminiError.message);
        const medicines = parseTextLocally(text);
        return { text, medicines };
      }
    } else {
      console.log('No Gemini API key configured. Utilizing local regex extraction rules.');
      const medicines = parseTextLocally(text);
      return { text, medicines };
    }
  } catch (error) {
    console.error('Prescription OCR scan failed:', error.message);
    throw error;
  }
};

module.exports = {
  scanPrescription
};
