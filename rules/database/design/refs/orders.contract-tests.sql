-- =====================================================================
-- orders.contract-tests.sql
-- Contract tests (section 7) for orders.reference.sql.
-- Run as a superuser:  psql -v ON_ERROR_STOP=1 -f orders.contract-tests.sql
-- Everything runs in one transaction and is rolled back.
-- Any failure raises and stops the run; a full pass prints ALL PASSED.
-- =====================================================================
\set QUIET on
BEGIN;

CREATE SCHEMA app_test;
GRANT USAGE ON SCHEMA app_test TO PUBLIC;

-- Statement must fail with exactly this constraint / rule name.
CREATE FUNCTION app_test.expect_rule(p_sql text, p_name text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE c text; s text; m text;
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS c = CONSTRAINT_NAME, s = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    IF c = p_name THEN RETURN; END IF;
    RAISE EXCEPTION 'FAIL [%] got constraint=% sqlstate=% msg=% sql=%', p_name, c, s, m, p_sql;
  END;
  RAISE EXCEPTION 'FAIL [%] statement succeeded: %', p_name, p_sql;
END $$;

-- Statement must fail with this SQLSTATE (and optional column).
CREATE FUNCTION app_test.expect_state(p_sql text, p_state text, p_column text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE s text; col text; m text;
BEGIN
  BEGIN
    EXECUTE p_sql;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, col = COLUMN_NAME, m = MESSAGE_TEXT;
    IF s = p_state AND (p_column IS NULL OR col = p_column) THEN RETURN; END IF;
    RAISE EXCEPTION 'FAIL [%/%] got sqlstate=% column=% msg=% sql=%', p_state, p_column, s, col, m, p_sql;
  END;
  RAISE EXCEPTION 'FAIL [%] statement succeeded: %', p_state, p_sql;
END $$;

CREATE FUNCTION app_test.expect_eq(p_actual anyelement, p_expected anyelement, p_label text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_actual IS DISTINCT FROM p_expected THEN
    RAISE EXCEPTION 'FAIL [%] expected % got %', p_label, p_expected, p_actual;
  END IF;
END $$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app_test TO PUBLIC;

-- Fixtures (superuser; tenants has no RLS)
INSERT INTO core.tenants (id, name) VALUES
  ('00000000-0000-7000-8000-000000000001', 'Tenant One'),
  ('00000000-0000-7000-8000-000000000002', 'Tenant Two');

-- ---------------------------------------------------------------------
-- 1. Shared functions
-- ---------------------------------------------------------------------
SELECT app_test.expect_eq(substr(app.new_id()::text, 15, 1), '7', 'uuidv7 version nibble');
SELECT app_test.expect_eq(substr(app.new_id()::text, 20, 1) IN ('8','9','a','b'), true, 'uuid RFC variant');
SELECT app_test.expect_eq(app.crockford_base32('\x0123456789abcdef0123456789abcdef'::bytea),
                          '04HMASW9NF6YY0938NKRKAYDXW', 'crockford known vector');
SELECT app_test.expect_eq(app.new_public_id('ord') ~ '^ord_[0-9A-HJKMNP-TV-Z]{26}$', true, 'public_id format');

SELECT app_test.expect_eq(app.is_canonical_text('abc'),               true,  'canonical plain');
SELECT app_test.expect_eq(app.is_canonical_text('a b'),               true,  'canonical inner space');
SELECT app_test.expect_eq(app.is_canonical_text(' abc'),              false, 'leading space');
SELECT app_test.expect_eq(app.is_canonical_text(E'abc\t'),            false, 'trailing tab');
SELECT app_test.expect_eq(app.is_canonical_text(E'\nabc'),            false, 'leading newline');
SELECT app_test.expect_eq(app.is_canonical_text(U&'\00A0abc'),        false, 'leading NBSP');
SELECT app_test.expect_eq(app.is_canonical_text(U&'abc\3000'),        false, 'trailing ideographic space');
SELECT app_test.expect_eq(app.is_canonical_text('e' || U&'\0301'),    false, 'non-NFC');
SELECT app_test.expect_eq(app.is_canonical_text(''),                  false, 'empty');

-- ---------------------------------------------------------------------
-- 2. Orders as the owning feature role
-- ---------------------------------------------------------------------
SET LOCAL ROLE orders_writer;
SELECT app.set_request_context('00000000-0000-7000-8000-000000000001', 'test-actor');

-- Valid native order (no source/external_id)
INSERT INTO core.orders (tenant_id, id, correlation_id, status, currency, amount)
VALUES ('00000000-0000-7000-8000-000000000001', '00000000-0000-7000-8000-0000000000a1',
        gen_random_uuid(), 'pending', 'USD', 10.50);

-- Valid upstream order
INSERT INTO core.orders (tenant_id, source, external_id, correlation_id, status, currency, amount)
VALUES ('00000000-0000-7000-8000-000000000001', 'partner_api', 'EXT-1',
        gen_random_uuid(), 'pending', 'KWD', 1.125);

-- Upsert on the partial unique index works and does not duplicate
INSERT INTO core.orders (tenant_id, source, external_id, correlation_id, status, currency, amount)
VALUES ('00000000-0000-7000-8000-000000000001', 'partner_api', 'EXT-1',
        gen_random_uuid(), 'pending', 'KWD', 2.000)
ON CONFLICT (tenant_id, source, external_id) WHERE external_id IS NOT NULL
DO UPDATE SET amount = EXCLUDED.amount;
SELECT app_test.expect_eq((SELECT count(*) FROM core.orders WHERE external_id = 'EXT-1'), 1::bigint, 'upsert no duplicate');

-- Column and constraint rules
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', gen_random_uuid(), 'pending', 'USD', -1)$$,
  'orders_amount_nonneg_ck');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', gen_random_uuid(), 'pending', 'JPY', 10.5)$$,
  'orders_amount_scale_tg');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', gen_random_uuid(), 'pending', 'KWD', 1.1255)$$,
  'orders_amount_scale_tg');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, source, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', 'partner_api', gen_random_uuid(), 'pending', 'USD', 1)$$,
  'orders_source_external_pair_ck');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, source, external_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', 'partner_api', 'EXT-1', gen_random_uuid(), 'pending', 'USD', 1)$$,
  'orders_tenant_source_ext_uk');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, source, external_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', 'partner_api', U&'\00A0EXT-2', gen_random_uuid(), 'pending', 'USD', 1)$$,
  'orders_external_id_canon_ck');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, source, external_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', 'partner_api', repeat('x', 65), gen_random_uuid(), 'pending', 'USD', 1)$$,
  'orders_external_id_len_ck');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, source, external_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', 'nope', 'EXT-3', gen_random_uuid(), 'pending', 'USD', 1)$$,
  'orders_source_fk');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', gen_random_uuid(), 'bogus', 'USD', 1)$$,
  'orders_status_fk');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', gen_random_uuid(), 'pending', 'usd', 1)$$,
  'orders_currency_fk');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, public_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', 'ord_bad', gen_random_uuid(), 'pending', 'USD', 1)$$,
  'orders_public_id_format_ck');
