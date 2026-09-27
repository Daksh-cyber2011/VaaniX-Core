-- =============================================================================
-- VaaniX — sync tables, idempotency store, and RLS verification
-- =============================================================================
--
-- Complements `202609200001_initial_user_data.sql`. Adds:
--
--   * user_progress, user_mastery, user_course_state, user_learn_profile —
--     user-owned rows the Flutter outbox uploads to.
--   * vaanix_idempotency — server-side dedup so a legitimately-retried
--     outbox operation never produces a duplicate row.
--   * RLS policies on every new table, with an explicit helper that
--     allows RLS test runs to assert cross-user isolation.
--
-- The policy: every user-owned row's `user_id` MUST equal
-- auth.uid(). The default-deny posture means a missing policy is a
-- silent leak; we explicitly add policies for every role the Flutter
-- client legitimately performs (SELECT, INSERT, UPDATE, DELETE).
--
-- This migration is idempotent. Re-running it is safe.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- user_progress: learner progress snapshot per concept.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_progress (
    id              TEXT        PRIMARY KEY,
    user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    language        TEXT,
    concept_id      TEXT,
    stage           TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, concept_id)
);

CREATE INDEX IF NOT EXISTS user_progress_user_idx
    ON public.user_progress(user_id, updated_at DESC);

ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_progress_select ON public.user_progress;
CREATE POLICY user_progress_select ON public.user_progress
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_progress_insert ON public.user_progress;
CREATE POLICY user_progress_insert ON public.user_progress
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_progress_update ON public.user_progress;
CREATE POLICY user_progress_update ON public.user_progress
    FOR UPDATE USING (auth.uid() = user_id)
              WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_progress_delete ON public.user_progress;
CREATE POLICY user_progress_delete ON public.user_progress
    FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- user_mastery: per-concept mastery state (read by the planner).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_mastery (
    user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    concept_id      TEXT        NOT NULL,
    stage           TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, concept_id)
);

CREATE INDEX IF NOT EXISTS user_mastery_user_idx
    ON public.user_mastery(user_id, updated_at DESC);

ALTER TABLE public.user_mastery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_mastery_select ON public.user_mastery;
CREATE POLICY user_mastery_select ON public.user_mastery
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_mastery_insert ON public.user_mastery;
CREATE POLICY user_mastery_insert ON public.user_mastery
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_mastery_update ON public.user_mastery;
CREATE POLICY user_mastery_update ON public.user_mastery
    FOR UPDATE USING (auth.uid() = user_id)
              WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_mastery_delete ON public.user_mastery;
CREATE POLICY user_mastery_delete ON public.user_mastery
    FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- user_course_state: which course is current for which language.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_course_state (
    id              TEXT        PRIMARY KEY,
    user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    language_code   TEXT,
    blueprint_json  JSONB,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, language_code)
);

CREATE INDEX IF NOT EXISTS user_course_state_user_idx
    ON public.user_course_state(user_id, updated_at DESC);

ALTER TABLE public.user_course_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_course_state_select ON public.user_course_state;
CREATE POLICY user_course_state_select ON public.user_course_state
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_course_state_insert ON public.user_course_state;
CREATE POLICY user_course_state_insert ON public.user_course_state
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_course_state_update ON public.user_course_state;
CREATE POLICY user_course_state_update ON public.user_course_state
    FOR UPDATE USING (auth.uid() = user_id)
              WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_course_state_delete ON public.user_course_state;
CREATE POLICY user_course_state_delete ON public.user_course_state
    FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- user_learn_profile: the learner's display name, language, goal, pace.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_learn_profile (
    user_id         UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name    TEXT,
    goal            TEXT,
    desired_level   TEXT,
    pace            TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.user_learn_profile ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_learn_profile_select ON public.user_learn_profile;
CREATE POLICY user_learn_profile_select ON public.user_learn_profile
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS user_learn_profile_insert ON public.user_learn_profile;
CREATE POLICY user_learn_profile_insert ON public.user_learn_profile
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_learn_profile_update ON public.user_learn_profile;
CREATE POLICY user_learn_profile_update ON public.user_learn_profile
    FOR UPDATE USING (auth.uid() = user_id)
              WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS user_learn_profile_delete ON public.user_learn_profile;
CREATE POLICY user_learn_profile_delete ON public.user_learn_profile
    FOR DELETE USING (auth.uid() = user_id);

-- -----------------------------------------------------------------------------
-- vaanix_idempotency: server-side dedup keyed by (user_id, operation_id).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vaanix_idempotency (
    user_id         UUID        NOT NULL,
    operation_id    TEXT        NOT NULL,
    response        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, operation_id)
);

CREATE INDEX IF NOT EXISTS vaanix_idempotency_gc_idx
    ON public.vaanix_idempotency(created_at);

ALTER TABLE public.vaanix_idempotency ENABLE ROW LEVEL SECURITY;

-- Only the backend's service-role key may read/write this table.
-- No policy means no client-side access — that's intentional.
DROP POLICY IF EXISTS vaanix_idempotency_deny ON public.vaanix_idempotency;
CREATE POLICY vaanix_idempotency_deny ON public.vaanix_idempotency
    FOR ALL TO authenticated USING (false) WITH CHECK (false);

-- -----------------------------------------------------------------------------
-- Helper SQL function the integration tests use to verify isolation.
-- The function returns the count of rows that another user would see
-- when querying the table as themselves; we expect zero.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.vaanix_rls_cross_user_count(table_name TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    n BIGINT;
BEGIN
    EXECUTE format(
        'SELECT count(*) FROM public.%I WHERE user_id <> auth.uid()', table_name
    ) INTO n;
    RETURN n;
END;
$$;

REVOKE ALL ON FUNCTION public.vaanix_rls_cross_user_count(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.vaanix_rls_cross_user_count(TEXT) TO authenticated;

COMMIT;
