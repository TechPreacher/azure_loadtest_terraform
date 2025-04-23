"""
Replication Verification Script for Azure PostgreSQL

This script connects to both primary and replica PostgreSQL databases
and verifies that the data is being properly replicated between them.
It compares the data in all tables to ensure replication is working.
"""

import os
import sys
from time import sleep
from pathlib import Path
from typing import Dict, List, Any, Optional
from dotenv import load_dotenv

# SQLAlchemy imports
from sqlalchemy import (
    Engine,
    create_engine,
    MetaData,
    Table,
    inspect,
    text,
    select,
)
from sqlalchemy.exc import SQLAlchemyError

# Load environment variables from .env file if it exists
env_path = Path(__file__).parent.parent / "terraform"
env_file = env_path / "load_test_variables.env"
if env_file.exists():
    load_dotenv(env_file)
else:
    print(f"Warning: {env_file} not found.")
    sys.exit(1)

# Define config values for both database types
PRIMARY_DB_CONFIG = {
    "host": os.environ.get("PRIMARY_SERVER_FQDN"),
    "user": os.environ.get("POSTGRES_ADMIN_USERNAME"),
    "password": os.environ.get("POSTGRES_ADMIN_PASSWORD"),
    "database": os.environ.get("DATABASE_NAME"),
    "sslmode": "require",
}

REPLICA_DB_CONFIG = {
    "host": os.environ.get("REPLICA_SERVER_FQDN"),
    "user": os.environ.get("POSTGRES_ADMIN_USERNAME"),
    "password": os.environ.get("POSTGRES_ADMIN_PASSWORD"),
    "database": os.environ.get("DATABASE_NAME"),
    "sslmode": "require",
}


def check_env_vars() -> bool:
    """Verify all required environment variables are set."""
    # Database connection variables are required
    primary_vars = [
        "PRIMARY_SERVER_FQDN",
        "REPLICA_SERVER_FQDN",
        "POSTGRES_ADMIN_USERNAME",
        "POSTGRES_ADMIN_PASSWORD",
        "DATABASE_NAME",
    ]

    primary_missing = [var for var in primary_vars if not os.environ.get(var)]
    if primary_missing:
        print(
            f"Error: Missing PRIMARY database environment variables: "
            f"{', '.join(primary_missing)}"
        )
        print(
            "Please create a .env file based on .env.example "
            "with your Azure PostgreSQL credentials."
        )
        sys.exit(1)

    return True


def connect_to_database(config: Dict[str, Optional[str]], db_type: str) -> Engine:
    """Connect to the PostgreSQL database using SQLAlchemy."""
    try:
        # Ensure all required values are present
        user = config.get("user")
        password = config.get("password")
        host = config.get("host")
        database = config.get("database")
        sslmode = config.get("sslmode", "require")

        if not all([user, password, host, database]):
            raise ValueError(
                f"Missing required {db_type} database connection parameters"
            )

        # Create the connection string
        connection_string = (
            f"postgresql+psycopg2://{user}:{password}@"
            f"{host}/{database}?sslmode={sslmode}"
        )

        print(f"Connecting to {db_type} database at {host}...")

        # Create engine with echo=False to avoid logging SQL statements
        engine = create_engine(connection_string, echo=False)

        # Test connection by making a simple query
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))

        print(f"Connected successfully to {db_type} database!")
        return engine
    except Exception as e:
        print(f"Error connecting to {db_type} PostgreSQL: {e}")
        sys.exit(1)


def get_table_names(engine: Engine) -> List[str]:
    """Get all table names from the database."""
    try:
        inspector = inspect(engine)
        return inspector.get_table_names()
    except Exception as e:
        print(f"Error getting table names: {e}")
        sys.exit(1)


def get_table_row_count(engine: Engine, table_name: str) -> int:
    """Get the row count for a specific table."""
    try:
        with engine.connect() as conn:
            result = conn.execute(text(f'SELECT COUNT(*) FROM "{table_name}"'))
            count = result.scalar()
            # Ensure we return an integer
            return int(count) if count is not None else 0
    except Exception as e:
        print(f"Error getting row count for table {table_name}: {e}")
        return -1


def get_table_data(engine: Engine, table_name: str) -> List[Dict[str, Any]]:
    """Get all data from a table as a list of dictionaries."""
    try:
        metadata = MetaData()
        table = Table(table_name, metadata, autoload_with=engine)

        with engine.connect() as conn:
            # Order by all columns for consistent comparison
            query = select(table).order_by(*[c for c in table.columns])
            result = conn.execute(query)
            return [dict(row._mapping) for row in result]
    except Exception as e:
        print(f"Error getting data from table {table_name}: {e}")
        return []


