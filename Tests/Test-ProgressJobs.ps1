
<#
.Synopsis
	How to use Write-Progress in jobs to show each job progress.

.Description
	The Begin script assigns $id to each job using the shared counter $lastId.
	$lastId does not have to be synchronised because Begin is invoked for each
	job on its creation synchronously. As far as Begin is invoked in a separate
	runspace, the counter has to be passed in via Variable.

	Then each job uses its $id as activity ID for Write-Progress so that each
	job progress is visualized separately.
#>

Import-Module SplitPipeline

$lastId = [ref]0

1..100 | Split-Pipeline -Count 5 -Variable lastId {
	$data = @($input)
	for($1 = 1; $1 -le $data.Count; ++$1) {
		Write-Progress -Id $id -Activity "Job $id" -Status Processing -PercentComplete (100*$1/$data.Count)
		Start-Sleep -Milliseconds (Get-Random -Maximum 500)
	}
} -Begin {
	$id = ++$lastId.Value
}
