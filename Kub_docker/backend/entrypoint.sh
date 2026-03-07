#!/bin/bash
set -e

# Wait for database to accept connections
echo "==> Waiting for database..."
python -c "
import asyncio, sys, os
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

async def wait():
    url = os.environ['DATABASE_URL']
    engine = create_async_engine(url, pool_pre_ping=True)
    for attempt in range(30):
        try:
            async with engine.connect() as conn:
                await conn.execute(text('SELECT 1'))
            print('Database is ready.')
            await engine.dispose()
            return
        except Exception:
            print(f'Waiting for database... (attempt {attempt + 1}/30)')
            await asyncio.sleep(2)
    await engine.dispose()
    print('Database not ready after 60s')
    sys.exit(1)

asyncio.run(wait())
"

# Run migrations (skip if SKIP_MIGRATIONS is set)
if [ "${SKIP_MIGRATIONS}" != "true" ]; then
    echo "==> Running Alembic migrations..."
    alembic upgrade head
fi

echo "==> Starting application..."
exec "$@"