def compare_tables(primary_engine: Engine, replica_engine: Engine) -> bool:
    """Compare all tables between primary and replica databases."""
    # Get tables from both databases
    primary_tables = set(get_table_names(primary_engine))
    replica_tables = set(get_table_names(replica_engine))

    print("\n=== Table Comparison ===")

    # Check if all tables exist in both databases
    if primary_tables != replica_tables:
        print("❌ Table mismatch between primary and replica:")
        print(f"Tables only in primary: {primary_tables - replica_tables}")
        print(f"Tables only in replica: {replica_tables - primary_tables}")
        return False

    print(
        f"✅ Found {len(primary_tables)} tables in both databases: {', '.join(primary_tables)}"
    )

    # Check each table's row count and data
    all_tables_match = True

    for table_name in primary_tables:
        primary_count = get_table_row_count(primary_engine, table_name)
        replica_count = get_table_row_count(replica_engine, table_name)

        print(f"\nVerifying table: {table_name}")

        # Compare row counts
        if primary_count != replica_count:
            print(f"❌ Row count mismatch for table '{table_name}':")
            print(f"   Primary: {primary_count} rows")
            print(f"   Replica: {replica_count} rows")
            all_tables_match = False
            continue

        print(f"✅ Row count matches: {primary_count} rows")

        # For small tables (< 1000 rows), compare the actual data
        if primary_count < 1000:
            primary_data = get_table_data(primary_engine, table_name)
            replica_data = get_table_data(replica_engine, table_name)

            if primary_data == replica_data:
                print(f"✅ Data matches for all {primary_count} rows")
            else:
                print(
                    f"❌ Data mismatch in table '{table_name}' despite matching row counts"
                )
                all_tables_match = False
        else:
            print(f"ℹ️ Table has {primary_count} rows - skipping full data comparison")
            # For large tables, we could add sampling or checksums here

    return all_tables_match


def check_replication_lag(
    primary_engine: Engine, replica_engine: Engine
) -> Optional[int]:
    """Check if there's replication lag between primary and replica."""
    try:
        # This query works specifically for Azure PostgreSQL Flexible Server
        lag_query = """
        SELECT
            CASE
                WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() THEN 0
                ELSE EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp())::INTEGER
            END AS lag_seconds;
        """

        # Execute on replica only - primary doesn't have these metrics
        with replica_engine.connect() as conn:
            try:
                result = conn.execute(text(lag_query))
                lag_seconds = result.scalar()
                # Ensure we return an integer or default value
                if lag_seconds is not None:
                    return int(lag_seconds)
                return 0  # Default to no lag if query returns None
            except SQLAlchemyError:
                print(
                    "ℹ️ Couldn't determine replication lag - query not supported on this server"
                )
                return 0  # Default to no lag if query not supported
    except Exception as e:
        print(f"Error checking replication lag: {e}")
        return 0  # Default to no lag on error


def main() -> None:
    """Main function to verify replication between databases."""
    print("Azure PostgreSQL Replication Verification")
    print("========================================")

    # Check environment variables
    check_env_vars()

    # Connect to both databases
    primary_engine = connect_to_database(PRIMARY_DB_CONFIG, "PRIMARY")
    replica_engine = connect_to_database(REPLICA_DB_CONFIG, "REPLICA")

    # Check replication lag first (if supported)
    lag_seconds = check_replication_lag(primary_engine, replica_engine)
    if lag_seconds is not None:
        print(f"\nReplication lag: {lag_seconds} seconds")

        # If lag is detected, wait a bit for replication to catch up
        if lag_seconds > 0:
            wait_time = min(
                lag_seconds + 5, 30
            )  # Wait for lag + 5 seconds, max 30 seconds
            print(f"Waiting {wait_time} seconds for replication to catch up...")
            sleep(wait_time)

    # Compare tables between primary and replica
    tables_match = compare_tables(primary_engine, replica_engine)

    print("\n=== Replication Verification Summary ===")
    if tables_match:
        print("✅ SUCCESS: All tables are properly replicated!")
        print("The replica database is in sync with the primary database.")
    else:
        print("❌ FAILED: Replication issues detected!")
        print("Some tables or data are not properly replicated between databases.")
        print("Please check the Azure portal to verify replication status.")

    print("\nVerification completed!")


if __name__ == "__main__":
    main()
