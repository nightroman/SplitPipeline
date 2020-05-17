
<#
.Synopsis
	Tests Split-Pipeline.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

$Version = $PSVersionTable.PSVersion.Major
$IsCore = $Version -eq 6 -and $PSVersionTable.PSEdition -eq 'Core'

task ApartmentState -If (!$IsCore) {
	# default
	assert ("MTA" -eq (1 | Split-Pipeline { [System.Threading.Thread]::CurrentThread.ApartmentState }))
	# MTA
	assert ("MTA" -eq (1 | Split-Pipeline -ApartmentState MTA { [System.Threading.Thread]::CurrentThread.ApartmentState }))
	# STA
	assert ("STA" -eq (1 | Split-Pipeline -ApartmentState STA { [System.Threading.Thread]::CurrentThread.ApartmentState }))
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
task WarningVariable {
	1..2 | Split-Pipeline -WarningVariable WV {process{ Write-Warning "test-WarningVariable-$_" }}
	equals $WV.Count 2
	equals $WV[0].Message test-WarningVariable-1
	equals $WV[1].Message test-WarningVariable-2
}
