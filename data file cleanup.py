import csv
import re
from datetime import datetime
from pathlib import Path

FILE_PATH = Path(r"c:\Users\wobbl\OneDrive\Documents\GitHub\DPS Sample Task\Senior Data Specialist Hiring Activity - Data File.txt")

DATE_FIELDS = {"BIRTH_DATE", "LATEST_SAT_DATE"}
MONTH_FIELDS = {"GRAD_DATE"}


def normalize_date(value):
    cleaned = (value or "").strip()
    if not cleaned or cleaned == "--":
        return ""

    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", cleaned):
        return cleaned
    if re.fullmatch(r"\d{4}-\d{2}", cleaned):
        return cleaned

    formats = [
        "%m/%d/%Y",
        "%m/%d/%y",
        "%m-%d-%Y",
        "%m-%d-%y",
        "%Y-%m-%d",
        "%Y-%m",
    ]
    for fmt in formats:
        try:
            return datetime.strptime(cleaned, fmt).strftime("%Y-%m-%d")
        except ValueError:
            pass
    return cleaned


def normalize_month(value):
    cleaned = (value or "").strip()
    if not cleaned or cleaned == "--":
        return ""

    if re.fullmatch(r"\d{4}-\d{2}", cleaned):
        return cleaned
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", cleaned):
        return cleaned[:7]

    formats = [
        "%m/%d/%Y",
        "%m/%d/%y",
        "%m-%d-%Y",
        "%m-%d-%y",
        "%Y-%m-%d",
        "%Y-%m",
    ]
    for fmt in formats:
        try:
            return datetime.strptime(cleaned, fmt).strftime("%Y-%m")
        except ValueError:
            pass
    return cleaned

def normalize_gender(value: str) -> str:
    """Normalize the gender field to M or F, leaving other codes blank."""
    cleaned = (value or "").strip()
    if not cleaned or cleaned == "--":
        return ""

    normalized = cleaned.lower()
    if normalized in {"m", "male"}:
        return "M"
    if normalized in {"f", "female"}:
        return "F"
    return ""


def normalize_race_flag(value):
    """Convert any Y/Yes response to 1 and blank/Missing to 0."""
    cleaned = (value or "").strip()
    if not cleaned or cleaned in {"--", " "}:
        return "0"
    if cleaned.lower() in {"y", "yes"}:
        return "1"
    return "0"


def normalize_sat_grade(value):
    """Map SAT grade values to the layout-specific codes."""
    cleaned = (value or "").strip()
    if not cleaned or cleaned in {"--", " ", "NA", "N/A"}:
        return ""

    num = cleaned.strip("0") if cleaned.strip("0") else "0"
    mapping = {
        "6": "11",
        "7": "12",
        "8": "13",
        "10": "",
        "11": "",
    }
    return mapping.get(str(int(num) if num.isdigit() else cleaned), "")


with FILE_PATH.open("r", encoding="utf-8", newline="") as infile:
    reader = csv.DictReader(infile, delimiter="\t")
    rows = list(reader)
    if not rows:
        raise ValueError("No rows found")

    race_columns = {
        "RACE_ETH_CUBAN",
        "RACE_ETH_MEXICAN",
        "RACE_ETH_PUERTORICAN",
        "RACE_ETH_HISP_LAT",
        "RACE_ETH_NON_HISP_LAT",
        "RACE_ETH_INDIAN_ALASKAN",
        "RACE_ETH_ASIAN",
        "RACE_ETH_AFRICANAMERICAN",
        "RACE_ETH_HAWAIIAN_PI",
        "RACE_ETH_WHITE",
        "RACE_ETH_OTHER",
    }

    clean_rows = []
    for row in rows:
        clean_row = {}
        for key, value in row.items():
            if key in DATE_FIELDS:
                clean_row[key] = normalize_date(value)
            elif key in MONTH_FIELDS:
                clean_row[key] = normalize_month(value)
            elif key == "GENDER":
                clean_row[key] = normalize_gender(value)
            elif key == "LATEST_SAT_GRADE":
                clean_row[key] = normalize_sat_grade(value)
            elif key in race_columns:
                clean_row[key] = normalize_race_flag(value)
            else:
                clean_row[key] = value
        clean_rows.append(clean_row)

with FILE_PATH.open("w", encoding="utf-8", newline="") as outfile:
    writer = csv.DictWriter(outfile, fieldnames=reader.fieldnames, delimiter="\t")
    writer.writeheader()
    writer.writerows(clean_rows)

print(f"Date normalization complete: {FILE_PATH}")
