
<#
.Synopsis
	How to use Write-Progress in jobs to show the total progress.

.Description
	The synchronised hashtable $data is used by jobs simultaneously. It
	contains the total number of items Count and the counter of processed
	items. These data are used to calculate the percentage for Write-Progress.
#>

Import-Module SplitPipeline

$items = 1..100

$data = [hashtable]::Synchronized(@{})
$data.Done = 0
$data.Count = $items.Count

$items | Split-Pipeline -Count 5 -Variable data {process{
	$done = ++$data.Done
	Write-Progress -Activity "Done $done" -Status Processing -PercentComplete (100*$done/$data.Count)
	Start-Sleep -Milliseconds (Get-Random -Maximum 500)
}}
