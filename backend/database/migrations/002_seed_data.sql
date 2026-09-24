-- =============================================================================
-- PharmaLink Database Seed - 002_seed_data.sql
-- Run AFTER 001_initial_schema.sql
-- Run with: psql -U postgres -d pharmalink -f 002_seed_data.sql
-- All passwords are: password123
-- Hash generated with bcrypt rounds=12
-- =============================================================================

-- =============================================================================
-- USERS
-- =============================================================================

INSERT INTO users (id, name, email, phone, password_hash, role, is_verified, is_active) VALUES
  -- Admin
  ('00000000-0000-0000-0000-000000000001',
   'PharmaLink Admin',
   'admin@pharmalink.cm',
   '+237600000001',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'admin', TRUE, TRUE),

  -- Doctor
  ('00000000-0000-0000-0000-000000000002',
   'Dr. Amadou Bello',
   'amadou@pharmalink.cm',
   '+237600000002',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'doctor', TRUE, TRUE),

  -- Pharmacist
  ('00000000-0000-0000-0000-000000000003',
   'Marie Centrale',
   'pharmacie@centrale.cm',
   '+237600000003',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'pharmacist', TRUE, TRUE),

  -- Patient
  ('00000000-0000-0000-0000-000000000004',
   'Marie Nguema',
   'marie@patient.cm',
   '+237600000004',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'patient', TRUE, TRUE),

  -- Driver
  ('00000000-0000-0000-0000-000000000005',
   'Pierre Mbarga',
   'pierre@driver.cm',
   '+237600000005',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'delivery_driver', TRUE, TRUE),

  -- Extra pharmacist
  ('00000000-0000-0000-0000-000000000006',
   'Jean Nations',
   'pharmacie@nations.cm',
   '+237600000006',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'pharmacist', TRUE, TRUE),

  -- Extra doctor
  ('00000000-0000-0000-0000-000000000007',
   'Dr. Sophie Kamga',
   'sophie@pharmalink.cm',
   '+237600000007',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'doctor', TRUE, TRUE),

  -- Extra patient
  ('00000000-0000-0000-0000-000000000008',
   'Jean Tagne',
   'jean@patient.cm',
   '+237600000008',
   '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBpj4oBLIpBpEu',
   'patient', TRUE, TRUE);

-- =============================================================================
-- PATIENT PROFILES
-- =============================================================================

INSERT INTO patient_profiles (user_id, date_of_birth, address, blood_type, allergies) VALUES
  ('00000000-0000-0000-0000-000000000004',
   '1992-03-15',
   'Quartier Bastos, Yaoundé, Cameroun',
   'A+',
   'Aucune allergie connue'),
  ('00000000-0000-0000-0000-000000000008',
   '1988-07-22',
   'Quartier Melen, Yaoundé, Cameroun',
   'O+',
   'Pénicilline');

-- =============================================================================
-- DOCTOR PROFILES
-- =============================================================================

INSERT INTO doctor_profiles (id, user_id, license_number, specialty, approval_status, bio) VALUES
  ('10000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000002',
   'CMR-MED-2019-00421',
   'Médecin Généraliste',
   'approved',
   'Médecin généraliste avec 8 ans d''expérience à Yaoundé. Spécialisé en médecine préventive et suivi des maladies chroniques.'),
  ('10000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000007',
   'CMR-MED-2021-00867',
   'Pédiatre',
   'approved',
   'Pédiatre certifiée, spécialisée dans la santé infantile et les maladies tropicales.');

-- =============================================================================
-- DOCTOR AVAILABILITY
-- =============================================================================

