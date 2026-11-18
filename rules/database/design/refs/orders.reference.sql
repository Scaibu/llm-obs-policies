-- =====================================================================
-- orders.reference.sql
-- Reference implementation of Data Contract v1.2 for entity: orders
--
-- Target : PostgreSQL 14+ (verified on 16), UTF8 database encoding
-- Section A runs once per database as a superuser.
-- Sections B onward run as the migration role (migrator).
--
-- This file is a reference, not a migration to apply as-is. Real
-- migrations are generated from context.yml and split per section 9.
-- =====================================================================


-- ---------------------------------------------------------------------
-- A. Bootstrap (superuser, once per database)
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF pg_catalog.getdatabaseencoding() <> 'UTF8' THEN
    RAISE EXCEPTION 'Data contract requires UTF8 encoding, found %',
      pg_catalog.getdatabaseencoding();
  END IF;
END $$;

-- Roles are cluster-wide. Login users are granted membership in these.
CREATE ROLE migrator          NOLOGIN;            -- owns every schema object
CREATE ROLE orders_writer     NOLOGIN;            -- owning feature of core.orders
CREATE ROLE app_reader        NOLOGIN;            -- read-only feature access
CREATE ROLE integrity_checker NOLOGIN BYPASSRLS;  -- section 10 jobs, read-only, cross-tenant

DO $$
BEGIN
  EXECUTE format('GRANT CREATE ON DATABASE %I TO migrator', current_database());
  EXECUTE format('REVOKE CREATE, TEMPORARY ON DATABASE %I FROM PUBLIC', current_database());
END $$;

-- Extensions live in their own schema, never on an application search_path.
CREATE SCHEMA ext AUTHORIZATION migrator;
CREATE EXTENSION IF NOT EXISTS pgcrypto   SCHEMA ext;
CREATE EXTENSION IF NOT EXISTS btree_gist SCHEMA ext;

REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- New functions created by migrator are not executable by PUBLIC.
ALTER DEFAULT PRIVILEGES FOR ROLE migrator REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;


-- ---------------------------------------------------------------------
-- B. Migration session settings (section 9.3: every migration)
-- ---------------------------------------------------------------------
SET ROLE migrator;
SET lock_timeout      = '3s';     -- fail fast instead of queueing traffic behind us
SET statement_timeout = '5min';
SET search_path       = pg_catalog;

CREATE SCHEMA app;    -- shared functions
CREATE SCHEMA ref;    -- lookup and reference tables
CREATE SCHEMA core;   -- tenant-scoped entities
REVOKE ALL ON SCHEMA app, ref, core FROM PUBLIC;


-- ---------------------------------------------------------------------
-- C. Shared functions (section 1B, 3D)
--    Every function pins search_path. String literals containing
--    backslashes use E'' so behaviour does not depend on
--    standard_conforming_strings.
-- ---------------------------------------------------------------------

-- Raise a storage-gate rule violation in a form the error registry can map.
CREATE FUNCTION app.raise_rule(p_constraint text, p_table text, p_column text, p_message text)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  RAISE EXCEPTION USING
    ERRCODE    = '23514',
    CONSTRAINT = p_constraint,
    TABLE      = coalesce(p_table, ''),
    COLUMN     = coalesce(p_column, ''),
    MESSAGE    = p_message;
END $$;

-- Raise if any listed column differs between two row images.
CREATE FUNCTION app.assert_unchanged(p_old jsonb, p_new jsonb, p_columns text[],
                                     p_constraint text, p_table text)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
DECLARE
  c text;
BEGIN
  FOREACH c IN ARRAY p_columns LOOP
    IF NOT (p_old ? c) THEN
      RAISE EXCEPTION 'assert_unchanged: unknown column % on %', c, p_table;
    END IF;
    IF (p_old -> c) IS DISTINCT FROM (p_new -> c) THEN
      PERFORM app.raise_rule(p_constraint, p_table, c, format('%s.%s is immutable', p_table, c));
    END IF;
  END LOOP;
END $$;

