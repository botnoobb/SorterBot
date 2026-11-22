#Requires -Version 7.0

param(
	[string]$GodotPath,
	[ValidatePattern('^[a-z][a-z-]*$')]
	[string]$Suite
)

$ErrorActionPreference = 'Stop'

if ($GodotPath) {
	$enginePath = (Get-Item -LiteralPath $GodotPath).FullName
} else {
	$engine = Get-Command godot, godot4 -CommandType Application -ErrorAction SilentlyContinue |
		Select-Object -First 1
	if (-not $engine) {
		throw 'Godot не найден в PATH. Укажите путь к программе через -GodotPath.'
	}
	$enginePath = $engine.Source
}

function Invoke-GodotCheck {
	param([string]$Stage, [string]$Arguments)

	$logPath = Join-Path $testProject "$Stage.log"
	$commandLine = '--headless --path "{0}" --log-file "{1}" {2}' -f $testProject, $logPath, $Arguments
	$process = Start-Process -FilePath $enginePath -ArgumentList $commandLine -WindowStyle Hidden -Wait -PassThru
	if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
		throw "Godot не записал журнал этапа «$Stage». Код завершения $($process.ExitCode)."
	}
	$log = @(Get-Content -LiteralPath $logPath -Encoding UTF8)
	if ($process.ExitCode -ne 0 -or $log -match '^SCRIPT ERROR:') {
		$log | Write-Host
		throw "Не пройден этап «$Stage». Код завершения Godot $($process.ExitCode)."
	}
	return $log
}

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$tempRoot = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd('\', '/')
$testProject = Join-Path $tempRoot ('sorter-bot-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testProject | Out-Null
$previousAppData = $env:APPDATA
$previousXdgDataHome = $env:XDG_DATA_HOME
$previousTestProfile = $env:SORTER_TEST_PROFILE

try {
	$testProfile = Join-Path $testProject 'profile'
	New-Item -ItemType Directory -Path $testProfile | Out-Null
	$env:APPDATA = $testProfile
	$env:XDG_DATA_HOME = $testProfile
	$env:SORTER_TEST_PROFILE = $testProfile

	$projectFiles = 'project.godot', 'assets', 'scenes', 'scripts' |
		ForEach-Object { Join-Path $projectRoot $_ }
	Copy-Item -LiteralPath $projectFiles -Destination $testProject -Recurse

	$null = Invoke-GodotCheck -Stage 'Импорт' -Arguments '--editor --import'
	$testArguments = '--script res://scripts/tests/run_tests.gd'
	if ($Suite) {
		$testArguments += " -- --$Suite"
	}
	$testLog = @(Invoke-GodotCheck -Stage 'Тесты' -Arguments $testArguments)
	$summary = $testLog -match '^Проверки: \d+; ошибки: 0$'
	if (-not $summary) {
		$testLog | Write-Host
		throw 'Godot не подтвердил успешное завершение тестов.'
	}
	$summary
} finally {
	$env:APPDATA = $previousAppData
	$env:XDG_DATA_HOME = $previousXdgDataHome
	$env:SORTER_TEST_PROFILE = $previousTestProfile
	$resolvedTestProject = (Resolve-Path -LiteralPath $testProject).Path
	if ((Split-Path -Parent $resolvedTestProject) -eq $tempRoot -and $resolvedTestProject -eq $testProject) {
		Remove-Item -LiteralPath $resolvedTestProject -Recurse
	}
}
