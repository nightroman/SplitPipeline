
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
	The cmdlet splits pipeline input and processes input parts by parallel
	pipelines. The algorithm starts to work without having the entire input
	available. Input can be very large or even infinite.

	Input is processed by parts. Size of each part is defined by the parameter
	Load but not necessarily equal to it. The Limit is used in order to define
	the maximum part size.

	The cmdlet creates several pipelines. Each pipeline is created when input
	parts are available, created pipelines are busy, and their number is less
	than Count. Created pipelines are used for processing several input parts,
	one at a time.

	The Begin and End script are invoked for each created pipeline before and
	after processing. Each input part is piped to the script Script which is
	invoked by one of the pipelines (existing available or new).

	If number of created pipelines is equal to Count and all pipelines are busy
	then incoming input items are enqueued for later processing. If the queue
	size hits the limit Queue then the algorithm waits for a ready pipeline.

	Input items are not necessarily processed in the same order as they come.
	But output can be ordered according to input parts, use the switch Order.
'@
	parameters = @{
		Script = @'
		The script invoked for each input part of each pipeline with an input
		part piped to it. The script either processes the whole part ($input)
		or each item ($_) separately in the "process" block. Examples:

			# Process a whole $input part:
			... | Split-Pipeline { $input | %{ $_ } }

			# Process each item $_ separately:
			... | Split-Pipeline { process { $_ } }

		A script may have any of special blocks "begin", "process", and "end":

			... | Split-Pipeline { begin {...} process { $_ } end {...} }

		Note that such "begin" and "end" blocks are called for input parts but
		scripts defined by parameters Begin and End are called for pipelines.
'@
		Begin = @'
		The script invoked for each pipeline on creation before processing. The
		goal is to initialize the runspace to be used by the pipeline, normally
		to set some variables, dot-source scripts, import modules, and etc.
'@
		End = @'
		The script invoked for each pipeline once after processing. The goal
		is, for example, to output some results accumulated during processing
		of input parts by the pipeline. Consider to use Finally for releasing
		resources instead of End or in addition to it.
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
		number or processors. Use the default or even decrease it for intensive
		jobs, especially if there are other tasks working at the same time, for
		example, output is processed simultaneously. But for jobs not consuming
		much processor resources increasing the number may improve performance.
'@
		Queue = @'
		Maximum number of objects in the queue. If all pipelines are busy then
		incoming input objects are enqueued for later processing. The queue is
		unlimited by default. The limit should be specified for potentially
		large input. When the limit is hit the engine waits for a pipeline
		available for input from the queue.

		CAUTION: The Queue limit may be ignored and exceeded if Refill is used.
		Any number of objects written via [ref] go straight to the input queue.
'@
		Auto = @'
		Tells to tune some parameters automatically during processing in order
		to increase utilization of pipelines and reduce overhead. This is done
		normally by increasing the value of Load. Use Verbose in order to view
		some details during and after processing.

		Note that using of a reasonable initial Load value known from practice
		may be still useful with Auto, the algorithm may work effectively from
		the start and still be able to adapts the Load dynamically.

		Use Cost in order to specify internal overhead range. This is unlikely
		needed in most cases, the default range may be just fine.
'@
		Cost = @'
		Recommended percentage of inner overhead time with respect to overall
		time. It is used together with the switch Auto and ignored otherwise.
		It accepts one or two values: the maximum (first) and minimum (second)
		percentage. If the second value is omitted then 0 is assumed. Default
		values are 5 and 1 (they may change in future versions).
'@
		Load = @'
		Recommended minimum number of input objects for each parallel pipeline.
		The default is 1. If processing is fast then increasing this number may
		improve overall performance, it may reduce the total number of input
		parts and overhead of pipeline invocations for each part.

		Use the switch Auto in order to tune the Load during processing. But a
		proper initial value known from practice may be still useful with Auto.
'@
		Limit = @'
		Maximum number of input objects for each parallel pipeline. The default
		is 0 (unlimited). Setting this limit causes more frequent output (if it
		is actually hit). This may be important for feeding downstream commands
		in the pipeline working at the same time.
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
		Order = @'
		Tells to output part results in the same order as input parts arrive.
		The algorithm may work a little bit slower.
'@
		Refill = @'
		Tells to refill the input by [ref] objects from output. Other objects
		go to output as usual. This convention is used for processing items of
		hierarchical data structures: child container items come back to input,
		leaf items or other data produced by processing go to output.
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
		Input objects processed by parallel pipelines.
'@
		}
	)
	outputs = @(
		@{
			type = 'Object'
			description = @'
		Output of the Begin, Script, and End scripts. The Begin and End scripts
		are invoked once for each pipeline before and after processing. The
		Script script is invoked several times with input parts piped to it.
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
	Two commands perform the same job simulating long but not processor
	consuming operations of each item. The first command takes about 10
	seconds. The second takes about 2 seconds due to Split-Pipeline.
'@
			test = { . $args[0] }
		}
		@{
			code = {
				$PSHOME | Split-Pipeline -Refill {process{
					foreach($item in Get-ChildItem -LiteralPath $_ -Force) {
						if ($item.PSIsContainer) {
							[ref]$item.FullName
						}
						else {
							$item.Length
						}
					}
				}} | Measure-Object -Sum
			}
			remarks = @'
	This is an example of Split-Pipeline with refilled input. The convention:
	[ref] objects refill the input, other objects go to output as usual.

	The code calculates the number and size of files in $PSHOME. It is a "how
	to" sample, performance gain is not expected because the code is trivial
	and works relatively fast.

	See also another example with simulated slow data requests:
	https://github.com/nightroman/SplitPipeline/blob/master/Tests/Test-Refill.ps1
'@
			test = { . $args[0] }
		}
	)
	links = @(
		@{ text = 'Project site:'; URI = 'https://github.com/nightroman/SplitPipeline' }
	)
}
