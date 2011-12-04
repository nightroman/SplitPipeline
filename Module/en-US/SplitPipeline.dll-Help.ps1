
<#
.Synopsis
	Help script (https://github.com/nightroman/Helps)
#>

# Import the module to make commands available for the builder.
Import-Module SplitPipeline

### Split-Pipeline command help
@{
	command = 'Split-Pipeline'
	synopsis = @'
	Splits pipeline input and processes input parts by parallel pipelines.
'@
	description = @'
	The cmdlet splits pipeline input in real time and processes input parts by
	parallel pipelines. The algorithm works without having the entire input
	available. Input can be very large or even infinite.
'@
	parameters = @{
		Script = @'
		The script invoked with a part of input piped to it. The script either
		processes the whole part ($input) or each item ($_) separately in the
		process block.
'@
		Begin = @'
		The script invoked for each pipeline once before processing. The goal
		of this script is to initialize the current runspace, normally to set
		some variables, dot-source scripts, import modules, and etc.
'@
		End = @'
		The script invoked for each pipeline once after processing. The goal
		is, for example, to output some results accumulated during processing
		of all input parts.
'@
		Finally = @'
		The script invoked for each pipeline before its closing. The goal is to
		dispose resources, normally created by Begin. All output is ignored. If
		the script fails then its exception message is written as a warning and
		processing continues because Finally has to be called for all created
		pipelines.
'@
		Count = @'
		Maximum number of created parallel pipelines. The default value is the
		number or processors.
'@
		Queue = @'
		Maximum number of objects in the queue. If all pipelines are busy then
		incoming input objects are enqueued for later processing. The queue is
		unlimited by default. The limit should be specified for potentially
		large input. When the limit is hit the engine waits for a pipeline
		available for input from the queue.

		The minimum queue size is (Count * Load). Too small parameter values
		are replaced with this minimum.
'@
		Load = @'
		Recommended minimum number of input objects for each parallel pipeline.
		The default is 1. If processing is fast then increasing this number may
		improve overall performance, it may reduce the total number of input
		parts and overhead of pipeline invocations for each part.
'@
		Limit = @'
		Maximum number of input objects for each parallel pipeline. The default
		is 0 (unlimited). Setting this limit causes more frequent output (if it
		is actually hit). This may be important for feeding downstream commands
		working at the same time.
'@
		Variable = @'
		Variables imported from the current runspace to parallel.
'@
		Function = @'
		Functions imported from the current runspace to parallel.
'@
		Module = @'
		Modules imported to parallel runspaces.
'@
		InputObject = @'
		Input objects processed by parallel pipelines. Do not use this
		parameter directly, use the pipeline operator instead.
'@
	}
	inputs = @(
		@{
			type = 'Object'
			description = @'
		Input objects processed by parallel pipelines. Order of processing is
		unknown.
'@
		}
	)
	outputs = @(
		@{
			type = 'Object'
			description = @'
		Joined output of the Begin, Script, and End scripts. The Begin and End
		scripts are invoked once for each parallel pipeline before and after
		processing. The Script script is invoked for each input part piped to
		one of the pipelines.
'@
		}
	)
	examples = @(
		@{
			code = {
				1..10 | . {process{$_; sleep 1}}
				1..10 | Split-Pipeline -Count 10 {process{$_; sleep 1}}
			}
			remarks = @'
	These two commands perform the same trivial job emulating time
	consuming but latent operations on each item. The first command takes
	about 10 seconds. The second uses Split-Pipeline, it should take about
	2 seconds.
'@
			test = { . $args[0] }
		}
	)
	links = @(
		@{ text = 'Project site:'; URI = 'https://github.com/nightroman/SplitPipeline' }
	)
}
