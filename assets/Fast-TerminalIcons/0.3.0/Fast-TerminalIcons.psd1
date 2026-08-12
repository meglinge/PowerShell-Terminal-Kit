@{
    RootModule           = 'Fast-TerminalIcons.dll'
    ModuleVersion        = '0.3.0'
    GUID                 = '1287d8b7-0707-46c8-96c6-80428c0a8088'
    Author               = 'Fast-TerminalIcons contributors'
    CompanyName          = 'Community'
    Copyright            = '(c) 2026 Fast-TerminalIcons contributors. MIT License.'
    Description          = 'High-performance binary file and directory icons for PowerShell.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    CmdletsToExport      = @('Format-FastTerminalIcon', 'Format-FastTerminalTable')
    FunctionsToExport    = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('Color', 'Terminal', 'Console', 'NerdFonts', 'Icon', 'BinaryModule')
            LicenseUri = 'https://github.com/devblackops/Terminal-Icons/blob/v0.11.0/LICENSE'
            ProjectUri = 'https://github.com/devblackops/Terminal-Icons'
        }
    }
}