-- Generic trigger: TG_ARGV[0] = rule name, TG_ARGV[1..] = protected columns.
CREATE FUNCTION app.forbid_column_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  PERFORM app.assert_unchanged(to_jsonb(OLD), to_jsonb(NEW),
                               TG_ARGV[1:TG_NARGS - 1], TG_ARGV[0], TG_TABLE_NAME);
  RETURN NEW;
END $$;

-- UUIDv7. PG14 to 17 implementation: 48-bit Unix ms timestamp + random bits.
-- Not monotonic within the same millisecond (PG18 native is, per backend).
-- On PG18+, replace the body with: SELECT pg_catalog.uuidv7()
CREATE FUNCTION app.new_id()
RETURNS uuid
LANGUAGE sql VOLATILE PARALLEL SAFE
SET search_path = pg_catalog
AS $$
  SELECT encode(
           set_bit(set_bit(
             overlay(uuid_send(gen_random_uuid())
                     PLACING substring(int8send(floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint) FROM 3)
                     FROM 1 FOR 6),
           52, 1), 53, 1),
         'hex')::uuid
$$;

-- Crockford base32, MSB-first, zero-padded at the end. 16 bytes -> 26 chars.
CREATE FUNCTION app.crockford_base32(p bytea)
RETURNS text
LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE
SET search_path = pg_catalog
AS $$
DECLARE
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  nbits    int := length(p) * 8;
  nchars   int := (nbits + 4) / 5;
  result   text := '';
  v        int;
  bitpos   int;
BEGIN
  FOR i IN 0 .. nchars - 1 LOOP
    v := 0;
    FOR j IN 0 .. 4 LOOP
      bitpos := i * 5 + j;
      v := v << 1;
      -- get_bit numbers bits LSB-first within each byte.
      IF bitpos < nbits AND get_bit(p, (bitpos / 8) * 8 + (7 - bitpos % 8)) = 1 THEN
        v := v | 1;
      END IF;
    END LOOP;
    result := result || substr(alphabet, v + 1, 1);
  END LOOP;
  RETURN result;
END $$;

-- External id: prefix + 128 random bits. Never derived from app.new_id().
CREATE FUNCTION app.new_public_id(p_prefix text)
RETURNS text
LANGUAGE sql VOLATILE PARALLEL SAFE
SET search_path = pg_catalog
AS $$
  SELECT p_prefix || '_' || app.crockford_base32(ext.gen_random_bytes(16))
$$;

-- Canonical whitespace set (section 2.3), pinned as an explicit list:
-- ASCII 0009-000D, 0020, and Unicode White_Space 0085 00A0 1680 2000-200A
-- 2028 2029 202F 205F 3000. Ingress uses the same list (parity test 7.4).
CREATE FUNCTION app.canonical_ws_class()
RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
SET search_path = pg_catalog
AS $$
  SELECT E'[\\u0009-\\u000D\\u0020\\u0085\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000]'
$$;

CREATE FUNCTION app.is_canonical_text(t text)
RETURNS boolean
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
SET search_path = pg_catalog
AS $$
  SELECT t <> ''
     AND t IS NFC NORMALIZED
     AND t !~ ('^' || app.canonical_ws_class())
     AND t !~ (app.canonical_ws_class() || '$')
$$;

-- Request context (sections 3C, 5.4). Transaction-local only.
-- Must be called inside an explicit transaction; in autocommit the
-- context vanishes after this statement and the next query fails closed.
CREATE FUNCTION app.set_request_context(p_tenant_id uuid, p_actor_id text)
RETURNS void
LANGUAGE plpgsql VOLATILE
SET search_path = pg_catalog
AS $$
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22004', MESSAGE = 'tenant_id must not be null';
  END IF;
  PERFORM set_config('app.tenant_id', p_tenant_id::text, true);
  PERFORM set_config('app.actor_id', coalesce(p_actor_id, ''), true);
END $$;

-- Fails closed: no tenant context means an error, never "all rows" or "no rows".
CREATE FUNCTION app.current_tenant_id()
RETURNS uuid
LANGUAGE plpgsql STABLE PARALLEL SAFE
SET search_path = pg_catalog
AS $$
DECLARE
  v text := current_setting('app.tenant_id', true);
BEGIN
  IF v IS NULL OR v = '' THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'tenant context not set',
      HINT    = 'call app.set_request_context() inside the transaction';
  END IF;
  RETURN v::uuid;
