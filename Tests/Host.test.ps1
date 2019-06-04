
<#
.Synopsis
	Tests Split-Pipeline host features.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest
$Version = $PSVersionTable.PSVersion.Major

task ProgressJobs {
	exec { PowerShell.exe .\Test-ProgressJobs.ps1 }
}

task ProgressTotal {
	exec { PowerShell.exe .\Test-ProgressTotal.ps1 }
}

task ProgressTotal2 {
	exec { PowerShell.exe .\Test-ProgressTotal2.ps1 }
}

task WriteHost {
	1..5 | Split-Pipeline -Count 5 -Variable lastId {process{
		Write-Host "Item $_"
		"Done $_"
	}}
}

task Transcript -If ($Version -ge 5) {
	.\Test-Transcript.ps1

	$r = [IO.File]::ReadAllLines("$env:TEMP\z.log")
	assert ($r -contains 'log (1)')
	assert ($r -contains 'log (42)')
	assert ($r -contains 'process (1)')
	assert ($r -contains 'process (42)')

	remove "$env:TEMP\z.log"
}
