
Import-Module SplitPipeline

task Finally1 {
	$$ = ''
	try {
		1..10 | Split-Pipeline -Count 2 -Limit 1 `
		-Script {throw 'Throw in Script'} `
		-Finally {throw 'Throw in Finally'}
	}
	catch { $$ = "$_" }
	assert ($$ -eq 'Throw in Script')
}

task Finally2 {
	$result = 1..2 | Split-Pipeline -Count 2 -Limit 1 `
	-Script {process{$_}} `
	-Finally {throw 'Throw in Finally'}

	$result
	assert ($result.Count -eq 2)
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

	# 2 'begin/end split' due to -Count 2
	assert (($result -eq 'begin split').Count -eq 2)
	assert (($result -eq 'end split').Count -eq 2)

	# 4 'begin/end part' due to 4 items and -Limit 1
	assert (($result -eq 'begin part').Count -eq 4)
	assert (($result -eq 'end part').Count -eq 4)

	# + 4 items 1..4 -> 16
	assert ($result.Count -eq 16)
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
	$$ = 1..9 | Split-Pipeline -Count 2 {
		@($input).Count
		Start-Sleep -Milliseconds 250
	}
	# 4 parts: 1, 1, 4, 5. At first 2 pipes are loaded by 1. Next part size is
	# 3 ~ 7/2. The last takes all.
	assert ($$.Count -eq 4) $$.Count
	assert ($$[0] -eq 1)
	assert ($$[1] -eq 1)
	assert ($$[2] -eq 3)
	assert ($$[3] -eq 4)
}

task SmallQueue {
	$$ = 1..111 | Split-Pipeline -Load 20 -Queue 10 {
		process {$_}
	}
	assert ($$.Count -eq 111)
}
