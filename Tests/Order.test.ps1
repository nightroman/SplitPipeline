
<#
.Synopsis
	Tests Split-Pipeline -Order.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

task Ordered {
	# common parameters of two tests
	$param = @{
		Variable = 'lastId'
		Count = 3
		Load = 1, 5
		Begin = {
			$id = ++$lastId.Value
		}
		Script = {
			$input
			[System.Threading.Thread]::Sleep((3 - $id) * 50)
		}
	}

	$data = 1..100
	$sample = "$data"

	# unordered
	$lastId = [ref]-1
	($r = 1..100 | Split-Pipeline @param)
	if ("$r" -eq $sample) { Write-Warning "Normally expected unordered data." }

	# ordered
	$lastId = [ref]-1
	($r = 1..100 | Split-Pipeline -Order @param)
	equals "$r" $sample

	# ordered, 1.6.0
	$lastId = [ref]-1
	($r = Split-Pipeline -Order @param (1..100))
	equals "$r" $sample
}
