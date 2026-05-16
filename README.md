# Livesport Data Engineer task

SQL-based data quality comparison of two affiliate player data dumps
(`players_data_v1.csv`, `players_data_v2.csv`).

Submission for the Livesport Summer Internship 2026 Data Engineer task.

## Layout

```
.
├── load_data.py            # imports both CSVs into livesport.db
├── sql/
│   ├── 01_explore.sql      # exploratory pass: keys, time range, cardinalities
│   └── 02_differences.sql  # six formal checks from the task brief
└── README.md
```

The CSVs and the generated SQLite file are gitignored, so the repo only
contains source.

## Running it

Requires Python 3.9+ and the `sqlite3` CLI. Both come preinstalled on macOS
and most Linux distros. No third-party Python packages.

Drop `players_data_v1.csv` and `players_data_v2.csv` into the project root,
then load them into SQLite:

```
python3 load_data.py
```

Expected output:

```
players_v1: 197,516 rows
players_v2: 205,070 rows
```

Then run the analyses:

```
sqlite3 livesport.db < sql/01_explore.sql
sqlite3 livesport.db < sql/02_differences.sql
```

## Schema notes

- `tracker_id` is loaded as TEXT to preserve leading zeros and to tolerate
  non-numeric values present in v2.
- Natural key for both tables is `(user_id, as_of)`, not `user_id` alone:
  the data is panel-shaped (one row per user per month).
