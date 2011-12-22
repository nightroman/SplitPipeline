SplitPipeline Release Notes
===========================

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
