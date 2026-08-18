# PowerShell script to import SAT data into SQLite
# Usage: .\import_sat_data.ps1 -DbPath "assessment_data.db" -CsvPath "Senior Data Specialist Hiring Activity - Data File.csv"

param(
    [string]$DbPath = "assessment_data.db",
    [string]$CsvPath = "Senior Data Specialist Hiring Activity - Data File.csv"
)

$ErrorActionPreference = "Stop"

# Verify files exist
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

if (-not (Test-Path $DbPath)) {
    Write-Error "Database file not found: $DbPath. Create schema first."
    exit 1
}

Write-Host "Importing SAT data from $CsvPath into $DbPath" -ForegroundColor Cyan

# Build the SQLite commands
$sqliteCommands = @"
.mode csv
.import "$CsvPath" temp_csv_import
"@

# Read the transformation SQL script
$transformSql = Get-Content "import_sat_data.sql" -Raw

# Add summary queries at the end
$summarySql = @"

-- Summary counts
SELECT 'Students: ' || COUNT(*) FROM sat_student;
SELECT 'Demographics: ' || COUNT(*) FROM sat_demographics;
SELECT 'Scores: ' || COUNT(*) FROM sat_scores;
SELECT 'Schools: ' || COUNT(*) FROM sat_schools;
"@

# Combine all SQL
$allSql = $sqliteCommands + "`n" + $transformSql + $summarySql

# Execute in SQLite
$allSql | sqlite3 $DbPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "Import complete." -ForegroundColor Green
} else {
    Write-Error "Import failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
