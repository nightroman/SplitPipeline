
<#
.Synopsis
	Tests Split-Pipeline -Variable -Function -Module.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

task ImportVariable {
	$value1 = 1
	$value2 = 2
	$result = 1..10 | Split-Pipeline -Count 2 -Variable value1, value2 {
		if ($value1 -ne 1) {throw 'value1'}
		if ($value2 -ne 2) {throw 'value2'}
		$input
	}
	assert ($result.Count -eq 10)
}

task ImportFunction {
	function Function1 {1}
	function Function2 {2}
	$result = 1..10 | Split-Pipeline -Count 2 -Function Function1, Function2 {
		if ((Function1) -ne 1) {throw 'Function1'}
		if ((Function2) -ne 2) {throw 'Function2'}
		$input
	}
	assert ($result.Count -eq 10)
}

task ImportModule {
	$result = 1..10 | Split-Pipeline -Count 2 -Module SplitPipeline {
		$input | Split-Pipeline -Count 2 {$input}
	}
	assert ($result.Count -eq 10)
}
