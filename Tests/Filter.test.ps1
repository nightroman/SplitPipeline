
<#
.Synopsis
	Tests Split-Pipeline -Filter.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

task FilterInputUniqueByScript {
	$hash = @{}
	1,1,2,2,3,3,4,4,5,5 | Split-Pipeline -OutVariable OutVariable {$input} -Filter {
		if (!$hash.Contains($args[0])) {
			$hash.Add($args[0], $null)
			$true
		}
	}
	assert ($OutVariable.Count -eq 5)
	assert ('1 2 3 4 5' -eq (($OutVariable | Sort-Object) -join ' '))
}

task FilterInputUniqueByHashtable {
	1,1,2,2,3,3,4,4,5,5 | Split-Pipeline -OutVariable OutVariable {$input} -Filter @{}
	assert ($OutVariable.Count -eq 5)
	assert ('1 2 3 4 5' -eq (($OutVariable | Sort-Object) -join ' '))
}
