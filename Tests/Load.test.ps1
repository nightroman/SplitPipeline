
<#
.Synopsis
	Tests Split-Pipeline -Load.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

# Count words in input data. We used to output just `@($input).Count` and check
# output counts, i.e. $r[0] 1, $r[1] 1. The problem: 3rd load may output before
# 2nd pipe is done. Thus we either should use -Order or output/check differently.
# So we output joined items and check them anywhere, not just at [0] or [1].
function Get-WordCount($Data) {
	$count = 0
	foreach($_ in $Data) {
		$count += $_.Split(' ').Length
	}
	$count
}

task Error {
	# 0 args
	($r = try {1..9 | Split-Pipeline {} -Load @()} catch {$_})
	equals $r.FullyQualifiedErrorId 'ParameterArgumentValidationError,SplitPipeline.SplitPipelineCommand'

	# null
	($r = try {1..9 | Split-Pipeline {} -Load $null} catch {$_})
	equals $r.FullyQualifiedErrorId 'ParameterArgumentValidationError,SplitPipeline.SplitPipelineCommand'

	# 3+ args
	($r = try {1..9 | Split-Pipeline {} -Load 1,2,3} catch {$_})
	equals $r.FullyQualifiedErrorId 'ParameterArgumentValidationError,SplitPipeline.SplitPipelineCommand'

	# [0] > [1]
	($r = try {1..9 | Split-Pipeline {} -Load 1,0} catch {$_})
	equals $r.FullyQualifiedErrorId 'ParameterBindingFailed,SplitPipeline.SplitPipelineCommand'

	# [0]<1 is fine and treated as omitted, [1] is ignored
	$r = 1..9 | Split-Pipeline {@($input).Count} -Load 0,-1 -Count 2
	equals $r.Count 2
	equals $r[0] 5
	equals $r[1] 4
}

# v1.4.0 By default the whole input is collected and split evenly
#! The order is not guaranteed but so far this test works as is.
task TheWholeInput {
	($r = 1..11 | Split-Pipeline -Count 2 {@($input).Count})
	equals $r.Count 2
	equals $r[0] 6
	equals $r[1] 5

	# same using the parameter, 1.6.0
	($r = Split-Pipeline -Count 2 {@($input).Count} (1..11))
	equals $r.Count 2
	equals $r[0] 6
	equals $r[1] 5
}

# `-Load 1` lets the algorithm to work as soon as any input available
#! This test was the first to show not predicted order problems and was redesigned.
task LetItChoose {
	($r = 1..11 | Split-Pipeline -Count 2 {@($input) -join ' '} -Load 1)
	assert ($r.Count -ge 4)
	assert ($r -contains '1')
	assert ($r -contains '2')
	equals (Get-WordCount $r) 11
}

# `-Load 2` sets the minimum
task Min2MaxX {
	($r = 1..11 | Split-Pipeline -Count 2 {@($input) -join ' '} -Load 2)
	assert ($r.Count -ge 4)
	assert ($r -contains '1 2')
	assert ($r -contains '3 4')
	equals (Get-WordCount $r) 11
}

# `-Load 4,4` sets the part size to 4
task Min4Max4 {
	($r = 1..11 | Split-Pipeline -Count 2 {@($input) -join ' '} -Load 4,4 -Order)
	equals $r.Count 3
	assert ($r -contains '1 2 3 4')
	assert ($r -contains '5 6 7 8')
	assert ($r -contains '9 10 11')
}
