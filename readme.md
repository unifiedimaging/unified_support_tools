# Unified's powerful powershells

## copy2inbox.ps1

<br>

## robocopy2inbox.ps1

<br>


## sync2inbox.ps1

<br>


## sync2inbox2.ps1
<br>


## Dynamic File Processor (prosync2inbox.ps1)

This PowerShell script is designed to monitor a source directory, modify filenames according to user-defined rules, and move files to a specified destination directory. It is ideal for environments where files need to be dynamically renamed and organized based on their content or naming conventions.

### Features

- **Dynamic Filename Modification**: Customize how files are renamed using a simple JSON configuration.
- **Robust File Handling**: Uses `Robocopy` for reliable file transfers.
- **Configurable**: All paths, intervals, and settings are easily configurable.
- **Logging**: Detailed logging of actions and errors.

### Configuration

Modify the `config.json` file to set up your filename processing rules. Here is the structure of the configuration file:

```json
{
    "delimiter": "string",
    "conditions": [
        {
            "segmentIndex": int,
            "expectedValue": "string",
            "template": "string"
        }
    ]
}
```

#### Parameters

- `delimiter`: The character used to split the filename into parts.
- `conditions`: An array of conditions to apply to the filename parts.
- `segmentIndex`: The index of the part to evaluate.
- `expectedValue`: The value that triggers the rule.
- `template`: The format to reconstruct the filename. Use `{n}` placeholders for parts.

### Usage

Ensure all paths and settings in the script are correct for your environment:

- `$sourcePath`
- `$destinationPath`
- `$trackingFilePath`
- `$logPath`
- `$configPath`

Place your `config.json` in the correct location as specified in the script.

Run the script in PowerShell:

```powershell
.\DynamicFileProcessor.ps1
```

### Example

Given the configuration:

```json
{
    "delimiter": "-",
    "conditions": [
        {
            "segmentIndex": 2,
            "expectedValue": "fundus",
            "template": "{0}-{1}-{2}.jpg"
        }
    ]
}
```

A file named `image-20210101-fundus-001.jpg` will be renamed to `image-20210101-fundus.jpg` based on the matching condition.

### Troubleshooting

- **Configuration Errors**: Ensure `config.json` is valid JSON and correctly structured.
- **File Permissions**: The script needs appropriate permissions to read from the source and write to the destination directories.
- **Log Files**: Review log files for any errors or warnings that may indicate what went wrong.

### Contributing

Feel free to fork and send pull requests or create issues if you find bugs or have feature requests.

### License
<br>

