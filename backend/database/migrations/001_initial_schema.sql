-- =============================================================================
-- PharmaLink Database Migration - 001_initial_schema.sql
-- Run with: psql -U postgres -d pharmalink -f 001_initial_schema.sql
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE user_role AS ENUM (
  'patient', 'doctor', 'pharmacist', 'delivery_driver', 'admin'
);

CREATE TYPE approval_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TYPE order_status AS ENUM (
  'pending', 'confirmed', 'preparing',
  'out_for_delivery', 'delivered', 'cancelled', 'picked_up'
);

CREATE TYPE order_type AS ENUM ('delivery', 'pickup');

CREATE TYPE prescription_status AS ENUM (
  'issued', 'sent_to_pharmacy', 'fulfilled', 'cancelled'
);

CREATE TYPE appointment_status AS ENUM (
  'pending', 'confirmed', 'cancelled', 'completed'
);

CREATE TYPE appointment_type AS ENUM ('in_person', 'telemedicine');

CREATE TYPE delivery_status AS ENUM (
  'assigned', 'picked_up', 'in_transit', 'delivered'
);

CREATE TYPE transaction_type AS ENUM ('payment', 'refund', 'earning');

CREATE TYPE payment_method AS ENUM (
  'momo', 'orange_money', 'card', 'cash'
);

CREATE TYPE transaction_status AS ENUM ('pending', 'success', 'failed');

CREATE TYPE complaint_status AS ENUM ('open', 'in_review', 'resolved');

CREATE TYPE message_type AS ENUM ('text', 'image');

-- =============================================================================
-- CORE USERS TABLE
-- =============================================================================

CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name             VARCHAR(255) NOT NULL,
  email            VARCHAR(255) UNIQUE,
  phone            VARCHAR(20)  UNIQUE,
  password_hash    VARCHAR(255) NOT NULL,
  role             user_role    NOT NULL,
  is_verified      BOOLEAN      NOT NULL DEFAULT FALSE,
  is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
  profile_photo_url VARCHAR(500),
  fcm_token        VARCHAR(500),
  otp              VARCHAR(10),
  otp_expires_at   TIMESTAMPTZ,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  CONSTRAINT users_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE INDEX idx_users_email   ON users(email);
CREATE INDEX idx_users_phone   ON users(phone);
CREATE INDEX idx_users_role    ON users(role);
CREATE INDEX idx_users_active  ON users(is_active);

-- =============================================================================
-- ROLE-SPECIFIC PROFILES
-- =============================================================================

