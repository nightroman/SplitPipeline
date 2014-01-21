
<#
.Synopsis
	Tests stopping of Split-Pipeline.

.Link
	Invoked by https://github.com/nightroman/Invoke-Build
#>

Import-Module SplitPipeline
Set-StrictMode -Version Latest

<#
	[Ctrl-C] hangs in v1.2.0, works in 1.2.1
	https://github.com/nightroman/SplitPipeline/issues/3

	MANUAL TEST SCRIPT

		1..4 | Split-Pipeline -Verbose -Count 2 {process{
			$p = Start-Process notepad -PassThru
			$p.WaitForExit()
		}}

	- Invoke the script. Two notepads are opened by two jobs. Split-Pipeline
	waits for them.

	- Press [Ctrl-C] in the calling console. Split-Pipeline still waits because
	WaitForExit is not stopped so, I guess.

	- Close notepads. Split-Pipeline exits, not hangs.
#>
task Issue3 {
	assert (!(Get-Process [n]otepad))

	Remove-Item -LiteralPath "C:\TEMP\SplitPipelineIssue3" -Force -Recurse -ErrorAction 0
	$null = mkdir "C:\TEMP\SplitPipelineIssue3"

	# Split-Pipeline to be stopped
	$ps = [PowerShell]::Create()
	$null = $ps.AddScript({
		Import-Module SplitPipeline
		1..4 | Split-Pipeline -Verbose -Count 2 `
		-Script {process{
			$p = Start-Process notepad -PassThru
			$p.WaitForExit()
		}} `
		-Begin {
			$id = [runspace]::DefaultRunspace.InstanceId
			1 > "C:\TEMP\SplitPipelineIssue3\Begin-$id"
		} `
		-End {
			1 > "C:\TEMP\SplitPipelineIssue3\End-$id"
		} `
		-Finally {
			1 > "C:\TEMP\SplitPipelineIssue3\Finally-$id"
		}
	})

	# start Split-Pipeline
	'BeginInvoke'
	$a1 = $ps.BeginInvoke()

	# wait for two jobs to start, i.e. two notepads
	while(@(Get-Process [n]otepad).Count -lt 2) {
		Start-Sleep -Milliseconds 100
	}

	# 2 jobs started
	assert (@(Get-Process [n]otepad).Count -eq 2)

	# start stopping, fake [Ctrl-C]
	'BeginStop'
	$a2 = $ps.BeginStop($null, $null)

	#! kill notepads, this releases jobs
	#! PSv2 Stop-Process is not enough
	Start-Sleep 2
	while(Get-Process [n]otepad) {
		Stop-Process -Name [n]otepad
		Start-Sleep -Milliseconds 100
	}

	# wait, hangs in v1.2.0
	'WaitOne'
	$null = $a2.AsyncWaitHandle.WaitOne()

	# no new jobs or notepads (3 and 4)
	Start-Sleep 2
	assert (!(Get-Process [N]otepad))

	# logs
	$logs = Get-Item "C:\TEMP\SplitPipelineIssue3\*"
	assert ($logs.Count -eq 4)
	assert ($logs[0].Name -like 'Begin-*-*-*-*-*')
	assert ($logs[1].Name -like 'Begin-*-*-*-*-*')
	assert ($logs[2].Name -like 'Finally-*-*-*-*-*')
	assert ($logs[3].Name -like 'Finally-*-*-*-*-*')

	# end
	Remove-Item -LiteralPath "C:\TEMP\SplitPipelineIssue3" -Force -Recurse -ErrorAction 0
}

task Random {
	.\Test-Stopping-Random.ps1 10
}
