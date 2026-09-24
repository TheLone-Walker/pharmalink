require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const HOSPITALS = [
  'Yaoundé Central Hospital',
  'Yaoundé General Hospital',
  'CHUY (Teaching Hospital Yaoundé)',
  'Douala General Hospital',
  'Laquintinie Hospital Douala',
  'Bastos Medical Center',
  'Military Hospital Yaoundé',
  'Jamot Hospital Yaoundé',
  'Biyem-Assi District Hospital',
  'Cité Verte District Hospital',
  'Regional Hospital Bafoussam',
  'Regional Hospital Bamenda',
  'Buea Regional Hospital',
  'Limbe Regional Hospital',
  'Garoua General Hospital',
];

async function main() {
  const doctors = await prisma.doctorProfile.findMany();
  console.log(`Assigning hospitals to ${doctors.length} doctors...`);
  for (let i = 0; i < doctors.length; i++) {
    const hospital = HOSPITALS[i % HOSPITALS.length];
    await prisma.doctorProfile.update({
      where: { id: doctors[i].id },
      data: { hospital },
    });
  }
  console.log('✅ Successfully assigned hospitals to all doctors!');
}

main()
  .catch(e => { console.error('Error:', e); process.exit(1); })
  .finally(() => prisma.$disconnect());
