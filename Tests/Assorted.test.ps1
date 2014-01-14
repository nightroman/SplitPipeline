
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
	42 | Split-Pipeline -ErrorAction Continue -OutVariable OutVariable -ErrorVariable ErrorVariable {process{
		$_
		Get-Variable MissingSafe
	}}

	assert ($OutVariable.Count -eq 1)
	assert (42 -eq $OutVariable[0])
	assert ($ErrorVariable.Count -eq 1)
	assert ("Cannot find a variable with name 'MissingSafe'." -eq $ErrorVariable[0])
}

task JobSoftErrorThenFailure {
	$4 = ''
	try {
		42 | Split-Pipeline {process{
			Get-Variable MissingSafe
			Get-Variable MissingStop -ErrorAction Stop
		}}
	}
	catch {$4 = "$_"}

	Write-Build Magenta $4
	assert ($4 -eq "Cannot find a variable with name 'MissingStop'.") $4
}

task Refill {
	.\Test-Refill.ps1
}
