#!/usr/bin/env python3
"""Read and display Poker Night Requirements Excel file."""

import pandas as pd
import sys

filepath = r"C:\Users\farooq sarwar\Downloads\Poker_Night_Requirements.xlsx"

try:
    xl = pd.ExcelFile(filepath)
    print("Sheet names:", xl.sheet_names)
    print()
    
    for sheet in xl.sheet_names:
        df = pd.read_excel(xl, sheet_name=sheet)
        print(f"=== Sheet: {sheet} ===")
        print(f"Dimensions: {df.shape}")
        print(f"Columns: {list(df.columns)}")
        print()
        # Print all rows
        for idx, row in df.iterrows():
            # Convert to string, handling NaN
            row_str = {}
            for col in df.columns:
                val = row[col]
                if pd.isna(val):
                    row_str[col] = ""
                else:
                    row_str[col] = str(val)
            print(f"Row {idx}: {row_str}")
        print()
    
except Exception as e:
    print(f"Error reading file: {e}")
    sys.exit(1)