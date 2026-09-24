const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const DRUG_SYNONYMS = {
  coartem: ['artemether', 'lumefantrine'],
  augmentin: ['amoxicillin', 'clavulanate', 'clavulanic'],
  flagyl: ['metronidazole'],
  panadol: ['paracetamol', 'acetaminophen'],
  doliprane: ['paracetamol'],
  efferalgan: ['paracetamol'],
  voltaren: ['diclofenac'],
  zantac: ['ranitidine'],
  losec: ['omeprazole'],
  glucophage: ['metformin'],
  norvasc: ['amlodipine'],
  zithromax: ['azithromycin'],
  cipro: ['ciprofloxacin'],
};

function extractDrugKeywords(name) {
  if (!name) return [];
  const clean = name
    .toLowerCase()
    .replace(/\b\d+(\.\d+)?\s*(mg|g|ml|mcg|iu|%|cpm|bpm|tab|tabs|tablet|tablets|capsule|capsules|syrup|drop|drops|injection|ampoule|powder|cream|ointment|gel|inhaler)\b/gi, ' ')
    .replace(/\b\d+\b/g, ' ')
    .replace(/[^a-z\s]/gi, ' ')
    .trim();

  const words = clean.split(/\s+/).filter(w => w.length >= 3 && !['and', 'for', 'with', 'the', 'oral', 'forte'].includes(w));
  
  const expanded = new Set(words);
  for (const w of words) {
    if (DRUG_SYNONYMS[w]) {
      for (const syn of DRUG_SYNONYMS[w]) {
        expanded.add(syn);
      }
    }
  }

  return Array.from(expanded);
}

function isDrugMatch(prescribedName, inventoryName) {
  if (!prescribedName || !inventoryName) return false;
  const normPrescribed = prescribedName.toLowerCase().trim();
  const normInv = inventoryName.toLowerCase().trim();

  if (normInv.includes(normPrescribed) || normPrescribed.includes(normInv)) return true;

  const reqKeywords = extractDrugKeywords(prescribedName);
  const invKeywords = extractDrugKeywords(inventoryName);

  if (reqKeywords.length === 0 || invKeywords.length === 0) return false;
  return reqKeywords.some(rk => invKeywords.some(ik => ik.includes(rk) || rk.includes(ik)));
}

async function test() {
  const allMeds = await prisma.medication.findMany({ select: { id: true, name: true, pharmacyId: true } });
  
  const testDrugs = [
    'Artemether 80mg',
    'Artemether-Lumefantrine 20/120mg (Coartem)',
    'Coartem (Artemether/Lumefantrine 80/480mg)',
    'Paracetamol 500mg',
    'Amoxicillin 500mg',
    'Ciprofloxacin 500mg',
    'Metformin 850mg',
  ];

  for (const d of testDrugs) {
    const matches = allMeds.filter(m => isDrugMatch(d, m.name));
    const uniquePharmacies = new Set(matches.map(m => m.pharmacyId));
    console.log(`\nTesting "${d}":`);
    console.log(`  -> Matched ${matches.length} inventory items across ${uniquePharmacies.size} pharmacies.`);
    console.log(`  -> Sample matches: ${matches.slice(0, 3).map(m => m.name).join(' | ')}`);
  }
}

test().catch(console.error).finally(() => prisma.$disconnect());
