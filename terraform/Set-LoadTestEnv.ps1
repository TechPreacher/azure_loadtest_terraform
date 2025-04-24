# Set-LoadTestEnv.ps1
# Script to load environment variables from load_test_variables.env file

# Get the directory of the script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path -Path $ScriptDir -ChildPath "load_test_variables.env"

# Check if the env file exists
if (-not (Test-Path $EnvFile)) {
    Write-Error "Environment file $EnvFile not found!"
    exit 1
}

# Read the file content
$FileContent = Get-Content -Path $EnvFile

# Process each line in the file
foreach ($Line in $FileContent) {
    # Skip empty lines, comments, and lines without an equals sign
    if ([string]::IsNullOrWhiteSpace($Line) -or $Line.StartsWith("#") -or (-not $Line.Contains("="))) {
        continue
    }
    
    # Extract variable name and value
    $SplitIndex = $Line.IndexOf("=")
    $VarName = $Line.Substring(0, $SplitIndex).Trim()
    $VarValue = $Line.Substring($SplitIndex + 1).Trim()
    
    # Handle quoted values correctly
    if ($VarValue.StartsWith('"') -and $VarValue.EndsWith('"')) {
        $VarValue = $VarValue.Substring(1, $VarValue.Length - 2)
    }
    
    # Set the environment variable for the current process
    Set-Variable -Name $VarName -Value $VarValue
    Write-Host "Exported: $VarName=$VarValue"

}

Write-Host "Environment variables from $EnvFile have been loaded."