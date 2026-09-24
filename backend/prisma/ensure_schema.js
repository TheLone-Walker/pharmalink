require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "public"."doctor_blocked_times" (
      "id" TEXT NOT NULL PRIMARY KEY,
      "doctor_profile_id" TEXT NOT NULL REFERENCES "public"."doctor_profiles"("id") ON DELETE CASCADE,
      "start_date" TIMESTAMP(3) NOT NULL,
      "end_date" TIMESTAMP(3) NOT NULL,
      "reason" TEXT,
      "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);
  console.log('✅ doctor_blocked_times table ensured!');
}

main()
  .catch(e => { console.error('Error:', e); process.exit(1); })
  .finally(() => prisma.$disconnect());
