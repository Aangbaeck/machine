﻿# Wrap the prompt by default.
$Global:WrapPrompt = $true;
$Global:WindowTitle = $null;

# Load PoSh-Git.
$Global:PoShGitInstalled = (Get-Module -ListAvailable -Name posh-git)
if ($Global:PoShGitInstalled) {
    Import-Module posh-git
}
else {
    Write-Host "PoSh-Git has not been installed."
}

# The prompt
Function Global:Prompt() {
    # Store the last exit code.
    $REALLASTEXITCODE = $LASTEXITCODE

    # Not at top row? Check if we should insert a blank space.
    if ($host.UI.RawUI.CursorPosition.Y -ge 1) {
        $previousX = $host.UI.RawUI.CursorPosition.X 
        $previousY = $host.UI.RawUI.CursorPosition.Y - 1
        $rect = New-Object System.Management.Automation.Host.Rectangle(0, $previousY, $host.UI.RawUI.BufferSize.Width, $previousY)
        $content = $host.UI.RawUI.GetBufferContents($rect)
        $writeNewLine = $false;
        for ($i = 0; $i -lt $host.UI.RawUI.BufferSize.Width; $i++) {
            $character = $content[$i, 0].Character
            if ($character -ne ' ' -and $character -ne $null) {
                $writeNewLine = $true;
                break;
            }
        }
        if ($writeNewLine) {
            Write-Host "  "
        }
    }

    # User and computer name
    Write-Host ([Environment]::UserName) -n -f ([ConsoleColor]::Cyan)
    Write-Host "@" -n
    Write-Host ([net.dns]::GetHostName()) -n -f ([ConsoleColor]::Green)

    # Current path
    Write-Host " " -n
    Write-Host "[" -nonewline -f ([ConsoleColor]::Yellow)
    Write-Host($pwd.Path) -nonewline
    Write-Host "]" -n -f ([ConsoleColor]::Yellow)

    # Git status
    if ($Global:PoShGitInstalled) {
        Write-VcsStatus
    }

    # Show stack
    if ((get-location -stack).Count -gt 0) {
        write-host " " -NoNewLine
        write-host (("+" * ((get-location -stack).Count))) -NoNewLine -ForegroundColor Cyan
    }

    # New line
    Write-Host ""

    # Print exit code
    if ($REALLASTEXITCODE -ne 0) {
        write-host " X $REALLASTEXITCODE " -NoNewLine -BackgroundColor DarkRed -ForegroundColor Yellow
        write-host " " -NoNewline
    }

    # Prompt
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = new-object 'System.Security.Principal.WindowsPrincipal' $windowsIdentity
    $IsAdministrator = $windowsPrincipal.IsInRole("Administrators") -eq 1;
    $PromptColor = if ($IsAdministrator) {[ConsoleColor]::Red} Else {[ConsoleColor]::Green}
    Write-Host "λ" -n -f ($PromptColor)

    # Set the window title.
    if ($null -eq $Global:WindowTitle) {
        $CurrentPath = $pwd.ProviderPath
        $CustomWindowTitle = if ($IsAdministrator) {"[Admin] " + $CurrentPath} Else {$CurrentPath}
        $host.UI.RawUI.WindowTitle = $CustomWindowTitle;
    }
    else {
        $CustomWindowTitle = if ($IsAdministrator) {"[Admin] " + $Global:WindowTitle} Else {$Global:WindowTitle}
        $host.UI.RawUI.WindowTitle = $CustomWindowTitle;
    }

    $global:LASTEXITCODE = $REALLASTEXITCODE
    return " "
}

function Find-Files([string]$Pattern)
{
    if($null -ne $Pattern -and $Pattern -ne "") {
        Get-Childitem -Include $Pattern -File -Recurse -ErrorAction SilentlyContinue `
            | ForEach-Object { Resolve-Path -Relative $_ | Write-Host }
    }
}

function Set-As([Parameter(Mandatory = $true)][string]$Name) {
    New-PSDrive -PSProvider FileSystem -Name $Name -Root . -Scope Global | Out-Null
    Set-Location -LiteralPath "$($name):"
}

# Add virtual drives for projects
function Add-VirtualDrive([string]$Path, [string]$Name) {
    Push-Location
    Set-Location $Path
    Set-As $Name
    Pop-Location
}

# Copies the current location to the clipboard.
Function Copy-CurrentLocation() {
    $Result = (Get-Location).Path | clip.exe
    Write-Host "Copied current location to clipboard."
    return $Result
}

# Creates a new directory and enters it.
Function New-Directory([string]$Name) {
    $Directory = New-Item -Path $Name -ItemType Directory;
    if (Test-Path $Directory) {
        Set-Location $Name;
    }
}

# Source location shortcuts.
Function Enter-GitHubLocation { Enter-SourceLocation -Provider "GitHub" -Path $Global:SourceLocation }
Function Enter-AzureDevOpsLocation { Enter-SourceLocation -Provider "Azure DevOps" -Path $Global:AzureDevOpsSourceLocation }
Function Enter-BitBucketLocation { Enter-SourceLocation -Provider "BitBucket" -Path $Global:BitBucketSourceLocation }
Function Enter-GitLabLocation { Enter-SourceLocation -Provider "GitLab" -Path $Global:GitLabSourceLocation }
Function Enter-SourceLocation([string]$Provider,[string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Host "The source location for $Provider have not been set."
        return
    }
    Set-Location $Path
}

function Set-WindowTitle([string]$Title) {
    $Global:WindowTitle = $Title;
}

# Aliases
Set-Alias open start
Set-Alias ccl Copy-CurrentLocation
Set-Alias gs Enter-GitHubLocation
Set-Alias gsa Enter-AzureDevOpsLocation
Set-Alias gsb Enter-BitBucketLocation
Set-Alias gsg Enter-GitLabLocation
Set-Alias mcd New-Directory
Set-Alias back popd
Set-Alias build ./build.ps1
Set-Alias sw Set-WindowTitle
Set-Alias f Find-Files