INSERT INTO doctor_availability (doctor_id, day_of_week, start_time, end_time, is_available) VALUES
  -- Dr. Amadou: Mon-Fri 08:00-17:00, Sat morning
  ('10000000-0000-0000-0000-000000000001', 0, '08:00', '17:00', TRUE),
  ('10000000-0000-0000-0000-000000000001', 1, '08:00', '17:00', TRUE),
  ('10000000-0000-0000-0000-000000000001', 2, '08:00', '17:00', TRUE),
  ('10000000-0000-0000-0000-000000000001', 3, '08:00', '17:00', TRUE),
  ('10000000-0000-0000-0000-000000000001', 4, '08:00', '17:00', TRUE),
  ('10000000-0000-0000-0000-000000000001', 5, '09:00', '13:00', TRUE),
  ('10000000-0000-0000-0000-000000000001', 6, '00:00', '00:00', FALSE),
  -- Dr. Sophie: Mon-Fri 09:00-16:00
  ('10000000-0000-0000-0000-000000000002', 0, '09:00', '16:00', TRUE),
  ('10000000-0000-0000-0000-000000000002', 1, '09:00', '16:00', TRUE),
  ('10000000-0000-0000-0000-000000000002', 2, '09:00', '16:00', TRUE),
  ('10000000-0000-0000-0000-000000000002', 3, '09:00', '16:00', TRUE),
  ('10000000-0000-0000-0000-000000000002', 4, '09:00', '16:00', TRUE),
  ('10000000-0000-0000-0000-000000000002', 5, '00:00', '00:00', FALSE),
  ('10000000-0000-0000-0000-000000000002', 6, '00:00', '00:00', FALSE);

-- =============================================================================
-- PHARMACIST PROFILES
-- =============================================================================

INSERT INTO pharmacist_profiles (id, user_id, pharmacy_name, license_number, pharmacy_address, pharmacy_category, approval_status, opening_hours, lat, lng) VALUES
  ('20000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000003',
   'Pharmacie Centrale',
   'CMR-PH-2018-0042',
   'Avenue Kennedy, Bastos, Yaoundé',
   'Pharmacie Générale',
   'approved',
   '08:00 - 20:00',
   3.8802, 11.5165),
  ('20000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000006',
   'Pharmacie des Nations',
   'CMR-PH-2020-0198',
   'Rue des Nations, Centre-ville, Yaoundé',
   'Pharmacie Générale',
   'approved',
   '08:00 - 20:00',
   3.8665, 11.5173);

-- =============================================================================
-- DRIVER PROFILES
-- =============================================================================

INSERT INTO driver_profiles (id, user_id, vehicle_info, approval_status, is_online, current_lat, current_lng) VALUES
  ('30000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000005',
   'Moto Honda CG 125 - CE 7843 A',
   'approved',
   TRUE,
   3.8480, 11.5021);

-- =============================================================================
-- MEDICATIONS - Pharmacie Centrale
-- =============================================================================

INSERT INTO medications (id, pharmacy_id, name, description, price_fcfa, stock_quantity, category, requires_prescription) VALUES
  ('40000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000001',
   'Paracétamol 500mg',
   'Antalgique et antipyrétique. Soulage la douleur et fait baisser la fièvre.',
   1200.00, 150, 'Antalgiques', FALSE),

  ('40000000-0000-0000-0000-000000000002',
   '20000000-0000-0000-0000-000000000001',
   'Paracétamol 1g',
   'Antalgique fort pour douleurs modérées à sévères.',
   1800.00, 80, 'Antalgiques', FALSE),

  ('40000000-0000-0000-0000-000000000003',
   '20000000-0000-0000-0000-000000000001',
   'Amoxicilline 500mg',
   'Antibiotique à large spectre de la famille des pénicillines.',
   2500.00, 60, 'Antibiotiques', TRUE),

  ('40000000-0000-0000-0000-000000000004',
   '20000000-0000-0000-0000-000000000001',
   'Ibuprofène 400mg',
   'Anti-inflammatoire non stéroïdien (AINS). Antidouleur et anti-fièvre.',
   1400.00, 90, 'Anti-inflammatoires', FALSE),

  ('40000000-0000-0000-0000-000000000005',
   '20000000-0000-0000-0000-000000000001',
   'Metformine 500mg',
   'Antidiabétique oral de la classe des biguanides.',
   1100.00, 40, 'Diabète', TRUE),

  ('40000000-0000-0000-0000-000000000006',
   '20000000-0000-0000-0000-000000000001',
   'Lisinopril 10mg',
   'Inhibiteur de l''ECA pour le traitement de l''hypertension artérielle.',
   1600.00, 35, 'Cardiologie', TRUE),

  ('40000000-0000-0000-0000-000000000007',
   '20000000-0000-0000-0000-000000000001',
   'Vitamine C 500mg',
   'Supplément vitaminique pour renforcer le système immunitaire.',
   800.00, 200, 'Vitamines', FALSE),

  ('40000000-0000-0000-0000-000000000008',
   '20000000-0000-0000-0000-000000000001',
   'Oméprazole 20mg',
   'Inhibiteur de la pompe à protons. Traitement des ulcères gastriques.',
   1900.00, 55, 'Gastro-entérologie', TRUE),

  ('40000000-0000-0000-0000-000000000009',
   '20000000-0000-0000-0000-000000000001',
   'Cotrimoxazole 480mg',
   'Association sulfaméthoxazole + triméthoprime. Antibiotique.',
   1300.00, 70, 'Antibiotiques', TRUE),

  ('40000000-0000-0000-0000-000000000010',
   '20000000-0000-0000-0000-000000000001',
   'Artéméther-Luméfantrine 80/480mg',
   'Antipaludéen combiné pour le traitement du paludisme non compliqué.',
   3500.00, 45, 'Antipaludéens', TRUE);

