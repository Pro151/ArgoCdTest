#!/bin/bash
set -e

# Function to check if a database exists
check_db_exists() {
    local db_name=$1
    psql -U "$POSTGRES_USER" -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -tc "SELECT 1 FROM pg_database WHERE datname = '$db_name'" | grep -q 1
}

# Create database if it does not exist
create_db_if_not_exists() {
    local db_name=$1
    if ! check_db_exists "$db_name"; then
        psql -U "$POSTGRES_USER" -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -c "CREATE DATABASE \"$db_name\""
    fi
}

# Check and create databases
create_db_if_not_exists "$KEYCLOAK_DB"
create_db_if_not_exists "$MQTT_DB"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" <<EOF

-- Connect to MQTT_DB
\c ${MQTT_DB}

-- Check if roles exist, if not create them
DO \$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${MQTT_ADMIN_USER}') THEN
        CREATE ROLE ${MQTT_ADMIN_USER} LOGIN PASSWORD '${MQTT_ADMIN_PASSWORD}';
    END IF;
END
\$$;

-- Grant necessary permissions to ${POSTGRES_USER} user to create schema for mqtt_admin
GRANT ${MQTT_ADMIN_USER} TO ${POSTGRES_USER};

-- Check if schema exists, if not create it
DO \$$
BEGIN
    IF NOT EXISTS (SELECT schema_name FROM information_schema.schemata WHERE schema_name = '${MQTT_SCHEMA}') THEN
        CREATE SCHEMA ${MQTT_SCHEMA} AUTHORIZATION ${MQTT_ADMIN_USER};
    ELSE
        ALTER ROLE ${MQTT_ADMIN_USER} PASSWORD '${MQTT_ADMIN_PASSWORD}';    
    END IF;
END
\$$;

-- Revoke the permissions after schema creation
REVOKE ${MQTT_ADMIN_USER} FROM ${POSTGRES_USER};


-- Connect to KEYCLOAK_DB
\c ${KEYCLOAK_DB}

-- Check if roles exist, if not create them
DO \$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${KEYCLOAK_USER}') THEN
        CREATE ROLE ${KEYCLOAK_USER} LOGIN PASSWORD '${KEYCLOAK_PASSWORD}';
    ELSE
        ALTER ROLE ${KEYCLOAK_USER} PASSWORD '${KEYCLOAK_PASSWORD}';    
    END IF;
END
\$$;

-- Grant necessary permissions to ${POSTGRES_USER} user to create schema for ${KEYCLOAK_USER}
GRANT ${KEYCLOAK_USER} TO ${POSTGRES_USER};

-- Check if schema exists, if not create it
DO \$$
BEGIN
    IF NOT EXISTS (SELECT schema_name FROM information_schema.schemata WHERE schema_name = '${KEYCLOAK_SCHEMA}') THEN
        CREATE SCHEMA ${KEYCLOAK_SCHEMA} AUTHORIZATION ${KEYCLOAK_USER};
    END IF;
END
\$$;

-- Revoke the permissions after schema creation
REVOKE ${KEYCLOAK_USER} FROM ${POSTGRES_USER};

EOF
