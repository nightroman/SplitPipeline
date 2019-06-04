
<#
.Synopsis
	Tests Split-Pipeline -Count.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

# Use large enough number of items. Small number may not load all cores.
# Example: 20 items for 8 cores actually gives 7 pipes: 3, 3, .. 2
$ItemCount = 1000
$ProcessorCount = [Environment]::ProcessorCount

task Error {
	# [0] <= 0 ~ default
	$r = 1..$ItemCount | Split-Pipeline {@($input).Count} -Count 0, -1
	equals $r.Count $ProcessorCount

	$$ = try { 1..9 | Split-Pipeline {} -Count 1, -1 } catch { $_ }
	assert ("$$" -clike @'
*Exception setting "Count": "Count maximum must be greater or equal to minimum."
'@)
}

task LessThanProcessorCount {
	$r = @(1..$ItemCount | Split-Pipeline {1} -Count 1, 1)
	equals $r.Count 1
}

task EqualToProcessorCount0 {
	$r = @(1..$ItemCount | Split-Pipeline {1} -Count 1, $ProcessorCount)
	equals $r.Count $ProcessorCount
}

task EqualToProcessorCount1 {
	$r = @(1..$ItemCount | Split-Pipeline {1} -Count 1, ($ProcessorCount + 1))
	equals $r.Count $ProcessorCount
}
