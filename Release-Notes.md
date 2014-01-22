SplitPipeline Release Notes
===========================

## v1.4.1

If the minimum `Load` is less than 1 then the parameter is treated as omitted.

## v1.4.0

*Potentially incompatible change*. By default, i.e. when `Load` is omitted, the
whole input is collected and split evenly between parallel pipelines. This way
seems to be the most effective in simple cases. In other cases, e.g. on large
or slow input, `Load` should be used in order to enable processing of input
parts and specify their limits.

Corrected input item count in `Refill` mode in verbose statistics.

Refactoring of ending, closing, and stopping.

## v1.3.1

Removed the obsolete switch `Auto` and pieces of old code.

## v1.3.0

Reviewed automatic load balancing, made it the default and less aggressive
(*potentially incompatible change*). The obsolete switch `Auto` still exists
but it is ignored. Use the parameter `Load` in order to specify part limits.
E.g. `-Load N,N` tells to use N items per pipeline, i.e. no load balancing.

In order words: a) `Auto` is slightly redundant with `Load`; b) not using
`Auto`, e.g. forgetting, often causes less effective work. `Auto` will be
removed in the next version.

Improved stopping (e.g. by `[Ctrl-C]`):

- Fixed some known and some potential issues.
- The `Finally` script should work on stopping.

Amended verbose messages. They are for:

- Each job feed with current data.
- End of processing with end data.
- Summary with totals.

## v1.2.1

Added processing of `StopProcessing()` which is called on `[Ctrl-C]`. Note that
stopping is normally not recommended. But in some cases "under construction" it
may help, e.g. [#3](https://github.com/nightroman/SplitPipeline/issues/3).

## v1.2.0

Debug streams of parallel pipelines are processed as well and debug messages
are propagated to the main pipeline, just like errors, warnings, and verbose
messages.

## v1.1.0

New parameter `ApartmentState`.

## v1.0.1

Help. Mentioned why and when to use `Variable`, `Function`, and `Module`. Added
the related example.

## v1.0.0

Minor cosmetic changes in help and code. The API seems to be stabilized and no
issues were found for a while. Changed the status from "beta" to "release".

## v0.4.1

Refactoring and minor improvements.

## v0.4.0

Revision of parameters and automatic load balancing (mostly simplification).
Joined parameters Load and Limit into the single parameter Load (one or two
values). Removed parameters Cost (not needed now) and Queue (Load is used in
order to limit the queue).

## v0.3.2

Minor tweaks.

## v0.3.1

Refilled input makes infinite loops possible in some scenarios. Use the new
parameter `Filter` in order to exclude already processed objects and avoid
loops.

## v0.3.0

New switch `Refill` tells to refill the input queue from output. `[ref]`
objects are intercepted and added to the input queue. Other objects go to
output as usual. See an example in help and
[Test-Refill.ps1](https://github.com/nightroman/SplitPipeline/blob/master/Tests/Test-Refill.ps1).

Tweaks in feeding parallel pipelines and automatic tuning of load.

## v0.2.0

New switch `Order` tells to output part results in the same order as input
parts arrive. Thus, although order of processing is not predictable, output
order can be made predictable. This feature open doors for more scenarios.

Added checks for `Stopping` in `EndProcessing` (faster stop on `Ctrl+C`).

## v0.1.1

Tweaks, including related to PowerShell V3 CTP2.

## v0.1.0

New switch `Auto` is used in order to determine Load values automatically during
processing. Use `Verbose` in order to view some related information. Yet another
new parameter `Cost` is used together with `Auto`; it is introduced rather for
experiments.

## v0.0.1

This is the first of v0 series (pre-release versions). Cmdlet parameters and
behaviour may change.

The cmdlet Split-Pipeline passes simple tests and shows good performance gain
in a few practical scenarios.

Failures, errors, warnings, and verbose messages from parallel pipelines are
trivial, straightforward, and perhaps not useful enough for troubleshooting.