END $$;


-- ---------------------------------------------------------------------
-- D. Lookup tables (sections 2.4, 4.1, 4.7)
--    Attributes that rules depend on are immutable once written.
-- ---------------------------------------------------------------------
CREATE TABLE ref.id_source (
  code        text NOT NULL,
  description text NOT NULL,
  CONSTRAINT id_source_pk                   PRIMARY KEY (code),
  CONSTRAINT id_source_code_format_ck       CHECK (code ~ '^[a-z][a-z0-9_]{1,31}$'),
  CONSTRAINT id_source_description_len_ck   CHECK (char_length(description) BETWEEN 1 AND 200),
  CONSTRAINT id_source_description_canon_ck CHECK (app.is_canonical_text(description))
);

CREATE TABLE ref.currencies (
  code       text     NOT NULL,
  minor_unit smallint NOT NULL,
  CONSTRAINT currencies_pk               PRIMARY KEY (code),
  CONSTRAINT currencies_code_format_ck   CHECK (code ~ '^[A-Z]{3}$'),
  CONSTRAINT currencies_minor_unit_ck    CHECK (minor_unit BETWEEN 0 AND 4)  -- bounded by numeric(20,4)
);

CREATE TABLE ref.order_status (
  code                text    NOT NULL,
  requires_shipped_at boolean NOT NULL,
  CONSTRAINT order_status_pk             PRIMARY KEY (code),
  CONSTRAINT order_status_code_format_ck CHECK (code ~ '^[a-z][a-z_]{1,31}$')
);

CREATE TABLE ref.order_transition (
  from_status text NOT NULL,
  to_status   text NOT NULL,
  CONSTRAINT order_transition_pk       PRIMARY KEY (from_status, to_status),
  CONSTRAINT order_transition_from_fk  FOREIGN KEY (from_status) REFERENCES ref.order_status (code) ON DELETE RESTRICT,
  CONSTRAINT order_transition_to_fk    FOREIGN KEY (to_status)   REFERENCES ref.order_status (code) ON DELETE RESTRICT,
  CONSTRAINT order_transition_self_ck  CHECK (from_status <> to_status)
);
CREATE INDEX order_transition_to_ix ON ref.order_transition (to_status);

CREATE TRIGGER id_source_guard BEFORE UPDATE ON ref.id_source
  FOR EACH ROW EXECUTE FUNCTION app.forbid_column_change('id_source_attr_immutable_tg', 'code');
CREATE TRIGGER currencies_guard BEFORE UPDATE ON ref.currencies
  FOR EACH ROW EXECUTE FUNCTION app.forbid_column_change('currencies_attr_immutable_tg', 'code', 'minor_unit');
CREATE TRIGGER order_status_guard BEFORE UPDATE ON ref.order_status
  FOR EACH ROW EXECUTE FUNCTION app.forbid_column_change('order_status_attr_immutable_tg', 'code', 'requires_shipped_at');

-- Example seed data. Every status at or after "shipped" requires shipped_at.
INSERT INTO ref.id_source (code, description) VALUES
  ('partner_api', 'Orders received from the partner API');
INSERT INTO ref.currencies (code, minor_unit) VALUES
  ('USD', 2), ('EUR', 2), ('INR', 2), ('JPY', 0), ('KWD', 3);
INSERT INTO ref.order_status (code, requires_shipped_at) VALUES
  ('pending', false), ('paid', false), ('cancelled', false),
  ('shipped', true), ('delivered', true), ('returned', true);
INSERT INTO ref.order_transition (from_status, to_status) VALUES
  ('pending', 'paid'), ('pending', 'cancelled'), ('paid', 'cancelled'),
  ('paid', 'shipped'), ('shipped', 'delivered'), ('delivered', 'returned');


