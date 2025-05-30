#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to get physical disks
function Get-PhysicalDisks {
    $disks = Get-WmiObject Win32_DiskDrive | Where-Object { $_.MediaType -like "*Removable*" -or $_.InterfaceType -eq "USB" }
    return $disks | Select-Object Index, Model, @{Name="SizeGB";Expression={[math]::Round($_.Size / 1GB, 2)}}
}

# Function to create diskpart script for cleaning
function Create-DiskpartScript {
    param (
        [string]$DiskNumber,
        [string]$ScriptPath
    )
    $diskpartScript = @"
select disk $DiskNumber
clean all
"@
    $diskpartScript | Out-File -FilePath $ScriptPath -Encoding ASCII
}

# Function to estimate wipe time per pass (based on disk size and approximate write speed)
function Estimate-PassTime {
    param (
        [double]$SizeGB
    )
    # Assume average write speed of 50 MB/s for USB drives (adjust as needed)
    $writeSpeedMBps = 50
    $sizeMB = $SizeGB * 1024
    $seconds = [math]::Round($sizeMB / $writeSpeedMBps)
    return $seconds
}

# Function to wipe a disk
function Wipe-Disk {
    param (
        [string]$DiskNumber,
        [double]$SizeGB,
        [System.Windows.Forms.Form]$ProgressForm
    )

    $totalPasses = 3
    $progressBar = $ProgressForm.Controls | Where-Object { $_.Name -eq "ProgressBar" }
    $statusLabel = $ProgressForm.Controls | Where-Object { $_.Name -eq "StatusLabel" }
    $etaLabel = $ProgressForm.Controls | Where-Object { $_.Name -eq "ETALabel" }

    # Estimate total time for all passes
    $estimatedSecondsPerPass = Estimate-PassTime -SizeGB $SizeGB
    $eta = [TimeSpan]::FromSeconds($estimatedSecondsPerPass * $totalPasses)

    Write-Host "Wiping disk $DiskNumber ($SizeGB GB) with $totalPasses passes..."

    for ($pass = 1; $pass -le $totalPasses; $pass++) {
        $statusLabel.Text = "Pass $pass of $totalPasses : Writing zeros to disk $DiskNumber"
        $progressBar.Value = (($pass - 1) * 100) / $totalPasses
        $etaLabel.Text = "Estimated time remaining: $eta"

        [System.Windows.Forms.Application]::DoEvents()

        # Create and run diskpart script with clean all
        $diskpartScriptPath = "$env:TEMP\diskpart_script_$DiskNumber.txt"
        Create-DiskpartScript -DiskNumber $DiskNumber -ScriptPath $diskpartScriptPath

        try {
            $startTime = Get-Date
            $diskpartOutput = diskpart /s $diskpartScriptPath
            Write-Host $diskpartOutput
            $elapsed = (Get-Date) - $startTime
            # Update ETA based on actual time taken
            $eta = [TimeSpan]::FromSeconds($elapsed.TotalSeconds * ($totalPasses - $pass))
        } catch {
            Write-Warning "Error during zeroing pass $pass on disk $DiskNumber : $_"
            $ProgressForm.Close()
            Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
            return $false
        }

        Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
        $progressBar.Value = ($pass * 100) / $totalPasses
        [System.Windows.Forms.Application]::DoEvents()
    }

    $statusLabel.Text = "Disk $DiskNumber wiped successfully."
    $etaLabel.Text = "Completed"
    $ProgressForm.Controls | Where-Object { $_.Text -eq "Cancel" } | ForEach-Object { $_.Enabled = $false }
    Start-Sleep -Seconds 2
    $ProgressForm.Close()
    return $true
}

