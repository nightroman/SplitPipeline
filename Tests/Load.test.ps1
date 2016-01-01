
<#
.Synopsis
	Tests Split-Pipeline -Load.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

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
task TheWholeInput {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count}
	$r
	equals $r.Count 2
	equals $r[0] 6
	equals $r[1] 5
}

# `-Load 1` lets the algorithm to work as soon as any input available
task LetItChoose {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count} -Load 1
	$r
	assert ($r.Count -ge 4)
	equals $r[0] 1
	equals $r[1] 1
	equals ($r | Measure-Object -Sum).Sum 11.0
}

# `-Load 2` sets the minimum
task Min2MaxX {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count} -Load 2
	$r
	assert ($r.Count -ge 4)
	equals $r[0] 2
	equals $r[1] 2
	equals ($r | Measure-Object -Sum).Sum 11.0
}

# `-Load 4,4` sets the part size to 4
task Min4Max4 {
	$r = 1..11 | Split-Pipeline -Count 2 {@($input).Count} -Load 4,4 -Order
	$r
	equals $r.Count 3
	equals $r[0] 4
	equals $r[1] 4
	equals $r[2] 3
}
