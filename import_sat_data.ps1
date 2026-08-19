# PowerShell script to pull the nightly SAT file via FTP/curl and load it into SQLite
# Example: .\import_sat_data.ps1 -DbPath "assessment_data.db" -FtpServer "ftp.collegeboard.org" -RemoteDirectory "/nightly" -RemoteFile "Senior Data Specialist Hiring Activity - Data File.csv"

param(
    [string]$DbPath = "assessment_data.db",
    [string]$FtpServer = "ftp.collegeboard.org",
    [string]$RemoteDirectory = "/nightly",
    [string]$RemoteFile = "Senior Data Specialist Hiring Activity - Data File.csv",
    [string]$LocalPath = ".",
    [string]$FtpUsername = "",
    [string]$FtpPassword = "",
    [switch]$UseCurl
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DbPath)) {
    Write-Error "Database file not found: $DbPath. Create schema first."
    exit 1
}

$localFile = Join-Path $LocalPath $RemoteFile
$remoteUrl = "ftp://$FtpServer$RemoteDirectory/$RemoteFile"

Write-Host "Downloading nightly SAT file from $remoteUrl" -ForegroundColor Cyan

if ($UseCurl) {
    $curlArgs = @('-f', '-L', '-o', $localFile, $remoteUrl)

    if (-not [string]::IsNullOrWhiteSpace($FtpUsername)) {
        $curlArgs = @('-f', '-L', '-u', "$FtpUsername:$FtpPassword", '-o', $localFile, $remoteUrl)
    }

    & curl @curlArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "curl download failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
else {
    $ftpArgs = @('-f', '-L', '-o', $localFile, $remoteUrl)
    if (-not [string]::IsNullOrWhiteSpace($FtpUsername)) {
        $ftpArgs = @('-f', '-L', '-u', "$FtpUsername:$FtpPassword", '-o', $localFile, $remoteUrl)
    }

    & curl @ftpArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "FTP download failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path $localFile)) {
    Write-Error "Downloaded file not found: $localFile"
    exit 1
}

Write-Host "Running Python ETL step before database load" -ForegroundColor Cyan

# Run the Python import script first so it can preprocess or validate the downloaded file
$pythonScript = "import_sat_data.py"
if (-not (Test-Path $pythonScript)) {
    Write-Error "Python import script not found: $pythonScript"
    exit 1
}

& python $pythonScript --csv "$localFile" --db "$DbPath"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Python ETL step failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Importing SAT data from $localFile into $DbPath" -ForegroundColor Cyan

# Build the SQLite commands
$sqliteCommands = @"
.mode csv
.import "$localFile" temp_csv_import
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
    Write-Host "Nightly FTP import complete." -ForegroundColor Green
} else {
    Write-Error "Import failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}
