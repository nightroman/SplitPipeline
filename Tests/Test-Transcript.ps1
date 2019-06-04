<#
.Synopsis
	How to use transcript with Write-Host in pipelines.

.Description
	This technique works around the issue #25.

.Link
	https://github.com/nightroman/SplitPipeline/issues/25
#>

Start-Transcript "$env:TEMP\z.log"

# The helper for Write-Host for pipelines working with transcript.
$helper = New-Module -AsCustomObject -ScriptBlock {
	Import-Module Microsoft.PowerShell.Utility
	function WriteHost {
		Write-Host $args[0]
	}
}

1..42 | Split-Pipeline -Variable helper -Script {process{
	# call the helper Write-Host using the lock
	$Pipeline.Lock({ $helper.WriteHost("log ($_)") })

	# normal processing
	"process ($_)"
}}

Stop-Transcript
