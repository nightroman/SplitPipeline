
<#
.Synopsis
	Tests Split-Pipeline -Begin -Script -End -Finally.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

$Version = $PSVersionTable.PSVersion.Major
$IsCore = $Version -eq 6 -and $PSVersionTable.PSEdition -eq 'Core'

task Finally1 {
	$1 = ''
	try {
		1..10 | Split-Pipeline -Count 2 -Load 1 `
		-Script {throw 'Throw in Script'} `
		-Finally {throw 'Throw in Finally'}
	}
	catch { $1 = "$_" }
	equals $1 'Throw in Script'
}

task Finally2 {
	$result = @(
		1..2 | Split-Pipeline -Count 2 -Load 1 `
		-Script {process{$_}} `
		-Finally {throw 'Throw in Finally'}
	)

	assert ($result.Count -eq 2) $result.Count
}

task BeginProcessEnd -If (!$IsCore) {
	$DebugPreference = 'Continue'
	$result = 1..4 | Split-Pipeline -Count 2 -Load 1 -Verbose `
	-Begin {
		$DebugPreference = 'Continue'
		$VerbosePreference = 'Continue'
		'begin split'
		Write-Debug 'Debug in begin split'
		Write-Error 'Error in begin split'
		Write-Verbose 'Verbose in begin split'
		Write-Warning 'Warning in begin split'
	} `
	-End {
		'end split'
		Write-Debug 'Debug in end split'
		Write-Error 'Error in end split'
		Write-Verbose 'Verbose in end split'
		Write-Warning 'Warning in end split'
	} `
	-Script {
		begin {
			'begin part'
			Write-Debug 'Debug in script'
			Write-Error 'Error in script'
			Write-Verbose 'Verbose in script'
			Write-Warning 'Warning in script'
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
	equals $begin_split $end_split

	# 4 'begin/end part' due to 4 items and -Limit 1
	equals ($result -eq 'begin part').Count 4
	equals ($result -eq 'end part').Count 4

	# all
	equals $result.Count (12 + 2 * $end_split)
}
