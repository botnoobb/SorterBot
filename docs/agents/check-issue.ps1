param(
    [Parameter(Mandatory = $true)]
    [string]$IssuePath
)

$ErrorActionPreference = 'Stop'
$IssuePath = $IssuePath.Replace('\', '/')
if ($IssuePath -notmatch '^\.scratch/[^/]+/issues/[^/]+\.md$') {
    throw 'Укажите путь к файлу задачи относительно корня проекта.'
}

git diff --cached --quiet -- $IssuePath
if ($LASTEXITCODE -ne 1) {
    throw "В подготовленном коммите нет изменений задачи: $IssuePath"
}
git diff --quiet -- $IssuePath
if ($LASTEXITCODE -ne 0) {
    throw "Подготовьте последнюю версию файла задачи к коммиту: $IssuePath"
}

$issue = Get-Content -LiteralPath $IssuePath -Encoding UTF8 -Raw
$status = [regex]::Match($issue, '^Status: (closed|in-progress)[ \t]*\r?$', 'Multiline')
if (-not $status.Success -or $status.Index -ne 0) {
    throw 'В первой строке задачи должен быть статус closed или in-progress.'
}

$section = [regex]::Match($issue, '(?ms)^## Критерии приёмки[ \t]*\r?\n(.*?)(?=^## |\z)')
$criteria = [regex]::Matches($section.Groups[1].Value, '(?m)^- \[([ xX])\] \S.*$')
if ($criteria.Count -eq 0) {
    throw 'В разделе «Критерии приёмки» нет пунктов.'
}

$comments = [regex]::Match($issue, '(?ms)^## Comments[ \t]*\r?\n(.*?)(?=^## |\z)')
$unchecked = 0
for ($index = 0; $index -lt $criteria.Count; $index++) {
    if ($criteria[$index].Groups[1].Value -eq ' ') {
        $unchecked++
        $number = $index + 1
        if ($status.Groups[1].Value -eq 'closed') {
            throw "У закрытой задачи остался неотмеченный критерий $number."
        }
        if ($comments.Groups[1].Value -notmatch "(?m)^- Критерий ${number}:[ \t]*\S") {
            throw "Добавьте в Comments объяснение в строке «- Критерий ${number}: …»."
        }
    }
}
if ($unchecked -eq 0 -and $status.Groups[1].Value -ne 'closed') {
    throw 'Все критерии отмечены. Установите статус closed.'
}