SELECT app_test.expect_state($$INSERT INTO core.orders (tenant_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', 'pending', 'USD', 1)$$,
  '23502', 'correlation_id');

-- Status-dependent fields
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount, shipped_at)
  VALUES ('00000000-0000-7000-8000-000000000001', gen_random_uuid(), 'pending', 'USD', 1, now())$$,
  'orders_shipped_at_premature_tg');
SELECT app_test.expect_rule($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000001', gen_random_uuid(), 'shipped', 'USD', 1)$$,
  'orders_shipped_at_required_tg');

-- Transitions
SELECT app_test.expect_rule($$UPDATE core.orders SET status = 'delivered', shipped_at = now()
  WHERE id = '00000000-0000-7000-8000-0000000000a1'$$, 'orders_status_transition_tg');

UPDATE core.orders SET status = 'paid' WHERE id = '00000000-0000-7000-8000-0000000000a1';
UPDATE core.orders SET status = 'shipped', shipped_at = '2026-11-01T10:00:00Z'
  WHERE id = '00000000-0000-7000-8000-0000000000a1';
-- The v1.0 CHECK rejected this: shipped_at must survive later statuses.
UPDATE core.orders SET status = 'delivered' WHERE id = '00000000-0000-7000-8000-0000000000a1';
UPDATE core.orders SET status = 'returned'  WHERE id = '00000000-0000-7000-8000-0000000000a1';
SELECT app_test.expect_eq((SELECT shipped_at FROM core.orders WHERE id = '00000000-0000-7000-8000-0000000000a1'),
                          '2026-11-01T10:00:00Z'::timestamptz, 'shipped_at kept after delivered/returned');

SELECT app_test.expect_rule($$UPDATE core.orders SET shipped_at = now()
  WHERE id = '00000000-0000-7000-8000-0000000000a1'$$, 'orders_shipped_at_immutable_tg');
SELECT app_test.expect_rule($$UPDATE core.orders SET shipped_at = NULL
  WHERE id = '00000000-0000-7000-8000-0000000000a1'$$, 'orders_shipped_at_immutable_tg');

-- Immutability
SELECT app_test.expect_rule($$UPDATE core.orders SET public_id = app.new_public_id('ord')
  WHERE id = '00000000-0000-7000-8000-0000000000a1'$$, 'orders_identity_immutable_tg');
