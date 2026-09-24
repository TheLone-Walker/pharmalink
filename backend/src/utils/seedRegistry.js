const prisma = require('../config/db');

const initialDoctors = [
  {
    licenseNumber: 'ONMC/2023/8492',
    fullName: 'Dr. Marie Nguema',
    specialty: 'Cardiology',
    hospital: 'Hôpital Central de Yaoundé',
    region: 'Centre (Yaoundé)',
    registeredYear: 2023,
    status: 'active',
  },
  {
    licenseNumber: 'ONMC/2021/5120',
    fullName: 'Dr. Paul Biya Essomba',
    specialty: 'General Practitioner',
    hospital: 'Centre Hospitalier Universitaire (CHU) Yaoundé',
    region: 'Centre (Yaoundé)',
    registeredYear: 2021,
    status: 'active',
  },
  {
    licenseNumber: 'ONMC/2020/3891',
    fullName: 'Dr. Jeanne Manga',
    specialty: 'Pediatrics',
    hospital: 'Fondation Chantal Biya, Yaoundé',
    region: 'Centre (Yaoundé)',
    registeredYear: 2020,
    status: 'active',
  },
  {
    licenseNumber: 'ONMC/2019/1204',
    fullName: 'Dr. Alain Fofana',
    specialty: 'Dermatology',
    hospital: 'Hôpital Général de Yaoundé',
    region: 'Centre (Yaoundé)',
    registeredYear: 2019,
    status: 'active',
  },
  {
    licenseNumber: 'ONMC/2022/6740',
    fullName: 'Dr. Samuel Eto\'o Mbida',
    specialty: 'Internal Medicine',
    hospital: 'Clinique Bastos, Yaoundé',
    region: 'Centre (Yaoundé)',
    registeredYear: 2022,
    status: 'active',
  },
  {
    licenseNumber: 'ONMC/2024/9021',
    fullName: 'Dr. Walker Jr',
    specialty: 'General Medicine & Surgery',
    hospital: 'Hôpital Central de Yaoundé',
    region: 'Centre (Yaoundé)',
    registeredYear: 2024,
    status: 'active',
  },
];

const initialPharmacies = [
  {
    licenseNumber: 'ONPC/PHARM/2022/104',
    pharmacyName: 'Pharmacie du Centre',
    titularPharmacist: 'Dr. Pharm. Estelle Ndom',
    address: 'Rue Joseph Essono Balla, Bastos, Yaoundé',
    category: 'Officine',
    region: 'Centre (Yaoundé)',
    authorizedYear: 2022,
    status: 'active',
  },
  {
    licenseNumber: 'ONPC/PHARM/2020/088',
    pharmacyName: 'Pharmacie du Soleil',
    titularPharmacist: 'Dr. Pharm. Christian Mballa',
    address: 'Carrefour Mvan, Yaoundé',
    category: 'Officine',
    region: 'Centre (Yaoundé)',
    authorizedYear: 2020,
    status: 'active',
  },
  {
    licenseNumber: 'ONPC/PHARM/2018/045',
    pharmacyName: 'Pharmacie de l\'Avenue',
    titularPharmacist: 'Dr. Pharm. Patrick Ndongo',
    address: 'Avenue Kennedy, Centre-Ville, Yaoundé',
    category: 'Officine',
    region: 'Centre (Yaoundé)',
    authorizedYear: 2018,
    status: 'active',
  },
  {
    licenseNumber: 'ONPC/PHARM/2023/162',
    pharmacyName: 'Pharmacie Bastos Santé',
    titularPharmacist: 'Dr. Pharm. Sandrine Abena',
    address: 'Boulevard de l\'URSS, Bastos, Yaoundé',
    category: 'Officine',
    region: 'Centre (Yaoundé)',
    authorizedYear: 2023,
    status: 'active',
  },
  {
    licenseNumber: 'ONPC/PHARM/2021/095',
    pharmacyName: 'Pharmacie de Melen',
    titularPharmacist: 'Dr. Pharm. Yves Kamga',
    address: 'Carrefour Emia, Melen, Yaoundé',
    category: 'Officine',
    region: 'Centre (Yaoundé)',
    authorizedYear: 2021,
    status: 'active',
  },
];

async function seedRegistry() {
  try {
    for (const doc of initialDoctors) {
      await prisma.onmcRegistry.upsert({
        where: { licenseNumber: doc.licenseNumber },
        create: doc,
        update: doc,
      });
    }

    for (const pharm of initialPharmacies) {
      await prisma.onpcRegistry.upsert({
        where: { licenseNumber: pharm.licenseNumber },
        create: pharm,
        update: pharm,
      });
    }
  } catch (err) {
    console.error('Error seeding official registries:', err.message);
  }
}

module.exports = { seedRegistry };
