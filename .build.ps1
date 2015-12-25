
<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)

.Description
	HOW TO USE THIS SCRIPT AND BUILD THE MODULE

	Get the utility script Invoke-Build.ps1:
	https://github.com/nightroman/Invoke-Build

	Copy it to the path. Set location to here. Build:
	PS> Invoke-Build Build

	The task Help fails if Helps.ps1 is missing.
	Ignore this error or get Helps.ps1:
	https://github.com/nightroman/Helps
#>

param(
	$Configuration = 'Release'
)

$ModuleName = 'SplitPipeline'

# Module directory.
$ModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) WindowsPowerShell\Modules\$ModuleName

# Use MSBuild.
use 4.0 MSBuild

# Get version from release notes.
function Get-Version {
	switch -Regex -File Release-Notes.md {'##\s+v(\d+\.\d+\.\d+)' {return $Matches[1]} }
}

# Synopsis: Generate or update meta files.
task Meta -Inputs Release-Notes.md -Outputs Module\$ModuleName.psd1, Src\AssemblyInfo.cs {
	$Version = Get-Version
	$Project = 'https://github.com/nightroman/SplitPipeline'
	$Summary = 'SplitPipeline - Parallel Data Processing in PowerShell'
	$Copyright = 'Copyright (c) 2011-2015 Roman Kuzmin'

	Set-Content Module\$ModuleName.psd1 @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$Version'
	Description = '$Summary'
	CompanyName = '$Project'
	Copyright = '$Copyright'

	ModuleToProcess = '$ModuleName.dll'

	PowerShellVersion = '2.0'
	GUID = '7806b9d6-cb68-4e21-872a-aeec7174a087'
}
"@

	Set-Content Src\AssemblyInfo.cs @"
using System;
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyProduct("$ModuleName")]
[assembly: AssemblyVersion("$Version")]
[assembly: AssemblyTitle("$Summary")]
[assembly: AssemblyCompany("$Project")]
[assembly: AssemblyCopyright("$Copyright")]

[assembly: ComVisible(false)]
[assembly: CLSCompliant(false)]
"@
}

# Synopsis: Build, on post-build event copy files and make help.
task Build Meta, {
	exec { MSBuild Src\$ModuleName.csproj /t:Build /p:Configuration=$Configuration /p:TargetFrameworkVersion=v2.0 }
}

# Synopsis: Copy files to the module, then make help.
# It is called from the post-build event.
task PostBuild {
	exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
	Copy-Item Src\Bin\$Configuration\$ModuleName.dll $ModuleRoot
},
(job Help -Safe)

# Synopsis: Remove temp and info files.
task Clean {
	Remove-Item -Force -Recurse -ErrorAction 0 `
	Module\$ModuleName.psd1, "$ModuleName.*.nupkg",
	z, Src\bin, Src\obj, Src\AssemblyInfo.cs, README.htm, Release-Notes.htm
}

# Synopsis: Build help by Helps (https://github.com/nightroman/Helps).
task Help -Inputs (
	Get-Item Src\*.cs, Module\en-US\$ModuleName.dll-Help.ps1
) -Outputs (
	"$ModuleRoot\en-US\$ModuleName.dll-Help.xml"
) {
	. Helps.ps1
	Convert-Helps Module\en-US\$ModuleName.dll-Help.ps1 $Outputs
}

# Synopsis: Build and test help.
task TestHelp Help, {
	. Helps.ps1
	Test-Helps Module\en-US\$ModuleName.dll-Help.ps1
}

# Synopsis: Convert markdown files to HTML.
# <http://johnmacfarlane.net/pandoc/>
task Markdown {
	exec { pandoc.exe --standalone --from=markdown_strict --output=README.htm README.md }
	exec { pandoc.exe --standalone --from=markdown_strict --output=Release-Notes.htm Release-Notes.md }
}

# Synopsis: Set $script:Version.
task Version {
	($script:Version = Get-Version)
	# module version
	assert ((Get-Module $ModuleName -ListAvailable).Version -eq ([Version]$script:Version))
	# assembly version
	assert ((Get-Item $ModuleRoot\$ModuleName.dll).VersionInfo.FileVersion -eq ([Version]"$script:Version.0"))
}

# Synopsis: Make the package in z\tools.
task Package Markdown, {
	Remove-Item [z] -Force -Recurse
	$null = mkdir z\tools\$ModuleName\en-US

	Copy-Item -Destination z\tools\$ModuleName `
	LICENSE.txt,
	README.htm,
	Release-Notes.htm,
	$ModuleRoot\$ModuleName.dll,
	$ModuleRoot\$ModuleName.psd1

	Copy-Item -Destination z\tools\$ModuleName\en-US `
	$ModuleRoot\en-US\about_$ModuleName.help.txt,
	$ModuleRoot\en-US\$ModuleName.dll-Help.xml
}

# Synopsis: Make NuGet package.
task NuGet Package, Version, {
	$summary = @'
PowerShell module for parallel data processing. Split-Pipeline splits the
input, processes parts by parallel pipelines, and outputs data for further
processing. It may work without collecting the whole input, large or infinite.
'@
	$description = @"
$summary

---

To install SplitPipeline, follow the Quick Start steps:
https://github.com/nightroman/SplitPipeline#quick-start

---
"@
	# nuspec
	Set-Content z\Package.nuspec @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
	<metadata>
		<id>$ModuleName</id>
		<version>$Version</version>
		<owners>Roman Kuzmin</owners>
		<authors>Roman Kuzmin</authors>
		<requireLicenseAcceptance>false</requireLicenseAcceptance>
		<licenseUrl>http://www.apache.org/licenses/LICENSE-2.0</licenseUrl>
		<projectUrl>https://github.com/nightroman/SplitPipeline</projectUrl>
		<summary>$summary</summary>
		<description>$description</description>
		<tags>PowerShell Module Parallel</tags>
		<releaseNotes>https://github.com/nightroman/SplitPipeline/blob/master/Release-Notes.md</releaseNotes>
	</metadata>
</package>
"@
	# pack
	exec { NuGet pack z\Package.nuspec -NoPackageAnalysis }
}

# Synopsis: Push to the repository with a version tag.
task PushRelease Version, {
	$changes = exec { git status --short }
	assert (!$changes) "Please, commit changes."

	exec { git push }
	exec { git tag -a "v$Version" -m "v$Version" }
	exec { git push origin "v$Version" }
}

# Synopsis: Make and push the NuGet package.
task PushNuGet NuGet, {
	exec { NuGet push "$ModuleName.$Version.nupkg" }
},
Clean

# Synopsis: Test v2.
task TestV2 {
	exec {PowerShell.exe -Version 2 Invoke-Build ** Tests}
}

# Synopsis: Test vN.
task Test {
	Invoke-Build ** Tests
}

# Synopsis: Build, test and clean all.
task . Build, Test, TestV2, TestHelp, Clean
