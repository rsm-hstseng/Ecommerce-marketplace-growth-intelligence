
from pathlib import Path
import pandas as pd

# 1. Locate the project folder
project_root = Path(__file__).resolve().parents[1]

# 2. Locate the raw CSV files
data_dir = project_root / "data" / "raw"

# 3. Find all CSV files
csv_files = sorted(data_dir.glob("*.csv"))

print(f"Found {len(csv_files)} CSV files\n")

# 4. Inspect each dataset
for file in csv_files:

    # Read CSV into a DataFrame
    df = pd.read_csv(file)

    print("=" * 60)
    print(f"File: {file.name}")
    print(f"Rows: {len(df):,}")
    print(f"Columns: {len(df.columns)}")

    # Check missing values
    print(f"Missing values: {df.isnull().sum().sum():,}")

    # Check duplicate rows
    print(f"Duplicate rows: {df.duplicated().sum():,}")

    # Display column names
    print(f"Column names: {list(df.columns)}")

    print()
