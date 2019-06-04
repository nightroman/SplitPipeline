<#
.Synopsis
	Test-ProgressTotal.ps1 using the helper $Pipeline.Lock.

.Description
	This sample is the simplified variant of Test-ProgressTotal.ps1.
	The helper $Pipeline.Lock was introduced for scenarios like this.
#>

Import-Module SplitPipeline

# input items
$items = 1..100

# shared data
$data = @{
	Count = $items.Count
	Done = 0
}

$items | Split-Pipeline -Count 5 -Variable data {process{
	# simulate some job
	Start-Sleep -Milliseconds (Get-Random -Maximum 500)

	# update and get shared data using the lock
	#! covers `InvokeReturnAsIs` instead of `Invoke`
	$done = $Pipeline.Lock({ $done = ++$data.Done; $done })

	# show progress
	Write-Progress -Activity "Done $done" -Status Processing -PercentComplete (100*$done/$data.Count)
}}

# assert
if ($data.Done -ne $items.Count) { throw 'Processed and input item counts must be equal.' }