-- ---------------------------------------------------------------------
-- E. Tenants (stub: only what orders needs)
-- ---------------------------------------------------------------------
CREATE TABLE core.tenants (
  id         uuid        NOT NULL DEFAULT app.new_id(),
  public_id  text        NOT NULL DEFAULT app.new_public_id('ten'),
  name       text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT tenants_pk               PRIMARY KEY (id),
  CONSTRAINT tenants_public_id_uk     UNIQUE (public_id),
  CONSTRAINT tenants_public_id_fmt_ck CHECK (public_id ~ '^ten_[0-9A-HJKMNP-TV-Z]{26}$'),
  CONSTRAINT tenants_name_len_ck      CHECK (char_length(name) BETWEEN 1 AND 200),
  CONSTRAINT tenants_name_canon_ck    CHECK (app.is_canonical_text(name))
);


-- ---------------------------------------------------------------------
-- F. Orders
-- ---------------------------------------------------------------------
CREATE TABLE core.orders (
  tenant_id      uuid          NOT NULL,
  id             uuid          NOT NULL DEFAULT app.new_id(),
  public_id      text          NOT NULL DEFAULT app.new_public_id('ord'),
  source         text,                      -- null: natively created order
  external_id    text,                      -- null: natively created order
  correlation_id uuid          NOT NULL,
  status         text          NOT NULL,
  currency       text          NOT NULL,
  amount         numeric(20,4) NOT NULL,
  shipped_at     timestamptz,               -- null until a status requiring it
  created_at     timestamptz   NOT NULL DEFAULT now(),
  updated_at     timestamptz   NOT NULL DEFAULT now(),
  version        bigint        NOT NULL DEFAULT 1,

  CONSTRAINT orders_pk                      PRIMARY KEY (tenant_id, id),
  CONSTRAINT orders_public_id_uk            UNIQUE (public_id),
  CONSTRAINT orders_public_id_format_ck     CHECK (public_id ~ '^ord_[0-9A-HJKMNP-TV-Z]{26}$'),
  CONSTRAINT orders_tenant_fk               FOREIGN KEY (tenant_id) REFERENCES core.tenants (id)     ON DELETE RESTRICT,
  CONSTRAINT orders_source_fk               FOREIGN KEY (source)    REFERENCES ref.id_source (code)  ON DELETE RESTRICT,
  CONSTRAINT orders_status_fk               FOREIGN KEY (status)    REFERENCES ref.order_status (code) ON DELETE RESTRICT,
  CONSTRAINT orders_currency_fk             FOREIGN KEY (currency)  REFERENCES ref.currencies (code) ON DELETE RESTRICT,
  CONSTRAINT orders_source_external_pair_ck CHECK (num_nonnulls(source, external_id) IN (0, 2)),
  CONSTRAINT orders_external_id_len_ck      CHECK (char_length(external_id) BETWEEN 1 AND 64),
  CONSTRAINT orders_external_id_canon_ck    CHECK (app.is_canonical_text(external_id)),
  CONSTRAINT orders_amount_nonneg_ck        CHECK (amount >= 0),
  CONSTRAINT orders_version_pos_ck          CHECK (version >= 1)
);

-- Upsert target for upstream ingestion:
--   ON CONFLICT (tenant_id, source, external_id) WHERE external_id IS NOT NULL
CREATE UNIQUE INDEX orders_tenant_source_ext_uk
  ON core.orders (tenant_id, source, external_id)
  WHERE external_id IS NOT NULL;

-- Single dispatcher per table (section 4A). Rule order is fixed here,
-- not by trigger names. Unknown status/currency are skipped so the FK
-- reports them under its own name.
CREATE FUNCTION core.orders_before_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
DECLARE
  v_requires_shipped boolean;
  v_minor_unit       smallint;
  v_check_amount     boolean;