-- =============================================================================
-- MEDICATIONS - Pharmacie des Nations
-- =============================================================================

INSERT INTO medications (id, pharmacy_id, name, description, price_fcfa, stock_quantity, category, requires_prescription) VALUES
  ('40000000-0000-0000-0000-000000000011',
   '20000000-0000-0000-0000-000000000002',
   'Paracétamol 500mg',
   'Antalgique et antipyrétique.',
   1150.00, 120, 'Antalgiques', FALSE),

  ('40000000-0000-0000-0000-000000000012',
   '20000000-0000-0000-0000-000000000002',
   'Amoxicilline 500mg',
   'Antibiotique à large spectre.',
   2400.00, 50, 'Antibiotiques', TRUE),

  ('40000000-0000-0000-0000-000000000013',
   '20000000-0000-0000-0000-000000000002',
   'Ibuprofène 400mg',
   'Anti-inflammatoire non stéroïdien.',
   1300.00, 75, 'Anti-inflammatoires', FALSE),

  ('40000000-0000-0000-0000-000000000014',
   '20000000-0000-0000-0000-000000000002',
   'Zinc 20mg',
   'Supplément minéral essentiel pour l''immunité.',
   900.00, 100, 'Vitamines', FALSE),

  ('40000000-0000-0000-0000-000000000015',
   '20000000-0000-0000-0000-000000000002',
   'Artéméther-Luméfantrine 80/480mg',
   'Antipaludéen de référence.',
   3400.00, 30, 'Antipaludéens', TRUE);

-- =============================================================================
-- PRESCRIPTIONS
-- =============================================================================

INSERT INTO prescriptions (id, doctor_id, patient_id, pharmacist_id, status, notes) VALUES
  ('50000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000003',
   'fulfilled',
   'Traitement pour infection respiratoire. Repos conseillé.'),
  ('50000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000008',
   NULL,
   'issued',
   'Traitement antipaludéen. Prendre avec un repas.');

INSERT INTO prescription_items (prescription_id, medication_name, dosage, instructions, duration_days) VALUES
  ('50000000-0000-0000-0000-000000000001', 'Amoxicilline 500mg', '500mg',  'Prendre 1 gélule 3 fois par jour', 7),
  ('50000000-0000-0000-0000-000000000001', 'Paracétamol 500mg',  '500mg',  'Prendre 1 comprimé si fièvre > 38°C', 5),
  ('50000000-0000-0000-0000-000000000002', 'Artéméther-Luméfantrine 80/480mg', '4 comprimés', 'Prendre 4 comprimés à H0, H8, H24, H36, H48, H60', 3);

-- =============================================================================
-- APPOINTMENTS
-- =============================================================================

INSERT INTO appointments (id, patient_id, doctor_id, status, appointment_date, type, notes) VALUES
  ('60000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000002',
   'confirmed',
   NOW() + INTERVAL '2 days',
   'in_person',
   'Consultation de suivi - tension artérielle'),
  ('60000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000008',
   '00000000-0000-0000-0000-000000000002',
   'pending',
   NOW() + INTERVAL '4 days',
   'telemedicine',
   'Consultation en ligne - résultats d''analyses'),
  ('60000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000007',
   'completed',
   NOW() - INTERVAL '5 days',
   'in_person',
   'Bilan de santé annuel');

-- =============================================================================
-- ORDERS
-- =============================================================================

