
SplitPipeline - Parallel Data Processing in PowerShell
======================================================

SplitPipeline is a PowerShell module for parallel data processing. The cmdlet
Split-Pipeline splits input and processes its parts by parallel pipelines. The
algorithm works without having the entire input available, it is well designed
for large or even infinite input.

## Quick Start

**Step 1:**
An easy way to get and update the package is
[NuGet.exe Command Line](http://nuget.codeplex.com/releases):

    NuGet install SplitPipeline

Alternatively, manually download and unzip the latest package from
[Downloads](https://github.com/nightroman/SplitPipeline/downloads).

Copy the directory *SplitPipeline* from the package to one of the PowerShell
module directories (see `$env:PSModulePath`). For example:

    C:/Users/.../Documents/WindowsPowerShell/Modules/SplitPipeline

**Step 2:** In a PowerShell command prompt import the module:

    Import-Module SplitPipeline

**Step 3:** Take a look at help:

    help about_SplitPipeline
    help -full Split-Pipeline

**Step 4:**

Try these three commands performing the same job simulating long but not
processor consuming operations of each item:

    1..10 | . {process{$_; sleep 1}}
    1..10 | Split-Pipeline {process{$_; sleep 1}}
    1..10 | Split-Pipeline -Count 10 {process{$_; sleep 1}}

Output of all commands is the same, numbers from 1 to 10 (Split-Pipeline does
not guarantee the same order without the switch `Order`). But consumed times
are different. Let's measure them:

    Measure-Command { 1..10 | . {process{$_; sleep 1}} }
    Measure-Command { 1..10 | Split-Pipeline {process{$_; sleep 1}} }
    Measure-Command { 1..10 | Split-Pipeline -Count 10 {process{$_; sleep 1}} }

The first command takes about 10 seconds.

Performance of the second command depends on the number of processors. For
example, with 2 processors it takes about 6 seconds.

The third command takes about 2 seconds. The number of processors is not very
important for such sleeping jobs. The split count is important, increasing it
to some extent improves overall performance. As for intensive jobs, the split
count normally should not exceed the number of processors.
