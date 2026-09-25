const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database with comprehensive directory...');

  const hash = await bcrypt.hash('password123', 12);

  // 1. Admin
  await prisma.user.upsert({
    where: { email: 'admin@pharmalink.cm' },
    update: {},
    create: {
      name: 'PharmaLink Admin',
      email: 'admin@pharmalink.cm',
      phone: '+237600000001',
      passwordHash: hash,
      role: 'admin',
      isVerified: true,
      isActive: true,
    },
  });

  // 2. Doctors
  const doctorsData = [
    {
      name: 'Dr. Amadou',
      email: 'amadou@pharmalink.cm',
      phone: '+237600000002',
      licenseNumber: 'DOC-2024-001',
      specialty: 'General Medicine',
      hospital: 'Hôpital Central de Yaoundé',
      bio: 'Chief GP & Emergency Medical Officer with 12 years experience at Hôpital Central.',
    },
    {
      name: 'Dr. Marie Ngo',
      email: 'mariengo@pharmalink.cm',
      phone: '+237600000012',
      licenseNumber: 'DOC-2024-002',
      specialty: 'Cardiology',
      hospital: 'CHU Yaoundé & Clinique Bastos',
      bio: 'Senior Consultant Cardiologist specializing in hypertension and cardiovascular diseases.',
    },
    {
      name: 'Dr. Pierre Kamdem',
      email: 'kamdem@pharmalink.cm',
      phone: '+237600000013',
      licenseNumber: 'DOC-2024-003',
      specialty: 'Pediatrics',
      hospital: 'Hôpital Général de Yaoundé',
      bio: 'Consultant Pediatrician with extensive focus on child infectious diseases and neonatology.',
    },
    {
      name: 'Dr. Estelle Fotso',
      email: 'fotso@pharmalink.cm',
      phone: '+237600000014',
      licenseNumber: 'DOC-2024-004',
      specialty: 'Dermatology',
      hospital: 'Hôpital Laquintinie de Douala',
      bio: 'Dermatologist expert in tropical skin conditions and allergic reactions.',
    },
    {
      name: 'Dr. Joseph Ebanda',
      email: 'ebanda@pharmalink.cm',
      phone: '+237600000015',
      licenseNumber: 'DOC-2024-005',
      specialty: 'Gynecology & Obstetrics',
      hospital: 'Hôpital Central de Yaoundé',
      bio: 'OB/GYN specialist and maternity on-call emergency surgeon.',
    },
  ];

  for (const doc of doctorsData) {
    const user = await prisma.user.upsert({
      where: { email: doc.email },
      update: { name: doc.name, isActive: true },
      create: {
        name: doc.name,
        email: doc.email,
        phone: doc.phone,
        passwordHash: hash,
        role: 'doctor',
        isVerified: true,
        isActive: true,
      },
    });

    await prisma.doctorProfile.upsert({
      where: { userId: user.id },
      update: {
        specialty: doc.specialty,
        hospital: doc.hospital,
        approvalStatus: 'approved',
        isOnmcVerified: true,
        bio: doc.bio,
      },
      create: {
        userId: user.id,
        licenseNumber: doc.licenseNumber,
        specialty: doc.specialty,
        hospital: doc.hospital,
        approvalStatus: 'approved',
        isOnmcVerified: true,
        bio: doc.bio,
      },
    });
  }

  // 3. Pharmacies
  const pharmaciesData = [
    {
      name: 'Pharmacie Centrale',
      email: 'pharmacie@centrale.cm',
      phone: '+237600000003',
      address: 'Avenue Kennedy, Bastos, Yaoundé',
      category: 'General Pharmacy',
      hours: '8:00 AM - 10:00 PM',
      lat: 3.8802,
      lng: 11.5165,
    },
    {
      name: 'Pharmacie Bastos',
      email: 'bastos@pharmalink.cm',
      phone: '+237670001122',
      address: 'Rond-point Bastos, Yaoundé',
      category: '24/7 Night Guard Pharmacy',
      hours: '24h/24 Open (Garde de Nuit)',
      lat: 3.8850,
      lng: 11.5180,
    },
    {
      name: 'Pharmacie du Soleil',
      email: 'soleil@pharmalink.cm',
      phone: '+237677334455',
      address: 'Centre-ville, Yaoundé',
      category: 'General Pharmacy',
      hours: '8:00 AM - 9:00 PM',
      lat: 3.8650,
      lng: 11.5200,
    },
    {
      name: 'Pharmacie de la Gare',
      email: 'gare@pharmalink.cm',
      phone: '+237690112233',
      address: 'Avenue de la Gare, Yaoundé',
      category: '24/7 Night Guard Pharmacy',
      hours: '24h/24 Open (Garde de Nuit)',
      lat: 3.8710,
      lng: 11.5250,
    },
  ];

  const standardMeds = [
    { name: 'Paracetamol 500mg', basePrice: 1200, category: 'Pain Relief', rx: false },
    { name: 'Paracetamol 1g', basePrice: 1800, category: 'Pain Relief', rx: false },
    { name: 'Coartem (Artemether-Lumefantrine)', basePrice: 2200, category: 'Antimalarial', rx: false },
    { name: 'Ibuprofen 400mg', basePrice: 1400, category: 'Pain Relief & Inflammation', rx: false },
    { name: 'Amoxicillin 500mg', basePrice: 2500, category: 'Antibiotics', rx: true },
    { name: 'Augmentin 1g (Amoxicillin/Clavulanate)', basePrice: 4500, category: 'Antibiotics', rx: true },
    { name: 'Metformin 500mg', basePrice: 1100, category: 'Diabetes', rx: true },
    { name: 'Lisinopril 10mg', basePrice: 1600, category: 'Hypertension', rx: true },
  ];

  let pIndex = 0;
  for (const pharm of pharmaciesData) {
    pIndex++;
    const user = await prisma.user.upsert({
      where: { email: pharm.email },
      update: { name: pharm.name, isActive: true },
      create: {
        name: pharm.name,
        email: pharm.email,
        phone: pharm.phone,
        passwordHash: hash,
        role: 'pharmacist',
        isVerified: true,
        isActive: true,
      },
    });

    const pharmProfile = await prisma.pharmacistProfile.upsert({
      where: { userId: user.id },
      update: {
        pharmacyName: pharm.name,
        pharmacyAddress: pharm.address,
        pharmacyCategory: pharm.category,
        openingHours: pharm.hours,
        approvalStatus: 'approved',
        isOnpcVerified: true,
      },
      create: {
        userId: user.id,
        pharmacyName: pharm.name,
        pharmacyAddress: pharm.address,
        pharmacyCategory: pharm.category,
        openingHours: pharm.hours,
        approvalStatus: 'approved',
        isOnpcVerified: true,
        lat: pharm.lat,
        lng: pharm.lng,
      },
    });

    // Seed medications for each pharmacy with slight price variance
    for (const med of standardMeds) {
      const priceVariation = (pIndex - 1) * 150;
      const medPrice = med.basePrice + priceVariation;
      const medId = `seed-${pharmProfile.id.slice(0, 6)}-${med.name.replace(/[^a-zA-Z0-9]/g, '-').toLowerCase()}`;

      await prisma.medication.upsert({
        where: { id: medId },
        update: {
          priceFcfa: medPrice,
          stockQuantity: 40 + pIndex * 5,
          requiresPrescription: med.rx,
        },
        create: {
          id: medId,
          pharmacyId: pharmProfile.id,
          name: med.name,
          category: med.category,
          priceFcfa: medPrice,
          stockQuantity: 40 + pIndex * 5,
          requiresPrescription: med.rx,
          description: `Standard Cameroon pharmaceutical formulation. ${med.rx ? 'Prescription required for purchase.' : 'Over-the-counter medication.'}`,
        },
      }).catch(() => {});
    }
  }

  // 4. Patient
  await prisma.user.upsert({
    where: { email: 'marie@patient.cm' },
    update: {},
    create: {
      name: 'Marie Nguema',
      email: 'marie@patient.cm',
      phone: '+237600000004',
      passwordHash: hash,
      role: 'patient',
      isVerified: true,
      isActive: true,
      patientProfile: {
        create: {
          address: 'Quartier Bastos, Yaoundé',
          bloodType: 'A+',
          allergies: 'None known',
        },
      },
    },
  });

  // 5. Driver
  await prisma.user.upsert({
    where: { email: 'pierre@driver.cm' },
    update: {},
    create: {
      name: 'Pierre Mbarga',
      email: 'pierre@driver.cm',
      phone: '+237600000005',
      passwordHash: hash,
      role: 'delivery_driver',
      isVerified: true,
      isActive: true,
      driverProfile: {
        create: {
          vehicleInfo: 'Motorbike CG 125 - CE 7843 A',
          approvalStatus: 'approved',
          isOnline: true,
          currentLat: 3.848,
          currentLng: 11.502,
        },
      },
    },
  });

  console.log('✅ Comprehensive Seed complete!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
