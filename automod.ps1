$host.ui.RawUI.WindowTitle = "AutoMod+ for Intel iGPU 7-10th generation driver"

# Check if we can find the inf file (I.E, are we in a driver folder?)
if (Test-Path '.\Graphics\iigd_dch.inf' -PathType Leaf) { $inffile = '.\Graphics\iigd_dch.inf' }
if (Test-Path '.\Graphics\igdlh64.inf' -PathType Leaf) { $inffile = '.\Graphics\igdlh64.inf' }

# If we can't find the inf file then prompt for it
if (!$inffile) {
    $inffile = Read-Host -Prompt 'Please drag your driver INF file here and press enter'
    $inffile = $inffile.Replace('"',"")
}

# Create backup before making changes
$backupFile = "$inffile.backup"
if (!(Test-Path $backupFile)) {
    Copy-Item $inffile $backupFile
    Write-Host "Created backup of INF file: $backupFile"
}

# Function to perform safe file replacement
function Replace-InFile {
    param (
        [string]$filePath,
        [string]$originalText,
        [string]$newText
    )
    $content = Get-Content $filePath -Raw
    if ($content -match [regex]::Escape($originalText)) {
        $content -replace [regex]::Escape($originalText), $newText | Out-File $filePath -Force
        Write-Host "Replaced: $originalText → $newText"
    } else {
        Write-Host "Pattern not found (may already be modified): $originalText" -ForegroundColor Yellow
    }
}

# Ask if the user is happy with a power plan override
$message  = 'User input needed'
$question = 'Force change power plan to maximum performance? (On DC power only)'

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -eq 0) {
    # Maximium Power Plan
    Replace-InFile -filePath $inffile -originalText '%AC%, 1' -newText '%AC%, 1'
    Replace-InFile -filePath $inffile -originalText '%AC%, 0' -newText '%AC%, 1'
    Replace-InFile -filePath $inffile -originalText '%DC%, 1' -newText '%DC%, 2'
    Replace-InFile -filePath $inffile -originalText '%DC%, 0' -newText '%DC%, 2'
    Write-Host "Changed to maximum power configuration"
} else {
    Write-Host "Kept default power configuration"
}

# Change max mem config
Replace-InFile -filePath $inffile -originalText 'MaximumDeviceMemoryConfiguration = 512' -newText 'MaximumDeviceMemoryConfiguration = 1024'
Write-Host "Modified maximum memory configuration"

# Optimizations from drivers
Replace-InFile -filePath $inffile -originalText 'HKR,, IncreaseFixedSegment,%REG_DWORD%, 0' -newText ('HKR,, IncreaseFixedSegment,%REG_DWORD%, 0; 0 - disabled, 1- enabled' + "`n" + 'HKR,, Display1_PipeOptimizationEnable,%REG_DWORD%, 1')
Replace-InFile -filePath $inffile -originalText 'HKR,, AdaptiveVsyncEnable,%REG_DWORD%, 1' -newText 'HKR,, AdaptiveVsyncEnable,%REG_DWORD%, 0'
Replace-InFile -filePath $inffile -originalText 'HKR,, Disable_OverlayDSQualityEnhancement,  %REG_DWORD%,     0' -newText 'HKR,, Disable_OverlayDSQualityEnhancement,  %REG_DWORD%, 1'
Write-Host "Applied driver optimizations"

# Check if we can find the inf file for the CUI (Common User Interface)
if (Test-Path '.\Graphics\cui_dch.inf' -PathType Leaf) {
    $cuiFile = '.\Graphics\cui_dch.inf'
    $cuiBackup = "$cuiFile.backup"
    if (!(Test-Path $cuiBackup)) {
        Copy-Item $cuiFile $cuiBackup
    }

    $message  = 'Enable CUI Mods?'
    $question = 'There are some CUI (Common User-Interface) mods we can perform, would you like to use them?'

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
    if ($decision -eq 0) {
        $newCuiContent = 'HKR,,"ShowOptimalBalloon",%REG_DWORD%,0' + "`n" + 'HKR,,"ShowPromotions",%REG_DWORD%,0'
        Replace-InFile -filePath $cuiFile -originalText 'HKR,,"ShowOptimalBalloon",%REG_DWORD%,1' -newText $newCuiContent
        Write-Host "Modified the CUI"
    } else {
        Write-Host "Skipped CUI mods"
    }
}

