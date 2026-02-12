-- Migration script to add new columns for paper trading, multi-currency, and portfolio snapshots.
-- Run this against the PostgreSQL database if ddl-auto=update fails to add columns.

-- User table: add paper trading and currency fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS paper_balance numeric(38,2) DEFAULT 100000;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_paper_trading boolean DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferred_currency varchar(255) DEFAULT 'USD';

-- PortfolioHoldings: add paper mode flag
ALTER TABLE portfolio_holdings ADD COLUMN IF NOT EXISTS is_paper boolean NOT NULL DEFAULT false;

-- Transactions: add paper mode flag
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS is_paper boolean NOT NULL DEFAULT false;

-- Portfolio snapshots table
CREATE TABLE IF NOT EXISTS portfolio_snapshots (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id),
    snapshot_date date NOT NULL,
    total_value numeric(19,4) NOT NULL,
    total_cost_basis numeric(19,4) NOT NULL,
    cash_balance numeric(19,4) NOT NULL,
    holdings_count integer NOT NULL,
    is_paper boolean NOT NULL DEFAULT false,
    created_at timestamp(6),
    UNIQUE (user_id, snapshot_date, is_paper)
);
