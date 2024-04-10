# Set Execution Policy for the script
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Define paths and settings
$sourcePath = 'C:\unified_imaging\source'
$destinationPath = 'C:\unified_imaging\inbox'
$trackingFilePath = "C:\unified_imaging\logs\copiedFiles.txt"
$logPath = "C:\unified_imaging\logs\CopyFilesLog.txt"
$batchSize = 1000
$waitTimeInSeconds = 5
$minFileSizeKB = 100  # Minimum file size to copy, in kilobytes (KB)
$excludedFileTypes = @('.exe', '.tmp', '.log', '.txt')  # Extensions to exclude

# Create a logger function to handle message logging
function Log-Message {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage
    Add-Content -Path $logPath -Value $logMessage
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
    $uniqueKey = $relativePath.ToLower() + "_" + $FileSize  # Concatenate path and file size for uniqueness
    return $alreadyCopied.ContainsKey($uniqueKey)
}

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
        $fullPath = $file.FullName
        $relativePath = $fullPath.Substring($sourcePath.Length).TrimStart('\')
        $fileSizeKB = $file.Length / 1KB
        $fileExt = $file.Extension.ToLower()
        $fileSizeBytes = $file.Length  # File size in bytes

        $hasBeenCopied = File-HasBeenCopied $fullPath $fileSizeBytes

        if ($excludedFileTypes -contains $fileExt -or $fileSizeKB -le $minFileSizeKB -or $hasBeenCopied) {
            Log-Message "Skipping $relativePath - Conditions not met."
            continue
        }

        while ((Get-ChildItem -Path $destinationPath -File).Count -ge $batchSize) {
            Log-Message "Destination has reached batch size limit. Waiting..."
            Start-Sleep -Seconds $waitTimeInSeconds
        }

        Robocopy $file.DirectoryName $destinationPath $file.Name /NP /R:2 /W:2 | Out-Null
        if ($LASTEXITCODE -le 1) {
            $uniqueKey = $relativePath.ToLower() + "_" + $fileSizeBytes
            $alreadyCopied[$uniqueKey] = $true
            "$uniqueKey=$true" | Out-File $trackingFilePath -Append
            Log-Message "Successfully copied $file.Name from $relativePath"
        }
    }
    Start-Sleep -Seconds $waitTimeInSeconds
} while ($true)
