
<#
.Synopsis
	Tests Split-Pipeline -Filter.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

task Error {
	$$ = try { 1..9 | Split-Pipeline {} -Filter 42 } catch { $_ }
	assert ("$$" -clike @'
*Exception setting "Filter": "Expected a hashtable or a script block."
'@)
}

task FilterInputUniqueByScript {
	$hash = @{}
	1,1,2,2,3,3,4,4,5,5 | Split-Pipeline -OutVariable OutVariable {$input} -Filter {
		if (!$hash.Contains($args[0])) {
			$hash.Add($args[0], $null)
			$true
		}
	}
	equals $OutVariable.Count 5
	equals '1 2 3 4 5' (($OutVariable | Sort-Object) -join ' ')
}

task FilterInputUniqueByHashtable {
	1,1,2,2,3,3,4,4,5,5 | Split-Pipeline -OutVariable OutVariable {$input} -Filter @{}
	equals $OutVariable.Count 5
	equals '1 2 3 4 5' (($OutVariable | Sort-Object) -join ' ')
}
