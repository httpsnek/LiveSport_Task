"""Load players_data_v1.csv and players_data_v2.csv into a local SQLite
database as two separate tables with explicit column types."""

import csv
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DB_PATH = HERE / "livesport.db"
BATCH_SIZE = 5000

# tracker_id stays TEXT: values have leading zeros and v2 contains
# non-numeric strings in this column.
COLUMNS: list[tuple[str, str]] = [
    ("as_of",                  "TEXT"),
    ("country",                "TEXT"),
    ("tracker_id",             "TEXT"),
    ("tracker_name",           "TEXT"),
    ("user_id",                "INTEGER"),
    ("signup_date",            "TEXT"),
    ("signup_year",            "INTEGER"),
    ("first_deposit_date",     "TEXT"),
    ("first_deposit_year",     "INTEGER"),
    ("first_deposit_amount",   "REAL"),
    ("sports_bets_turnover",   "REAL"),
    ("sportsbook_net_revenue", "REAL"),
    ("total_net_revenue",      "REAL"),
    ("deposits",               "REAL"),
    ("revenue",                "REAL"),
    ("project_name",           "TEXT"),
    ("platform",               "TEXT"),
]
COL_NAMES = [c[0] for c in COLUMNS]


def coerce(value: str, sqlite_type: str):
    """Cast a CSV cell to the target type. Bad values fall through as text
    so the row still loads and the issue can be spotted in the analysis step."""
    if value == "":
        return None
    if sqlite_type == "INTEGER":
        try:
            return int(value)
        except ValueError:
            return value
    if sqlite_type == "REAL":
        try:
            return float(value)
        except ValueError:
            return value
    return value


def load(conn: sqlite3.Connection, csv_path: Path, table: str) -> int:
    """Recreate `table` and load `csv_path` into it. Returns the row count."""
    cur = conn.cursor()
    cur.execute(f"DROP TABLE IF EXISTS {table};")
    cols_sql = ", ".join(f"{name} {ctype}" for name, ctype in COLUMNS)
    cur.execute(f"CREATE TABLE {table} ({cols_sql});")

    placeholders = ",".join("?" * len(COLUMNS))
    insert_sql = f"INSERT INTO {table} VALUES ({placeholders})"

    n = 0
    batch: list[list] = []
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        if header != COL_NAMES:
            raise SystemExit(f"unexpected header in {csv_path.name}: {header}")
        for row in reader:
            batch.append([coerce(v, COLUMNS[i][1]) for i, v in enumerate(row)])
            n += 1
            if len(batch) >= BATCH_SIZE:
                cur.executemany(insert_sql, batch)
                batch.clear()
        if batch:
            cur.executemany(insert_sql, batch)
    conn.commit()
    return n


def main() -> None:
    if DB_PATH.exists():
        DB_PATH.unlink()

    conn = sqlite3.connect(DB_PATH)
    try:
        for csv_name, table in [
            ("players_data_v1.csv", "players_v1"),
            ("players_data_v2.csv", "players_v2"),
        ]:
            n = load(conn, HERE / csv_name, table)
            print(f"{table}: {n:,} rows")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