CREATE TABLE patient_profiles (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  date_of_birth DATE,
  address       VARCHAR(500),
  blood_type    VARCHAR(10),
  allergies     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE doctor_profiles (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  license_number   VARCHAR(100),
  specialty        VARCHAR(150),
  license_doc_url  VARCHAR(500),
  approval_status  approval_status NOT NULL DEFAULT 'pending',
  bio              TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_doctor_profiles_approval ON doctor_profiles(approval_status);

CREATE TABLE pharmacist_profiles (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  pharmacy_name     VARCHAR(255),
  license_number    VARCHAR(100),
  pharmacy_address  VARCHAR(500),
  pharmacy_category VARCHAR(100),
  license_doc_url   VARCHAR(500),
  approval_status   approval_status NOT NULL DEFAULT 'pending',
  opening_hours     VARCHAR(100),
  lat               DOUBLE PRECISION,
  lng               DOUBLE PRECISION,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pharmacist_profiles_approval ON pharmacist_profiles(approval_status);
CREATE INDEX idx_pharmacist_profiles_location ON pharmacist_profiles(lat, lng);

CREATE TABLE driver_profiles (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  vehicle_info      VARCHAR(255),
  driver_license_url VARCHAR(500),
  national_id_url   VARCHAR(500),
  is_online         BOOLEAN NOT NULL DEFAULT FALSE,
  current_lat       DOUBLE PRECISION,
  current_lng       DOUBLE PRECISION,
  approval_status   approval_status NOT NULL DEFAULT 'pending',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_driver_profiles_online   ON driver_profiles(is_online);
CREATE INDEX idx_driver_profiles_approval ON driver_profiles(approval_status);

-- =============================================================================
-- DOCTOR AVAILABILITY
-- =============================================================================

CREATE TABLE doctor_availability (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doctor_id     UUID NOT NULL REFERENCES doctor_profiles(id) ON DELETE CASCADE,
  day_of_week   SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time    VARCHAR(5)  NOT NULL,  -- "08:00"
  end_time      VARCHAR(5)  NOT NULL,  -- "17:00"
  is_available  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_doctor_availability_doctor ON doctor_availability(doctor_id);

-- =============================================================================
-- MEDICATIONS
-- =============================================================================

CREATE TABLE medications (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pharmacy_id           UUID NOT NULL REFERENCES pharmacist_profiles(id) ON DELETE CASCADE,
  name                  VARCHAR(255) NOT NULL,
  description           TEXT,
  price_fcfa            NUMERIC(12, 2) NOT NULL,
  stock_quantity        INTEGER NOT NULL DEFAULT 0,
  category              VARCHAR(100),
  image_url             VARCHAR(500),
  requires_prescription BOOLEAN NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_medications_pharmacy  ON medications(pharmacy_id);
CREATE INDEX idx_medications_name      ON medications(name);
CREATE INDEX idx_medications_stock     ON medications(stock_quantity);
CREATE INDEX idx_medications_category  ON medications(category);

-- Full-text search index on medication name
CREATE INDEX idx_medications_name_fts ON medications USING gin(to_tsvector('english', name));

-- =============================================================================
-- ORDERS
-- =============================================================================

CREATE TABLE orders (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id        UUID NOT NULL REFERENCES users(id),
  pharmacy_id       UUID NOT NULL REFERENCES pharmacist_profiles(id),
  driver_profile_id UUID REFERENCES driver_profiles(id),
  status            order_status NOT NULL DEFAULT 'pending',
  order_type        order_type   NOT NULL,
  total_fcfa        NUMERIC(12, 2) NOT NULL,
  delivery_address  VARCHAR(500),
  delivery_lat      DOUBLE PRECISION,
  delivery_lng      DOUBLE PRECISION,
  pickup_code       VARCHAR(20),
  otp               VARCHAR(10),
  otp_expires_at    TIMESTAMPTZ,
  signature_url     VARCHAR(500),
  proof_photo_url   VARCHAR(500),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_patient     ON orders(patient_id);
CREATE INDEX idx_orders_pharmacy    ON orders(pharmacy_id);
CREATE INDEX idx_orders_driver      ON orders(driver_profile_id);
CREATE INDEX idx_orders_status      ON orders(status);
CREATE INDEX idx_orders_created_at  ON orders(created_at DESC);

-- =============================================================================
-- ORDER ITEMS
-- =============================================================================

CREATE TABLE order_items (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id        UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  medication_id   UUID NOT NULL REFERENCES medications(id),
  quantity        INTEGER NOT NULL CHECK (quantity > 0),
  unit_price_fcfa NUMERIC(12, 2) NOT NULL
);

CREATE INDEX idx_order_items_order      ON order_items(order_id);
CREATE INDEX idx_order_items_medication ON order_items(medication_id);

-- =============================================================================
-- PRESCRIPTIONS
-- =============================================================================

CREATE TABLE prescriptions (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  doctor_id      UUID NOT NULL REFERENCES users(id),
  patient_id     UUID NOT NULL REFERENCES users(id),
  pharmacist_id  UUID REFERENCES users(id),
  status         prescription_status NOT NULL DEFAULT 'issued',
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_prescriptions_doctor     ON prescriptions(doctor_id);
CREATE INDEX idx_prescriptions_patient    ON prescriptions(patient_id);
CREATE INDEX idx_prescriptions_pharmacist ON prescriptions(pharmacist_id);
CREATE INDEX idx_prescriptions_status     ON prescriptions(status);

CREATE TABLE prescription_items (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  prescription_id  UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
  medication_name  VARCHAR(255) NOT NULL,
  dosage           VARCHAR(100),
  instructions     TEXT,
  duration_days    INTEGER
);

CREATE INDEX idx_prescription_items_prescription ON prescription_items(prescription_id);

-- =============================================================================
-- APPOINTMENTS
-- =============================================================================

CREATE TABLE appointments (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id       UUID NOT NULL REFERENCES users(id),
  doctor_id        UUID NOT NULL REFERENCES users(id),
  status           appointment_status NOT NULL DEFAULT 'pending',
  appointment_date TIMESTAMPTZ NOT NULL,
  type             appointment_type   NOT NULL DEFAULT 'in_person',
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_appointments_patient  ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor   ON appointments(doctor_id);
CREATE INDEX idx_appointments_status   ON appointments(status);
CREATE INDEX idx_appointments_date     ON appointments(appointment_date);

-- =============================================================================
-- DELIVERIES
-- =============================================================================

CREATE TABLE deliveries (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id     UUID NOT NULL UNIQUE REFERENCES orders(id),
  driver_id    UUID NOT NULL REFERENCES driver_profiles(id),
  status       delivery_status NOT NULL DEFAULT 'assigned',
  pickup_lat   DOUBLE PRECISION,
  pickup_lng   DOUBLE PRECISION,
  dropoff_lat  DOUBLE PRECISION,
  dropoff_lng  DOUBLE PRECISION,
  current_lat  DOUBLE PRECISION,
  current_lng  DOUBLE PRECISION,
  started_at   TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ
);

CREATE INDEX idx_deliveries_order  ON deliveries(order_id);
CREATE INDEX idx_deliveries_driver ON deliveries(driver_id);
CREATE INDEX idx_deliveries_status ON deliveries(status);

-- =============================================================================
-- TRANSACTIONS
-- =============================================================================

CREATE TABLE transactions (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES users(id),
  order_id       UUID REFERENCES orders(id),
  appointment_id UUID REFERENCES appointments(id),
  type           transaction_type   NOT NULL,
  amount_fcfa    NUMERIC(12, 2)     NOT NULL,
  method         payment_method     NOT NULL,
  status         transaction_status NOT NULL DEFAULT 'pending',
  reference      VARCHAR(100) UNIQUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_user       ON transactions(user_id);
CREATE INDEX idx_transactions_order      ON transactions(order_id);
CREATE INDEX idx_transactions_status     ON transactions(status);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================

CREATE TABLE notifications (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      VARCHAR(255) NOT NULL,
  body       TEXT NOT NULL,
  type       VARCHAR(50),
  is_read    BOOLEAN NOT NULL DEFAULT FALSE,
  data       JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user     ON notifications(user_id);
CREATE INDEX idx_notifications_is_read  ON notifications(is_read);
CREATE INDEX idx_notifications_created  ON notifications(created_at DESC);

-- =============================================================================
-- COMPLAINTS
-- =============================================================================

CREATE TABLE complaints (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID NOT NULL REFERENCES users(id),
  subject        VARCHAR(255) NOT NULL,
  body           TEXT NOT NULL,
  status         complaint_status NOT NULL DEFAULT 'open',
  admin_response TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_complaints_user   ON complaints(user_id);
CREATE INDEX idx_complaints_status ON complaints(status);

-- =============================================================================
-- MEDICAL HISTORY
-- =============================================================================

CREATE TABLE medical_history (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id UUID NOT NULL REFERENCES users(id),
  doctor_id  UUID REFERENCES users(id),
  diagnosis  VARCHAR(500) NOT NULL,
  notes      TEXT,
  date       DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE INDEX idx_medical_history_patient ON medical_history(patient_id);
CREATE INDEX idx_medical_history_doctor  ON medical_history(doctor_id);

-- =============================================================================
-- REMINDERS
-- =============================================================================

CREATE TABLE reminders (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  patient_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  medication_name  VARCHAR(255) NOT NULL,
  dosage           VARCHAR(100),
  frequency        VARCHAR(100),
  reminder_time    VARCHAR(5) NOT NULL,  -- "08:00"
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reminders_patient ON reminders(patient_id);
CREATE INDEX idx_reminders_active  ON reminders(is_active);

-- =============================================================================
-- MESSAGES (IN-APP CHAT)
-- =============================================================================

CREATE TABLE messages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id   UUID NOT NULL REFERENCES users(id),
  receiver_id UUID NOT NULL REFERENCES users(id),
  order_id    UUID REFERENCES orders(id),
  content     TEXT NOT NULL,
  type        message_type NOT NULL DEFAULT 'text',
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_messages_sender   ON messages(sender_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_order    ON messages(order_id);
CREATE INDEX idx_messages_created  ON messages(created_at ASC);

-- Composite index for chat history queries
CREATE INDEX idx_messages_conversation ON messages(sender_id, receiver_id, created_at DESC);

-- =============================================================================
-- AUTO-UPDATE updated_at TRIGGER
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_users
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at_medications
  BEFORE UPDATE ON medications
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at_orders
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER set_updated_at_complaints
  BEFORE UPDATE ON complaints
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Order summary view
CREATE VIEW order_summary AS
SELECT
  o.id,
  o.status,
  o.order_type,
  o.total_fcfa,
  o.created_at,
  u.name  AS patient_name,
  u.phone AS patient_phone,
  ph.pharmacy_name,
  ph.pharmacy_address,
  d.status AS delivery_status,
  dp.vehicle_info AS driver_vehicle,
  du.name AS driver_name,
  du.phone AS driver_phone
FROM orders o
JOIN users u                  ON o.patient_id        = u.id
JOIN pharmacist_profiles ph   ON o.pharmacy_id       = ph.id
LEFT JOIN deliveries d        ON d.order_id          = o.id
LEFT JOIN driver_profiles dp  ON d.driver_id         = dp.id
LEFT JOIN users du            ON dp.user_id          = du.id;

-- Pharmacy medications view
CREATE VIEW pharmacy_stock AS
SELECT
  m.id,
  m.name,
  m.price_fcfa,
  m.stock_quantity,
  m.category,
  m.requires_prescription,
  ph.pharmacy_name,
  ph.pharmacy_address,
  ph.lat,
  ph.lng,
  ph.opening_hours,
  u.phone AS pharmacy_phone
FROM medications m
JOIN pharmacist_profiles ph ON m.pharmacy_id = ph.id
JOIN users u                ON ph.user_id    = u.id
WHERE m.stock_quantity > 0
  AND ph.approval_status = 'approved';

-- Doctor appointments view
CREATE VIEW doctor_schedule AS
SELECT
  a.id,
  a.appointment_date,
  a.status,
  a.type,
  a.notes,
  pu.name  AS patient_name,
  pu.phone AS patient_phone,
  du.name  AS doctor_name,
  dp.specialty
FROM appointments a
JOIN users pu         ON a.patient_id = pu.id
JOIN users du         ON a.doctor_id  = du.id
JOIN doctor_profiles dp ON dp.user_id = du.id;

-- =============================================================================
-- DONE
-- =============================================================================
SELECT 'PharmaLink database schema created successfully!' AS result;