BEGIN
  -- 1. Identity and history immutability
  IF TG_OP = 'UPDATE' THEN
    PERFORM app.assert_unchanged(to_jsonb(OLD), to_jsonb(NEW),
      ARRAY['tenant_id', 'id', 'public_id', 'correlation_id', 'created_at'],
      'orders_identity_immutable_tg', TG_TABLE_NAME);

    IF OLD.shipped_at IS NOT NULL AND NEW.shipped_at IS DISTINCT FROM OLD.shipped_at THEN
      PERFORM app.raise_rule('orders_shipped_at_immutable_tg', TG_TABLE_NAME, 'shipped_at',
                             'shipped_at cannot change once set');
    END IF;
  END IF;

  -- 2. State transition and 3. status-dependent fields
  SELECT s.requires_shipped_at INTO v_requires_shipped
    FROM ref.order_status s WHERE s.code = NEW.status;

  IF FOUND THEN
    IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
      IF NOT EXISTS (SELECT 1 FROM ref.order_transition t
                      WHERE t.from_status = OLD.status AND t.to_status = NEW.status) THEN
        PERFORM app.raise_rule('orders_status_transition_tg', TG_TABLE_NAME, 'status',
                               format('illegal transition %s -> %s', OLD.status, NEW.status));
      END IF;
    END IF;

    IF v_requires_shipped AND NEW.shipped_at IS NULL THEN
      PERFORM app.raise_rule('orders_shipped_at_required_tg', TG_TABLE_NAME, 'shipped_at',
                             format('status %s requires shipped_at', NEW.status));
    ELSIF NOT v_requires_shipped AND NEW.shipped_at IS NOT NULL THEN
      PERFORM app.raise_rule('orders_shipped_at_premature_tg', TG_TABLE_NAME, 'shipped_at',
                             format('status %s does not allow shipped_at', NEW.status));
    END IF;
  END IF;

  -- 4. Amount precision must match the currency's minor unit
  IF TG_OP = 'INSERT' THEN
    v_check_amount := true;
  ELSE
    v_check_amount := NEW.amount IS DISTINCT FROM OLD.amount
                   OR NEW.currency IS DISTINCT FROM OLD.currency;
  END IF;

  IF v_check_amount AND NEW.amount IS NOT NULL THEN
    SELECT c.minor_unit INTO v_minor_unit FROM ref.currencies c WHERE c.code = NEW.currency;
    IF FOUND AND NEW.amount <> round(NEW.amount, v_minor_unit) THEN
      PERFORM app.raise_rule('orders_amount_scale_tg', TG_TABLE_NAME, 'amount',
                             format('%s allows %s decimal places', NEW.currency, v_minor_unit));
    END IF;
  END IF;

  -- 5. Server-owned columns, always last. Client-supplied values are overwritten.
  IF TG_OP = 'INSERT' THEN
    NEW.created_at := now();
    NEW.updated_at := NEW.created_at;
    NEW.version    := 1;
  ELSE
    NEW.updated_at := now();
    NEW.version    := OLD.version + 1;
  END IF;

  RETURN NEW;
END $$;

CREATE TRIGGER orders_before_write
  BEFORE INSERT OR UPDATE ON core.orders
  FOR EACH ROW EXECUTE FUNCTION core.orders_before_write();


-- ---------------------------------------------------------------------
-- G. Tenant isolation (section 3C)
--    (SELECT ...) makes the planner evaluate the context once per
--    query as an InitPlan instead of once per row.
-- ---------------------------------------------------------------------
ALTER TABLE core.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE core.orders FORCE  ROW LEVEL SECURITY;

CREATE POLICY orders_tenant_isolation ON core.orders
  USING      (tenant_id = (SELECT app.current_tenant_id()))
  WITH CHECK (tenant_id = (SELECT app.current_tenant_id()));


-- ---------------------------------------------------------------------
-- H. Grants (sections 3B, 3D)
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA app, ref, core, ext TO orders_writer, app_reader, integrity_checker;

GRANT EXECUTE ON FUNCTION
  app.new_id(), app.new_public_id(text), app.crockford_base32(bytea),
  app.canonical_ws_class(), app.is_canonical_text(text),
  app.raise_rule(text, text, text, text),
  app.assert_unchanged(jsonb, jsonb, text[], text, text),
  app.set_request_context(uuid, text), app.current_tenant_id()
TO orders_writer;

GRANT EXECUTE ON FUNCTION
  app.set_request_context(uuid, text), app.current_tenant_id()
TO app_reader;

GRANT SELECT ON ALL TABLES IN SCHEMA ref TO orders_writer, app_reader, integrity_checker;

-- Orders are never hard-deleted: cancellation is a status. No DELETE, no TRUNCATE.
GRANT SELECT, INSERT, UPDATE ON core.orders TO orders_writer;
GRANT SELECT                 ON core.orders TO app_reader, integrity_checker;
GRANT SELECT                 ON core.tenants TO integrity_checker;

RESET ROLE;
