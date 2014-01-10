
<#
.Synopsis
	https://github.com/nightroman/SplitPipeline/issues/3

.Description
	Problem: Ctrl-C does not stop the pipeline, it hangs.

	It is difficult to reproduce the original problem case (3rd party tools).
	This script has a similar problem. The change fixes both cases.

	Manual test steps:

	- Invoke the script. Two Notepad windows are opened by two parallel
	pipelines and Split-Pipeline waits for them infinitely.
	- Press Ctrl-C in the calling console, it still waits.
	- Close Notepad windows manually.

	As a result, Split-Pipeline should exit to the prompt or completely
	depending on how it was started. It should not hang in any case.
#>

1..9 | Split-Pipeline -Verbose -Count 2 {process{
	$p = Start-Process Notepad -PassThru
	$p.WaitForExit()
}}
