<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build
#>

param(
	$Configuration = 'Release'
)

Set-StrictMode -Version 3
$ModuleName = 'SplitPipeline'
$ModuleRoot = "$env:ProgramFiles\WindowsPowerShell\Modules\$ModuleName"

# Synopsis: Remove temp files.
task clean {
	remove z, Src\bin, Src\obj, README.html
}

# Synopsis: Generate meta files.
task meta -Inputs $BuildFile, Release-Notes.md -Outputs "Module\$ModuleName.psd1", Src\Directory.Build.props -Jobs version, {
	$Project = 'https://github.com/nightroman/SplitPipeline'
	$Summary = 'SplitPipeline - Parallel Data Processing in PowerShell'
	$Copyright = 'Copyright (c) Roman Kuzmin'

	Set-Content "Module\$ModuleName.psd1" @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$Version'
	Description = '$Summary'
	CompanyName = '$Project'
	Copyright = '$Copyright'

	RootModule = '$ModuleName.dll'

	PowerShellVersion = '5.1'
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
			ReleaseNotes = 'https://github.com/nightroman/SplitPipeline/blob/main/Release-Notes.md'
		}
	}
}
"@

	Set-Content Src\Directory.Build.props @"
<Project>
	<PropertyGroup>
		<Company>$Project</Company>
		<Copyright>$Copyright</Copyright>
		<Description>$Summary</Description>
		<Product>$ModuleName</Product>
		<Version>$Version</Version>
		<IncludeSourceRevisionInInformationalVersion>False</IncludeSourceRevisionInInformationalVersion>
	</PropertyGroup>
</Project>
"@
}

# Synopsis: Build, publish in post-build, make help.
task build meta, {
	exec { dotnet build "Src\$ModuleName.csproj" -c $Configuration --tl:off }
}

# Synopsis: Publish the module (post-build).
task publish {
	exec { robocopy Module $ModuleRoot /s /xf *-Help.ps1 } (0..3)
	exec { dotnet publish Src\$ModuleName.csproj --no-build -c $Configuration -o $ModuleRoot }
	remove $ModuleRoot\System.Management.Automation.dll, $ModuleRoot\*.deps.json
}

# Synopsis: Build help by https://github.com/nightroman/Helps
task help -After ?build -Inputs @(Get-Item Src\*.cs, "Module\en-US\$ModuleName.dll-Help.ps1") -Outputs "$ModuleRoot\en-US\$ModuleName.dll-Help.xml" {
	. Helps.ps1
	Convert-Helps "Module\en-US\$ModuleName.dll-Help.ps1" $Outputs
}

# Synopsis: Set $Script:Version.
task version {
	($Script:Version = Get-BuildVersion Release-Notes.md '##\s+v(\d+\.\d+\.\d+)')
}

# Synopsis: Convert markdown files to HTML.
task markdown {
	exec { pandoc.exe --standalone --from=gfm --output=README.html --metadata=pagetitle=$ModuleName README.md }
}

# Synopsis: Make the package.
task package markdown, version, {
	equals $Version (Get-Item $ModuleRoot\$ModuleName.dll).VersionInfo.ProductVersion
	equals ([Version]$Version) (Get-Module $ModuleName -ListAvailable).Version

	remove z
	exec { robocopy $ModuleRoot z\$ModuleName /s /xf *.pdb } (0..3)

	Copy-Item LICENSE, README.html -Destination z\$ModuleName

	Assert-SameFile.ps1 -Result (Get-ChildItem z\$ModuleName -Recurse -File -Name) -Text -View $env:MERGE @'
LICENSE
README.html
SplitPipeline.dll
SplitPipeline.psd1
en-US\about_SplitPipeline.help.txt
en-US\SplitPipeline.dll-Help.xml
'@
}

# Synopsis: Make and push the PSGallery package.
task pushPSGallery package, {
	$NuGetApiKey = Read-Host NuGetApiKey
	Publish-Module -Path z\$ModuleName -NuGetApiKey $NuGetApiKey
},
clean

# Synopsis: Push to the repository with a version tag.
task pushRelease version, {
	$changes = exec { git status --short }
	assert (!$changes) "Please, commit changes."

	exec { git push }
	exec { git tag -a "v$Version" -m "v$Version" }
	exec { git push origin "v$Version" }
}

# Synopsis: Run tests.
task test {
	Invoke-Build ** Tests
}

# Synopsis: Test Core.
task core {
	exec { pwsh -NoProfile -Command Invoke-Build test }
}

# Synopsis: Test Desktop.
task desktop {
	exec { powershell -NoProfile -Command Invoke-Build test }
}

# Synopsis: Test editions.
task tests desktop, core

# Synopsis: Build and clean.
task . build, clean
