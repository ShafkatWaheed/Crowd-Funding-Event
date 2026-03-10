"""One-off script to add all missing columns to the database."""
import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect(
        user="postgres",
        password="mysecretpassword",
        database="event_db",
        host="localhost",
        port=5432,
    )

    statements = [
        # ticket_sales - all columns that might be missing
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS subtotal_cents INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS tax_cents INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS tax_rate DOUBLE PRECISION NOT NULL DEFAULT 0",
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS tax_jurisdiction VARCHAR(32) NOT NULL DEFAULT ''",
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS gateway_transaction_id VARCHAR(128)",
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS gateway_auth_code VARCHAR(64)",
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS scanned_at TIMESTAMPTZ",
        "ALTER TABLE ticket_sales ADD COLUMN IF NOT EXISTS scanned_by_id INTEGER REFERENCES users(id)",

        # sponsor_payments
        "ALTER TABLE sponsor_payments ADD COLUMN IF NOT EXISTS subtotal_cents INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE sponsor_payments ADD COLUMN IF NOT EXISTS tax_cents INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE sponsor_payments ADD COLUMN IF NOT EXISTS tax_rate DOUBLE PRECISION NOT NULL DEFAULT 0",
        "ALTER TABLE sponsor_payments ADD COLUMN IF NOT EXISTS gateway_transaction_id VARCHAR(128)",
        "ALTER TABLE sponsor_payments ADD COLUMN IF NOT EXISTS gateway_auth_code VARCHAR(64)",

        # fundings
        "ALTER TABLE fundings ADD COLUMN IF NOT EXISTS tax_cents BIGINT NOT NULL DEFAULT 0",
        "ALTER TABLE fundings ADD COLUMN IF NOT EXISTS gateway_transaction_id VARCHAR(128)",
        "ALTER TABLE fundings ADD COLUMN IF NOT EXISTS gateway_auth_code VARCHAR(64)",

        # stamp alembic version
        "UPDATE alembic_version SET version_num = 'kkk_add_tax_columns'",
    ]

    for stmt in statements:
        try:
            await conn.execute(stmt)
            print(f"OK: {stmt[:80]}")
        except Exception as e:
            print(f"SKIP: {stmt[:80]} ({e})")

    await conn.close()
    print("\nDone! Restart the backend server.")

asyncio.run(main())
