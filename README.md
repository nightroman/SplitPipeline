
# Parallel Data Processing in PowerShell

PowerShell v2.0+ module for parallel data processing. Split-Pipeline splits the
input, processes parts by parallel pipelines, and outputs results. It may work
without collecting the whole input, large or infinite.

## Quick Start

**Step 1:** Get and install.

SplitPipeline is distributed as the PowerShell Gallery module [SplitPipeline](https://www.powershellgallery.com/packages/SplitPipeline).
In PowerShell 5.0 or with PowerShellGet you can install it by this command:

    Install-Module SplitPipeline

SplitPipeline is also available as the NuGet package [SplitPipeline](https://www.nuget.org/packages/SplitPipeline).
Download it by NuGet tools or [directly](http://nuget.org/api/v2/package/SplitPipeline).
In the latter case save it as *".zip"* and unzip. Use the package subdirectory *"tools/SplitPipeline"*.

**Step 2:** In a PowerShell command prompt import the module:

    Import-Module SplitPipeline

**Step 3:** Take a look at help:

    help about_SplitPipeline
    help -full Split-Pipeline

**Step 4:** Try these three commands performing the same job simulating long
but not processor consuming operations on each item:

    1..10 | . {process{ $_; sleep 1 }}
    1..10 | Split-Pipeline {process{ $_; sleep 1 }}
    1..10 | Split-Pipeline -Count 10 {process{ $_; sleep 1 }}

Output of all commands is the same, numbers from 1 to 10 (Split-Pipeline does
not guarantee the same order without the switch `Order`). But consumed times
are different. Let's measure them:

    Measure-Command { 1..10 | . {process{ $_; sleep 1 }} }
    Measure-Command { 1..10 | Split-Pipeline {process{ $_; sleep 1 }} }
    Measure-Command { 1..10 | Split-Pipeline -Count 10 {process{ $_; sleep 1 }} }

The first command takes about 10 seconds.

Performance of the second command depends on the number of processors which is
used as the default split count. For example, with 2 processors it takes about
6 seconds.

The third command takes about 2 seconds. The number of processors is not very
important for such sleeping jobs. The split count is important. Increasing it
to some extent improves overall performance. As for intensive jobs, the split
count normally should not exceed the number of processors.
