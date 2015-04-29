
<#
.Synopsis
	Tests Split-Pipeline.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

task ApartmentState {
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

	assert ($OV.Count -eq 1)
	assert (42 -eq $OV[0])
	assert ($EV.Count -eq 1)
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
