
Import-Module SplitPipeline

task Finally1 {
	$1 = ''
	try {
		1..10 | Split-Pipeline -Count 2 -Limit 1 `
		-Script {throw 'Throw in Script'} `
		-Finally {throw 'Throw in Finally'}
	}
	catch { $1 = "$_" }
	assert ($1 -eq 'Throw in Script')
}

task Finally2 {
	$result = @(
		1..2 | Split-Pipeline -Count 2 -Limit 1 `
		-Script {process{$_}} `
		-Finally {throw 'Throw in Finally'}
	)

	assert ($result.Count -eq 2) $result.Count
}

task BeginProcessEnd {
	$result = 1..4 | Split-Pipeline -Count 2 -Limit 1 -Verbose `
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

#! Sleep long enough in order to get these results.
task LastTakesAll {
	$1 = 1..9 | Split-Pipeline -Count 2 {
		@($input).Count
		Start-Sleep -Milliseconds 250
	}
	# 4 parts: 1, 1, 4, 5. At first 2 pipes are loaded by 1. Next part size is
	# 3 ~ 7/2. The last takes all.
	assert ($1.Count -eq 4) $1.Count
	assert ($1[0] -eq 1)
	assert ($1[1] -eq 1)
	assert ($1[2] -eq 3)
	assert ($1[3] -eq 4)
}

task SmallQueue {
	$1 = 1..111 | Split-Pipeline -Load 20 -Queue 10 {
		process {$_}
	}
	assert ($1.Count -eq 111)
}
