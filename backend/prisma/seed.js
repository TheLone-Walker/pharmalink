const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  const hash = await bcrypt.hash('password123', 12);

  // Admin
  const admin = await prisma.user.upsert({
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

  // Doctor
  const doctor = await prisma.user.upsert({
    where: { email: 'amadou@pharmalink.cm' },
    update: {},
    create: {
      name: 'Dr. Amadou',
      email: 'amadou@pharmalink.cm',
      phone: '+237600000002',
      passwordHash: hash,
      role: 'doctor',
      isVerified: true,
      isActive: true,
      doctorProfile: {
        create: {
          licenseNumber: 'DOC-2024-001',
          specialty: 'General Practitioner',
          approvalStatus: 'approved',
          bio: 'Experienced GP with 10 years of practice in Yaoundé.',
        },
      },
    },
  });

  // Pharmacist
  const pharmacist = await prisma.user.upsert({
    where: { email: 'pharmacie@centrale.cm' },
    update: {},
    create: {
      name: 'Marie Centrale',
      email: 'pharmacie@centrale.cm',
      phone: '+237600000003',
      passwordHash: hash,
      role: 'pharmacist',
      isVerified: true,
      isActive: true,
      pharmacistProfile: {
        create: {
          pharmacyName: 'Pharmacie Centrale',
          licenseNumber: 'PH-2024-001',
          pharmacyAddress: 'Avenue Kennedy, Bastos, Yaoundé',
          pharmacyCategory: 'General',
          approvalStatus: 'approved',
          openingHours: '8:00 AM - 8:00 PM',
          lat: 3.8802,
          lng: 11.5165,
        },
      },
    },
    include: { pharmacistProfile: true },
  });

  // Seed medications
  if (pharmacist.pharmacistProfile) {
    const meds = [
      { name: 'Paracetamol 500mg', priceFcfa: 1200, stockQuantity: 50, category: 'Pain Relief' },
      { name: 'Paracetamol 1g', priceFcfa: 1800, stockQuantity: 30, category: 'Pain Relief' },
      { name: 'Amoxicillin 500mg', priceFcfa: 2500, stockQuantity: 40, category: 'Antibiotics' },
      { name: 'Ibuprofen 400mg', priceFcfa: 1400, stockQuantity: 35, category: 'Pain Relief' },
      { name: 'Metformin 500mg', priceFcfa: 1100, stockQuantity: 25, category: 'Diabetes' },
      { name: 'Lisinopril 10mg', priceFcfa: 1600, stockQuantity: 20, category: 'Hypertension' },
    ];

    for (const med of meds) {
      await prisma.medication.upsert({
        where: { id: `seed-${med.name.replace(/\s/g, '-').toLowerCase()}` },
        update: {},
        create: {
          id: `seed-${med.name.replace(/\s/g, '-').toLowerCase()}`,
          pharmacyId: pharmacist.pharmacistProfile.id,
          ...med,
          priceFcfa: med.priceFcfa,
          requiresPrescription: ['Amoxicillin 500mg', 'Metformin 500mg', 'Lisinopril 10mg'].includes(med.name),
        },
      }).catch(() => {}); // Skip if exists
    }
  }

  // Patient
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

  // Driver
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

  console.log('✅ Seed complete!');
  console.log('Test accounts (all use password: password123):');
  console.log('  Admin:      admin@pharmalink.cm');
  console.log('  Doctor:     amadou@pharmalink.cm');
  console.log('  Pharmacist: pharmacie@centrale.cm');
  console.log('  Patient:    marie@patient.cm');
  console.log('  Driver:     pierre@driver.cm');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
