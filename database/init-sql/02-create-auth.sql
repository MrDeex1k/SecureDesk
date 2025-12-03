-- =============================================================================
-- BastionDesk - Better-Auth Database Schema
-- =============================================================================
-- Funkcjonalności:
--   - Podstawowa autoryzacja email/password
--   - PassKeys (WebAuthn/U2F) - klucze sprzętowe
--   - HaveIBeenPwned (sprawdzanie kompromitacji haseł)
--   - Organizacje z rolami (pracownik, analityk, admin)
--   - Teams (zespoły wewnątrz organizacji)
--   - Last Login Method tracking
-- =============================================================================

-- =============================================================================
-- TYPY ENUM
-- =============================================================================

-- Role użytkowników w organizacji:
--   - pracownik: podstawowy dostęp
--   - analityk: dostęp do raportów i analityk
--   - admin: pełne uprawnienia (właściciel)
CREATE TYPE user_role AS ENUM ('pracownik', 'analityk', 'admin');

-- Status zaproszenia
CREATE TYPE invitation_status AS ENUM ('pending', 'accepted', 'rejected', 'canceled');

-- =============================================================================
-- TABELA: user (główna tabela użytkowników)
-- =============================================================================
CREATE TABLE IF NOT EXISTS "user" (
	id text PRIMARY KEY,
	name text,
	email text NOT NULL UNIQUE,
	email_verified boolean NOT NULL DEFAULT false,
	image text,
	is_active boolean NOT NULL DEFAULT true,
	-- HaveIBeenPwned - czy hasło było sprawdzone i czy jest bezpieczne
	password_compromised boolean DEFAULT false,
	password_last_checked_at timestamptz,
	-- Last Login Method tracking
	last_login_method text, -- 'password', 'passkey', 'oauth'
	last_login_at timestamptz,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_email_lower ON "user" (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_user_last_login ON "user" (last_login_at DESC);

-- =============================================================================
-- TABELA: session (sesje użytkowników)
-- =============================================================================
CREATE TABLE IF NOT EXISTS session (
	id text PRIMARY KEY,
	user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	token text NOT NULL UNIQUE,
	expires_at timestamptz NOT NULL,
	ip_address text,
	user_agent text,
	-- Organizacje - aktywna organizacja i zespół w sesji
	active_organization_id text,
	active_team_id text,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_session_user_id ON session (user_id);
CREATE INDEX IF NOT EXISTS idx_session_token ON session (token);
CREATE INDEX IF NOT EXISTS idx_session_expires_at ON session (expires_at);

-- =============================================================================
-- TABELA: account (konta OAuth i credential)
-- =============================================================================
CREATE TABLE IF NOT EXISTS account (
	id text PRIMARY KEY,
	user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	account_id text NOT NULL,
	provider_id text NOT NULL,
	access_token text,
	refresh_token text,
	id_token text,
	access_token_expires_at timestamptz,
	refresh_token_expires_at timestamptz,
	scope text,
	password text,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz NOT NULL DEFAULT now(),
	UNIQUE (provider_id, account_id)
);

CREATE INDEX IF NOT EXISTS idx_account_user_id ON account (user_id);
CREATE INDEX IF NOT EXISTS idx_account_provider ON account (provider_id, account_id);

-- =============================================================================
-- TABELA: verification (tokeny weryfikacyjne)
-- =============================================================================
CREATE TABLE IF NOT EXISTS verification (
	id text PRIMARY KEY,
	identifier text NOT NULL,
	value text NOT NULL,
	expires_at timestamptz NOT NULL,
	user_id text REFERENCES "user"(id) ON DELETE CASCADE,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verification_identifier ON verification (identifier);
CREATE INDEX IF NOT EXISTS idx_verification_expires ON verification (expires_at);

-- =============================================================================
-- TABELA: passkey (WebAuthn/U2F - klucze sprzętowe)
-- =============================================================================
CREATE TABLE IF NOT EXISTS passkey (
	id text PRIMARY KEY,
	user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	-- Nazwa klucza (np. "YubiKey 5", "Titan Security Key")
	name text,
	-- Klucz publiczny (base64 encoded)
	public_key text NOT NULL,
	-- Credential ID z WebAuthn (base64 encoded)
	credential_id text NOT NULL,
	-- Counter do zapobiegania atakom replay
	counter integer NOT NULL DEFAULT 0,
	-- Typ urządzenia (platform, cross-platform)
	device_type text NOT NULL,
	-- Czy klucz ma backup (np. w chmurze)
	backed_up boolean NOT NULL DEFAULT false,
	-- Metody transportu (usb, nfc, ble, internal)
	transports text, -- JSON array
	-- AAGUID - identyfikator typu autentyfikatora
	aaguid text,
	-- Timestamps
	created_at timestamptz DEFAULT now(),
	updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_passkey_user_id ON passkey (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_passkey_credential_id ON passkey (credential_id);
CREATE INDEX IF NOT EXISTS idx_passkey_aaguid ON passkey (aaguid);

-- =============================================================================
-- TABELA: organization (organizacje)
-- =============================================================================
CREATE TABLE IF NOT EXISTS organization (
	id text PRIMARY KEY,
	name text NOT NULL,
	slug text NOT NULL UNIQUE,
	logo text,
	-- Metadane organizacji (JSON)
	metadata jsonb,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_organization_slug ON organization (slug);
CREATE INDEX IF NOT EXISTS idx_organization_name ON organization (name);

-- =============================================================================
-- TABELA: member (członkowie organizacji)
-- Obsługuje role: pracownik, analityk, admin
-- =============================================================================
CREATE TABLE IF NOT EXISTS member (
	id text PRIMARY KEY,
	organization_id text NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
	user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	-- Role: pracownik (podstawowy), analityk (raporty), admin (właściciel)
	role text NOT NULL DEFAULT 'pracownik',
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz DEFAULT now(),
	-- Unikalność - użytkownik może być członkiem organizacji tylko raz
	UNIQUE (organization_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_member_organization_id ON member (organization_id);
CREATE INDEX IF NOT EXISTS idx_member_user_id ON member (user_id);
CREATE INDEX IF NOT EXISTS idx_member_role ON member (role);

-- =============================================================================
-- TABELA: team (zespoły wewnątrz organizacji)
-- =============================================================================
CREATE TABLE IF NOT EXISTS team (
	id text PRIMARY KEY,
	organization_id text NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
	name text NOT NULL,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_team_organization_id ON team (organization_id);
CREATE INDEX IF NOT EXISTS idx_team_name ON team (name);

-- =============================================================================
-- TABELA: team_member (członkowie zespołów)
-- =============================================================================
CREATE TABLE IF NOT EXISTS team_member (
	id text PRIMARY KEY,
	team_id text NOT NULL REFERENCES team(id) ON DELETE CASCADE,
	user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	-- Timestamps
	created_at timestamptz DEFAULT now(),
	-- Unikalność - użytkownik może być w zespole tylko raz
	UNIQUE (team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_team_member_team_id ON team_member (team_id);
CREATE INDEX IF NOT EXISTS idx_team_member_user_id ON team_member (user_id);

-- =============================================================================
-- TABELA: invitation (zaproszenia do organizacji)
-- =============================================================================
CREATE TABLE IF NOT EXISTS invitation (
	id text PRIMARY KEY,
	organization_id text NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
	email text NOT NULL,
	-- Rola przypisana po zaakceptowaniu zaproszenia
	role text NOT NULL DEFAULT 'member',
	-- Status zaproszenia
	status text NOT NULL DEFAULT 'pending',
	-- Kto zaprosił
	inviter_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	-- Opcjonalnie zespół
	team_id text REFERENCES team(id) ON DELETE SET NULL,
	-- Wygasanie
	expires_at timestamptz NOT NULL,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invitation_organization_id ON invitation (organization_id);
CREATE INDEX IF NOT EXISTS idx_invitation_email ON invitation (email);
CREATE INDEX IF NOT EXISTS idx_invitation_status ON invitation (status);
CREATE INDEX IF NOT EXISTS idx_invitation_inviter_id ON invitation (inviter_id);
CREATE INDEX IF NOT EXISTS idx_invitation_expires_at ON invitation (expires_at);

-- =============================================================================
-- TABELA: organization_role (dynamiczne role w organizacji - opcjonalne)
-- =============================================================================
CREATE TABLE IF NOT EXISTS organization_role (
	id text PRIMARY KEY,
	organization_id text NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
	-- Nazwa roli
	role text NOT NULL,
	-- Uprawnienia (JSON)
	permission jsonb NOT NULL DEFAULT '{}',
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now(),
	updated_at timestamptz DEFAULT now(),
	-- Unikalność roli w organizacji
	UNIQUE (organization_id, role)
);

CREATE INDEX IF NOT EXISTS idx_organization_role_org_id ON organization_role (organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_role_role ON organization_role (role);

-- =============================================================================
-- TABELA: password_history (historia haseł dla HaveIBeenPwned)
-- =============================================================================
CREATE TABLE IF NOT EXISTS password_history (
	id text PRIMARY KEY,
	user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	-- Hash hasła (nie samo hasło!)
	password_hash text NOT NULL,
	-- Czy było sprawdzone w HIBP
	hibp_checked boolean NOT NULL DEFAULT false,
	-- Czy było kompromitowane
	hibp_compromised boolean DEFAULT false,
	-- Liczba wystąpień w HIBP
	hibp_count integer DEFAULT 0,
	-- Timestamps
	created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_history_user_id ON password_history (user_id);
CREATE INDEX IF NOT EXISTS idx_password_history_created ON password_history (created_at DESC);

-- =============================================================================
-- TABELA: login_history (historia logowań dla Last Login Method)
-- =============================================================================
CREATE TABLE IF NOT EXISTS login_history (
	id text PRIMARY KEY,
	user_id text NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
	-- Metoda logowania: password, passkey, oauth, 2fa, backup_code
	login_method text NOT NULL,
	-- Szczegóły
	ip_address text,
	user_agent text,
	-- Lokalizacja (opcjonalnie)
	country text,
	city text,
	-- Sukces logowania
	success boolean NOT NULL DEFAULT true,
	-- Przyczyna niepowodzenia (jeśli success = false)
	failure_reason text,
	-- Timestamp
	created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_login_history_user_id ON login_history (user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_created ON login_history (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_history_method ON login_history (login_method);
CREATE INDEX IF NOT EXISTS idx_login_history_success ON login_history (success);

-- =============================================================================
-- TRIGGERY - automatyczna aktualizacja updated_at
-- =============================================================================

CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
	NEW.updated_at = now();
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- User
DROP TRIGGER IF EXISTS set_timestamp ON "user";
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON "user"
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Session
DROP TRIGGER IF EXISTS set_timestamp ON session;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON session
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Account
DROP TRIGGER IF EXISTS set_timestamp ON account;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON account
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Verification
DROP TRIGGER IF EXISTS set_timestamp ON verification;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON verification
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Passkey
DROP TRIGGER IF EXISTS set_timestamp ON passkey;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON passkey
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Organization
DROP TRIGGER IF EXISTS set_timestamp ON organization;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON organization
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Member
DROP TRIGGER IF EXISTS set_timestamp ON member;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON member
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Team
DROP TRIGGER IF EXISTS set_timestamp ON team;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON team
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Invitation
DROP TRIGGER IF EXISTS set_timestamp ON invitation;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON invitation
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Organization Role
DROP TRIGGER IF EXISTS set_timestamp ON organization_role;
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON organization_role
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- =============================================================================
-- TRIGGER - aktualizacja last_login w tabeli user
-- =============================================================================

CREATE OR REPLACE FUNCTION update_user_last_login()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.success = true THEN
		UPDATE "user" 
		SET 
			last_login_method = NEW.login_method,
			last_login_at = NEW.created_at
		WHERE id = NEW.user_id;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_last_login ON login_history;
CREATE TRIGGER update_last_login
AFTER INSERT ON login_history
FOR EACH ROW
EXECUTE FUNCTION update_user_last_login();

-- =============================================================================
-- DOMYŚLNE ROLE ORGANIZACJI
-- =============================================================================
-- Role będą tworzone dynamicznie przez aplikację, ale można dodać funkcję
-- do inicjalizacji domyślnych ról

CREATE OR REPLACE FUNCTION create_default_organization_roles(org_id text)
RETURNS void AS $$
BEGIN
	-- Rola: admin (właściciel - pełne uprawnienia)
	INSERT INTO organization_role (id, organization_id, role, permission)
	VALUES (
		uuidv7()::text,
		org_id,
		'admin',
		'{
			"organization": ["create", "read", "update", "delete"],
			"member": ["create", "read", "update", "delete"],
			"team": ["create", "read", "update", "delete"],
			"invitation": ["create", "read", "update", "delete"],
			"reports": ["create", "read", "update", "delete"],
			"analytics": ["create", "read", "update", "delete"]
		}'::jsonb
	) ON CONFLICT (organization_id, role) DO NOTHING;
	
	-- Rola: analityk (dostęp do raportów i analityk)
	INSERT INTO organization_role (id, organization_id, role, permission)
	VALUES (
		uuidv7()::text,
		org_id,
		'analityk',
		'{
			"organization": ["read"],
			"member": ["read"],
			"team": ["read"],
			"reports": ["create", "read", "update", "delete"],
			"analytics": ["create", "read", "update"]
		}'::jsonb
	) ON CONFLICT (organization_id, role) DO NOTHING;
	
	-- Rola: pracownik (podstawowy dostęp)
	INSERT INTO organization_role (id, organization_id, role, permission)
	VALUES (
		uuidv7()::text,
		org_id,
		'pracownik',
		'{
			"organization": ["read"],
			"member": ["read"],
			"team": ["read"]
		}'::jsonb
	) ON CONFLICT (organization_id, role) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- TRIGGER - automatyczne tworzenie domyślnych ról przy nowej organizacji
-- =============================================================================

CREATE OR REPLACE FUNCTION on_organization_created()
RETURNS TRIGGER AS $$
BEGIN
	PERFORM create_default_organization_roles(NEW.id);
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS organization_created ON organization;
CREATE TRIGGER organization_created
AFTER INSERT ON organization
FOR EACH ROW
EXECUTE FUNCTION on_organization_created();

-- =============================================================================
-- KOMENTARZE DO TABEL
-- =============================================================================

COMMENT ON TABLE "user" IS 'Główna tabela użytkowników Better-Auth z obsługą PassKeys';
COMMENT ON COLUMN "user".password_compromised IS 'Czy hasło było wykryte jako skompromitowane w HIBP';
COMMENT ON COLUMN "user".last_login_method IS 'Ostatnia metoda logowania: password, passkey, oauth';

COMMENT ON TABLE session IS 'Sesje użytkowników z obsługą aktywnej organizacji/zespołu';
COMMENT ON COLUMN session.active_organization_id IS 'ID aktywnej organizacji w tej sesji';
COMMENT ON COLUMN session.active_team_id IS 'ID aktywnego zespołu w tej sesji';

COMMENT ON TABLE passkey IS 'Klucze WebAuthn/U2F (PassKeys) użytkowników';
COMMENT ON COLUMN passkey.credential_id IS 'Unikalny identyfikator credential z WebAuthn';
COMMENT ON COLUMN passkey.counter IS 'Counter do zapobiegania atakom replay';
COMMENT ON COLUMN passkey.aaguid IS 'Authenticator Attestation GUID - typ autentyfikatora';

COMMENT ON TABLE organization IS 'Organizacje w systemie';
COMMENT ON COLUMN organization.metadata IS 'Dodatkowe metadane organizacji (JSON)';

COMMENT ON TABLE member IS 'Członkowie organizacji z rolami: pracownik, analityk, admin';
COMMENT ON COLUMN member.role IS 'Rola użytkownika: pracownik (podstawowy), analityk (raporty), admin (właściciel)';

COMMENT ON TABLE team IS 'Zespoły wewnątrz organizacji';
COMMENT ON TABLE team_member IS 'Powiązanie użytkowników z zespołami';

COMMENT ON TABLE invitation IS 'Zaproszenia do organizacji';
COMMENT ON COLUMN invitation.status IS 'Status: pending, accepted, rejected, canceled';

COMMENT ON TABLE organization_role IS 'Dynamiczne definicje ról i uprawnień w organizacji';
COMMENT ON COLUMN organization_role.permission IS 'Uprawnienia roli (JSON object z zasobami i akcjami)';

COMMENT ON TABLE password_history IS 'Historia haseł do sprawdzania w HaveIBeenPwned';
COMMENT ON TABLE login_history IS 'Historia logowań do śledzenia metod logowania';