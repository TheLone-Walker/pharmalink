#!/bin/bash
# =============================================================================
# PharmaLink Database Reset Script
# WARNING: Drops and recreates the entire database!
# Usage: bash scripts/reset_db.sh
# =============================================================================

set -e

if [ -f ../.env ]; then
  export $(grep -v '^#' ../.env | xargs)
fi

DB_NAME="${DB_NAME:-pharmalink}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo ""
echo "⚠️  WARNING: This will DROP and recreate the database '$DB_NAME'!"
read -p "   Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Dropping database '$DB_NAME'..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
  -c "DROP DATABASE IF EXISTS $DB_NAME;"
echo "  ✅ Dropped."

echo "Recreating database '$DB_NAME'..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
  -c "CREATE DATABASE $DB_NAME;"
echo "  ✅ Created."

echo ""
echo "Running setup..."
bash "$(dirname "$0")/setup_db.sh"
