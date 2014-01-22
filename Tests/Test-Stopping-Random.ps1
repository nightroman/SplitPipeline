
<#
.Synopsis
	Tests random stopping of Split-Pipeline.

.Description
	Without parameters it repeats random tests infinitely.

	It starts Split-Pipeline with large enough input, slow Script, and Begin
	and Finally scripts. Then it waits for a random time and stops (like by
	Ctrl-C). Then it checks that Begin and Finally logs match, i.e. for each
	started job the Finally script should work even on stopping.

.Parameter Repeat
		Specifies the number of tests.
#>

param(
	$Repeat = [int]::MaxValue
)

Set-StrictMode -Version Latest

# global logs
Add-Type @'
using System;
using System.Collections;
public static class SplitPipelineLog {
	public static readonly ArrayList Begin = new ArrayList();
	public static readonly ArrayList Finally = new ArrayList();
}
'@

# test to be invoked async
$test = {
	Import-Module SplitPipeline
	$VerbosePreference = 2
	$lastId = [ref]-1

	$param = @{
		Variable = 'lastId'
		Verbose = $true
		Count = 10
		Load = 3, 1000
		Begin = {
			$random = New-Object System.Random
			$VerbosePreference = 2
			$id = ++$lastId.Value
			Write-Verbose "[$id] begin"
			$null = [SplitPipelineLog]::Begin.Add($id)
		}
		Finally = {
			$null = [SplitPipelineLog]::Finally.Add($id)
		}
		Script = {
			$all = @($input).Count
			Write-Verbose "[$id] $all items"
			[System.Threading.Thread]::Sleep($random.Next(0, 50))
		}
	}

	1..1mb | Split-Pipeline @param
}

# repeat random tests
for($n = 1; $n -le $Repeat; ++$n) {
	"[$n]" + '-'*70

	# reset logs
	[SplitPipelineLog]::Begin.Clear()
	[SplitPipelineLog]::Finally.Clear()

	# start Split-Pipeline
	$ps = [PowerShell]::Create()
	$null = $ps.AddScript($test)
	$a1 = $ps.BeginInvoke()

	# wait for a random time
	$random = New-Object System.Random
	$sleep = $random.Next(0, 2000)
	"Stop after $sleep ms"
	[System.Threading.Thread]::Sleep($sleep)

	# stop
	$ps.Stop()

	# show results
	$ps.Streams.Error
	$ps.Streams.Verbose

	#! weird, else logs may not match
	Start-Sleep -Milliseconds 500

	# Begin and Finally should match
	$begin = [SplitPipelineLog]::Begin
	$finally = [SplitPipelineLog]::Finally
	"$begin"
	"$finally"
	if ($begin.Count -ne $finally.Count) {
		Write-Warning "$begin <> $finally"
		Read-Host 'Enter'
	}
}