SELECT app_test.expect_rule($$UPDATE core.orders SET correlation_id = gen_random_uuid()
  WHERE id = '00000000-0000-7000-8000-0000000000a1'$$, 'orders_identity_immutable_tg');
SELECT app_test.expect_rule($$UPDATE core.orders SET tenant_id = '00000000-0000-7000-8000-000000000002'
  WHERE id = '00000000-0000-7000-8000-0000000000a1'$$, 'orders_identity_immutable_tg');
SELECT app_test.expect_rule($$UPDATE core.orders SET created_at = '2000-01-01'
  WHERE id = '00000000-0000-7000-8000-0000000000a1'$$, 'orders_identity_immutable_tg');

-- Server-owned columns: version counts every update (4 status changes above), client values ignored
SELECT app_test.expect_eq((SELECT version FROM core.orders WHERE id = '00000000-0000-7000-8000-0000000000a1'),
                          5::bigint, 'version incremented by trigger');
UPDATE core.orders SET version = 999 WHERE id = '00000000-0000-7000-8000-0000000000a1';
SELECT app_test.expect_eq((SELECT version FROM core.orders WHERE id = '00000000-0000-7000-8000-0000000000a1'),
                          6::bigint, 'client-supplied version ignored');
INSERT INTO core.orders (tenant_id, id, correlation_id, status, currency, amount, created_at, version)
VALUES ('00000000-0000-7000-8000-000000000001', '00000000-0000-7000-8000-0000000000a2',
        gen_random_uuid(), 'pending', 'INR', 5, '2000-01-01', 42);
SELECT app_test.expect_eq((SELECT (created_at > '2020-01-01', version) FROM core.orders
                           WHERE id = '00000000-0000-7000-8000-0000000000a2')::text, '(t,1)', 'created_at/version overwritten on insert');

-- Grants: no DELETE, no TRUNCATE, no lookup writes
SELECT app_test.expect_state($$DELETE FROM core.orders$$, '42501');
SELECT app_test.expect_state($$TRUNCATE core.orders$$, '42501');
SELECT app_test.expect_state($$UPDATE ref.currencies SET minor_unit = 3 WHERE code = 'USD'$$, '42501');

-- ---------------------------------------------------------------------
-- 3. Tenant isolation (RLS)
-- ---------------------------------------------------------------------
-- Writing into another tenant is refused by the policy
SELECT app_test.expect_state($$INSERT INTO core.orders (tenant_id, correlation_id, status, currency, amount)
  VALUES ('00000000-0000-7000-8000-000000000002', gen_random_uuid(), 'pending', 'USD', 1)$$, '42501');

-- Tenant two sees nothing of tenant one, even without a WHERE clause
SELECT app.set_request_context('00000000-0000-7000-8000-000000000002', 'test-actor');
SELECT app_test.expect_eq((SELECT count(*) FROM core.orders), 0::bigint, 'RLS hides other tenant rows');
UPDATE core.orders SET amount = 0;  -- touches nothing
SELECT app.set_request_context('00000000-0000-7000-8000-000000000001', 'test-actor');
SELECT app_test.expect_eq((SELECT count(*) FROM core.orders WHERE amount = 0), 0::bigint, 'cross-tenant update was a no-op');

-- No context: fail closed with an error
SELECT set_config('app.tenant_id', '', true);
SELECT app_test.expect_state($$SELECT count(*) FROM core.orders$$, '42501');
SELECT app.set_request_context('00000000-0000-7000-8000-000000000001', 'test-actor');

-- Reader role is subject to the same policy
SET LOCAL ROLE app_reader;
SELECT app_test.expect_eq((SELECT count(*) FROM core.orders), 3::bigint, 'reader sees own tenant');
SELECT app_test.expect_state($$UPDATE core.orders SET amount = 1$$, '42501');

-- Integrity checker bypasses RLS, read-only, no context needed
SET LOCAL ROLE integrity_checker;
SELECT set_config('app.tenant_id', '', true);
SELECT app_test.expect_eq((SELECT count(*) FROM core.orders), 3::bigint, 'checker sees all tenants');
SELECT app_test.expect_state($$UPDATE core.orders SET amount = 1$$, '42501');

-- ---------------------------------------------------------------------
-- 4. Lookup attribute immutability (as owner)
-- ---------------------------------------------------------------------
SET LOCAL ROLE migrator;
SELECT app_test.expect_rule($$UPDATE ref.currencies SET minor_unit = 3 WHERE code = 'USD'$$,
                            'currencies_attr_immutable_tg');
SELECT app_test.expect_rule($$UPDATE ref.order_status SET requires_shipped_at = false WHERE code = 'delivered'$$,
                            'order_status_attr_immutable_tg');
SELECT app_test.expect_rule($$DELETE FROM ref.order_status WHERE code = 'pending'$$,
                            'order_transition_from_fk');

\echo ALL PASSED
ROLLBACK;
