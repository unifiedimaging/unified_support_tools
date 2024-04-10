# Define paths, settings, minimum file size for copying, and excluded file types
$sourcePath = 'C:\Dicom-Files'
$destinationPath = 'C:\unified_imaging\inbox'
$trackingFilePath = "C:\unified_imaging\logs\copiedFiles.txt"
$logPath = "C:\unified_imaging\logs\CopyFilesLog.txt"
$batchSize = 1000
$waitTimeInSeconds = 5
$minFileSizeKB = 100 # Minimum file size to copy, in kilobytes (KB)
$excludedFileTypes = @('.exe', '.tmp', '.log', '.txt') # Extensions to exclude

# Function to ensure hashtable from file content
function Get-HashtableFromFile {
    param ([string]$FilePath)
    $hashTable = @{}
    if (Test-Path $FilePath) {
        Get-Content $FilePath | ForEach-Object {
            $parts = $_ -split '='
            $hashTable[$parts[0]] = $parts[1]
        }
    }
    return $hashTable
}

$alreadyCopied = Get-HashtableFromFile -FilePath $trackingFilePath

function Log-Message {
    param([string]$Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $logMessage
    Add-Content -Path $logPath -Value $logMessage
}

function Is-InboxEmpty {
    param([string]$Path)
    $files = Get-ChildItem -Path $Path -File
    if ($files.Count -eq 0) {
        return $true
    }
    elseif ($files.Count -eq 1 -and $files[0].Name -eq 'refresh' -and $files[0].Length -eq 0) {
        return $true
    }
    else {
        return $false
    }
}

Log-Message "Script started."

$fileWatcher = New-Object System.IO.FileSystemWatcher
$fileWatcher.Path = $sourcePath
$fileWatcher.IncludeSubdirectories = $true
$fileWatcher.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $fileWatcher -EventName Created -Action {
    param($source, $eventArgs)
    $name = $eventArgs.Name
    if (-not $global:alreadyCopied.ContainsKey($name) -and (Is-InboxEmpty -Path $destinationPath)) {
        Robocopy $sourcePath $destinationPath $name /NP /R:2 /W:2 | Out-Null
        if ($LASTEXITCODE -le 1) {
            $global:alreadyCopied[$name] = $true
            "$name=$true" | Out-File $trackingFilePath -Append
            Log-Message "Dynamically copied $name"
        }
    }
}

do {
    $fileList = Get-ChildItem -Path $sourcePath -File -Recurse
    
    if ($fileList.Count -eq 0) {
        Log-Message "No new files to copy. Waiting for new files..."
        Start-Sleep -Seconds $waitTimeInSeconds
    }

    foreach ($file in $fileList) {
        while ((Get-ChildItem -Path $destinationPath -File).Count -ge $batchSize) {
            Log-Message "Destination has reached or exceeded batch size limit. Waiting..."
            Start-Sleep -Seconds $waitTimeInSeconds
        }

        $fullPath = $file.FullName
        $relativePath = $fullPath.Substring($sourcePath.Length).TrimStart('\')
        $directory = $file.DirectoryName
        $fileSizeKB = $file.Length / 1KB
        $fileExt = $file.Extension.ToLower()
        $name = $file.Name
        
        Log-Message "Processing file: $relativePath"

        if ($excludedFileTypes.Contains($fileExt)) {
            Log-Message "Skipping $relativePath - file is included file type list"
            continue
        }
        
        if ($fileSizeKB -le $minFileSizeKB) {
            Log-Message "Skipping $relativePath - filesize is smaller than allowed"
            continue
        }
        
        if ($alreadyCopied.ContainsKey($relativePath)) {
            Log-Message "Skipping $relativePath - it has already been copied"
            continue
        }

        Robocopy $directory $destinationPath $fileName /NP /R:2 /W:2 | Out-Null

        if ($LASTEXITCODE -le 3) {
            $alreadyCopied[$relativePath] = $true
            "$relativePath=$true" | Out-File $trackingFilePath -Append
            Log-Message "Successfully copied $fileName from $relativePath"
        }
    }
} while ($true)