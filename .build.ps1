
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

param
(
	$Configuration = 'Release'
)

# Standard location of the SplitPipeline module (caveat: may not work if MyDocuments is not standard)
$ModuleRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) WindowsPowerShell\Modules\SplitPipeline

# Use MSBuild.
use Framework\v4.0.30319 MSBuild

# Build all.
task Build {
	exec { MSBuild Src\SplitPipeline.csproj /t:Build /p:Configuration=$Configuration }
}

# Clean all.
task Clean RemoveMarkdownHtml, {
	Remove-Item z, Src\bin, Src\obj, Module\SplitPipeline.dll, SplitPipeline.*.zip, *.nupkg -Force -Recurse -ErrorAction 0
}

# Copy all to the module root directory and then build help.
# It is called as the post-build event of SplitPipeline.csproj.
task PostBuild {
	Copy-Item Src\Bin\$Configuration\SplitPipeline.dll Module
	exec { robocopy Module $ModuleRoot /s /np /r:0 /xf *-Help.ps1 } (0..3)
},
@{Help=1}

# Build module help by Helps (https://github.com/nightroman/Helps).
task Help -Incremental @{(Get-Item Src\Commands\*, Module\en-US\SplitPipeline.dll-Help.ps1) = "$ModuleRoot\en-US\SplitPipeline.dll-Help.xml"} {
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

# Call tests.
task Test {
	Invoke-Build * Tests\Test.build.ps1
}

# Import markdown tasks ConvertMarkdown and RemoveMarkdownHtml.
# <https://github.com/nightroman/Invoke-Build/wiki/Partial-Incremental-Tasks>
try { Markdown.tasks.ps1 }
catch { task ConvertMarkdown; task RemoveMarkdownHtml }

# Make the package in z\tools for Zip and NuGet.
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

# Make zip package.
task Zip Package, Version, {
	Set-Location z\tools
	exec { & 7z a ..\..\SplitPipeline.$Version.zip * }
}

# Make NuGet package.
task NuGet Package, Version, {
	$text = @'
SplitPipeline is a PowerShell module for parallel data processing. The cmdlet
Split-Pipeline splits input and processes its parts by parallel pipelines. The
algorithm works without having the entire input available, it is well designed
for large or even infinite input.
'@
	# nuspec
	Set-Content z\Package.nuspec @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
	<metadata>
		<id>SplitPipeline</id>
		<version>$Version</version>
		<authors>Roman Kuzmin</authors>
		<owners>Roman Kuzmin</owners>
		<projectUrl>https://github.com/nightroman/SplitPipeline</projectUrl>
		<licenseUrl>http://www.apache.org/licenses/LICENSE-2.0</licenseUrl>
		<requireLicenseAcceptance>false</requireLicenseAcceptance>
		<summary>$text</summary>
		<description>$text</description>
		<tags>PowerShell Module Parallel</tags>
	</metadata>
</package>
"@
	# pack
	exec { NuGet pack z\Package.nuspec -NoPackageAnalysis }
}

# Make all packages.
task Pack Zip, NuGet

# Build, test and clean all.
task . Build, Test, TestHelp, Clean
