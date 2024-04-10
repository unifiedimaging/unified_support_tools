# Set Execution Policy for the script
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Define paths and settings
$sourcePath = 'C:\unified_imaging\source'
$destinationPath = 'C:\unified_imaging\inbox'
$trackingFilePath = "C:\unified_imaging\logs\copiedFiles.txt"
$logPath = "C:\unified_imaging\logs\CopyFilesLog.txt"
$batchSize = 1000
$waitTimeInSeconds = 5
$minFileSizeKB = 100
$excludedFileTypes = @('.exe', '.tmp', '.log', '.txt')
$configPath = "C:\unified_imaging\config.json"

# Ensure log directory exists
$null = New-Item -ItemType Directory -Path (Split-Path -Path $logPath) -Force

# Create a logger function to handle message logging
function Log-Message {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage
    Add-Content -Path $logPath -Value $logMessage
}

# Load configuration for file processing
function Load-Config {
    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        Log-Message "Configuration file not found or is invalid. Default settings will be used."
        return $null
    }
}

# Function to modify filename dynamically based on configuration
function Modify-Filename {
    param([string]$FileName, $Config)
    if ($Config) {
        $delimiter = $Config.delimiter
        $fields = $FileName -split $delimiter
        foreach ($condition in $Config.conditions) {
            if ($fields[$condition.segmentIndex] -eq $condition.expectedValue) {
                $template = $condition.template -f $fields
                return $template
            }
        }
    }
    return $FileName
}

# Read the tracking file and create a hashtable of copied files
function Get-HashtableFromFile {
    param ([string]$FilePath)
    $hashTable = @{}
    if (Test-Path $FilePath) {
        Get-Content $FilePath | ForEach-Object {
            $parts = $_ -split '=', 2
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim().ToLower()
                $value = $parts[1].Trim()
                $hashTable[$key] = $value
            }
        }
    }
    return $hashTable
}

# Determine if a file has already been copied based on its unique key (path + size)
function File-HasBeenCopied {
    param([string]$FilePath, [long]$FileSize)
    $relativePath = $FilePath.Substring($sourcePath.Length).Replace('\', '/').TrimStart('/')
    $uniqueKey = $relativePath.ToLower() + "_" + $FileSize
    return $alreadyCopied.ContainsKey($uniqueKey)
}

$config = Load-Config

# Main script logic
$alreadyCopied = Get-HashtableFromFile -FilePath $trackingFilePath
Log-Message "Script started."

# Monitor and copy new files
do {
    $fileList = Get-ChildItem -Path $sourcePath -File -Recurse
    if ($fileList.Count -eq 0) {
        Log-Message "No new files to copy. Waiting for new files..."
        Start-Sleep -Seconds $waitTimeInSeconds
        continue
    }

    foreach ($file in $fileList) {
        $originalName = $file.Name
        $newFileName = Modify-Filename -FileName $originalName -Config $config
        $fullPath = $file.FullName
        $relativePath = $fullPath.Substring($sourcePath.Length).TrimStart('\')
        $fileSizeKB = $file.Length / 1KB
        $fileExt = $file.Extension.ToLower()
        $fileSizeBytes = $file.Length
        $destinationFile = Join-Path -Path $destinationPath -ChildPath $newFileName

        $hasBeenCopied = File-HasBeenCopied $fullPath $fileSizeBytes

        if (-not (Test-Path -Path $destinationFile) -and -not $hasBeenCopied -and -not ($excludedFileTypes -contains $fileExt) -and $fileSizeKB -gt $minFileSizeKB) {
            Robocopy $file.DirectoryName $destinationPath $file.Name /NP /R:2 /W:2 /Mov | Out-Null
            if ($LASTEXITCODE -le 1) {
                $uniqueKey = $relativePath.ToLower() + "_" + $fileSizeBytes
                $alreadyCopied[$uniqueKey] = $true
                "$uniqueKey=$true" | Out-File $trackingFilePath -Append
                Log-Message "Successfully moved $originalName to $newFileName"
            }
        } elseif (Test-Path -Path $destinationFile) {
            Log-Message "File $newFileName already exists in destination."
        }
    }
    Start-Sleep -Seconds $waitTimeInSeconds
} while ($true)
