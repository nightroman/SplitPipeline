<#
.Synopsis
	Tests Split-Pipeline.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

#requires -Modules SplitPipeline
Set-StrictMode -Version 3

task help {
	. Helps.ps1
	Test-Helps ..\Module\en-US\SplitPipeline.dll-Help.ps1
}

task ApartmentState {
	equals MTA (1 | Split-Pipeline { [System.Threading.Thread]::CurrentThread.ApartmentState.ToString() })
	equals MTA (1 | Split-Pipeline -ApartmentState MTA { [System.Threading.Thread]::CurrentThread.ApartmentState.ToString() })
	equals STA (1 | Split-Pipeline -ApartmentState STA { [System.Threading.Thread]::CurrentThread.ApartmentState.ToString() })
}

task JobSoftErrorAndCmdletErrorContinueMode {
	42 | Split-Pipeline -ErrorAction Continue -OutVariable OV -ErrorVariable EV {process{
		$_
		Get-Variable MissingSafe
	}}

	equals $OV.Count 1
	equals $OV[0] 42
	equals $EV.Count 1
	assert ('ObjectNotFound: (MissingSafe:String) [Split-Pipeline], ItemNotFoundException' -eq $EV[0].CategoryInfo)
}

task JobSoftErrorThenFailure {
	$e = ''
	try {
		42 | Split-Pipeline {process{
			Get-Variable MissingSafe
			Get-Variable MissingStop -ErrorAction Stop
		}}
	}
	catch {($e = $_)}
	assert ('ObjectNotFound: (MissingStop:String) [Get-Variable], ItemNotFoundException' -eq $e.CategoryInfo)
}

task Refill {
	.\Test-Refill.ps1
}

# Issue #12
task VerbosePreferenceString {
	$VerbosePreference = 'Continue'
	1 | Split-Pipeline {
		Write-Verbose test-verbose
	}
}

# Issue #12
task VerbosePreferenceNumber {
	$VerbosePreference = 2
	1 | Split-Pipeline {
		Write-Verbose test-verbose
	}
}

# Issue #12
task VerbosePreferenceInvalid {
	$VerbosePreference = 'Invalid'
	1 | Split-Pipeline {
		Write-Verbose test-verbose
	}
}

# Issue #29
# 2024-01-11: With v2.0.0 or Windows 11 or new PC, output is less predictble
task WarningVariable {
	1..2 | Split-Pipeline -WarningVariable WV {process{ Write-Warning "test-WarningVariable" }}
	assert ($WV.Count -ge 2)
	equals $WV[0].Message test-WarningVariable
	equals $WV[1].Message test-WarningVariable
}

# Issue #32
task Test-Start-Job {
	$r = ./Test-Start-Job.ps1
	$r | Out-String

	# expected saved time
	assert ($r.Time -lt 8)

	# expected 20 items with different PIDs
	$data = $r.Data | Sort-Object Item
	equals $data.Count 8
	equals $data[0].Item 1
	equals $data[-1].Item 8
	assert ($data[0].PID -ne $data[1].PID)
}
