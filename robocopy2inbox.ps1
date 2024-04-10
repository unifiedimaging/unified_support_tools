# Define paths and settings
$sourcePath = 'C:\unified_imaging\source'
$destinationPath = 'C:\unified_imaging\inbox'
$trackingFilePath = "C:\unified_imaging\logs\copiedFiles.txt" # Tracks copied files
$pendingCopyFilePath = "C:\unified_imaging\logs\pendingCopyFiles.txt" # Tracks files pending copy
$logPath = "C:\unified_imaging\logs\CopyFilesLog.txt" # Log file for script messages
$batchSize = 1000
$waitTimeInSeconds = 5

# Load or initialize the tracking lists
$alreadyCopied = @{}
if (Test-Path $trackingFilePath) {
    Get-Content $trackingFilePath | ForEach-Object { $alreadyCopied[$_] = $true }
} else {
    New-Item -Path $trackingFilePath -ItemType File
}

$pendingCopy = @{}
if (Test-Path $pendingCopyFilePath) {
    Get-Content $pendingCopyFilePath | ForEach-Object { $pendingCopy[$_] = $true }
}

# Function to log messages
function Log-Message {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage
    $logMessage | Out-File $logPath -Append
}

Log-Message "Script started."

# Function to refresh the pending copy list
function RefreshPendingCopyList {
    # Clear the existing content safely
    $global:pendingCopy = @{}
    Remove-Item $pendingCopyFilePath -ErrorAction SilentlyContinue
    New-Item -Path $pendingCopyFilePath -ItemType File

    Get-ChildItem -Path $sourcePath -File | Where-Object { -not $alreadyCopied.ContainsKey($_.Name) } | ForEach-Object {
        $global:pendingCopy[$_.Name] = $true
        $_.Name | Out-File $pendingCopyFilePath -Append
    }
    Log-Message "Pending copy list refreshed."
}


# Initial refresh if pending copy list is empty
if ($pendingCopy.Count -eq 0) {
    RefreshPendingCopyList
}

# Main processing loop
do {
    $inboxFiles = Get-ChildItem -Path $destinationPath -File
    if ($inboxFiles.Count -eq 0) {
        $filesToCopy = $pendingCopy.Keys | Select-Object -First $batchSize
        foreach ($fileName in $filesToCopy) {
            $sourceFile = Join-Path -Path $sourcePath -ChildPath $fileName
            $destinationFile = Join-Path -Path $destinationPath -ChildPath $fileName
            
            robocopy $(Split-Path $sourceFile) $(Split-Path $destinationFile) $(Split-Path -Leaf $sourceFile) /NP /R:2 /W:2 | Out-Null
            if ($LASTEXITCODE -le 1) {
                $alreadyCopied[$fileName] = $true
                $fileName | Out-File $trackingFilePath -Append
                $global:pendingCopy.Remove($fileName)
                Log-Message "Successfully copied $fileName"
            }
        }
        Log-Message "Batch copy completed. Waiting $waitTimeInSeconds seconds before next batch."
        Start-Sleep -Seconds $waitTimeInSeconds
    } else {
        Log-Message "Inbox not empty. Waiting..."
        Start-Sleep -Seconds $waitTimeInSeconds
    }

    # Periodically refresh the pending copy list in the background
    RefreshPendingCopyList
} while ($true)

Log-Message "Script completed."