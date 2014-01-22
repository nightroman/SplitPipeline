
<#
.Synopsis
	Tests Split-Pipeline host features.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

task ProgressJobs {
	exec { PowerShell.exe .\Test-ProgressJobs.ps1 }
}

task ProgressTotal {
	exec { PowerShell.exe .\Test-ProgressTotal.ps1 }
}

task WriteHost {
	1..5 | Split-Pipeline -Count 5 -Variable lastId {process{
		Write-Host "Item $_"
		"Done $_"
	}}
}