INSERT INTO orders (id, patient_id, pharmacy_id, driver_profile_id, status, order_type, total_fcfa, delivery_address, delivery_lat, delivery_lng, pickup_code) VALUES
  -- Delivered order (delivery)
  ('70000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000004',
   '20000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000001',
   'delivered',
   'delivery',
   2400.00,
   'Quartier Bastos, Yaoundé',
   3.8802, 11.5165,
   NULL),

  -- Active order (out for delivery)
  ('70000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000004',
   '20000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000001',
   'out_for_delivery',
   'delivery',
   1200.00,
   'Quartier Melen, Yaoundé',
   3.8665, 11.5080,
   NULL),

  -- Pickup order (confirmed)
  ('70000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000008',
   '20000000-0000-0000-0000-000000000001',
   NULL,
   'confirmed',
   'pickup',
   3500.00,
   NULL, NULL, NULL,
   'PL5678'),

  -- Pending order
  ('70000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000004',
   '20000000-0000-0000-0000-000000000002',
   NULL,
   'pending',
   'delivery',
   1150.00,
   'Omnisport, Yaoundé',
   3.8732, 11.5250,
   NULL);

-- =============================================================================
-- ORDER ITEMS
-- =============================================================================

INSERT INTO order_items (order_id, medication_id, quantity, unit_price_fcfa) VALUES
  -- Order 1: delivered
  ('70000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 1, 1200.00),
  ('70000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000004', 1, 1200.00),

  -- Order 2: out for delivery
  ('70000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 1, 1200.00),

  -- Order 3: pickup
  ('70000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000010', 1, 3500.00),

  -- Order 4: pending
  ('70000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000011', 1, 1150.00);

-- =============================================================================
-- DELIVERIES
-- =============================================================================

INSERT INTO deliveries (order_id, driver_id, status, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, current_lat, current_lng, started_at, delivered_at) VALUES
  -- Delivered
  ('70000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000001',
   'delivered',
   3.8802, 11.5165,
   3.8802, 11.5165,
   3.8802, 11.5165,
   NOW() - INTERVAL '2 hours',
   NOW() - INTERVAL '1 hour'),

  -- Active delivery
  ('70000000-0000-0000-0000-000000000002',
   '30000000-0000-0000-0000-000000000001',
   'in_transit',
   3.8802, 11.5165,
   3.8665, 11.5080,
   3.8740, 11.5100,
   NOW() - INTERVAL '20 minutes',
   NULL);

-- =============================================================================
-- TRANSACTIONS
-- =============================================================================

INSERT INTO transactions (user_id, order_id, type, amount_fcfa, method, status, reference) VALUES
  ('00000000-0000-0000-0000-000000000004',
   '70000000-0000-0000-0000-000000000001',
   'payment', 2400.00, 'momo', 'success', 'PL-TXN-001'),
  ('00000000-0000-0000-0000-000000000004',
   '70000000-0000-0000-0000-000000000002',
   'payment', 1200.00, 'orange_money', 'success', 'PL-TXN-002'),
  ('00000000-0000-0000-0000-000000000008',
   '70000000-0000-0000-0000-000000000003',
   'payment', 3500.00, 'momo', 'success', 'PL-TXN-003');

-- Driver earning
INSERT INTO transactions (user_id, order_id, type, amount_fcfa, method, status, reference) VALUES
  ('00000000-0000-0000-0000-000000000005',
   '70000000-0000-0000-0000-000000000001',
   'earning', 240.00, 'momo', 'success', 'PL-DRV-001');

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================

INSERT INTO notifications (user_id, title, body, type, is_read) VALUES
  ('00000000-0000-0000-0000-000000000004',
   'Commande livrée !',
   'Votre commande #70000000 a été livrée avec succès.',
   'order', TRUE),
  ('00000000-0000-0000-0000-000000000004',
   'Commande en cours',
   'Votre commande est en route. Le livreur arrive dans ~12 min.',
   'order', FALSE),
  ('00000000-0000-0000-0000-000000000004',
   'Rendez-vous confirmé',
   'Votre rendez-vous avec Dr. Amadou a été confirmé.',
   'appointment', FALSE),
  ('00000000-0000-0000-0000-000000000002',
   'Nouveau rendez-vous',
   'Marie Nguema a réservé un rendez-vous pour dans 2 jours.',
   'appointment', FALSE),
  ('00000000-0000-0000-0000-000000000003',
   'Nouvelle commande',
   'Vous avez reçu une nouvelle commande #70000000.',
   'order', TRUE),
  ('00000000-0000-0000-0000-000000000005',
   'Nouvelle livraison',
   'Une livraison vous a été assignée. Rendez-vous à la Pharmacie Centrale.',
   'delivery', FALSE);

-- =============================================================================
-- MEDICAL HISTORY
-- =============================================================================

INSERT INTO medical_history (patient_id, doctor_id, diagnosis, notes, date) VALUES
  ('00000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000002',
   'Hypertension artérielle légère',
   'Tension 140/90. Début traitement Lisinopril 10mg. Régime pauvre en sel recommandé.',
   CURRENT_DATE - INTERVAL '3 months'),
  ('00000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000007',
   'Infection respiratoire haute',
   'Amygdalite bactérienne. Traitement antibiotique Amoxicilline 500mg 7 jours.',
   CURRENT_DATE - INTERVAL '6 months'),
  ('00000000-0000-0000-0000-000000000008',
   '00000000-0000-0000-0000-000000000002',
   'Paludisme simple',
   'Test TDR positif. Traitement Artéméther-Luméfantrine 3 jours.',
   CURRENT_DATE - INTERVAL '1 month');

-- =============================================================================
-- REMINDERS
-- =============================================================================

INSERT INTO reminders (patient_id, medication_name, dosage, frequency, reminder_time, is_active) VALUES
  ('00000000-0000-0000-0000-000000000004',
   'Lisinopril 10mg',
   '1 comprimé',
   'Tous les jours',
   '08:00',
   TRUE),
  ('00000000-0000-0000-0000-000000000004',
   'Vitamine C 500mg',
   '1 comprimé effervescent',
   'Tous les jours',
   '12:00',
   TRUE),
  ('00000000-0000-0000-0000-000000000008',
   'Metformine 500mg',
   '1 comprimé',
   'Matin et soir',
   '07:30',
   TRUE);

-- =============================================================================
-- COMPLAINTS
-- =============================================================================

INSERT INTO complaints (user_id, subject, body, status, admin_response) VALUES
  ('00000000-0000-0000-0000-000000000004',
   'Livraison en retard',
   'Ma commande a mis plus de 2 heures à arriver alors que le délai annoncé était de 30 minutes.',
   'resolved',
   'Nous vous présentons nos excuses pour ce retard. Un bon de réduction de 500 FCFA a été ajouté à votre compte.'),
  ('00000000-0000-0000-0000-000000000008',
   'Médicament manquant',
   'Il manquait un médicament dans ma commande. J''ai commandé 2 articles mais n''en ai reçu qu''un.',
   'in_review',
   NULL);

-- =============================================================================
-- MESSAGES (CHAT)
-- =============================================================================

INSERT INTO messages (sender_id, receiver_id, order_id, content, type, is_read) VALUES
  ('00000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000005',
   '70000000-0000-0000-0000-000000000002',
   'Bonjour, je suis au 3ème étage, appartement 301.',
   'text', TRUE),
  ('00000000-0000-0000-0000-000000000005',
   '00000000-0000-0000-0000-000000000004',
   '70000000-0000-0000-0000-000000000002',
   'Bien reçu ! J''arrive dans environ 10 minutes.',
   'text', FALSE);

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT 'Users:'         AS table_name, COUNT(*) AS count FROM users
UNION ALL
SELECT 'Medications:',  COUNT(*) FROM medications
UNION ALL
SELECT 'Orders:',       COUNT(*) FROM orders
UNION ALL
SELECT 'Prescriptions:',COUNT(*) FROM prescriptions
UNION ALL
SELECT 'Appointments:', COUNT(*) FROM appointments
UNION ALL
SELECT 'Deliveries:',   COUNT(*) FROM deliveries
UNION ALL
SELECT 'Transactions:', COUNT(*) FROM transactions
UNION ALL
SELECT 'Notifications:',COUNT(*) FROM notifications
UNION ALL
SELECT 'Reminders:',    COUNT(*) FROM reminders
UNION ALL
SELECT 'Messages:',     COUNT(*) FROM messages;

SELECT 'PharmaLink seed data inserted successfully!' AS result;
