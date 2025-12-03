-- BastionDesk - PostgreSQL Initialization Script
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bastiondesk_superadmin') THEN
		CREATE ROLE bastiondesk_superadmin WITH LOGIN;
	END IF;

	IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'bastiondesk_db') THEN
		PERFORM dblink_connect('dbname=postgres');
		EXECUTE 'CREATE DATABASE bastiondesk_db OWNER bastiondesk_superadmin';
	ELSE
		EXECUTE 'ALTER DATABASE bastiondesk_db OWNER TO bastiondesk_superadmin';
	END IF;
EXCEPTION WHEN undefined_function THEN
	IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'bastiondesk_db') THEN
		EXECUTE 'CREATE DATABASE bastiondesk_db OWNER bastiondesk_superadmin';
	ELSE
		EXECUTE 'ALTER DATABASE bastiondesk_db OWNER TO bastiondesk_superadmin';
	END IF;
END$$;