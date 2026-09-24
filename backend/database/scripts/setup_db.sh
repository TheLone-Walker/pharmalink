#!/bin/bash
# =============================================================================
# PharmaLink Database Setup Script
# Usage: bash scripts/setup_db.sh
# =============================================================================

set -e  # Exit on any error

# Load .env if it exists
if [ -f ../.env ]; then
  export $(grep -v '^#' ../.env | xargs)
fi

# Defaults
DB_NAME="${DB_NAME:-pharmalink}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo ""
echo "======================================================"
echo "  PharmaLink Database Setup"
echo "======================================================"
echo "  Host:     $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User:     $DB_USER"
echo "======================================================"
echo ""

# 1. Create database if not exists
echo "Step 1: Creating database '$DB_NAME'..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -tc \
  "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" \
  | grep -q 1 || psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
  -c "CREATE DATABASE $DB_NAME;"
echo "  ✅ Database ready."

# 2. Run schema migration
echo ""
echo "Step 2: Running schema migration (001_initial_schema.sql)..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -f "$(dirname "$0")/../migrations/001_initial_schema.sql"
echo "  ✅ Schema applied."

# 3. Run seed data
echo ""
echo "Step 3: Seeding test data (002_seed_data.sql)..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -f "$(dirname "$0")/../migrations/002_seed_data.sql"
echo "  ✅ Seed data inserted."

echo ""
echo "======================================================"
echo "  Setup complete!"
echo ""
echo "  Test accounts (password: password123):"
echo "    Admin:      admin@pharmalink.cm"
echo "    Doctor:     amadou@pharmalink.cm"
echo "    Pharmacist: pharmacie@centrale.cm"
echo "    Patient:    marie@patient.cm"
echo "    Driver:     pierre@driver.cm"
echo "======================================================"
echo ""
