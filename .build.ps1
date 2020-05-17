<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build
#>

param(
	$Configuration = 'Release'
)

# Module data.
$ModuleName = 'SplitPipeline'
$ModuleRoot = "$env:ProgramW6432\WindowsPowerShell\Modules\$ModuleName"

# Use MSBuild.
Set-Alias MSBuild (Resolve-MSBuild)

# Get version from release notes.
function Get-Version {
	switch -Regex -File Release-Notes.md {'##\s+v(\d+\.\d+\.\d+)' {return $Matches[1]} }
}

# Synopsis: Generate or update meta files.
task meta -Inputs Release-Notes.md, .build.ps1 -Outputs Module\$ModuleName.psd1, Src\AssemblyInfo.cs {
	$Version = Get-Version
	$Project = 'https://github.com/nightroman/SplitPipeline'
	$Summary = 'SplitPipeline - Parallel Data Processing in PowerShell'
	$Copyright = 'Copyright (c) Roman Kuzmin'

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

	CmdletsToExport = 'Split-Pipeline'
	FunctionsToExport = @()
	VariablesToExport = @()
	AliasesToExport = @()

	PrivateData = @{
		PSData = @{
			Tags = 'Parallel', 'Pipeline', 'Runspace', 'Invoke', 'Foreach'
			LicenseUri = 'http://www.apache.org/licenses/LICENSE-2.0'
			ProjectUri = 'https://github.com/nightroman/SplitPipeline'
			ReleaseNotes = 'https://github.com/nightroman/SplitPipeline/blob/master/Release-Notes.md'
		}
	}
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
task build meta, {
	exec { MSBuild Src\$ModuleName.csproj /t:Build /p:Configuration=$Configuration }
}

# Synopsis: Copy files to the module, then make help.
# It is called from the post-build event.
task postBuild {
	exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
	Copy-Item Src\Bin\$Configuration\$ModuleName.dll $ModuleRoot
},
?help

# Synopsis: Remove temp and info files.
task clean {
	remove Module\$ModuleName.psd1, "$ModuleName.*.nupkg", z, Src\bin, Src\obj, README.htm
}

# Synopsis: Build help by https://github.com/nightroman/Helps
task help -Inputs (
	Get-Item Src\*.cs, Module\en-US\$ModuleName.dll-Help.ps1
) -Outputs (
	"$ModuleRoot\en-US\$ModuleName.dll-Help.xml"
) {
	. Helps.ps1
	Convert-Helps Module\en-US\$ModuleName.dll-Help.ps1 $Outputs
}

# Synopsis: Build and test help.
task testHelp help, {
	. Helps.ps1
	Test-Helps Module\en-US\$ModuleName.dll-Help.ps1
}

# Synopsis: Convert markdown files to HTML.
# <http://johnmacfarlane.net/pandoc/>
task markdown {
	exec { pandoc.exe --standalone --from=gfm --output=README.htm --metadata=pagetitle=$ModuleName README.md }
}

# Synopsis: Set $script:Version.
task version {
	($script:Version = Get-Version)
	# module version
	assert ((Get-Module $ModuleName -ListAvailable).Version -eq ([Version]$script:Version))
	# assembly version
	assert ((Get-Item $ModuleRoot\$ModuleName.dll).VersionInfo.FileVersion -eq ([Version]"$script:Version.0"))
}

# Synopsis: Make the package in z\tools.
task package markdown, {
	remove z
	$null = mkdir z\tools\$ModuleName\en-US

	Copy-Item -Destination z\tools\$ModuleName `
	LICENSE,
	README.htm,
	$ModuleRoot\$ModuleName.dll,
	$ModuleRoot\$ModuleName.psd1

	Copy-Item -Destination z\tools\$ModuleName\en-US `
	$ModuleRoot\en-US\about_$ModuleName.help.txt,
	$ModuleRoot\en-US\$ModuleName.dll-Help.xml
}

# Synopsis: Make NuGet package.
task nuget package, version, {
	$description = @'
PowerShell v2.0+ module for parallel data processing. Split-Pipeline splits the
input, processes parts by parallel pipelines, and outputs results. It may work
without collecting the whole input, large or infinite.
'@

	# nuspec
	Set-Content z\Package.nuspec @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
	<metadata>
		<id>$ModuleName</id>
		<version>$Version</version>
		<owners>Roman Kuzmin</owners>
		<authors>Roman Kuzmin</authors>
		<license type="expression">Apache-2.0</license>
		<requireLicenseAcceptance>false</requireLicenseAcceptance>
		<projectUrl>https://github.com/nightroman/SplitPipeline</projectUrl>
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
task pushRelease version, {
	$changes = exec { git status --short }
	assert (!$changes) "Please, commit changes."

	exec { git push }
	exec { git tag -a "v$Version" -m "v$Version" }
	exec { git push origin "v$Version" }
}

# Synopsis: Make and push the NuGet package.
task pushNuGet nuget, {
	$ApiKey = Read-Host ApiKey
	exec { NuGet push "$ModuleName.$Version.nupkg" -Source nuget.org -ApiKey $ApiKey }
},
clean

# Synopsis: Make and push the PSGallery package.
task pushPSGallery nuget, {
	$NuGetApiKey = Read-Host NuGetApiKey
	Publish-Module -Path z/tools/$ModuleName -NuGetApiKey $NuGetApiKey
},
clean

# Synopsis: Complete the module for PSGallery.
task module markdown, {
	# copy/move files
	Copy-Item LICENSE -Destination $ModuleRoot
	Move-Item README.htm -Destination $ModuleRoot -Force

	# test all files
	$r = (Get-ChildItem $ModuleRoot -Force -Recurse -Name) -join '*'
	equals $r en-US*LICENSE*README.htm*SplitPipeline.dll*SplitPipeline.psd1*en-US\about_SplitPipeline.help.txt*en-US\SplitPipeline.dll-Help.xml
}

# Synopsis: Tests.
task test {
	Invoke-Build ** Tests
}

# Synopsis: Build, test and clean all.
task . build, test, testHelp, clean
