<#
.Synopsis
	Tests stopping of Split-Pipeline.
#>

#requires -Modules SplitPipeline
Set-StrictMode -Version 3

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
	WaitForExit is not stopped this way.

	- Close notepads. Split-Pipeline exits, not hangs.
#>
task Issue3 {
	assert (!(Get-Process wordpad -ErrorAction Ignore))

	remove C:\TEMP\SplitPipelineIssue3
	$null = mkdir C:\TEMP\SplitPipelineIssue3

	# Split-Pipeline to be stopped
	$ps = [PowerShell]::Create()
	$null = $ps.AddScript({
		Import-Module SplitPipeline
		1..4 | Split-Pipeline -Verbose -Count 2 `
		-Script {process{
			$p = Start-Process wordpad -PassThru
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
	$null = $ps.BeginInvoke()

	# wait for two jobs to start, i.e. two processes
	while(@(Get-Process wordpad -ErrorAction Ignore).Count -lt 2) {
		Start-Sleep -Milliseconds 100
	}

	# 2 jobs started
	equals @(Get-Process wordpad).Count 2

	# start stopping, fake [Ctrl-C]
	'BeginStop'
	$a2 = $ps.BeginStop($null, $null)

	#! kill processes, this releases jobs
	#! PSv2 Stop-Process is not enough
	Start-Sleep 2
	while(Get-Process wordpad -ErrorAction Ignore) {
		Stop-Process -Name wordpad
		Start-Sleep -Milliseconds 100
	}

	# wait, hangs in v1.2.0
	'WaitOne'
	$null = $a2.AsyncWaitHandle.WaitOne()

	# no new jobs or processes (3 and 4)
	Start-Sleep 2
	assert (!(Get-Process wordpad -ErrorAction Ignore))

	# logs
	$logs = Get-Item C:\TEMP\SplitPipelineIssue3\*
	equals $logs.Count 4
	assert ($logs[0].Name -like 'Begin-*-*-*-*-*')
	assert ($logs[1].Name -like 'Begin-*-*-*-*-*')
	assert ($logs[2].Name -like 'Finally-*-*-*-*-*')
	assert ($logs[3].Name -like 'Finally-*-*-*-*-*')

	# end
	remove C:\TEMP\SplitPipelineIssue3
}

task Random {
	.\Test-Stopping-Random.ps1 10
}
