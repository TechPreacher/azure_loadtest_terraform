"""
Azure PostgreSQL Python Application

This script initializes and populates an Azure Database for PostgreSQL instance.
It creates tables, loads sample data, and demonstrates basic database operations.
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Optional
from dotenv import load_dotenv

# SQLAlchemy imports
from sqlalchemy import (
    Engine,
    create_engine,
    inspect,
    Column,
    Integer,
    String,
    Float,
    Boolean,
    DateTime,
    ForeignKey,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
import uuid
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker, relationship


# Load environment variables from .env file if it exists
env_path = Path(__file__).parent
env_file = env_path / ".env"
if env_file.exists():
    load_dotenv(env_file)
else:
    print("Warning: .env file not found. Using environment variables.")

# Define database configuration
DB_CONFIG = {
    "host": os.environ.get("AZURE_POSTGRES_PRIMARY_HOST"),
    "user": os.environ.get("AZURE_POSTGRES_PRIMARY_USER"),
    "password": os.environ.get("AZURE_POSTGRES_PRIMARY_PASSWORD"),
    "database": os.environ.get("AZURE_POSTGRES_PRIMARY_DB"),
    "sslmode": os.environ.get("AZURE_POSTGRES_PRIMARY_SSL_MODE", "require"),
}

# Define SQLAlchemy Base and Models
Base = declarative_base()


class Product(Base):
    __tablename__ = "products"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    category = Column(String(50), nullable=False)
    price = Column(Float(precision=10, decimal_return_scale=2), nullable=False)
    in_stock = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, server_default=func.now())

    # Relationship with Order model
    orders = relationship("Order", back_populates="product")

    def __repr__(self) -> str:
        return (f"<Product(id={self.id}, name='{self.name}', "
                f"category='{self.category}', price={self.price})>")


class Order(Base):
    __tablename__ = "orders"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.id"))
    quantity = Column(Integer, nullable=False)
    order_date = Column(DateTime, server_default=func.now())

    # Relationship with Product model
    product = relationship("Product", back_populates="orders")

    def __repr__(self) -> str:
        return f"<Order(id={self.id}, product_id={self.product_id}, quantity={self.quantity})>"


def check_env_vars() -> bool:
    """Verify all required environment variables are set."""
    required_vars = [
        "AZURE_POSTGRES_PRIMARY_HOST",
        "AZURE_POSTGRES_PRIMARY_USER",
        "AZURE_POSTGRES_PRIMARY_PASSWORD",
        "AZURE_POSTGRES_PRIMARY_DB",
    ]

    missing_vars = [var for var in required_vars if not os.environ.get(var)]
    if missing_vars:
        print(
            f"Error: Missing database environment variables: "
            f"{', '.join(missing_vars)}"
        )
        print(
            "Please create a .env file based on .env.example "
            "with your Azure PostgreSQL credentials."
        )
        sys.exit(1)

    return True


def connect_to_database(config: Dict[str, Optional[str]]) -> Engine:
    """Connect to the Azure PostgreSQL database using SQLAlchemy."""
    try:
        # Make sure all required values are present
        user = config.get('user')
        password = config.get('password')
        host = config.get('host')
        database = config.get('database')
        sslmode = config.get('sslmode', 'require')
        if not all([user, password, host, database]):
            raise ValueError("Missing required database connection parameters")
        
        # Create the connection string
        connection_string = (
            f"postgresql+psycopg2://{user}:{password}@"
            f"{host}/{database}?sslmode={sslmode}"
        )

        print(f"Connecting to database at {host}...")

        # Create engine with echo=False to avoid logging SQL statements
        engine = create_engine(connection_string, echo=False)

        # Test connection by making a simple query
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))

        print("Connected successfully to database!")
        return engine
    except Exception as e:
        print(f"Error connecting to PostgreSQL: {e}")
        sys.exit(1)


def check_tables_exist(engine: Engine) -> bool:
    """Check if tables already exist in the database using SQLAlchemy."""
    try:
        inspector = inspect(engine)
        products_exist = "products" in inspector.get_table_names()
        orders_exist = "orders" in inspector.get_table_names()

        return products_exist or orders_exist
    except Exception as e:
        print(f"Error checking tables: {e}")
        sys.exit(1)


def drop_tables(engine: Engine) -> None:
    """Drop existing tables from the database using SQLAlchemy."""
    try:
        # Drop tables using the metadata
        # Order matters due to foreign key constraints
        Base.metadata.drop_all(engine)
        print("Tables dropped successfully!")
    except Exception as e:
        print(f"Error dropping tables: {e}")
        sys.exit(1)


def create_tables(engine: Engine) -> None:
    """Create necessary tables in the database using SQLAlchemy."""
    try:
        # Check if tables already exist
        tables_exist = check_tables_exist(engine)

        if tables_exist:
            print("Tables already exist in the database.")
            response = (
                input("Do you want to delete and re-create the tables? (y/n): ")
                .strip()
                .lower()
            )

            if response == "y":
                drop_tables(engine)
            else:
                print("Using existing tables.")
                return

        # Create all tables defined in Base metadata
        Base.metadata.create_all(engine)
        print("Tables created successfully!")
    except Exception as e:
        print(f"Error creating tables: {e}")
        sys.exit(1)


def load_sample_data(engine: Engine) -> None:
    """Load sample data from JSON file into the database using SQLAlchemy."""
    try:
        # Create a session to interact with the database
        Session = sessionmaker(bind=engine)
        session = Session()

        # Check if products table already has data
        product_count = session.query(Product).count()

        if product_count > 0:
            print(
                f"Products table already contains {product_count} records. "
                "Skipping data import."
            )
            session.close()
            return

        # Load sample data from JSON file
        data_path = Path(__file__).parent / "data" / "sample_data.json"
        with open(data_path, "r") as file:
            products_data = json.load(file)

        # Insert products
        for product_data in products_data:
            product = Product(
                id=uuid.UUID(product_data["id"]),
                name=product_data["name"],
                category=product_data["category"],
                price=product_data["price"],
                in_stock=product_data["in_stock"],
            )
            session.add(product)

        # Commit the changes
        session.commit()
        print(f"Imported {len(products_data)} products successfully!")
        session.close()
    except FileNotFoundError:
        print("Error: Sample data file not found at data/sample_data.json")
        sys.exit(1)
    except Exception as e:
        print(f"Error loading sample data: {e}")
        sys.exit(1)


def query_data(engine: Engine) -> None:
    """Run and display some sample queries using SQLAlchemy."""
    try:
        # Create a session to interact with the database
        Session = sessionmaker(bind=engine)
        session = Session()

        # Check if products table has data before querying
        product_count = session.query(Product).count()
        if product_count == 0:
            print("\nNo products found to query.")
            session.close()
            return

        print("\n----- Database Query Results -----")

        # Query 1: All products
        print("\nAll Products:")
        products = session.query(Product).order_by(Product.created_at).all()
        for product in products:
            print(
                f"ID: {product.id}, Name: {product.name}, "
                f"Category: {product.category}, Price: ${product.price}, "
                f"In Stock: {product.in_stock}"
            )

        # Query 2: Group by category
        print("\nProducts by Category:")
        # Use a simpler query to avoid potential database function differences
        categories = session.query(Product.category).distinct().all()
        for (category,) in categories:
            count = (
                session.query(func.count(Product.id))
                .filter(Product.category == category)
                .scalar()
            )
            avg_price = (
                session.query(func.avg(Product.price))
                .filter(Product.category == category)
                .scalar()
            )
            print(
                f"Category: {category}, Count: {count}, Avg Price: ${avg_price:.2f}"
            )

        # Query 3: In-stock products
        print("\nIn-Stock Products:")
        in_stock_count = (
            session.query(Product).filter(Product.in_stock.is_(True)).count()
        )
        print(f"Total in-stock products: {in_stock_count}")

        session.close()
    except Exception as e:
        print(f"Error querying data: {e}")
        sys.exit(1)


def main() -> None:
    """Main function to run the application."""
    print("Azure PostgreSQL Database Setup")
    print("===============================")

    # Check environment variables
    check_env_vars()

    # Connect to PostgreSQL with SQLAlchemy
    engine = connect_to_database(DB_CONFIG)

    # Create database schema
    create_tables(engine)

    # Load sample data
    load_sample_data(engine)

    # Query and display data
    query_data(engine)

    print("\nDatabase setup completed successfully!")


if __name__ == "__main__":
    main()