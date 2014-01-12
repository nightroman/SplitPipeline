
<#
.Synopsis
	Build script (https://github.com/nightroman/Invoke-Build)

.Description
	How to use this script and build the module:

	Get the utility script Invoke-Build.ps1:
	https://github.com/nightroman/Invoke-Build

	Copy it to the path. Set location to this directory. Build:
	PS> Invoke-Build Build

	This command builds the module and installs it to the $ModuleRoot which is
	the working location of the module. The build fails if the module is
	currently in use. Ensure it is not and then repeat.

	The build task Help fails if the help builder Helps is not installed.
	Ignore this or better get and use the script (it is really easy):
	https://github.com/nightroman/Helps
#>

param(
	$Configuration = 'Release'
)

# Standard location of the SplitPipeline module (caveat: may not work if MyDocuments is not standard)
$ModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) WindowsPowerShell\Modules\SplitPipeline

# Use MSBuild.
use 4.0 MSBuild

# Build all.
task Build {
	exec { MSBuild Src\SplitPipeline.csproj /t:Build /p:Configuration=$Configuration /p:TargetFrameworkVersion=v2.0 }
}

# Clean all.
task Clean RemoveMarkdownHtml, {
	Remove-Item z, Src\bin, Src\obj, Module\SplitPipeline.dll, *.nupkg -Force -Recurse -ErrorAction 0
}

# Copy all to the module root directory and then build help.
# It is called as the post-build event of SplitPipeline.csproj.
task PostBuild {
	Copy-Item Src\Bin\$Configuration\SplitPipeline.dll Module
	exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
},
@{Help=1}

# Build module help by Helps (https://github.com/nightroman/Helps).
task Help -Inputs (Get-Item Src\Commands\*, Module\en-US\SplitPipeline.dll-Help.ps1) -Outputs "$ModuleRoot\en-US\SplitPipeline.dll-Help.xml" {
	. Helps.ps1
	Convert-Helps Module\en-US\SplitPipeline.dll-Help.ps1 $Outputs
}

# Build and test help.
task TestHelp Help, {
	. Helps.ps1
	Test-Helps Module\en-US\SplitPipeline.dll-Help.ps1
}

# Build and show help.
task ShowHelp Help, {
	Import-Module SplitPipeline
	. { Get-Help Split-Pipeline -Full; Get-Help about_SplitPipeline } | more
}

# Tests.
task Test {
	Invoke-Build ** Tests
}

# Import markdown tasks ConvertMarkdown and RemoveMarkdownHtml.
# <https://github.com/nightroman/Invoke-Build/wiki/Partial-Incremental-Tasks>
try { Markdown.tasks.ps1 }
catch { task ConvertMarkdown; task RemoveMarkdownHtml }

# Make the package in z\tools NuGet.
task Package ConvertMarkdown, {
	Remove-Item [z] -Force -Recurse
	$null = mkdir z\tools\SplitPipeline\en-US

	Copy-Item -Destination z\tools\SplitPipeline `
	LICENSE.txt,
	$ModuleRoot\SplitPipeline.dll,
	$ModuleRoot\SplitPipeline.psd1

	Copy-Item -Destination z\tools\SplitPipeline\en-US `
	$ModuleRoot\en-US\about_SplitPipeline.help.txt,
	$ModuleRoot\en-US\SplitPipeline.dll-Help.xml

	Move-Item -Destination z\tools\SplitPipeline `
	README.htm,
	Release-Notes.htm
}

# Set $script:Version = assembly version
task Version {
	assert ((Get-Item $ModuleRoot\SplitPipeline.dll).VersionInfo.FileVersion -match '^(\d+\.\d+\.\d+)')
	$script:Version = $matches[1]
}

# Make NuGet package.
task NuGet Package, Version, {
	$text = @'
PowerShell module for parallel data processing. Split-Pipeline splits the
input, processes parts by parallel pipelines, and outputs data for further
processing. It works without collecting the entire input, large or infinite.
'@
	# nuspec
	Set-Content z\Package.nuspec @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
	<metadata>
		<id>SplitPipeline</id>
		<version>$Version</version>
		<owners>Roman Kuzmin</owners>
		<authors>Roman Kuzmin</authors>
		<requireLicenseAcceptance>false</requireLicenseAcceptance>
		<licenseUrl>http://www.apache.org/licenses/LICENSE-2.0</licenseUrl>
		<projectUrl>https://github.com/nightroman/SplitPipeline</projectUrl>
		<summary>$text</summary>
		<description>$text</description>
		<tags>PowerShell Module Parallel</tags>
		<releaseNotes>https://github.com/nightroman/SplitPipeline/blob/master/Release-Notes.md</releaseNotes>
	</metadata>
</package>
"@
	# pack
	exec { NuGet pack z\Package.nuspec -NoPackageAnalysis }
}

# Push to the repository with a version tag.
task PushRelease Version, {
     exec { git push }
     exec { git tag -a "v$Version" -m "v$Version" }
     exec { git push origin "v$Version" }
}

# Make and push the NuGet package.
task PushNuGet NuGet, {
     exec { NuGet push "SplitPipeline.$Version.nupkg" }
},
Clean

# Build, test and clean all.
task . Build, Test, TestHelp, Clean
