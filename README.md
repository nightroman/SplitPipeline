# SplitPipeline

PowerShell module for parallel data processing

SplitPipeline is designed for Windows PowerShell 5.1 and PowerShell Core.
It provides the only command `Split-Pipeline`.

`Split-Pipeline` splits the input, processes parts by parallel pipelines, and
outputs results. It may work without collecting the whole input, large or
infinite.

## Quick Start

**Step 1:** Get and install.

The module is published at the PSGallery: [SplitPipeline](https://www.powershellgallery.com/packages/SplitPipeline).
It may be installed by this command:

```powershell
Install-Module SplitPipeline
```

**Step 2:** Import the module:

```powershell
Import-Module SplitPipeline
```

**Step 3:** Take a look at help:

```powershell
help Split-Pipeline
```

**Step 4:** Try these three commands performing the same job simulating long
but not processor consuming operations on each item:

```powershell
1..10 | . {process{ $_; sleep 1 }}
1..10 | Split-Pipeline {process{ $_; sleep 1 }}
1..10 | Split-Pipeline -Count 10 {process{ $_; sleep 1 }}
```

Output of all commands is the same, numbers from 1 to 10 (Split-Pipeline does
not guarantee the same order without the switch `Order`). But consumed times
are different. Let's measure them:

```powershell
Measure-Command { 1..10 | . {process{ $_; sleep 1 }} }
Measure-Command { 1..10 | Split-Pipeline {process{ $_; sleep 1 }} }
Measure-Command { 1..10 | Split-Pipeline -Count 10 {process{ $_; sleep 1 }} }
```

The first command takes about 10 seconds.

Performance of the second command depends on the number of processors which is
used as the default split count. For example, with 2 processors it takes about
6 seconds.

The third command takes about 2 seconds. The number of processors is not very
important for such sleeping jobs. The split count is important. Increasing it
to some extent improves overall performance. As for intensive jobs, the split
count normally should not exceed the number of processors.

## See also

- [SplitPipeline Release Notes](https://github.com/nightroman/SplitPipeline/blob/main/Release-Notes.md)
