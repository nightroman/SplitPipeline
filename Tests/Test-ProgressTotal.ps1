
<#
.Synopsis
	How to use Write-Progress in jobs to show the total progress.

.Description
	The hashtable $data is used by jobs simultaneously. It contains the total
	number of items Count (read only) and the counter of processed items Done
	(read and written). These data are used to calculate the percentage for
	Write-Progress.

	Note that Done is updated in a critical section. Use of try/finally there
	may be redundant in this trivial example but this is the standard pattern.
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

	# enter the critical section
	[System.Threading.Monitor]::Enter($data)
	try {
		# update shared data
		$done = ++$data.Done
	}
	finally {
		# exit the critical section
		[System.Threading.Monitor]::Exit($data)
	}

	# show progress
	Write-Progress -Activity "Done $done" -Status Processing -PercentComplete (100*$done/$data.Count)
}}

# assert
if ($data.Done -ne $items.Count) { throw 'Processed and input item counts must be equal.' }
