
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

	The cmdlet creates several pipelines. Each new pipeline is created as soon
	as input is available, existing pipelines are busy, and number of created
	pipelines is less than Count. Input items are processed by parts, part
	sizes are defined by the Load parameter but not necessarily equal to it.

	The Begin and End script are invoked for each created pipeline before and
	after processing. Each input part is piped to the script Script which is
	invoked by one of the pipelines (existing available or new).

	If number of created pipelines is equal to Count and all pipelines are busy
	then incoming input items are enqueued for later processing. If the queue
	size hits the limit Queue then the algorithm waits for a ready pipeline.

	NOTES

	* Input items are not necessarily processed in the same order as they come
	into the cmdlet.

	* The cmdlet is not recommended for scenarios with slow input, that is when
	input items comes slower than they are processed by a script.
'@
	parameters = @{
		Script = @'
		The script invoked for each input part of each pipeline with an input
		part piped to it. The script either processes the whole part ($input)
		or each item ($_) separately in the process block. Examples:

			# Process a whole $input part:
			... | Split-Pipeline { $input | %{ $_ } }

			# Process each item $_ separately:
			... | Split-Pipeline { process { $_ } }

		A script may have all three special blocks begin/process/end:

			... | Split-Pipeline { begin {...} process { $_ } end {...} }

		Note that these begin and end blocks are called for each input part,
		unlike scripts Begin and End (parameters) called for each pipeline.
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
		number or processors. Use the default or even decrease it for intensive
		jobs. But for jobs not consuming much processor resources increasing
		this number may improve overall performance a lot.
'@
		Queue = @'
		Maximum number of objects in the queue. If all pipelines are busy then
		incoming input objects are enqueued for later processing. The queue is
		unlimited by default. The limit should be specified for potentially
		large input. When the limit is hit the engine waits for a pipeline
		available for input from the queue.
'@
		Auto = @'
		Tells to tune some parameters automatically during processing in order
		to increase utilization of pipelines and reduce overhead. This is done
		normally by increasing the value of Load. Use Verbose in order to view
		some details.

		Note that using of a reasonable initial Load value known from practice
		may be still useful with Auto, the algorithm may work effectively from
		the start and still be able to adjust the Load dynamically.

		Use Cost in order to specify internal overhead range. This is unlikely
		needed in most cases, the default range may be just fine.
'@
		Cost = @'
		Recommended percentage of inner overhead time with respect to overall
		time. It is used together with the switch Auto and ignored otherwise.
		It accepts one or two values: the maximum (first) and minimum (second)
		percentage. Values 5, 1 are used by default (may change in vNext).
'@
		Load = @'
		Recommended minimum number of input objects for each parallel pipeline.
		The default is 1. If processing is fast then increasing this number may
		improve overall performance, it may reduce the total number of input
		parts and overhead of pipeline invocations for each part.

		Use the switch Auto in order to define the Load during processing. But
		a proper initial value known from practice may be still important.
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
	)
	links = @(
		@{ text = 'Project site:'; URI = 'https://github.com/nightroman/SplitPipeline' }
	)
}
