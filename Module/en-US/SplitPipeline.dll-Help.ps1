
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
	Splits pipeline input and processes its parts by parallel pipelines.
'@
	description = @'
    The cmdlet splits the input, processes its parts by parallel pipelines, and
    outputs the results for further processing. It may work without collecting
    the whole input, large or infinite.

	When Load is omitted the whole input is collected and split evenly between
	Count parallel pipelines. This method shows the best performance in simple
	cases. In other cases, e.g. on large or slow input, Load should be used in
	order to enable processing of partially collected input.

	The cmdlet creates several pipelines. Each pipeline is created when input
	parts are available, created pipelines are busy, and their number is less
	than Count. Each pipeline is used for processing one or more input parts.

	Because each pipeline works in its own runspace variables, functions, and
	modules from the main script are not automatically available for pipeline
	scripts. Such items should be specified by Variable, Function, and Module
	parameters in order to be available.

	The Begin and End scripts are invoked for each created pipeline once before
	and after processing. Each input part is piped to the script block Script.
	The Finally script is invoked after all, even on failures or stopping.

	If number of created pipelines is equal to Count and all pipelines are busy
	then incoming input items are enqueued for later processing. If the queue
	size hits the limit then the algorithm waits for any pipeline to complete.

	Input parts are not necessarily processed in the same order as they come.
	But output parts can be ordered according to input, use the switch Order.
'@
	parameters = @{
		Script = @'
		The script invoked for each input part of each pipeline with an input
		part piped to it. The script either processes the whole part ($input)
		or each item ($_) separately in the "process" block. Examples:

			# Process the whole $input part:
			... | Split-Pipeline { $input | %{ $_ } }

			# Process input items $_ separately:
			... | Split-Pipeline { process { $_ } }

		The script may have any of "begin", "process", and "end" blocks:

			... | Split-Pipeline { begin {...} process { $_ } end {...} }

		Note that "begin" and "end" blocks are called for each input part but
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
		The script invoked for each opened pipeline before its closing, even on
		terminating errors or stopping (Ctrl-C). It is normally needed in order
		to release resources created by Begin. Output is ignored. If Finally
		fails then its errors are written as warnings because it has to be
		called for remaining pipelines.
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
		Enables processing of partially collected input and specifies input
		part limits. If it is omitted then the whole input is collected and
		split evenly between pipelines.

		The parameter accepts an array of one or two integers. The first is the
		minimum number of objects per pipeline. If it is less than 1 then Load
		is treated as omitted. The second number is the optional maximum.

		If processing is fast then it is important to specify a proper minimum.
		Otherwise Split-Pipeline may work even slower than a standard pipeline.

		Setting the maximum causes more frequent output. For example, this may
		be important for feeding simultaneously working downstream pipelines.

		Setting the maximum number is also needed for potentially large input
		in order to limit the input queue size and avoid out of memory issues.
		The maximum queue size is set internally to Load[1] * Count.

		Use the switch Verbose in order to get some statistics which may help
		to choose suitable load limits.

		CAUTION: The queue limit may be ignored and exceeded if Refill is used.
		Any number of objects written via [ref] go straight to the input queue.
		Thus, depending on data Refill scenarios may fail due to out of memory.
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
		ApartmentState = @'
		Specify either "MTA" (multi-threaded ) or "STA" (single-threaded) for
		the apartment states of the threads used to run commands in pipelines.
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
		Output of the Begin, Script, and End script blocks. The scripts Begin
		and End are invoked once for each pipeline before and after processing.
		The script Script is invoked repeatedly with input parts piped to it.
'@
		}
	)
	examples = @(
		@{
			code = {
				1..10 | . {process{ $_; sleep 1 }}
				1..10 | Split-Pipeline -Count 10 {process{ $_; sleep 1 }}
			}
			remarks = @'
	Two commands perform the same job simulating long but not processor
	consuming operations on each item. The first command takes about 10
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
	This is an example of Split-Pipeline with refilled input. By the convention
	output [ref] objects refill the input, other objects go to output as usual.

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
	Because each pipeline works in its own runspace variables, functions, and
	modules from the main script are not automatically available for pipeline
	scripts. Such items should be specified by Variable, Function, and Module
	parameters in order to be available.

    > $arr = @('one', 'two', 'three'); 0..2 | . {process{ $arr[$_] }}
    one
    two
    three

    > $arr = @('one', 'two', 'three'); 0..2 | Split-Pipeline {process{ $arr[$_] }}
    Split-Pipeline : Cannot index into a null array.
    ...

    > $arr = @('one', 'two', 'three'); 0..2 | Split-Pipeline -Variable arr {process{ $arr[$_] }}
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
