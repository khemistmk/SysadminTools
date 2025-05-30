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

# Function to estimate wipe time per pass
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

# Function to wipe a disk (runs in a job)
function Wipe-Disk {
    param (
        [string]$DiskNumber,
        [double]$SizeGB
    )

    $totalPasses = 3
    $jobId = $DiskNumber
    $cancelFlagFile = "$env:TEMP\diskpart_cancel_$jobId.txt"

    # Create progress form
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = "Wiping Disk $DiskNumber"
    $progressForm.Size = New-Object System.Drawing.Size(400, 200)
    $progressForm.StartPosition = "CenterScreen"
    $progressForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

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

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150, 120)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.Add_Click({
        New-Item -Path $cancelFlagFile -ItemType File -Force | Out-Null
        $progressForm.Close()
    })

    $progressForm.Controls.AddRange(@($progressBar, $statusLabel, $etaLabel, $cancelButton))

    # Show form in a separate runspace to keep it responsive
    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("progressForm", $progressForm)
    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript({ $progressForm.ShowDialog() }) | Out-Null
    $ps.BeginInvoke() | Out-Null

    # Estimate total time for all passes
    $estimatedSecondsPerPass = Estimate-PassTime -SizeGB $SizeGB
    $eta = [TimeSpan]::FromSeconds($estimatedSecondsPerPass * $totalPasses)

    Write-Host "Wiping disk $DiskNumber ($SizeGB GB) with $totalPasses passes..."

    for ($pass = 1; $pass -le $totalPasses; $pass++) {
        if (Test-Path $cancelFlagFile) {
            Write-Host "Wipe operation cancelled for disk $DiskNumber."
            $statusLabel.Text = "Wipe operation cancelled."
            $etaLabel.Text = "Cancelled"
            $progressBar.Value = 0
            Start-Sleep -Seconds 2
            $progressForm.Close()
            Remove-Item $cancelFlagFile -Force -ErrorAction SilentlyContinue
            $runspace.Close()
            $ps.Dispose()
            return $false
        }

        $statusLabel.Text = "Pass $pass of $totalPasses : Writing zeros to disk $DiskNumber"
        $progressBar.Value = (($pass - 1) * 100) / $totalPasses
        $etaLabel.Text = "Estimated time remaining: $eta"
        [System.Windows.Forms.Application]::DoEvents()

        # Create and run diskpart script
        $diskpartScriptPath = "$env:TEMP\diskpart_script_$DiskNumber.txt"
        Create-DiskpartScript -DiskNumber $DiskNumber -ScriptPath $diskpartScriptPath

        try {
            $startTime = Get-Date
            $process = Start-Process diskpart -ArgumentList "/s $diskpartScriptPath" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\diskpart_output_$DiskNumber.txt"
            while (-not $process.HasExited) {
                if (Test-Path $cancelFlagFile) {
                    $process.Kill()
                    Write-Host "Wipe operation cancelled for disk $DiskNumber."
                    $statusLabel.Text = "Wipe operation cancelled."
                    $etaLabel.Text = "Cancelled"
                    $progressBar.Value = 0
                    Start-Sleep -Seconds 2
                    $progressForm.Close()
                    Remove-Item $cancelFlagFile -Force -ErrorAction SilentlyContinue
                    Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
                    Remove-Item "$env:TEMP\diskpart_output_$DiskNumber.txt" -Force -ErrorAction SilentlyContinue
                    $runspace.Close()
                    $ps.Dispose()
                    return $false
                }
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 100
            }
            $diskpartOutput = Get-Content "$env:TEMP\diskpart_output_$DiskNumber.txt" -ErrorAction SilentlyContinue
            Write-Host $diskpartOutput
            Remove-Item "$env:TEMP\diskpart_output_$DiskNumber.txt" -Force -ErrorAction SilentlyContinue
            $elapsed = (Get-Date) - $startTime
            $eta = [TimeSpan]::FromSeconds($elapsed.TotalSeconds * ($totalPasses - $pass))
        } catch {
            Write-Warning "Error during zeroing pass $pass on disk $DiskNumber : $_"
            $statusLabel.Text = "Error during wipe."
            $etaLabel.Text = "Failed"
            $progressForm.Close()
            Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
            $runspace.Close()
            $ps.Dispose()
            return $false
        }

        Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
        $progressBar.Value = ($pass * 100) / $totalPasses
        [System.Windows.Forms.Application]::DoEvents()
    }

    $statusLabel.Text = "Disk $DiskNumber wiped successfully."
    $etaLabel.Text = "Completed"
    $cancelButton.Enabled = $false
    Start-Sleep -Seconds 2
    $progressForm.Close()
    $runspace.Close()
    $ps.Dispose()
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
    $form.Text = "Select Disks to Wipe"
    $form.Size = New-Object System.Drawing.Size(400, 300)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(10, 10)
    $listBox.Size = New-Object System.Drawing.Size(360, 150)
    $listBox.SelectionMode = "MultiExtended"

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

    $listBox.Add_SelectedIndexChanged({ if ($listBox.SelectedIndices.Count -gt 0) { $okButton.Enabled = $true } else { $okButton.Enabled = $false } })
    $cancelButton.Add_Click({ $form.Close() })

    $okButton.Add_Click({
        $selectedDisks = $listBox.SelectedIndices | ForEach-Object { $disks[$_] }
        $form.Close() # Close disk selection window

        # Confirm wipe action
        $diskList = ($selectedDisks | ForEach-Object { "Disk $($_.Index) ($($_.Model), $($_.SizeGB) GB)" }) -join "`n"
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "WARNING: This will PERMANENTLY erase all data on the following disks:`n$diskList`nType 'YES' in the next prompt to continue.",
            "Confirm Wipe",
            [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($confirm -eq "OK") {
            $confirmationForm = New-Object System.Windows.Forms.Form
            $confirmationForm.Text = "Confirm Wipe"
            $confirmationForm.Size = New-Object System.Drawing.Size(300, 150)
            $confirmationForm.StartPosition = "CenterScreen"
            $confirmationForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

            $label = New-Object System.Windows.Forms.Label
            $label.Location = New-Object System.Drawing.Point(10, 20)
            $label.Size = New-Object System.Drawing.Size(260, 20)
            $label.Text = "Type 'YES' to confirm wipe of selected disks"

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
                    $confirmationForm.Close() # Close confirmation window
                    # Start parallel wipe jobs
                    $jobs = @()
                    foreach ($disk in $selectedDisks) {
                        $diskNumber = $disk.Index
                        $sizeGB = $disk.SizeGB
                        $job = Start-Job -Name "WipeDisk$diskNumber" -ScriptBlock {
                            param ($DiskNumber, $SizeGB)

                            # Define required assemblies and functions within job
                            Add-Type -AssemblyName System.Windows.Forms
                            Add-Type -AssemblyName System.Drawing

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

                            function Estimate-PassTime {
                                param (
                                    [double]$SizeGB
                                )
                                $writeSpeedMBps = 50
                                $sizeMB = $SizeGB * 1024
                                $seconds = [math]::Round($sizeMB / $writeSpeedMBps)
                                return $seconds
                            }

                            function Wipe-Disk {
                                param (
                                    [string]$DiskNumber,
                                    [double]$SizeGB
                                )

                                $totalPasses = 3
                                $jobId = $DiskNumber
                                $cancelFlagFile = "$env:TEMP\diskpart_cancel_$jobId.txt"

                                # Create progress form
                                $progressForm = New-Object System.Windows.Forms.Form
                                $progressForm.Text = "Wiping Disk $DiskNumber"
                                $progressForm.Size = New-Object System.Drawing.Size(400, 200)
                                $progressForm.StartPosition = "CenterScreen"
                                $progressForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable

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

                                $cancelButton = New-Object System.Windows.Forms.Button
                                $cancelButton.Location = New-Object System.Drawing.Point(150, 120)
                                $cancelButton.Size = New-Object System.Drawing.Size(75, 30)
                                $cancelButton.Text = "Cancel"
                                $cancelButton.Add_Click({
                                    New-Item -Path $cancelFlagFile -ItemType File -Force | Out-Null
                                    $progressForm.Close()
                                })

                                $progressForm.Controls.AddRange(@($progressBar, $statusLabel, $etaLabel, $cancelButton))

                                # Show form in a separate runspace
                                $runspace = [RunspaceFactory]::CreateRunspace()
                                $runspace.Open()
                                $runspace.SessionStateProxy.SetVariable("progressForm", $progressForm)
                                $ps = [PowerShell]::Create()
                                $ps.Runspace = $runspace
                                $ps.AddScript({ $progressForm.ShowDialog() }) | Out-Null
                                $ps.BeginInvoke() | Out-Null

                                # Estimate total time
                                $estimatedSecondsPerPass = Estimate-PassTime -SizeGB $SizeGB
                                $eta = [TimeSpan]::FromSeconds($estimatedSecondsPerPass * $totalPasses)

                                Write-Host "Wiping disk $DiskNumber ($SizeGB GB) with $totalPasses passes..."

                                for ($pass = 1; $pass -le $totalPasses; $pass++) {
                                    if (Test-Path $cancelFlagFile) {
                                        Write-Host "Wipe operation cancelled for disk $DiskNumber."
                                        $statusLabel.Text = "Wipe operation cancelled."
                                        $etaLabel.Text = "Cancelled"
                                        $progressBar.Value = 0
                                        Start-Sleep -Seconds 2
                                        $progressForm.Close()
                                        Remove-Item $cancelFlagFile -Force -ErrorAction SilentlyContinue
                                        $runspace.Close()
                                        $ps.Dispose()
                                        return $false
                                    }

                                    $statusLabel.Text = "Pass $pass of $totalPasses : Writing zeros to disk $DiskNumber"
                                    $progressBar.Value = (($pass - 1) * 100) / $totalPasses
                                    $etaLabel.Text = "Estimated time remaining: $eta"
                                    [System.Windows.Forms.Application]::DoEvents()

                                    # Create and run diskpart script
                                    $diskpartScriptPath = "$env:TEMP\diskpart_script_$DiskNumber.txt"
                                    Create-DiskpartScript -DiskNumber $DiskNumber -ScriptPath $diskpartScriptPath

                                    try {
                                        $startTime = Get-Date
                                        $process = Start-Process diskpart -ArgumentList "/s $diskpartScriptPath" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\diskpart_output_$DiskNumber.txt"
                                        while (-not $process.HasExited) {
                                            if (Test-Path $cancelFlagFile) {
                                                $process.Kill()
                                                Write-Host "Wipe operation cancelled for disk $DiskNumber."
                                                $statusLabel.Text = "Wipe operation cancelled."
                                                $etaLabel.Text = "Cancelled"
                                                $progressBar.Value = 0
                                                Start-Sleep -Seconds 2
                                                $progressForm.Close()
                                                Remove-Item $cancelFlagFile -Force -ErrorAction SilentlyContinue
                                                Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
                                                Remove-Item "$env:TEMP\diskpart_output_$DiskNumber.txt" -Force -ErrorAction SilentlyContinue
                                                $runspace.Close()
                                                $ps.Dispose()
                                                return $false
                                            }
                                            [System.Windows.Forms.Application]::DoEvents()
                                            Start-Sleep -Milliseconds 100
                                        }
                                        $diskpartOutput = Get-Content "$env:TEMP\diskpart_output_$DiskNumber.txt" -ErrorAction SilentlyContinue
                                        Write-Host $diskpartOutput
                                        Remove-Item "$env:TEMP\diskpart_output_$DiskNumber.txt" -Force -ErrorAction SilentlyContinue
                                        $elapsed = (Get-Date) - $startTime
                                        $eta = [TimeSpan]::FromSeconds($elapsed.TotalSeconds * ($totalPasses - $pass))
                                    } catch {
                                        Write-Warning "Error during zeroing pass $pass on disk $DiskNumber : $_"
                                        $statusLabel.Text = "Error during wipe."
                                        $etaLabel.Text = "Failed"
                                        $progressForm.Close()
                                        Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
                                        $runspace.Close()
                                        $ps.Dispose()
                                        return $false
                                    }

                                    Remove-Item $diskpartScriptPath -Force -ErrorAction SilentlyContinue
                                    $progressBar.Value = ($pass * 100) / $totalPasses
                                    [System.Windows.Forms.Application]::DoEvents()
                                }

                                $statusLabel.Text = "Disk $DiskNumber wiped successfully."
                                $etaLabel.Text = "Completed"
                                $cancelButton.Enabled = $false
                                Start-Sleep -Seconds 2
                                $progressForm.Close()
                                $runspace.Close()
                                $ps.Dispose()
                                return $true
                            }

                            # Call Wipe-Disk within the job
                            Wipe-Disk -DiskNumber $DiskNumber -SizeGB $SizeGB
                        } -ArgumentList $diskNumber, $sizeGB
                        $jobs += $job
                    }

                    # Monitor jobs
                    while ($jobs | Where-Object { $_.State -eq "Running" }) {
                        Start-Sleep -Milliseconds 500
                    }

                    # Collect results
                    $results = $jobs | ForEach-Object { Receive-Job -Job $_ }
                    $successCount = ($results | Where-Object { $_ -eq $true }).Count
                    $failedOrCancelledCount = $results.Count - $successCount

                    [System.Windows.Forms.MessageBox]::Show(
                        "Wipe completed: $successCount disk(s) wiped successfully, $failedOrCancelledCount disk(s) cancelled or failed.",
                        "Wipe Complete",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )

                    # Clean up jobs
                    $jobs | Remove-Job -Force
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