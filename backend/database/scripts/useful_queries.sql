-- =============================================================================
-- PharmaLink - Useful Queries for Development & Debugging
-- Run any of these with: psql -U postgres -d pharmalink -c "..."
-- =============================================================================

-- ─── OVERVIEW ─────────────────────────────────────────────────────────────────

-- Row counts for all tables
SELECT
  schemaname,
  tablename,
  n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- ─── USERS ────────────────────────────────────────────────────────────────────

-- All users summary
SELECT id, name, email, phone, role, is_verified, is_active, created_at
FROM users ORDER BY created_at DESC;

-- Users by role
SELECT role, COUNT(*) FROM users GROUP BY role ORDER BY COUNT(*) DESC;

-- ─── ORDERS ───────────────────────────────────────────────────────────────────

-- Full order view
SELECT * FROM order_summary ORDER BY created_at DESC LIMIT 20;

-- Orders by status
SELECT status, COUNT(*), SUM(total_fcfa) AS total_revenue
FROM orders GROUP BY status ORDER BY COUNT(*) DESC;

-- Active deliveries
SELECT
  o.id AS order_id,
  o.status,
  o.total_fcfa,
  u.name AS patient,
  ph.pharmacy_name,
  du.name AS driver,
  d.status AS delivery_status,
  d.current_lat,
  d.current_lng
FROM orders o
JOIN users u ON o.patient_id = u.id
JOIN pharmacist_profiles ph ON o.pharmacy_id = ph.id
LEFT JOIN deliveries d ON d.order_id = o.id
LEFT JOIN driver_profiles dp ON d.driver_id = dp.id
LEFT JOIN users du ON dp.user_id = du.id
WHERE o.status IN ('out_for_delivery', 'confirmed', 'preparing');

-- ─── MEDICATIONS ──────────────────────────────────────────────────────────────

-- Stock levels across all pharmacies
SELECT * FROM pharmacy_stock ORDER BY pharmacy_name, name;

-- Low stock alert (< 10 units)
SELECT
  m.name,
  m.stock_quantity,
  ph.pharmacy_name
FROM medications m
JOIN pharmacist_profiles ph ON m.pharmacy_id = ph.id
WHERE m.stock_quantity < 10
ORDER BY m.stock_quantity ASC;

-- Top selling medications
SELECT
  m.name,
  SUM(oi.quantity) AS total_sold,
  SUM(oi.quantity * oi.unit_price_fcfa) AS revenue_fcfa
FROM order_items oi
JOIN medications m ON oi.medication_id = m.id
JOIN orders o ON oi.order_id = o.id
WHERE o.status IN ('delivered', 'picked_up')
GROUP BY m.name
ORDER BY total_sold DESC
LIMIT 10;

-- ─── PHARMACIES ───────────────────────────────────────────────────────────────

-- Pharmacies with medication count
SELECT
  ph.pharmacy_name,
  ph.pharmacy_address,
  ph.approval_status,
  ph.lat, ph.lng,
  COUNT(m.id) AS medication_count,
  SUM(m.stock_quantity) AS total_stock
FROM pharmacist_profiles ph
LEFT JOIN medications m ON m.pharmacy_id = ph.id
GROUP BY ph.id
ORDER BY medication_count DESC;

-- ─── REVENUE ──────────────────────────────────────────────────────────────────

-- Total revenue by payment method
SELECT
  method,
  COUNT(*) AS transactions,
  SUM(amount_fcfa) AS total_fcfa
FROM transactions
WHERE status = 'success' AND type = 'payment'
GROUP BY method
ORDER BY total_fcfa DESC;

-- Daily revenue (last 30 days)
SELECT
  DATE(created_at) AS day,
  COUNT(*) AS orders,
  SUM(amount_fcfa) AS revenue_fcfa
FROM transactions
WHERE status = 'success'
  AND type = 'payment'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- ─── APPOINTMENTS ─────────────────────────────────────────────────────────────

-- Upcoming appointments
SELECT * FROM doctor_schedule
WHERE appointment_date > NOW()
  AND status IN ('pending', 'confirmed')
ORDER BY appointment_date ASC;

-- ─── DRIVERS ──────────────────────────────────────────────────────────────────

-- Online drivers
SELECT
  u.name,
  u.phone,
  dp.vehicle_info,
  dp.current_lat,
  dp.current_lng,
  dp.approval_status
FROM driver_profiles dp
JOIN users u ON dp.user_id = u.id
WHERE dp.is_online = TRUE;

-- Driver earnings
SELECT
  u.name AS driver,
  COUNT(d.id) AS deliveries_completed,
  SUM(o.total_fcfa * 0.10) AS earnings_fcfa
FROM deliveries d
JOIN driver_profiles dp ON d.driver_id = dp.id
JOIN users u ON dp.user_id = u.id
JOIN orders o ON d.order_id = o.id
WHERE d.status = 'delivered'
GROUP BY u.name
ORDER BY earnings_fcfa DESC;

-- ─── MAINTENANCE ──────────────────────────────────────────────────────────────

-- Expired OTPs cleanup
DELETE FROM users WHERE otp_expires_at < NOW() AND otp IS NOT NULL;

-- Mark old unread notifications as read (older than 30 days)
UPDATE notifications
SET is_read = TRUE
WHERE is_read = FALSE AND created_at < NOW() - INTERVAL '30 days';

-- Vacuum and analyze (run periodically)
-- VACUUM ANALYZE;
