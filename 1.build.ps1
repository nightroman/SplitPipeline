<#
.Synopsis
	Build script, https://github.com/nightroman/Invoke-Build
#>

param(
	$Configuration = 'Release'
)

Set-StrictMode -Version 3
$_name = 'SplitPipeline'
$_root = "$env:ProgramFiles\WindowsPowerShell\Modules\$_name"

# Synopsis: Remove temp files.
task clean {
	remove z, Src\bin, Src\obj, README.html
}

# Synopsis: Generate meta files.
task meta -Inputs $BuildFile, Release-Notes.md -Outputs "Module\$_name.psd1", Src\Directory.Build.props -Jobs version, {
	$Project = 'https://github.com/nightroman/SplitPipeline'
	$Summary = 'SplitPipeline - Parallel Data Processing in PowerShell'
	$Copyright = 'Copyright (c) Roman Kuzmin'

	Set-Content "Module\$_name.psd1" @"
@{
	Author = 'Roman Kuzmin'
	ModuleVersion = '$_version'
	Description = '$Summary'
	CompanyName = '$Project'
	Copyright = '$Copyright'

	RootModule = '$_name.dll'

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
		<Product>$_name</Product>
		<Version>$_version</Version>
		<IncludeSourceRevisionInInformationalVersion>False</IncludeSourceRevisionInInformationalVersion>
	</PropertyGroup>
</Project>
"@
}

# Synopsis: Build, publish in post-build, make help.
task build meta, {
	exec { dotnet build "Src\$_name.csproj" -c $Configuration --tl:off }
}

# Synopsis: Publish the module (post-build).
task publish {
	exec { robocopy Module $_root /s /xf *-Help.ps1 } (0..3)
	exec { dotnet publish Src\$_name.csproj --no-build -c $Configuration -o $_root }
	remove $_root\System.Management.Automation.dll, $_root\*.deps.json
}

# Synopsis: Build help by https://github.com/nightroman/Helps
task help -After ?build -Inputs @(Get-Item Src\*.cs, "Module\en-US\$_name.dll-Help.ps1") -Outputs "$_root\en-US\$_name.dll-Help.xml" {
	. Helps.ps1
	Convert-Helps "Module\en-US\$_name.dll-Help.ps1" $Outputs
}

# Synopsis: Set $Script:_version.
task version {
	($Script:_version = Get-BuildVersion Release-Notes.md '##\s+v(\d+\.\d+\.\d+)')
}

# Synopsis: Convert markdown files to HTML.
task markdown {
	exec { pandoc.exe --standalone --from=gfm --output=README.html --metadata=pagetitle=$_name README.md }
}

# Synopsis: Make the package.
task package markdown, version, {
	equals $_version (Get-Item $_root\$_name.dll).VersionInfo.ProductVersion
	equals ([Version]$_version) (Get-Module $_name -ListAvailable).Version

	remove z
	exec { robocopy $_root z\$_name /s /xf *.pdb } (0..3)

	Copy-Item LICENSE, README.html -Destination z\$_name

	Assert-SameFile.ps1 -Result (Get-ChildItem z\$_name -Recurse -File -Name) -Text -View $env:MERGE @'
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
	Publish-Module -Path z\$_name -NuGetApiKey $NuGetApiKey
},
clean

# Synopsis: Push to the repository with a version tag.
task pushRelease version, {
	$changes = exec { git status --short }
	assert (!$changes) "Please, commit changes."

	exec { git push }
	exec { git tag -a "v$_version" -m "v$_version" }
	exec { git push origin "v$_version" }
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
