-- ==============================================================================
-- Bystronic Job History Schema
-- ==============================================================================
-- Relational tables for Job/Plan/Run/RunPart data from the Bystronic
-- BySoft Cell Control Cut OPC UA History interface.
--
-- These are regular PostgreSQL tables (NOT hypertables) because this
-- data is relational and low-frequency (tens of records per day).
-- ==============================================================================

-- ==============================================================================
-- Job Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS bystronic_job (
    job_guid        UUID PRIMARY KEY,
    asset_id        INTEGER NOT NULL REFERENCES asset(id),
    name            TEXT,
    description     TEXT,
    nc_program_file TEXT,
    user_info_1     TEXT,
    user_info_2     TEXT,
    user_info_3     TEXT,
    raw_json        JSONB,
    first_seen_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- Plan Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS bystronic_plan (
    plan_guid           UUID PRIMARY KEY,
    job_guid            UUID NOT NULL REFERENCES bystronic_job(job_guid),
    name                TEXT,
    material_name       TEXT,
    material_thickness  DOUBLE PRECISION,  -- mm
    total_runs          INTEGER,
    total_parts         INTEGER,
    plan_state          TEXT,              -- raw integer-as-string uit OPC UA
    plan_state_name     TEXT,              -- enum mapping (Inactive/Started/Completed/PartiallyCompleted/Failed)
    estimated_cut_time  DOUBLE PRECISION,  -- seconds
    size_x              DOUBLE PRECISION,  -- mm (used cut area)
    size_y              DOUBLE PRECISION,  -- mm (used cut area)
    material_size_x     DOUBLE PRECISION,  -- mm (raw sheet)
    material_size_y     DOUBLE PRECISION,  -- mm (raw sheet)
    raw_json            JSONB,
    first_seen_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bystronic_plan_job ON bystronic_plan(job_guid);

-- ==============================================================================
-- Run Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS bystronic_run (
    run_guid            UUID PRIMARY KEY,
    plan_guid           UUID REFERENCES bystronic_plan(plan_guid),
    job_guid            UUID NOT NULL REFERENCES bystronic_job(job_guid),
    run_number          INTEGER,
    cut_state           TEXT,              -- raw integer-as-string uit OPC UA
    cut_state_name      TEXT,              -- enum mapping (None/Started/WaitMaterial/Cutting/Completed/Aborted)
    cut_start_time      TIMESTAMPTZ,
    cut_end_time        TIMESTAMPTZ,
    actual_cut_time     DOUBLE PRECISION,  -- seconds
    actual_stop_time    DOUBLE PRECISION,  -- seconds
    actual_wait_time    DOUBLE PRECISION,  -- seconds
    sorting_enabled     BOOLEAN,
    recorded_at         TIMESTAMPTZ,       -- RunInfo.TimeStamp (niet in spec, wel in response)
    raw_json            JSONB,
    first_seen_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bystronic_run_job ON bystronic_run(job_guid);
CREATE INDEX IF NOT EXISTS idx_bystronic_run_time ON bystronic_run(cut_start_time);

-- ==============================================================================
-- Run Part Table
-- ==============================================================================
CREATE TABLE IF NOT EXISTS bystronic_run_part (
    id                  SERIAL PRIMARY KEY,
    run_guid            UUID NOT NULL REFERENCES bystronic_run(run_guid),
    part_id             INTEGER,
    part_ref_id         INTEGER,
    part_number         INTEGER,
    part_name           TEXT,
    cut_state           TEXT,
    cut_start_time      TIMESTAMPTZ,
    cut_end_time        TIMESTAMPTZ,
    actual_cut_time     DOUBLE PRECISION,  -- seconds
    actual_stop_time    DOUBLE PRECISION,  -- seconds
    actual_wait_time    DOUBLE PRECISION,  -- seconds
    stack_area_type     TEXT,
    raw_json            JSONB,
    first_seen_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(run_guid, part_id)
);

CREATE INDEX IF NOT EXISTS idx_bystronic_run_part_run ON bystronic_run_part(run_guid);

-- ==============================================================================
-- Sync State Table
-- ==============================================================================
-- Houdt per sync-key bij tot welke recorded_at de incremental poll gekomen is.
-- Wordt door de Node-RED bystronic backfill/poll flow gebruikt.
CREATE TABLE IF NOT EXISTS bystronic_sync_state (
    key                 TEXT PRIMARY KEY,
    last_recorded_at    TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- Machine Info Table
-- ==============================================================================
-- 1 rij per asset met statische metadata uit Machine.MachineInfo struct
-- (equipmentNumber, machineType, software versies etc.). Updates via
-- one-shot Node-RED read bij opstart of handmatige trigger.
CREATE TABLE IF NOT EXISTS bystronic_machine_info (
    asset_id              INTEGER PRIMARY KEY REFERENCES asset(id),
    equipment_number      TEXT,
    machine_type          TEXT,
    cutting_head_type     TEXT,
    by_motion_version     TEXT,
    by_vision_version     TEXT,
    raw_json              JSONB,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- Grant permissions to existing users
-- ==============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON bystronic_job TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON bystronic_plan TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON bystronic_run TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON bystronic_run_part TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON bystronic_sync_state TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON bystronic_machine_info TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON SEQUENCE bystronic_run_part_id_seq TO kafkatopostgresqlv2;

GRANT SELECT ON bystronic_job TO grafanareader;
GRANT SELECT ON bystronic_plan TO grafanareader;
GRANT SELECT ON bystronic_run TO grafanareader;
GRANT SELECT ON bystronic_run_part TO grafanareader;
GRANT SELECT ON bystronic_sync_state TO grafanareader;
GRANT SELECT ON bystronic_machine_info TO grafanareader;