# Device ID modifications
if ($inffile) {
    $message  = 'Modify device IDs?'
    $question = 'We can modify the device ID strings to help provide a FPS boost on some devices, would you like to continue? Note: This change may reset your graphics settings'

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
    if ($decision -eq 0) {
        # List of all device ID patterns to remove
        $devicePatterns = @(
            'iKBLHALOGT1    = "Intel\(R\) HD Graphics" "610"',
            'iKBLHALOGT2    = "Intel\(R\) HD Graphics" "630"',
            'iBXTGTP        = "Intel\(R\) HD Graphics" "505"',
            'iBXTGTP12      = "Intel\(R\) HD Graphics" "500"',
            'iKBLULTGT1     = "Intel\(R\) HD Graphics" "610"',
            'iKBLULTGT2     = "Intel\(R\) HD Graphics" "620"',
            'iKBLULTGT2R    = "Intel\(R\) UHD Graphics" "620"',
            'iKBLULTGT2F    = "Intel\(R\) HD Graphics" "620"',
            'iKBLULTGT3E15  = "Intel\(R\) Iris\(R\) Plus Graphics" "640"',
            'iKBLULTGT3E28  = "Intel\(R\) Iris\(R\) Plus Graphics" "650"',
            'iKBLULXGT2     = "Intel\(R\) HD Graphics" "615"',
            'iKBLDTGT1      = "Intel\(R\) HD Graphics" "610"',
            'iKBLDTGT2      = "Intel\(R\) HD Graphics" "630"',
            'iKBLWGT2       = "Intel\(R\) HD Graphics" "P630"',
            'iAMLULXGT2R    = "Intel\(R\) UHD Graphics" "615"',
            'iAMLULXGT2R7W  = "Intel\(R\) UHD Graphics" "617"',
            'iAMLULXGT2Y42  = "Intel\(R\) UHD Graphics"',
            'iCFLDTGT1           = "Intel\(R\) UHD Graphics" "610"',
            'iCFLDTGT2           = "Intel\(R\) UHD Graphics" "630"',
            'iCFLDTWSGT2         = "Intel\(R\) UHD Graphics" "P630"',
            'iCFLHALOGT2         = "Intel\(R\) UHD Graphics" "630"',
            'iCFLHALOWSGT2       = "Intel\(R\) UHD Graphics" "P630"',
            'iCFLULTGT3W15       = "Intel\(R\) Iris\(R\) Plus Graphics" "645"',
            'iCFLULTGT3W28       = "Intel\(R\) Iris\(R\) Plus Graphics" "655"',
            'iCFLULTGT3W28EU42   = "Intel\(R\) Iris\(R\) Plus Graphics" "655"',
            'iCFLDTGT1W35        = "Intel\(R\) UHD Graphics" "610"',
            'iCFLDTGT2W35        = "Intel\(R\) UHD Graphics" "630"',
            'iCFLDTGT2S8S2F1F    = "Intel\(R\) UHD Graphics" "630"',
            'iCFLDTGT2S82S6F2    = "Intel\(R\) UHD Graphics" "P630"',
            'iCFLHALOGT1H2F1F    = "Intel\(R\) UHD Graphics" "610"',
            'iCFLULTGT2D0        = "Intel\(R\) UHD Graphics" "620"',
            'INTEL_DEV_9B41 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9B21 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9BCA = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9BAA = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9BCC = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9BAC = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9BC5 = "Intel\(R\) UHD Graphics" "630"',
            'INTEL_DEV_9BC8 = "Intel\(R\) UHD Graphics" "630"',
            'INTEL_DEV_9BA8 = "Intel\(R\) UHD Graphics" "610"',
            'INTEL_DEV_9BC4 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9BE6 = "Intel\(R\) UHD Graphics" "P630"',
            'INTEL_DEV_9BF6 = "Intel\(R\) UHD Graphics" "P630"',
            'iWHLULTGT2U42U2F2   = "Intel\(R\) UHD Graphics" "620"',
            'iWHLULTGT1U41FU2F1F = "Intel\(R\) UHD Graphics" "610"',
            'iGLKGT2E18     = "Intel\(R\) UHD Graphics" "605"',
            'iGLKGT2E12     = "Intel\(R\) UHD Graphics" "600"',
            'INTEL_DEV_8A51 = "Intel\(R\) Iris\(R\) Plus Graphics"',
            'INTEL_DEV_8A52 = "Intel\(R\) Iris\(R\) Plus Graphics"',
            'INTEL_DEV_8A5A = "Intel\(R\) Iris\(R\) Plus Graphics"',
            'INTEL_DEV_8A56 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_8A5C = "Intel\(R\) Iris\(R\) Plus Graphics"',
            'INTEL_DEV_8A58 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_8A53 = "Intel\(R\) Iris\(R\) Plus Graphics"',
            'INTEL_DEV_9840 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_9841 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_4571 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_4555 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_4E61 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_4E71 = "Intel\(R\) UHD Graphics"',
            'INTEL_DEV_4E55 = "Intel\(R\) UHD Graphics"'
        )

        # First remove all the specific device strings
        $content = Get-Content $inffile -Raw
        foreach ($pattern in $devicePatterns) {
            $content = $content -replace $pattern, ''
        }

        # Now replace all device IDs with INTEL_DEV_9BC6
        $deviceIds = @(
            'iBXTGTP', 'iBXTGTP12', 'iKBLULTGT1', 'iKBLULTGT2', 'iKBLULTGT2R', 'iKBLULTGT2F',
            'iKBLULTGT3E15', 'iKBLULTGT3E28', 'iKBLULXGT2', 'iKBLDTGT1', 'iKBLDTGT2', 'iKBLHALOGT1',
            'iKBLHALOGT2', 'iKBLWGT2', 'iAMLULXGT2R', 'iAMLULXGT2R7W', 'iAMLULXGT2Y42', 'iCFLDTGT1',
            'iCFLDTGT2', 'iCFLDTWSGT2', 'iCFLHALOGT2', 'iCFLHALOWSGT2', 'iCFLULTGT3W15', 'iCFLULTGT3W28',
            'iCFLULTGT3W28EU42', 'iCFLDTGT1W35', 'iCFLDTGT2W35', 'iCFLDTGT2S8S2F1F', 'iCFLDTGT2S82S6F2',
            'iCFLHALOGT1H2F1F', 'iCFLULTGT2D0', 'INTEL_DEV_9B41', 'INTEL_DEV_9B21', 'INTEL_DEV_9BCA',
            'INTEL_DEV_9BAA', 'INTEL_DEV_9BCC', 'INTEL_DEV_9BAC', 'INTEL_DEV_9BC5', 'INTEL_DEV_9BC8',
            'INTEL_DEV_9BA8', 'INTEL_DEV_9BC4', 'INTEL_DEV_9BE6', 'INTEL_DEV_9BF6', 'iWHLULTGT2U42U2F2',
            'iWHLULTGT1U41FU2F1F', 'iGLKGT2E18', 'iGLKGT2E12', 'INTEL_DEV_8A51', 'INTEL_DEV_8A52',
            'INTEL_DEV_8A5A', 'INTEL_DEV_8A56', 'INTEL_DEV_8A5C', 'INTEL_DEV_8A58', 'INTEL_DEV_8A53',
            'INTEL_DEV_9840', 'INTEL_DEV_9841', 'INTEL_DEV_4571', 'INTEL_DEV_4555', 'INTEL_DEV_4E61',
            'INTEL_DEV_4E71', 'INTEL_DEV_4E55'
        )

        foreach ($id in $deviceIds) {
            $content = $content -replace $id, 'INTEL_DEV_9BC6'
        }

        $content | Out-File $inffile -Force
        Write-Host "Modified the device ID strings"
    } else {
        Write-Host "Skipped the device ID strings modifications"
    }
}

Write-Host "`nAll modifications completed successfully!"
Write-Host "Original files were backed up with .backup extension"
pause