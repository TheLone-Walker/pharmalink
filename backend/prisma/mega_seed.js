/**
 * PharmaLink Mega Seed Script (Schema-Accurate)
 * Seeds: 50 doctors, 50 patients, 50 delivery drivers, 10 pharmacists/pharmacies
 *        100 medications per pharmacy, appointments, prescriptions, orders
 *
 * Run: node prisma/mega_seed.js
 * Password for ALL accounts: password123
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

// ─── Helpers ──────────────────────────────────────────────────────────────────
function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function phone(i) { return `+2376${String(20000000 + i).slice(-8)}`; }
function futureDate(daysMin, daysMax) {
  const d = new Date();
  d.setDate(d.getDate() + randInt(daysMin, daysMax));
  d.setHours(pick([9, 10, 11, 14, 15, 16]), 0, 0, 0);
  return d;
}
function pastDate(daysMin, daysMax) {
  const d = new Date();
  d.setDate(d.getDate() - randInt(daysMin, daysMax));
  d.setHours(pick([9, 10, 11, 14, 15, 16]), 0, 0, 0);
  return d;
}

// ─── Data ─────────────────────────────────────────────────────────────────────
const SPECIALTIES = [
  'Cardiologist','Dermatologist','Pediatrician','Neurologist','Orthopedist',
  'Gynecologist','Ophthalmologist','Psychiatrist','Endocrinologist','Pulmonologist',
  'Gastroenterologist','Urologist','Rheumatologist','Oncologist','General Practitioner',
  'ENT Specialist','Nephrologist','Infectious Disease','Hematologist','Radiologist',
];

const DOCTOR_NAMES = [
  'Jean-Pierre Mbarga','Sophie Ngo Bilong','Alain Fotso','Grace Ngum','Eric Tagne',
  'Clara Abena','David Nji','Fatima Oumarou','Christian Mewoli','Angeline Biyong',
  'Paul Nkemdirim','Rose Akono','Samuel Beyala','Laure Ndoumbe','Henri Tita',
  'Madeleine Effa','Joseph Ngala','Yvonne Kouam','François Djoufack','Isabelle Meyo',
  'Thomas Ebede','Brigitte Nsom','Achille Foba','Rosalie Ngono','Maurice Tene',
  'Christine Mounjouopou','Patrick Njock','Solange Zambo','Victor Atangana','Chantal Mvondo',
  'Rodrigue Kenmogne','Anne-Marie Bikié','Blaise Kana','Josephine Wamba','Georges Tsafack',
  'Paulette Nnomo','Thierry Fonkou','Veronique Mbassi','Fernand Etoundi','Nathalie Mbah',
  'Lambert Owona','Genevieve Suh','Cyrille Abouem','Therese Ndongo','Sylvain Kamdem',
  'Marceline Nkoa','Edouard Bekolo','Albertine Fouda','Germain Tiako','Beatrice Onana',
];

const PATIENT_NAMES = [
  'Marie Nguema','Jean Tagne','Alice Bello','Robert Kamga','Esther Fonkou',
  'Michel Nkoa','Celine Mbarga','Pierre Abena','Josephine Bilong','Andre Meyo',
  'Cecile Mewoli','Francois Fouda','Therese Ngum','Emile Tita','Veronique Beyala',
  'Gustave Ndoumbe','Yvette Effa','Leonard Mvondo','Suzanne Atangana','Claude Mbah',
  'Delphine Ngono','Ernest Nji','Mathilde Kouam','Innocent Oumarou','Pascaline Biyong',
  'Aurelien Zambo','Dorothee Ebede','Simon Nsom','Felicite Ngala','Armand Foba',
  'Nathalie Tene','Bertrand Djoufack','Monique Akono','Hilaire Bekolo','Constance Kenmogne',
  'Patrice Wamba','Georgette Tsafack','Rene Njock','Adrienne Onana','Herve Etoundi',
  'Brigitte Owona','Victor Suh','Martine Mbassi','Ange Abouem','Serge Ndongo',
  'Colette Kamdem','Denis Tiako','Christine Fouda','Felix Kana','Honorine Bikié',
];

const DRIVER_NAMES = [
  'Pierre Mbarga','Joseph Tagne','Emmanuel Fonkou','Pascal Kamga','Sylvain Ngum',
  'Bruno Abena','Gilles Bilong','Remi Meyo','Didier Mewoli','Arnaud Fouda',
  'Cedric Ndoumbe','Tony Effa','Lionel Mvondo','Stephane Atangana','Kevin Mbah',
  'Roland Ngono','Faustin Nji','Gerard Kouam','Constant Oumarou','Albert Biyong',
  'Florent Zambo','Desire Ebede','Landry Nsom','Serge Ngala','Aubin Foba',
  'Blaise Tene','Calvin Djoufack','Daniel Akono','Edgard Bekolo','Firmin Kenmogne',
  'Gatien Wamba','Hermine Tsafack','Igor Njock','Junior Onana','Klaus Etoundi',
  'Leopold Owona','Marcel Suh','Nicolas Mbassi','Oscar Abouem','Philippe Ndongo',
  'Quentin Kamdem','Raymond Tiako','Stephane Fouda','Thierry Kana','Ulrich Bikié',
  'Valentin Bikam','William Ndoumou','Xavier Ondobo','Yannick Bwele','Zacharie Ebanga',
];

const PHARMACIST_NAMES = [
  'Marie Centrale','Jean Nations','Alice Lac','Robert Biyem','Esther Paix',
  'Michel Melen','Celine Bastos','Pierre Barbara','Josephine Stade','Andre Nouvelle',
  'Pauline Essos','Samuel Mokolo','Delphine Emana','Lucas Nlongkak','Blandine Kondengui',
  'Guy Simbock','Nadine Ahala','Boris Mvan','Solange Obobogo','Fabrice Tsinga',
  'Aline Madagscar','Gaston Messa','Clarisse Nsam','Hervé Odza','Leontine Biteng',
  'Albert Bonanjo','Carine Akwa','Serge Deido','Monique Bali','Yves Bonapriso',
  'Tatiana Makepe','Arnaud Logpom','Chantal Kotto','Emile Ndogpassi','Florence PK14',
  'Olivier Nylon','Gisèle Bépanda','Daniel New-Bell','Julienne Bonabéri','Marc Cité-Sic',
  'Brigitte Bafoussam','Rodrigue Dschang','Vanessa Bamenda','Patrick Kumba','Sandrine Limbe',
  'Alain Buea','Colette Garoua','Hamidou Maroua','Fadimatou Ngaoundere','Ibrahim Bertoua',
];

const PHARMACY_NAMES = [
  'Pharmacie Centrale','Pharmacie des Nations','Pharmacie du Lac','Pharmacie Biyem-Assi',
  'Pharmacie de la Paix','Pharmacie Melen','Pharmacie de Bastos','Pharmacie Santa Barbara',
  'Pharmacie du Stade','Pharmacie Nouvelle Génération','Pharmacie d\'Essos','Pharmacie du Marché Mokolo',
  'Pharmacie d\'Emana','Pharmacie de Nlongkak','Pharmacie de Kondengui','Pharmacie de Simbock',
  'Pharmacie de l\'Aéroport Ahala','Pharmacie de Mvan','Pharmacie d\'Obobogo','Pharmacie de Tsinga',
  'Pharmacie de Madagascar','Pharmacie de la Messa','Pharmacie de Nsam','Pharmacie d\'Odza',
  'Pharmacie de Biteng','Pharmacie de Bonanjo','Pharmacie de l\'Étoile Akwa','Pharmacie de Deido',
  'Pharmacie de Bali','Pharmacie de Bonapriso','Pharmacie des Palmiers Makepe','Pharmacie de Logpom',
  'Pharmacie de Kotto','Pharmacie de Ndogpassi','Pharmacie de l\'Espoir PK14','Pharmacie Populaire Nylon',
  'Pharmacie de Bépanda','Pharmacie du Soleil New-Bell','Pharmacie du Pont Bonabéri','Pharmacie de la Cité-Sic',
  'Pharmacie de l\'Ouest Bafoussam','Pharmacie Menoua Dschang','Pharmacie Highland Bamenda','Pharmacie Meme Kumba',
  'Pharmacie Océane Limbe','Pharmacie du Mont Fako Buea','Pharmacie de la Bénoué Garoua','Pharmacie du Sahel Maroua',
  'Pharmacie du Château Ngaoundéré','Pharmacie du Soleil Levant Bertoua',
];

const PHARMACY_ADDRESSES = [
  'Carrefour Warda, Yaoundé','Avenue Kennedy, Yaoundé','Quartier Lac, Yaoundé',
  'Biyem-Assi, Yaoundé','Marché Central, Yaoundé','Quartier Melen, Yaoundé',
  'Bastos, Yaoundé','Santa Barbara, Douala','Stade Omnisports, Yaoundé','Ngousso, Yaoundé',
  'Essos, Yaoundé','Marché Mokolo, Yaoundé','Emana, Yaoundé','Nlongkak, Yaoundé','Kondengui, Yaoundé',
  'Simbock, Yaoundé','Ahala, Yaoundé','Mvan, Yaoundé','Obobogo, Yaoundé','Tsinga, Yaoundé',
  'Madagascar, Yaoundé','Camp SIC Messa, Yaoundé','Nsam, Yaoundé','Odza, Yaoundé','Biteng, Yaoundé',
  'Bonanjo, Douala','Boulevard de la Liberté Akwa, Douala','Rue Deido, Douala','Bali, Douala','Bonapriso, Douala',
  'Makepe, Douala','Logpom, Douala','Kotto, Douala','Ndogpassi, Douala','PK14, Douala',
  'Nylon, Douala','Bépanda, Douala','New-Bell, Douala','Ancien Pont Bonabéri, Douala','Cité-Sic, Douala',
  'Centre-ville, Bafoussam','Avenue Principale, Dschang','Commercial Avenue, Bamenda','Main Market, Kumba',
  'Down Beach, Limbe','Molyko, Buea','Boulevard Lamido, Garoua','Carrefour Para, Maroua',
  'Grand Marché, Ngaoundéré','Avenue Royale, Bertoua',
];

const VEHICLE_TYPES = [
  'Motorcycle Honda CB500 - Red','Motorcycle Yamaha FZ - Blue','Motorcycle Suzuki - Black',
  'Motorcycle Bajaj - Green','Car Toyota Vitz - White','Car Hyundai i10 - Silver',
  'Bicycle - Yellow','Motorcycle TVS - Orange','Car Kia Picanto - Grey','Motorcycle Hero - Red',
];

// 100 medications across categories
const MEDICATIONS = [
  { name:'Amoxicillin 500mg', cat:'Antibiotics', price:500, stock:300, rx:false },
  { name:'Metformin 850mg', cat:'Diabetes', price:350, stock:250, rx:true },
  { name:'Amlodipine 5mg', cat:'Cardiovascular', price:600, stock:200, rx:true },
  { name:'Paracetamol 500mg', cat:'Analgesics', price:200, stock:500, rx:false },
  { name:'Ibuprofen 400mg', cat:'Anti-inflammatory', price:300, stock:400, rx:false },
  { name:'Omeprazole 20mg', cat:'Gastroenterology', price:450, stock:200, rx:false },
  { name:'Atorvastatin 20mg', cat:'Cardiovascular', price:750, stock:150, rx:true },
  { name:'Ciprofloxacin 500mg', cat:'Antibiotics', price:650, stock:180, rx:true },
  { name:'Losartan 50mg', cat:'Cardiovascular', price:700, stock:160, rx:true },
  { name:'Metronidazole 500mg', cat:'Antibiotics', price:400, stock:220, rx:false },
  { name:'Salbutamol Inhaler 100mcg', cat:'Respiratory', price:3500, stock:80, rx:false },
  { name:'Diclofenac 50mg', cat:'Anti-inflammatory', price:350, stock:280, rx:false },
  { name:'Chloroquine 250mg', cat:'Antimalarial', price:300, stock:350, rx:false },
  { name:'Artemether-Lumefantrine', cat:'Antimalarial', price:2500, stock:120, rx:false },
  { name:'Albendazole 400mg', cat:'Antiparasitic', price:800, stock:200, rx:false },
  { name:'Ferrous Sulfate 200mg', cat:'Hematology', price:250, stock:300, rx:false },
  { name:'Folic Acid 5mg', cat:'Vitamins', price:200, stock:400, rx:false },
  { name:'Zinc Sulfate 20mg', cat:'Vitamins', price:300, stock:350, rx:false },
  { name:'ORS Sachets', cat:'Electrolytes', price:150, stock:500, rx:false },
  { name:'Vitamin C 500mg', cat:'Vitamins', price:250, stock:450, rx:false },
  { name:'Doxycycline 100mg', cat:'Antibiotics', price:500, stock:200, rx:true },
  { name:'Azithromycin 500mg', cat:'Antibiotics', price:900, stock:150, rx:true },
  { name:'Cetirizine 10mg', cat:'Antihistamines', price:350, stock:300, rx:false },
  { name:'Loratadine 10mg', cat:'Antihistamines', price:300, stock:320, rx:false },
  { name:'Ranitidine 150mg', cat:'Gastroenterology', price:400, stock:250, rx:false },
  { name:'Fluconazole 150mg', cat:'Antifungals', price:1200, stock:100, rx:true },
  { name:'Nystatin Oral Drops', cat:'Antifungals', price:2000, stock:80, rx:false },
  { name:'Prednisolone 5mg', cat:'Corticosteroids', price:450, stock:200, rx:true },
  { name:'Hydrocortisone Cream 1%', cat:'Dermatology', price:1500, stock:120, rx:false },
  { name:'Betamethasone Cream 0.05%', cat:'Dermatology', price:1800, stock:100, rx:true },
  { name:'Gentamicin Eye Drops', cat:'Ophthalmology', price:1200, stock:90, rx:true },
  { name:'Timolol Eye Drops 0.5%', cat:'Ophthalmology', price:2500, stock:60, rx:true },
  { name:'Insulin Regular 100IU', cat:'Diabetes', price:8500, stock:50, rx:true },
  { name:'Glibenclamide 5mg', cat:'Diabetes', price:400, stock:200, rx:true },
  { name:'Simvastatin 20mg', cat:'Cardiovascular', price:600, stock:180, rx:true },
  { name:'Hydrochlorothiazide 25mg', cat:'Cardiovascular', price:350, stock:250, rx:true },
  { name:'Furosemide 40mg', cat:'Cardiovascular', price:300, stock:280, rx:true },
  { name:'Aspirin 100mg', cat:'Cardiovascular', price:200, stock:400, rx:false },
  { name:'Clopidogrel 75mg', cat:'Cardiovascular', price:900, stock:120, rx:true },
  { name:'Phenobarbitone 30mg', cat:'Neurology', price:300, stock:200, rx:true },
  { name:'Carbamazepine 200mg', cat:'Neurology', price:550, stock:150, rx:true },
  { name:'Valproic Acid 500mg', cat:'Neurology', price:800, stock:100, rx:true },
  { name:'Amitriptyline 25mg', cat:'Psychiatry', price:400, stock:180, rx:true },
  { name:'Chlorpromazine 100mg', cat:'Psychiatry', price:500, stock:150, rx:true },
  { name:'Haloperidol 5mg', cat:'Psychiatry', price:450, stock:160, rx:true },
  { name:'Tramadol 50mg', cat:'Analgesics', price:600, stock:200, rx:true },
  { name:'Naproxen 500mg', cat:'Anti-inflammatory', price:400, stock:250, rx:false },
  { name:'Mebendazole 500mg', cat:'Antiparasitic', price:700, stock:200, rx:false },
  { name:'Ivermectin 6mg', cat:'Antiparasitic', price:900, stock:150, rx:false },
  { name:'Erythromycin 250mg', cat:'Antibiotics', price:500, stock:200, rx:true },
  { name:'Cloxacillin 500mg', cat:'Antibiotics', price:600, stock:180, rx:true },
  { name:'Tetracycline 250mg', cat:'Antibiotics', price:400, stock:200, rx:true },
  { name:'Nitrofurantoin 100mg', cat:'Antibiotics', price:750, stock:160, rx:true },
  { name:'Trimethoprim+Sulfamethoxazole', cat:'Antibiotics', price:350, stock:250, rx:true },
  { name:'Aciclovir 200mg', cat:'Antivirals', price:900, stock:120, rx:true },
  { name:'Nevirapine 200mg', cat:'Antiretroviral', price:1500, stock:80, rx:true },
  { name:'Efavirenz 600mg', cat:'Antiretroviral', price:2000, stock:60, rx:true },
  { name:'Tenofovir 300mg', cat:'Antiretroviral', price:1800, stock:70, rx:true },
  { name:'Lamivudine 150mg', cat:'Antiretroviral', price:1200, stock:90, rx:true },
  { name:'Vitamin B Complex', cat:'Vitamins', price:300, stock:400, rx:false },
  { name:'Vitamin D3 5000IU', cat:'Vitamins', price:500, stock:300, rx:false },
  { name:'Calcium Carbonate 500mg', cat:'Vitamins', price:350, stock:350, rx:false },
  { name:'Omega-3 Fish Oil 1000mg', cat:'Supplements', price:800, stock:200, rx:false },
  { name:'Progestin 5mg', cat:'Gynecology', price:600, stock:150, rx:true },
  { name:'Clomiphene 50mg', cat:'Gynecology', price:1500, stock:80, rx:true },
  { name:'Oxytocin 10IU', cat:'Gynecology', price:2000, stock:50, rx:true },
  { name:'Misoprostol 200mcg', cat:'Gynecology', price:1200, stock:70, rx:true },
  { name:'Levodopa/Carbidopa 250/25mg', cat:'Neurology', price:1500, stock:80, rx:true },
  { name:'Allopurinol 300mg', cat:'Rheumatology', price:400, stock:200, rx:false },
  { name:'Colchicine 0.5mg', cat:'Rheumatology', price:600, stock:150, rx:true },
  { name:'Hydroxychloroquine 200mg', cat:'Rheumatology', price:800, stock:120, rx:true },
  { name:'Sulfasalazine 500mg', cat:'Rheumatology', price:700, stock:140, rx:true },
  { name:'Budesonide Inhaler 200mcg', cat:'Respiratory', price:5000, stock:60, rx:true },
  { name:'Montelukast 10mg', cat:'Respiratory', price:900, stock:120, rx:false },
  { name:'Theophylline 200mg', cat:'Respiratory', price:450, stock:180, rx:true },
  { name:'Domperidone 10mg', cat:'Gastroenterology', price:350, stock:250, rx:false },
  { name:'Metoclopramide 10mg', cat:'Gastroenterology', price:300, stock:280, rx:false },
  { name:'Loperamide 2mg', cat:'Gastroenterology', price:400, stock:220, rx:false },
  { name:'Lactulose Solution', cat:'Gastroenterology', price:2500, stock:60, rx:false },
  { name:'Pantoprazole 40mg', cat:'Gastroenterology', price:550, stock:200, rx:false },
  { name:'Esomeprazole 40mg', cat:'Gastroenterology', price:700, stock:180, rx:false },
  { name:'Sucralfate 1g', cat:'Gastroenterology', price:500, stock:160, rx:false },
  { name:'Spironolactone 25mg', cat:'Cardiovascular', price:550, stock:180, rx:true },
  { name:'Propranolol 40mg', cat:'Cardiovascular', price:350, stock:250, rx:true },
  { name:'Nifedipine 30mg', cat:'Cardiovascular', price:650, stock:160, rx:true },
  { name:'Verapamil 80mg', cat:'Cardiovascular', price:600, stock:150, rx:true },
  { name:'Digoxin 0.25mg', cat:'Cardiovascular', price:500, stock:140, rx:true },
  { name:'Warfarin 5mg', cat:'Anticoagulants', price:750, stock:100, rx:true },
  { name:'Morphine Sulfate 10mg', cat:'Analgesics', price:1200, stock:40, rx:true },
  { name:'Codeine Phosphate 30mg', cat:'Analgesics', price:800, stock:80, rx:true },
  { name:'ORS Powder Sachet', cat:'Electrolytes', price:200, stock:600, rx:false },
  { name:'Magnesium Hydroxide 400mg', cat:'Gastroenterology', price:350, stock:200, rx:false },
  { name:'Sennosides 15mg', cat:'Gastroenterology', price:250, stock:300, rx:false },
  { name:'Vitamin A 200000IU', cat:'Vitamins', price:400, stock:200, rx:false },
  { name:'Fluoride Mouth Rinse', cat:'Dental', price:1500, stock:100, rx:false },
  { name:'Chlorhexidine Mouthwash', cat:'Dental', price:1200, stock:120, rx:false },
  { name:'Piroxicam 20mg', cat:'Anti-inflammatory', price:450, stock:200, rx:false },
  { name:'Dexamethasone 4mg', cat:'Corticosteroids', price:550, stock:150, rx:true },
  { name:'Methylprednisolone 4mg', cat:'Corticosteroids', price:700, stock:120, rx:true },
  { name:'Betadine Antiseptic Solution 10% 125ml', cat:'Antiseptic', price:1800, stock:100, rx:false },
];

const DIAGNOSES = [
  'Malaria','Hypertension','Type 2 Diabetes','Upper Respiratory Infection',
  'Gastroenteritis','Arthritis','Asthma','UTI','Anemia','Skin Infection',
  'Typhoid Fever','Pneumonia','Peptic Ulcer','Epilepsy','Anxiety Disorder',
];

const APT_NOTES = [
  'Patient reports persistent headache for 3 days',
  'Routine checkup and blood pressure monitoring',
  'Follow-up for diabetes management',
  'Chest pain and shortness of breath',
  'Skin rash consultation',
  'Child fever and cough',
  'Back pain after lifting heavy objects',
  'Annual physical examination',
  'Migraine recurrence',
  'High blood sugar levels',
  'Medication review appointment',
  'Post-surgery follow-up',
  'Allergy reaction consultation',
  'Joint pain in both knees',
  'Stomach pain and nausea for 2 days',
];

const DELIVERY_ADDRESSES = [
  'Bastos, Yaoundé','Melen, Yaoundé','Ngousso, Yaoundé','Biyem-Assi, Yaoundé',
  'Essos, Yaoundé','Mokolo, Yaoundé','Omnisports, Yaoundé','Emana, Yaoundé',
  'Bonamoussadi, Douala','Akwa, Douala','Deido, Douala',
];

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n══════════════════════════════════════════════════════════');
  console.log('  PharmaLink Mega Seed');
  console.log('══════════════════════════════════════════════════════════\n');

  const hash = await bcrypt.hash('password123', 10);

  // 1. Seed 50 Doctors
  console.log('1/7 Seeding 50 doctors...');
  const doctorUsers = [];
  for (let i = 0; i < 50; i++) {
    const email = `doctor${i + 1}@pharmalink.cm`;
    try {
      const u = await prisma.user.upsert({
        where: { email },
        update: {},
        create: {
          name: DOCTOR_NAMES[i],
          email,
          phone: phone(1000 + i),
          passwordHash: hash,
          role: 'doctor',
          isVerified: true,
          isActive: true,
          doctorProfile: {
            create: {
              licenseNumber: `CMR-MED-${2010 + (i % 12)}-${String(10000 + i).padStart(5, '0')}`,
              specialty: SPECIALTIES[i % SPECIALTIES.length],
              approvalStatus: 'approved',
              bio: `${DOCTOR_NAMES[i].split(' ').pop()} specializes in ${SPECIALTIES[i % SPECIALTIES.length]} with ${5 + (i % 20)} years of experience. Graduated from FMBS Yaoundé.`,
            },
          },
        },
        include: { doctorProfile: true },
      });
      doctorUsers.push(u);
    } catch (e) { console.error(`  Skip doctor${i + 1}:`, e.message.substring(0, 80)); }
  }
  console.log(`  ✅ ${doctorUsers.length} doctors`);

  // 2. Seed 50 Pharmacists + Pharmacies
  console.log('2/7 Seeding 50 pharmacies...');
  const pharmacistUsers = [];
  for (let i = 0; i < 50; i++) {
    const email = `pharmacist${i + 1}@pharmalink.cm`;
    try {
      const u = await prisma.user.upsert({
        where: { email },
        update: {},
        create: {
          name: PHARMACIST_NAMES[i],
          email,
          phone: phone(2000 + i),
          passwordHash: hash,
          role: 'pharmacist',
          isVerified: true,
          isActive: true,
          pharmacistProfile: {
            create: {
              pharmacyName: PHARMACY_NAMES[i],
              licenseNumber: `CMR-PHARM-${2015 + (i % 8)}-${String(1000 + i).padStart(4, '0')}`,
              pharmacyAddress: PHARMACY_ADDRESSES[i],
              pharmacyCategory: pick(['general', 'specialized', 'hospital']),
              approvalStatus: 'approved',
              openingHours: '08:00 - 20:00',
              lat: 3.848 + (Math.random() * 0.1 - 0.05),
              lng: 11.502 + (Math.random() * 0.1 - 0.05),
            },
          },
        },
        include: { pharmacistProfile: true },
      });
      pharmacistUsers.push(u);
    } catch (e) { console.error(`  Skip pharmacist${i + 1}:`, e.message.substring(0, 80)); }
  }
  console.log(`  ✅ ${pharmacistUsers.length} pharmacies`);

  // 3. Seed 100 Medications (distributed across pharmacies)
  console.log('3/7 Seeding 100 medications...');
  const medRecords = [];
  for (let i = 0; i < MEDICATIONS.length; i++) {
    const m = MEDICATIONS[i];
    // Assign to a pharmacy (cycle through pharmacists)
    const pharmacist = pharmacistUsers[i % pharmacistUsers.length];
    if (!pharmacist?.pharmacistProfile?.id) continue;
    const medName = m.name + ` [${PHARMACY_NAMES[i % PHARMACY_NAMES.length]}]`;
    try {
      const med = await prisma.medication.create({
        data: {
          pharmacyId: pharmacist.pharmacistProfile.id,
          name: m.name,
          description: `${m.name} — ${m.cat}. Follow your doctor's instructions for dosage.`,
          priceFcfa: m.price,
          stockQuantity: m.stock,
          category: m.cat,
          requiresPrescription: m.rx,
        },
      });
      medRecords.push(med);
    } catch (e) { /* skip duplicate */ }
  }
  console.log(`  ✅ ${medRecords.length} medications`);

  // 4. Seed 50 Patients
  console.log('4/7 Seeding 50 patients...');
  const patientUsers = [];
  const bloodTypes = ['A+','A-','B+','B-','O+','O-','AB+','AB-'];
  for (let i = 0; i < 50; i++) {
    const email = `patient${i + 1}@pharmalink.cm`;
    const yr = 1955 + randInt(0, 55);
    const mo = String(randInt(1, 12)).padStart(2, '0');
    const dy = String(randInt(1, 28)).padStart(2, '0');
    try {
      const u = await prisma.user.upsert({
        where: { email },
        update: {},
        create: {
          name: PATIENT_NAMES[i],
          email,
          phone: phone(3000 + i),
          passwordHash: hash,
          role: 'patient',
          isVerified: true,
          isActive: true,
          patientProfile: {
            create: {
              dateOfBirth: new Date(`${yr}-${mo}-${dy}`),
              address: pick(DELIVERY_ADDRESSES),
              bloodType: pick(bloodTypes),
              allergies: pick(['None','Penicillin','Sulfa drugs','Aspirin','Latex','None','None']),
            },
          },
        },
        include: { patientProfile: true },
      });
      patientUsers.push(u);
    } catch (e) { console.error(`  Skip patient${i + 1}:`, e.message.substring(0, 80)); }
  }
  console.log(`  ✅ ${patientUsers.length} patients`);

  // 5. Seed 50 Delivery Drivers
  console.log('5/7 Seeding 50 delivery drivers...');
  const driverUsers = [];
  for (let i = 0; i < 50; i++) {
    const email = `driver${i + 1}@pharmalink.cm`;
    try {
      const u = await prisma.user.upsert({
        where: { email },
        update: {},
        create: {
          name: DRIVER_NAMES[i],
          email,
          phone: phone(4000 + i),
          passwordHash: hash,
          role: 'delivery_driver',
          isVerified: true,
          isActive: true,
          driverProfile: {
            create: {
              vehicleInfo: pick(VEHICLE_TYPES),
              approvalStatus: 'approved',
              isOnline: Math.random() > 0.4,
            },
          },
        },
        include: { driverProfile: true },
      });
      driverUsers.push(u);
    } catch (e) { console.error(`  Skip driver${i + 1}:`, e.message.substring(0, 80)); }
  }
  console.log(`  ✅ ${driverUsers.length} drivers`);

  // 6. Seed Appointments (2-4 per patient)
  console.log('6/7 Seeding appointments & prescriptions...');
  const aptStatuses = ['pending','confirmed','completed','completed','completed','cancelled'];
  let aptCount = 0, rxCount = 0, orderCount = 0;

  for (const patient of patientUsers) {
    const numApts = randInt(2, 4);
    for (let j = 0; j < numApts; j++) {
      const doctor = pick(doctorUsers);
      const isPast = Math.random() > 0.35;
      try {
        const apt = await prisma.appointment.create({
          data: {
            patientId: patient.id,
            doctorId: doctor.id,
            appointmentDate: isPast ? pastDate(1, 365) : futureDate(1, 90),
            type: pick(['in_person','telemedicine']),
            status: isPast ? pick(aptStatuses) : pick(['pending','confirmed']),
            notes: pick(APT_NOTES),
          },
        });
        aptCount++;

        // Create prescription for completed appointments
        if (apt.status === 'completed' && medRecords.length > 0) {
          const numItems = randInt(1, 4);
          await prisma.prescription.create({
            data: {
              doctorId: doctor.id,
              patientId: patient.id,
              notes: `Prescribed for ${pick(DIAGNOSES)}. Take as directed.`,
              status: pick(['issued','sent_to_pharmacy','fulfilled']),
              items: {
                create: Array.from({ length: numItems }, () => ({
                  medicationName: pick(MEDICATIONS).name,
                  dosage: pick(['1 tablet twice daily','2 tablets once daily','1 capsule three times daily','1 tablet at bedtime']),
                  instructions: pick(['Take with food','Take on empty stomach','Avoid alcohol','Take with water']),
                  durationDays: pick([7, 14, 21, 30, 90]),
                })),
              },
            },
          });
          rxCount++;
        }
      } catch (_) {}
    }

    // 7. Seed Orders (1-4 per patient)
    const numOrders = randInt(1, 4);
    for (let k = 0; k < numOrders; k++) {
      const pharmacist = pick(pharmacistUsers);
      if (!pharmacist?.pharmacistProfile?.id) continue;

      // Pick meds from this pharmacy
      const pharmacyMeds = medRecords.filter(m => m.pharmacyId === pharmacist.pharmacistProfile.id);
      if (pharmacyMeds.length === 0) continue;

      const status = pick(['pending','confirmed','preparing','out_for_delivery','delivered','delivered']);
      const driver = pick(driverUsers.filter(d => d.driverProfile));
      const items = Array.from({ length: randInt(1, 4) }, () => {
        const med = pick(pharmacyMeds);
        const qty = randInt(1, 10);
        return { medicationId: med.id, quantity: qty, unitPriceFcfa: med.priceFcfa };
      });
      const totalFcfa = items.reduce((s, it) => s + Number(it.unitPriceFcfa) * it.quantity, 0);

      try {
        await prisma.order.create({
          data: {
            patientId: patient.id,
            pharmacyId: pharmacist.pharmacistProfile.id,
            driverProfileId: ['out_for_delivery','delivered'].includes(status) && driver?.driverProfile
              ? driver.driverProfile.id : null,
            status,
            orderType: pick(['delivery','pickup']),
            totalFcfa,
            deliveryAddress: pick(DELIVERY_ADDRESSES),
            items: {
              create: items.map(it => ({
                medicationId: it.medicationId,
                quantity: it.quantity,
                unitPriceFcfa: it.unitPriceFcfa,
              })),
            },
          },
        });
        orderCount++;
      } catch (_) {}
    }
  }

  // Summary
  console.log('\n══════════════════════════════════════════════════════════');
  console.log('  ✅ Mega Seed Complete!');
  console.log('══════════════════════════════════════════════════════════');
  console.log(`  Doctors:       ${doctorUsers.length}`);
  console.log(`  Pharmacies:    ${pharmacistUsers.length}`);
  console.log(`  Patients:      ${patientUsers.length}`);
  console.log(`  Drivers:       ${driverUsers.length}`);
  console.log(`  Medications:   ${medRecords.length}`);
  console.log(`  Appointments:  ${aptCount}`);
  console.log(`  Prescriptions: ${rxCount}`);
  console.log(`  Orders:        ${orderCount}`);
  console.log('\nLogin Credentials (password for all: password123)');
  console.log('  Doctors:    doctor1@pharmalink.cm  — doctor50@pharmalink.cm');
  console.log('  Patients:   patient1@pharmalink.cm — patient50@pharmalink.cm');
  console.log('  Drivers:    driver1@pharmalink.cm  — driver50@pharmalink.cm');
  console.log('  Pharmacies: pharmacist1@pharmalink.cm — pharmacist50@pharmalink.cm');
  console.log('  Admin:      admin@pharmalink.cm\n');
}

main()
  .catch(e => { console.error('\n❌ Error:', e.message); process.exit(1); })
  .finally(() => prisma.$disconnect());
