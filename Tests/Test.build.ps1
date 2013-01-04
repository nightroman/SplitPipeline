
Import-Module SplitPipeline

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

task JobSoftErrorAndCmdletErrorContinueMode {
	#! V3 RC works
	#if ($PSVersionTable.PSVersion.Major -ge 3) { Write-Warning "Skipping V3 CTP2 issue."; return }

	42 | Split-Pipeline -ErrorAction Continue -OutVariable OutVariable -ErrorVariable ErrorVariable {process{
		$_
		Get-Variable MissingSafe
	}}

	assert ($OutVariable.Count -eq 1)
	assert (42 -eq $OutVariable[0])
	assert ($ErrorVariable.Count -eq 1)
	assert ("Cannot find a variable with name 'MissingSafe'." -eq $ErrorVariable[0])
}

task JobSoftErrorThenFailure {
	$4 = ''
	try {
		42 | Split-Pipeline {process{
			Get-Variable MissingSafe
			Get-Variable MissingStop -ErrorAction Stop
		}}
	}
	catch {$4 = "$_"}

	Write-Build Magenta $4
	assert ($4 -eq "Cannot find a variable with name 'MissingStop'.") $4
}

task Finally1 {
	$1 = ''
	try {
		1..10 | Split-Pipeline -Count 2 -Load 1 `
		-Script {throw 'Throw in Script'} `
		-Finally {throw 'Throw in Finally'}
	}
	catch { $1 = "$_" }
	assert ($1 -eq 'Throw in Script')
}

task Finally2 {
	$result = @(
		1..2 | Split-Pipeline -Count 2 -Load 1 `
		-Script {process{$_}} `
		-Finally {throw 'Throw in Finally'}
	)

	assert ($result.Count -eq 2) $result.Count
}

task BeginProcessEnd {
	$result = 1..4 | Split-Pipeline -Count 2 -Load 1 -Verbose `
	-Begin {
		$VerbosePreference = 'Continue'
		'begin split'
		Write-Warning 'Warning in begin split'
		Write-Verbose 'Verbose in begin split'
		Write-Error 'Error in begin split'
	} `
	-End {
		'end split'
		Write-Warning 'Warning in end split'
		Write-Verbose 'Verbose in end split'
		Write-Error 'Error in end split'
	} `
	-Script {
		begin {
			'begin part'
			Write-Warning 'Warning in script'
			Write-Verbose 'Verbose in script'
			Write-Error 'Error in script'
		}
		process {
			$_
		}
		end {
			'end part'
		}
	}
	$result

	# 1 or 2 'begin/end split' due to -Count 2
	$begin_split = ($result -eq 'begin split').Count
	$end_split = ($result -eq 'end split').Count
	assert ($begin_split -eq 1 -or $begin_split -eq 2) $begin_split
	assert ($end_split -eq 1 -or $end_split -eq 2) $end_split
	assert ($begin_split -eq $end_split)

	# 4 'begin/end part' due to 4 items and -Limit 1
	assert (($result -eq 'begin part').Count -eq 4)
	assert (($result -eq 'end part').Count -eq 4)

	# all
	assert ($result.Count -eq (12 + 2 * $end_split))
}

task ImportModule {
	$result = 1..10 | Split-Pipeline -Count 2 -Module SplitPipeline {
		$input | Split-Pipeline -Count 2 {$input}
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

task Refill {
	.\Test-Refill.ps1
}
