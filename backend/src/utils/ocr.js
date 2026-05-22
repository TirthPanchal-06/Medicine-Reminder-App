const Tesseract = require('tesseract.js');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Highly robust local fallback regex parser to extract structured information when Gemini API is unavailable/offline
const parseTextLocally = (text) => {
  console.log('Running highly robust local regex parser on OCR output...');
  if (!text) return [];

  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  const medicines = [];

  // Extended noise list to filter out ALL non-medication lines
  const noiseRegex = /^(doctor|dr\.|prescription|patient|pt|date|hospital|clinic|rx|name|phone|address|age|sex|gender|weight|history|diagnosis|report|sign|signature|ref|reg|registration|contact|email|time|notes|symptoms|advice|follow|visit|print|issued|valid|stamp|license|mbbs|ms|md|bsc|qualification|degree|seal|hospital|centre|center|health|care|general|government|private|clinic|ward|dept|department|room|bed|no\.|number|lab|test|result|blood|urine|x-ray|mri|ct|scan|sample|report|normal|abnormal|range|value|unit|total|count|level|tsh|hb|wbc|rbc|esr|crp|hba1c|cholesterol|triglyceride|ldl|hdl|platelet|sodium|potassium|calcium|creatinine|urea|protein|albumin|bilirubin)\b/i;

  // Medicine prefix strip list
  const prefixRegex = /^(tab\b\.?|tablet\b\.?|capsule\b\.?|cap\b\.?|syr\b\.?|syrup\b\.?|inj\b\.?|injection\b\.?|ointment\b\.?|cream\b\.?|drop\b\.?|drops\b\.?)\s+/i;

  // Dosage regex: e.g. "500 mg", "850mg", "10 ml", "1 tablet", "2 puffs", "5ml", "10mcg", "1 unit"
  const dosageRegex = /(\b\d+(?:\.\d+)?\s*(?:mg|g|ml|mcg|tab|capsule|pill|puff|drop|unit|ug|tsp|tablespoon)s?\b)/i;

  // Hyphen frequency patterns: e.g. "1-0-1", "1 - 1 - 1", "0-1-0", "1-0-0-1"
  const hyphenFreq4Regex = /\b([0-2])\s*-\s*([0-2])\s*-\s*([0-2])\s*-\s*([0-2])\b/;
  const hyphenFreq3Regex = /\b([0-2])\s*-\s*([0-2])\s*-\s*([0-2])\b/;

  // Duration regex: e.g. "5 Days", "1 week"
  const durationRegex = /\b\d+\s*(?:day|week|month|year)s?\b/i;

  // Instructions keywords mapping (refined to avoid standalone substring conflicts)
  const instructionsList = [
    { key: 'before food', regex: /\b(?:before\s+)(?:food|meals?|breakfast|lunch|dinner)\b/i },
    { key: 'before food', regex: /\b(?:empty\s*stomach|a\.c\.|ac)\b/i },
    { key: 'after food', regex: /\b(?:after\s+)(?:food|meals?|breakfast|lunch|dinner)\b/i },
    { key: 'after food', regex: /\b(?:p\.c\.|pc)\b/i },
    { key: 'at bedtime', regex: /\b(?:at\s+)?(?:bedtime|night|h\.s\.|hs|before\s*sleep|sleep)\b/i },
    { key: 'with water', regex: /\b(?:with\s+water)\b/i },
    { key: 'with milk', regex: /\b(?:with\s+milk)\b/i }
  ];

  lines.forEach((line) => {
    // If the line is short, doesn't contain alphabetical characters, or is clearly metadata, skip it
    if (line.length < 3 || !/[a-zA-Z]/.test(line)) return;
    if (noiseRegex.test(line)) return;

    // Clean stray dashes/hyphens surrounded by spaces or trailing hyphens
    let processedLine = line.replace(/\s+-\s+/g, ' ').replace(/\s*-\s*$/g, '').trim();

    // 1. Extract and remove duration
    processedLine = processedLine.replace(durationRegex, ' ').trim();

    // 2. Extract and remove instructions
    let instructions = 'Take as directed';
    for (const inst of instructionsList) {
      if (inst.regex.test(processedLine)) {
        instructions = inst.key;
        processedLine = processedLine.replace(inst.regex, ' ').trim();
        break;
      }
    }

    // 3. Extract and remove dosage
    let dosage = '1 pill';
    const dosageMatch = processedLine.match(dosageRegex);
    if (dosageMatch) {
      dosage = dosageMatch[0];
      processedLine = processedLine.replace(dosageMatch[0], ' ').trim();
    }

    // 4. Extract and remove hyphen frequencies
    let times = ['08:00'];
    let frequency = 'daily';
    let matchedFreq = false;

    const match4 = processedLine.match(hyphenFreq4Regex);
    if (match4) {
      matchedFreq = true;
      const count1 = parseInt(match4[1]);
      const count2 = parseInt(match4[2]);
      const count3 = parseInt(match4[3]);
      const count4 = parseInt(match4[4]);
      
      times = [];
      if (count1 > 0) times.push('08:00');
      if (count2 > 0) times.push('12:00');
      if (count3 > 0) times.push('16:00');
      if (count4 > 0) times.push('20:00');
      
      if (times.length === 0) times.push('08:00');
      processedLine = processedLine.replace(match4[0], ' ').trim();
    } else {
      const match3 = processedLine.match(hyphenFreq3Regex);
      if (match3) {
        matchedFreq = true;
        const count1 = parseInt(match3[1]);
        const count2 = parseInt(match3[2]);
        const count3 = parseInt(match3[3]);
        
        times = [];
        if (count1 > 0) times.push('08:00');
        if (count2 > 0) times.push('13:00');
        if (count3 > 0) times.push('20:00');
        
        if (times.length === 0) times.push('08:00');
        processedLine = processedLine.replace(match3[0], ' ').trim();
      }
    }

    // If no hyphen frequency, extract word frequencies
    if (!matchedFreq) {
      if (/\b(twice\s*daily|twice\s*a\s*day|bid|b\.i\.d\.|2x)\b/i.test(processedLine)) {
        times = ['08:00', '20:00'];
        processedLine = processedLine.replace(/\b(twice\s*daily|twice\s*a\s*day|bid|b\.i\.d\.|2x)\b/i, ' ').trim();
      } else if (/\b(thrice\s*daily|three\s*times\s*a\s*day|tid|t\.i\.d\.|3x)\b/i.test(processedLine)) {
        times = ['08:00', '13:00', '20:00'];
        processedLine = processedLine.replace(/\b(thrice\s*daily|three\s*times\s*a\s*day|tid|t\.i\.d\.|3x)\b/i, ' ').trim();
      } else if (/\b(four\s*times\s*daily|four\s*times\s*a\s*day|qid|q\.i\.d\.|4x)\b/i.test(processedLine)) {
        times = ['08:00', '12:00', '16:00', '20:00'];
        processedLine = processedLine.replace(/\b(four\s*times\s*daily|four\s*times\s*a\s*day|qid|q\.i\.d\.|4x)\b/i, ' ').trim();
      } else if (/\b(weekly|once\s*a\s*week)\b/i.test(processedLine)) {
        frequency = 'weekly';
        times = ['08:00'];
        processedLine = processedLine.replace(/\b(weekly|once\s*a\s*week)\b/i, ' ').trim();
      } else if (/\b(alternate\s*day|every\s*2\s*days|qod)\b/i.test(processedLine)) {
        frequency = 'interval';
        times = ['08:00'];
        processedLine = processedLine.replace(/\b(alternate\s*day|every\s*2\s*days|qod)\b/i, ' ').trim();
      } else if (/\b(once\s*daily|once\s*a\s*day|daily|qd|q\.d\.|1x)\b/i.test(processedLine)) {
        times = ['08:00'];
        processedLine = processedLine.replace(/\b(once\s*daily|once\s*a\s*day|daily|qd|q\.d\.|1x)\b/i, ' ').trim();
      }
    }

    // 5. Clean up medicine name
    // Clean list numbers and indices at the beginning: e.g. "1. ", "2) ", "3- "
    processedLine = processedLine.replace(/^\s*\d+[\s.)\-]+/g, '').trim();

    // Clean common prefixes (Tab, Capsule, Take, etc.) at the start
    processedLine = processedLine.replace(/^(take|rx)\s+/i, '').trim();
    processedLine = processedLine.replace(/^(tab\b\.?|tablet\b\.?|capsule\b\.?|cap\b\.?|syr\b\.?|syrup\b\.?|inj\b\.?|injection\b\.?|ointment\b\.?|cream\b\.?|drop\b\.?|drops\b\.?)\s+/i, '').trim();

    // Clean special characters and keep only text/number, spaces, and hyphens/dots
    let cleanName = processedLine.replace(/[^a-zA-Z0-9\s.\-]/g, '').replace(/\s+/g, ' ').trim();

    // Strip trailing punctuation like dashes or dots
    cleanName = cleanName.replace(/[\s.\-]+$/g, '').trim();

    // Avoid empty names or single-letter names, and metadata remnants
    if (cleanName.length > 2 && !/^(prescription|patient|doctor|date|hospital|clinic|tablet|capsule|syrup|injection|dosage|mg|mcg|ml)$/i.test(cleanName)) {
      // Split by any remaining dash or stray words, ensure we capture the actual brand name nicely
      // If name is excessively long, truncate to first 3 words
      const parts = cleanName.split(' ');
      if (parts.length > 3) {
        cleanName = parts.slice(0, 3).join(' ');
      }

      // Title case name
      cleanName = cleanName.split(' ')
        .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
        .join(' ');

      medicines.push({
        name: cleanName,
        dosage: dosage,
        frequency: frequency,
        times: times,
        instructions: instructions
      });
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
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        const prompt = `
          You are a pharmaceutical prescription scanner. Your ONLY job is to identify and extract MEDICINE/DRUG names from prescription text.
          
          STRICT RULES:
          1. Extract ONLY pharmaceutical drugs, medicines, tablets, capsules, syrups, injections, ointments, creams, and drops.
          2. COMPLETELY IGNORE and DO NOT include: patient name, doctor name, hospital name, clinic name, dates, phone numbers, addresses, diagnosis, symptoms, medical tests, blood reports, lab values, vital signs, advice notes, follow-up instructions, or any non-medicine text.
          3. A valid medicine will typically have: a brand name (e.g. Paracetamol, Amoxicillin, Metformin, Azithromycin, Omeprazole, Lisinopril), dosage (mg, ml, mcg, g), and frequency indicators (1-0-1, twice daily, OD, BD, TDS, etc.).
          4. Common prescription keywords that CONFIRM something is a medicine: Tab., Cap., Syp., Inj., mg, ml, mcg, OD, BD, TDS, QID, SOS, PRN, 1-0-1, 1-1-1, 0-0-1, twice daily, once daily.
          5. If you are not sure whether something is a medicine or not, DO NOT include it.
          
          For each confirmed medicine, return a JSON object with these fields:
          - "name": Only the medicine/drug name (brand or generic). Remove prefixes like Tab., Cap., Syp., etc.
          - "dosage": The dosage string (e.g. "500 mg", "1 tablet", "10 ml"). Default to "1 pill" if unclear.
          - "frequency": Strictly one of: "daily", "weekly", "specific_days", "interval".
          - "times": Array of 24h formatted times ("HH:MM"). Map common patterns: OD/1x -> ["08:00"], BD/1-0-1/twice -> ["08:00", "20:00"], TDS/1-1-1/thrice -> ["08:00", "13:00", "20:00"], QID/4x -> ["08:00", "12:00", "16:00", "20:00"].
          - "instructions": One of "before food", "after food", "at bedtime", "with water", "with milk", or "Take as directed" if not specified.

          Return ONLY a valid raw JSON array. No markdown, no code blocks, no extra text. If no medicines found, return [].

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
      console.log('No Gemini API key configured. Utilizing local robust regex extraction rules.');
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
