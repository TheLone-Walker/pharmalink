const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const coreMedications = [
  {
    name: 'Paracetamol 500mg',
    description: 'Analgesic and antipyretic for pain and fever relief.',
    priceFcfa: 500,
    category: 'Pain Relief & Fever',
    requiresPrescription: false,
  },
  {
    name: 'Paracetamol 1000mg',
    description: 'High-strength paracetamol for effective pain management.',
    priceFcfa: 1000,
    category: 'Pain Relief & Fever',
    requiresPrescription: false,
  },
  {
    name: 'Amoxicillin 500mg',
    description: 'Broad-spectrum penicillin antibiotic for bacterial infections.',
    priceFcfa: 1500,
    category: 'Antibiotics',
    requiresPrescription: true,
  },
  {
    name: 'Amoxicillin-Clavulanic Acid 1g (Augmentin)',
    description: 'Potent antibiotic combination for resistant respiratory and soft tissue infections.',
    priceFcfa: 4500,
    category: 'Antibiotics',
    requiresPrescription: true,
  },
  {
    name: 'Ibuprofen 400mg',
    description: 'Non-steroidal anti-inflammatory drug (NSAID) for inflammatory pain and headache.',
    priceFcfa: 800,
    category: 'Anti-inflammatory',
    requiresPrescription: false,
  },
  {
    name: 'Ciprofloxacin 500mg',
    description: 'Fluoroquinolone antibiotic for urinary tract and gastrointestinal infections.',
    priceFcfa: 2000,
    category: 'Antibiotics',
    requiresPrescription: true,
  },
  {
    name: 'Omeprazole 20mg',
    description: 'Proton pump inhibitor for gastric acidity, GERD, and peptic ulcers.',
    priceFcfa: 1800,
    category: 'Gastric & Ulcer',
    requiresPrescription: false,
  },
  {
    name: 'Cetirizine 10mg',
    description: 'Non-drowsy antihistamine for allergic rhinitis and itching.',
    priceFcfa: 1200,
    category: 'Allergy & Antihistamine',
    requiresPrescription: false,
  },
  {
    name: 'Metformin 500mg',
    description: 'First-line oral anti-diabetic medication for Type 2 diabetes.',
    priceFcfa: 1500,
    category: 'Diabetes',
    requiresPrescription: true,
  },
  {
    name: 'Amlodipine 5mg',
    description: 'Calcium channel blocker for hypertension and cardiovascular care.',
    priceFcfa: 2200,
    category: 'Cardiovascular',
    requiresPrescription: true,
  },
];

async function main() {
  const pharmacies = await prisma.pharmacistProfile.findMany();
  console.log(`Ensuring core medications exist across all ${pharmacies.length} pharmacies...`);

  let added = 0;
  for (const ph of pharmacies) {
    for (const med of coreMedications) {
      const exists = await prisma.medication.findFirst({
        where: {
          pharmacyId: ph.id,
          name: { contains: med.name.split(' ')[0], mode: 'insensitive' },
        },
      });

      if (!exists) {
        const priceVar = Math.floor(Math.random() * 200) - 100;
        const price = Math.max(300, med.priceFcfa + priceVar);
        const stock = Math.floor(Math.random() * 60) + 20;

        await prisma.medication.create({
          data: {
            pharmacyId: ph.id,
            name: med.name,
            description: med.description,
            priceFcfa: price,
            stockQuantity: stock,
            category: med.category,
            requiresPrescription: med.requiresPrescription,
          },
        });
        added++;
      }
    }
  }

  console.log(`Added ${added} core prescription medications across pharmacies!`);
}

main().catch(console.error).finally(() => prisma.$disconnect());
