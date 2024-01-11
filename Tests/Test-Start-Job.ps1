<#
.Synopsis
	How to use Start-Job for pipelines in separate processes.

.Description
	Use Start-Job to run pipelines in separate processes, e.g. in cases like
	https://github.com/nightroman/SplitPipeline/issues/32

	The sample jobs would take ~8 seconds when run sequentially.
	With Split-Pipeline and Start-Job they take ~4 seconds.

	Note that Start-Job is relatively expensive and
	Split-Pipeline may work slower with faster jobs.
#>

Import-Module SplitPipeline

$sw = [System.Diagnostics.Stopwatch]::StartNew()

$data = 1..8 | Split-Pipeline -Count 4 {process{
	$job = Start-Job -ArgumentList $_ {
		# fake time consuming job
		Start-Sleep 1

		# output the current item and process ID
		[PSCustomObject]@{
			Item = $args[0]
			PID = $PID
		}
	}
	$job | Receive-Job -Wait
}}

[PSCustomObject]@{
	Time = $sw.Elapsed.TotalSeconds
	Data = $data
}