# Create GUI for disk selection
function Show-DiskSelectionGUI {
    $disks = Get-PhysicalDisks
    if ($disks.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No removable or USB disks detected.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Disk to Wipe"
    $form.Size = New-Object System.Drawing.Size(400, 300)
    $form.StartPosition = "CenterScreen"

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10, 10)
    $listBox.Size = New-Object System.Drawing.Size(360, 150)
    $listBox.SelectionMode = "One"

    foreach ($disk in $disks) {
        $listBox.Items.Add("Disk $($disk.Index): $($disk.Model) ($($disk.SizeGB) GB)")
    }

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(100, 200)
    $okButton.Size = New-Object System.Drawing.Size(75, 30)
    $okButton.Text = "OK"
    $okButton.Enabled = $false

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(200, 200)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 30)
    $cancelButton.Text = "Cancel"

    $listBox.Add_SelectedIndexChanged({ $okButton.Enabled = $true })
    $cancelButton.Add_Click({ $form.Close() })

    $okButton.Add_Click({
        $selectedDisk = $disks[$listBox.SelectedIndex]
        $diskNumber = $selectedDisk.Index
        $sizeGB = $selectedDisk.SizeGB

        # Confirm wipe action
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "WARNING: This will PERMANENTLY erase all data on Disk $diskNumber ($($selectedDisk.Model), $sizeGB GB).`nType 'YES' in the next prompt to continue.",
            "Confirm Wipe",
            [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($confirm -eq "OK") {
            $form.Close()
            $confirmationForm = New-Object System.Windows.Forms.Form
            $confirmationForm.Text = "Confirm Wipe"
            $confirmationForm.Size = New-Object System.Drawing.Size(300, 150)
            $confirmationForm.StartPosition = "CenterScreen"

            $label = New-Object System.Windows.Forms.Label
            $label.Location = New-Object System.Drawing.Point(10, 20)
            $label.Size = New-Object System.Drawing.Size(260, 20)
            $label.Text = "Type 'YES' to confirm wipe of Disk $diskNumber"

            $textBox = New-Object System.Windows.Forms.TextBox
            $textBox.Location = New-Object System.Drawing.Point(10, 50)
            $textBox.Size = New-Object System.Drawing.Size(260, 20)

            $confirmButton = New-Object System.Windows.Forms.Button
            $confirmButton.Location = New-Object System.Drawing.Point(100, 80)
            $confirmButton.Size = New-Object System.Drawing.Size(75, 30)
            $confirmButton.Text = "Confirm"

            $cancelConfirmButton = New-Object System.Windows.Forms.Button
            $cancelConfirmButton.Location = New-Object System.Drawing.Point(180, 80)
            $cancelConfirmButton.Size = New-Object System.Drawing.Size(75, 30)
            $cancelConfirmButton.Text = "Cancel"

            $confirmButton.Add_Click({
                if ($textBox.Text -eq "YES") {
                    $confirmationForm.Close()
                    # Create progress form
                    $progressForm = New-Object System.Windows.Forms.Form
                    $progressForm.Text = "Wiping Disk $diskNumber"
                    $progressForm.Size = New-Object System.Drawing.Size(400, 200)
                    $progressForm.StartPosition = "CenterScreen"

                    $progressBar = New-Object System.Windows.Forms.ProgressBar
                    $progressBar.Name = "ProgressBar"
                    $progressBar.Location = New-Object System.Drawing.Point(10, 50)
                    $progressBar.Size = New-Object System.Drawing.Size(360, 20)
                    $progressBar.Minimum = 0
                    $progressBar.Maximum = 100

                    $statusLabel = New-Object System.Windows.Forms.Label
                    $statusLabel.Name = "StatusLabel"
                    $statusLabel.Location = New-Object System.Drawing.Point(10, 20)
                    $statusLabel.Size = New-Object System.Drawing.Size(360, 20)
                    $statusLabel.Text = "Preparing to wipe..."

                    $etaLabel = New-Object System.Windows.Forms.Label
                    $etaLabel.Name = "ETALabel"
                    $etaLabel.Location = New-Object System.Drawing.Point(10, 80)
                    $etaLabel.Size = New-Object System.Drawing.Size(360, 20)
                    $etaLabel.Text = "Estimating time..."

                    $cancelProgressButton = New-Object System.Windows.Forms.Button
                    $cancelProgressButton.Location = New-Object System.Drawing.Point(150, 120)
                    $cancelProgressButton.Size = New-Object System.Drawing.Size(75, 30)
                    $cancelProgressButton.Text = "Cancel"

                    $cancelProgressButton.Add_Click({ $progressForm.Close() })

                    $progressForm.Controls.AddRange(@($progressBar, $statusLabel, $etaLabel, $cancelProgressButton))
                    $progressForm.Show()

                    # Perform wipe
                    $success = Wipe-Disk -DiskNumber $diskNumber -SizeGB $sizeGB -ProgressForm $progressForm
                    if ($success) {
                        [System.Windows.Forms.MessageBox]::Show("Disk $diskNumber wiped successfully.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Failed to wipe Disk $diskNumber.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    }
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Wipe aborted. 'YES' was not entered.", "Aborted", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                    $confirmationForm.Close()
                }
            })

            $cancelConfirmButton.Add_Click({ $confirmationForm.Close() })

            $confirmationForm.Controls.AddRange(@($label, $textBox, $confirmButton, $cancelConfirmButton))
            $confirmationForm.ShowDialog()
        }
    })

    $form.Controls.AddRange(@($listBox, $okButton, $cancelButton))
    $form.ShowDialog()
}

# Main script
Show-DiskSelectionGUI
Write-Host "Script completed."