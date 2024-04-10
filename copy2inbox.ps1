# Define paths and settings
$sourcePath = 'C:\unified_imaging\source'
$destinationPath = 'C:\unified_imaging\inbox'
$batchSize = 1000
$waitTimeInSeconds = 5
$logPath = "C:\unified_imaging\logs\CopyFilesLog.txt" # Update this path to where you want the log file

# Function to log messages
function Log-Message {
    param(
        [string]$Message
    )
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage
    $logMessage | Out-File $logPath -Append
}

# Start of the script
Log-Message "Script started."

# Main loop
do {
    # Wait until the inbox is empty before proceeding
    do {
        Start-Sleep -Seconds $waitTimeInSeconds
        $inboxFiles = Get-ChildItem -Path $destinationPath -File
        Log-Message "Checking if inbox is empty. Current file count: $($inboxFiles.Count)"
    } while ($inboxFiles.Count -gt 0)

    # Get the list of files, excluding directories
    $files = Get-ChildItem -Path $sourcePath -File

    if ($files.Count -eq 0) {
        Log-Message "No more files to process. Exiting loop."
        break
    }

    Log-Message "Starting to copy a batch of up to $batchSize files."

    $files | Select-Object -First $batchSize | ForEach-Object {
        try {
            $destinationFilePath = Join-Path -Path $destinationPath -ChildPath $_.Name
            Copy-Item -Path $_.FullName -Destination $destinationFilePath -ErrorAction Stop
            Log-Message "Successfully copied `"$($_.Name)`" to inbox."
        } catch {
            Log-Message "Error copying file: $($_.Name). Error: $_"
        }
    }

    Log-Message "Batch copy completed. Waiting $waitTimeInSeconds seconds before next batch."
    Start-Sleep -Seconds $waitTimeInSeconds

} while ($true)

Log-Message "Script completed."
