
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

	Input is processed by parts. If processing is relatively fast then it is
	important to specify part size limits by the parameter Load or/and enable
	automatic load balancing by the switch Auto.

	The cmdlet creates several pipelines. Each pipeline is created when input
	parts are available, created pipelines are busy, and their number is less
	than Count. Each created pipeline is used for processing several input
	parts, one at a time.

	Because each pipeline runs in a separate runspace variables, functions, and
	modules from the main script are not available for the processing script by
	default. Items accessed in a pipeline script should be explicitly listed by
	Variable, Function, and Module parameters.

	The Begin and End script are invoked for each created pipeline before and
	after processing. Each input part is piped to the script block Script which
	is invoked by one of the available or newly created pipelines.

	If number of created pipelines is equal to Count and all pipelines are busy
	then incoming input items are enqueued for later processing. If the queue
	size hits the limit then the algorithm waits for a pipeline to complete.

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
		Filter = @'
		Either a hashtable for collecting unique input objects or a script used
		in order to test an input object. Input includes extra objects added in
		Refill mode. In fact, this filter is mostly needed for Refill.

		A hashtable is used in order to collect and enqueue unique objects. In
		Refill mode it may be useful for avoiding infinite loops.

		A script is invoked in a child scope of the scope where the cmdlet is
		invoked. The first argument is an object being tested. Returned $true
		tells to add an object to the input queue.
'@
		Count = @'
		Maximum number of created parallel pipelines. The default value is the
		number or processors. Use the default or even decrease it for intensive
		jobs, especially if there are other tasks working at the same time, for
		example, output is processed simultaneously. But for jobs not consuming
		much processor resources increasing the number may improve performance.
'@
		Load = @'
		One or two values specifying the minimum and maximum number of input
		objects for each parallel pipeline. The first value is the recommended
		minimum, 1 is the default. The second value is the maximum, not limited
		if omitted.

		If processing of input items is fast then increasing the minimum may
		improve performance.

		Setting the maximum number causes more frequent output if the limit is
		actually hit. This may be important for feeding downstream commands in
		the pipeline working at the same time.

		Setting the maximum number is also needed for potentially large input
		in order to limit the input queue size and avoid out of memory issues.
		The maximum queue size is set internally to Load[1] * Count.

		CAUTION: The queue limit may be ignored and exceeded if Refill is used.
		Any number of objects written via [ref] go straight to the input queue.
		Thus, depending on data Refill scenarios may fail due to out of memory.
'@
		Auto = @'
		Tells to perform automatic load balancing during processing in order to
		increase utilization of pipelines. Use Verbose in order to view some
		details during and after processing.

		Note that using of reasonable load values known from practice may be
		still useful, the algorithm may work effectively from the start and
		still be able to adjust the load dynamically.
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
		The algorithm may work slower.
'@
		Refill = @'
		Tells to refill the input by [ref] objects from output. Other objects
		go to output as usual. This convention is used for processing items of
		hierarchical data structures: child container items come back to input,
		leaf items or other data produced by processing go to output.

		NOTE: Refilled input makes infinite loops possible for some data. Use
		Filter in order to exclude already processed objects and avoid loops.
'@
		InputObject = @'
		Input objects processed by parallel pipelines. Do not use this
		parameter directly, use the pipeline operator instead.
'@
		Apartment = @'
		Specify either "MTA" or "STA" to use multi- or single-threaded COM
		apartments in the runspaces.
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
		Output of the Begin, Script, and End script blocks. The Begin and End
		scripts are invoked once for each pipeline before and after processing.
		The script Script is invoked repeatedly with input parts piped to it.
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
		@{
			remarks = @'
	Because each pipeline runs in a separate runspace variables, functions, and
	modules from the main script are not available for the processing script by
	default. Items accessed in a pipeline script should be explicitly listed by
	Variable, Function, and Module parameters.

    > $arr = @('one', 'two', 'three'); 0..2 | ForEach-Object {$arr[$_]}
    one
    two
    three

    > $arr = @('one', 'two', 'three'); 0..2 | Split-Pipeline {process{$arr[$_]}}
    Split-Pipeline : Cannot index into a null array.
    ...

    > $arr = @('one', 'two', 'three'); 0..2 | Split-Pipeline -Variable arr {process {$arr[$_]}}
    one
    two
    three
'@
		}
	)
	links = @(
		@{ text = 'Project site:'; URI = 'https://github.com/nightroman/SplitPipeline' }
	)
}
