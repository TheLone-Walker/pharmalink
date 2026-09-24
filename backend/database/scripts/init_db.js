/**
 * PharmaLink Database Initializer
 * Runs schema + seed using raw pg (no psql CLI needed)
 * Usage: node database/scripts/init_db.js
 *        node database/scripts/init_db.js --seed-only
 *        node database/scripts/init_db.js --reset
 */

require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

const args = process.argv.slice(2);
const SEED_ONLY = args.includes('--seed-only');
const RESET = args.includes('--reset');

// Parse DATABASE_URL
const DATABASE_URL = process.env.DATABASE_URL ||
  'postgresql://postgres:password@localhost:5432/pharmalink';

const url = new URL(DATABASE_URL);
const DB_NAME = url.pathname.replace('/', '');

// Connect to postgres (without specific db) to create it
const adminClient = new Client({
  host: url.hostname,
  port: parseInt(url.port) || 5432,
  user: url.username,
  password: url.password,
  database: 'postgres',
});

// Connect to pharmalink db
const dbClient = new Client({ connectionString: DATABASE_URL });

async function run() {
  console.log('\n══════════════════════════════════════════');
  console.log('  PharmaLink Database Initializer');
  console.log('══════════════════════════════════════════');
  console.log(`  Database: ${DB_NAME}`);
  console.log(`  Host:     ${url.hostname}:${url.port || 5432}`);
  console.log('══════════════════════════════════════════\n');

  try {
    await adminClient.connect();

    if (RESET) {
      console.log('⚠️  Resetting — dropping existing database...');
      await adminClient.query(`DROP DATABASE IF EXISTS ${DB_NAME}`);
      console.log('  ✅ Dropped.\n');
    }

    if (!SEED_ONLY) {
      // Create db if not exists
      const res = await adminClient.query(
        `SELECT 1 FROM pg_database WHERE datname = $1`, [DB_NAME]
      );
      if (res.rowCount === 0) {
        console.log(`Creating database '${DB_NAME}'...`);
        await adminClient.query(`CREATE DATABASE ${DB_NAME}`);
        console.log('  ✅ Created.\n');
      } else {
        console.log(`  ℹ️  Database '${DB_NAME}' already exists.\n`);
      }
    }

    await adminClient.end();

    // Connect to the target DB
    await dbClient.connect();

    if (!SEED_ONLY) {
      console.log('Running schema migration...');
      const schema = fs.readFileSync(
        path.join(__dirname, '../migrations/001_initial_schema.sql'), 'utf8'
      );
      await dbClient.query(schema);
      console.log('  ✅ Schema applied.\n');
    }

    console.log('Seeding database...');
    await seedDatabase(dbClient);
    console.log('  ✅ Seed complete.\n');

    await dbClient.end();

    console.log('══════════════════════════════════════════');
    console.log('  Done! Test accounts (password: password123):');
    console.log('    Admin:      admin@pharmalink.cm');
    console.log('    Doctor:     amadou@pharmalink.cm');
    console.log('    Pharmacist: pharmacie@centrale.cm');
    console.log('    Patient:    marie@patient.cm');
    console.log('    Driver:     pierre@driver.cm');
    console.log('══════════════════════════════════════════\n');

  } catch (err) {
    console.error('\n❌ Error:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
}

async function seedDatabase(client) {
  const hash = await bcrypt.hash('password123', 12);

  // ── Users ──────────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO users (id, name, email, phone, password_hash, role, is_verified, is_active)
    VALUES
      ('00000000-0000-0000-0000-000000000001','PharmaLink Admin','admin@pharmalink.cm','+237600000001',$1,'admin',true,true),
      ('00000000-0000-0000-0000-000000000002','Dr. Amadou Bello','amadou@pharmalink.cm','+237600000002',$1,'doctor',true,true),
      ('00000000-0000-0000-0000-000000000003','Marie Centrale','pharmacie@centrale.cm','+237600000003',$1,'pharmacist',true,true),
      ('00000000-0000-0000-0000-000000000004','Marie Nguema','marie@patient.cm','+237600000004',$1,'patient',true,true),
      ('00000000-0000-0000-0000-000000000005','Pierre Mbarga','pierre@driver.cm','+237600000005',$1,'delivery_driver',true,true),
      ('00000000-0000-0000-0000-000000000006','Jean Nations','pharmacie@nations.cm','+237600000006',$1,'pharmacist',true,true),
      ('00000000-0000-0000-0000-000000000007','Dr. Sophie Kamga','sophie@pharmalink.cm','+237600000007',$1,'doctor',true,true),
      ('00000000-0000-0000-0000-000000000008','Jean Tagne','jean@patient.cm','+237600000008',$1,'patient',true,true)
    ON CONFLICT (id) DO NOTHING
  `, [hash]);
  console.log('    ✓ Users');

  // ── Patient profiles ────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO patient_profiles (user_id, date_of_birth, address, blood_type, allergies)
    VALUES
      ('00000000-0000-0000-0000-000000000004','1992-03-15','Quartier Bastos, Yaoundé','A+','Aucune allergie connue'),
      ('00000000-0000-0000-0000-000000000008','1988-07-22','Quartier Melen, Yaoundé','O+','Pénicilline')
    ON CONFLICT (user_id) DO NOTHING
  `);
  console.log('    ✓ Patient profiles');

  // ── Doctor profiles ─────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO doctor_profiles (id, user_id, license_number, specialty, approval_status, bio)
    VALUES
      ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','CMR-MED-2019-00421','Médecin Généraliste','approved','Médecin généraliste avec 8 ans d''expérience.'),
      ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000007','CMR-MED-2021-00867','Pédiatre','approved','Pédiatre spécialisée dans la santé infantile.')
    ON CONFLICT (id) DO NOTHING
  `);
  console.log('    ✓ Doctor profiles');

  // ── Doctor availability ─────────────────────────────────────────────────
  await client.query(`
    INSERT INTO doctor_availability (doctor_id, day_of_week, start_time, end_time, is_available)
    SELECT '10000000-0000-0000-0000-000000000001', d, '08:00', '17:00', d < 5
    FROM generate_series(0,6) AS d
    ON CONFLICT DO NOTHING
  `);
  await client.query(`
    INSERT INTO doctor_availability (doctor_id, day_of_week, start_time, end_time, is_available)
    SELECT '10000000-0000-0000-0000-000000000002', d, '09:00', '16:00', d < 5
    FROM generate_series(0,6) AS d
    ON CONFLICT DO NOTHING
  `);
  console.log('    ✓ Doctor availability');

  // ── Pharmacist profiles ─────────────────────────────────────────────────
  await client.query(`
    INSERT INTO pharmacist_profiles (id, user_id, pharmacy_name, license_number, pharmacy_address, pharmacy_category, approval_status, opening_hours, lat, lng)
    VALUES
      ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','Pharmacie Centrale','CMR-PH-2018-0042','Avenue Kennedy, Bastos, Yaoundé','Pharmacie Générale','approved','08:00 - 20:00',3.8802,11.5165),
      ('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000006','Pharmacie des Nations','CMR-PH-2020-0198','Rue des Nations, Centre-ville, Yaoundé','Pharmacie Générale','approved','08:00 - 20:00',3.8665,11.5173)
    ON CONFLICT (id) DO NOTHING
  `);
  console.log('    ✓ Pharmacist profiles');

  // ── Driver profile ──────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO driver_profiles (id, user_id, vehicle_info, approval_status, is_online, current_lat, current_lng)
    VALUES ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000005','Moto Honda CG 125 - CE 7843 A','approved',true,3.8480,11.5021)
    ON CONFLICT (id) DO NOTHING
  `);
  console.log('    ✓ Driver profile');

  // ── Medications ─────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO medications (id, pharmacy_id, name, description, price_fcfa, stock_quantity, category, requires_prescription)
    VALUES
      ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Paracétamol 500mg','Antalgique et antipyrétique.',1200,150,'Antalgiques',false),
      ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Paracétamol 1g','Antalgique fort.',1800,80,'Antalgiques',false),
      ('40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','Amoxicilline 500mg','Antibiotique à large spectre.',2500,60,'Antibiotiques',true),
      ('40000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','Ibuprofène 400mg','Anti-inflammatoire non stéroïdien.',1400,90,'Anti-inflammatoires',false),
      ('40000000-0000-0000-0000-000000000005','20000000-0000-0000-0000-000000000001','Metformine 500mg','Antidiabétique oral.',1100,40,'Diabète',true),
      ('40000000-0000-0000-0000-000000000006','20000000-0000-0000-0000-000000000001','Lisinopril 10mg','Inhibiteur de l ECA.',1600,35,'Cardiologie',true),
      ('40000000-0000-0000-0000-000000000007','20000000-0000-0000-0000-000000000001','Vitamine C 500mg','Supplément vitaminique.',800,200,'Vitamines',false),
      ('40000000-0000-0000-0000-000000000008','20000000-0000-0000-0000-000000000001','Oméprazole 20mg','Inhibiteur de la pompe à protons.',1900,55,'Gastro-entérologie',true),
      ('40000000-0000-0000-0000-000000000009','20000000-0000-0000-0000-000000000001','Cotrimoxazole 480mg','Association antibiotique.',1300,70,'Antibiotiques',true),
      ('40000000-0000-0000-0000-000000000010','20000000-0000-0000-0000-000000000001','Artéméther-Luméfantrine 80/480mg','Antipaludéen combiné.',3500,45,'Antipaludéens',true),
      ('40000000-0000-0000-0000-000000000011','20000000-0000-0000-0000-000000000002','Paracétamol 500mg','Antalgique et antipyrétique.',1150,120,'Antalgiques',false),
      ('40000000-0000-0000-0000-000000000012','20000000-0000-0000-0000-000000000002','Amoxicilline 500mg','Antibiotique à large spectre.',2400,50,'Antibiotiques',true),
      ('40000000-0000-0000-0000-000000000013','20000000-0000-0000-0000-000000000002','Ibuprofène 400mg','Anti-inflammatoire.',1300,75,'Anti-inflammatoires',false),
      ('40000000-0000-0000-0000-000000000014','20000000-0000-0000-0000-000000000002','Zinc 20mg','Supplément minéral.',900,100,'Vitamines',false),
      ('40000000-0000-0000-0000-000000000015','20000000-0000-0000-0000-000000000002','Artéméther-Luméfantrine 80/480mg','Antipaludéen de référence.',3400,30,'Antipaludéens',true)
    ON CONFLICT (id) DO NOTHING
  `);
  console.log('    ✓ Medications (15)');

  // ── Orders + items ──────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO orders (id, patient_id, pharmacy_id, driver_profile_id, status, order_type, total_fcfa, delivery_address, delivery_lat, delivery_lng, pickup_code)
    VALUES
      ('70000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','delivered','delivery',2400,'Quartier Bastos, Yaoundé',3.8802,11.5165,NULL),
      ('70000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','out_for_delivery','delivery',1200,'Quartier Melen, Yaoundé',3.8665,11.5080,NULL),
      ('70000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000008','20000000-0000-0000-0000-000000000001',NULL,'confirmed','pickup',3500,NULL,NULL,NULL,'PL5678'),
      ('70000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002',NULL,'pending','delivery',1150,'Omnisport, Yaoundé',3.8732,11.5250,NULL)
    ON CONFLICT (id) DO NOTHING
  `);
  await client.query(`
    INSERT INTO order_items (order_id, medication_id, quantity, unit_price_fcfa)
    VALUES
      ('70000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',1,1200),
      ('70000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000004',1,1200),
      ('70000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001',1,1200),
      ('70000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000010',1,3500),
      ('70000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000011',1,1150)
    ON CONFLICT DO NOTHING
  `);
  console.log('    ✓ Orders + items');

  // ── Deliveries ──────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO deliveries (order_id, driver_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, current_lat, current_lng, started_at, delivered_at)
    VALUES
      ('70000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','delivered',3.8802,11.5165,3.8802,11.5165,3.8802,11.5165,NOW()-INTERVAL'2 hours',NOW()-INTERVAL'1 hour'),
      ('70000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000001','in_transit',3.8802,11.5165,3.8665,11.5080,3.8740,11.5100,NOW()-INTERVAL'20 minutes',NULL)
    ON CONFLICT (order_id) DO NOTHING
  `);
  console.log('    ✓ Deliveries');

  // ── Transactions ────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO transactions (user_id, order_id, type, amount_fcfa, method, status, reference)
    VALUES
      ('00000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000001','payment',2400,'momo','success','PL-TXN-001'),
      ('00000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000002','payment',1200,'orange_money','success','PL-TXN-002'),
      ('00000000-0000-0000-0000-000000000008','70000000-0000-0000-0000-000000000003','payment',3500,'momo','success','PL-TXN-003'),
      ('00000000-0000-0000-0000-000000000005','70000000-0000-0000-0000-000000000001','earning',240,'momo','success','PL-DRV-001')
    ON CONFLICT (reference) DO NOTHING
  `);
  console.log('    ✓ Transactions');

  // ── Prescriptions ───────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO prescriptions (id, doctor_id, patient_id, pharmacist_id, status, notes)
    VALUES
      ('50000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000003','fulfilled','Traitement infection respiratoire.'),
      ('50000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000008',NULL,'issued','Traitement antipaludéen.')
    ON CONFLICT (id) DO NOTHING
  `);
  await client.query(`
    INSERT INTO prescription_items (prescription_id, medication_name, dosage, instructions, duration_days)
    VALUES
      ('50000000-0000-0000-0000-000000000001','Amoxicilline 500mg','500mg','1 gélule 3 fois par jour',7),
      ('50000000-0000-0000-0000-000000000001','Paracétamol 500mg','500mg','1 comprimé si fièvre > 38°C',5),
      ('50000000-0000-0000-0000-000000000002','Artéméther-Luméfantrine','4 comprimés','Prendre à H0, H8, H24, H36, H48, H60',3)
  `);
  console.log('    ✓ Prescriptions');

  // ── Appointments ────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO appointments (id, patient_id, doctor_id, status, appointment_date, type, notes)
    VALUES
      ('60000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000002','confirmed',NOW()+INTERVAL'2 days','in_person','Suivi tension artérielle'),
      ('60000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000002','pending',NOW()+INTERVAL'4 days','telemedicine','Résultats d analyses'),
      ('60000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000007','completed',NOW()-INTERVAL'5 days','in_person','Bilan de santé annuel')
    ON CONFLICT (id) DO NOTHING
  `);
  console.log('    ✓ Appointments');

  // ── Notifications ───────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO notifications (user_id, title, body, type, is_read)
    VALUES
      ('00000000-0000-0000-0000-000000000004','Commande livrée !','Votre commande a été livrée avec succès.','order',true),
      ('00000000-0000-0000-0000-000000000004','Commande en cours','Votre commande est en route. ~12 min.','order',false),
      ('00000000-0000-0000-0000-000000000004','Rendez-vous confirmé','RDV avec Dr. Amadou confirmé.','appointment',false),
      ('00000000-0000-0000-0000-000000000002','Nouveau rendez-vous','Marie Nguema a réservé un RDV.','appointment',false),
      ('00000000-0000-0000-0000-000000000003','Nouvelle commande','Nouvelle commande reçue.','order',true),
      ('00000000-0000-0000-0000-000000000005','Nouvelle livraison','Livraison assignée. Rendez-vous Pharmacie Centrale.','delivery',false)
  `);
  console.log('    ✓ Notifications');

  // ── Medical history ─────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO medical_history (patient_id, doctor_id, diagnosis, notes, date)
    VALUES
      ('00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000002','Hypertension artérielle légère','Tension 140/90. Traitement Lisinopril 10mg.',CURRENT_DATE-INTERVAL'3 months'),
      ('00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000007','Infection respiratoire','Amygdalite bactérienne. Amoxicilline 7 jours.',CURRENT_DATE-INTERVAL'6 months'),
      ('00000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000002','Paludisme simple','TDR positif. Traitement Artéméther-Luméfantrine.',CURRENT_DATE-INTERVAL'1 month')
  `);
  console.log('    ✓ Medical history');

  // ── Reminders ───────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO reminders (patient_id, medication_name, dosage, frequency, reminder_time, is_active)
    VALUES
      ('00000000-0000-0000-0000-000000000004','Lisinopril 10mg','1 comprimé','Tous les jours','08:00',true),
      ('00000000-0000-0000-0000-000000000004','Vitamine C 500mg','1 comprimé','Tous les jours','12:00',true),
      ('00000000-0000-0000-0000-000000000008','Metformine 500mg','1 comprimé','Matin et soir','07:30',true)
  `);
  console.log('    ✓ Reminders');

  // ── Complaints ──────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO complaints (user_id, subject, body, status, admin_response)
    VALUES
      ('00000000-0000-0000-0000-000000000004','Livraison en retard','Ma commande a mis plus de 2h.','resolved','Nos excuses. Un bon de 500 FCFA a été ajouté.'),
      ('00000000-0000-0000-0000-000000000008','Médicament manquant','Il manquait un médicament dans ma commande.','in_review',NULL)
  `);
  console.log('    ✓ Complaints');

  // ── Messages ────────────────────────────────────────────────────────────
  await client.query(`
    INSERT INTO messages (sender_id, receiver_id, order_id, content, type, is_read)
    VALUES
      ('00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000005','70000000-0000-0000-0000-000000000002','Je suis au 3ème étage, appartement 301.','text',true),
      ('00000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000002','Bien reçu ! J arrive dans ~10 minutes.','text',false)
  `);
  console.log('    ✓ Messages');
}

run();
