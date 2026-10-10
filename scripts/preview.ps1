param(
    [int]$Port = 8765,
    [switch]$NoBuild,
    [string]$DotnetPath
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$publishRoot = Join-Path $repoRoot 'artifacts\local-preview-net10'
$projectPath = Join-Path $repoRoot 'Www\WithBugs.WebSite.Www.csproj'
if (-not $NoBuild) {
    if (-not $DotnetPath) {
        $portableSdk = Join-Path $repoRoot 'artifacts\dotnet-sdk\dotnet.exe'
        if (Test-Path -LiteralPath $portableSdk) { $DotnetPath = $portableSdk }
        else {
            $installed = Get-Command dotnet -ErrorAction SilentlyContinue
            if ($installed -and ((& $installed.Source --list-sdks) -match '^10\.')) { $DotnetPath = $installed.Source }
        }
    }
    if (-not $DotnetPath) { throw '.NET 10 SDKが必要です。インストールするか、-DotnetPathでdotnet.exeを指定してください。' }
    Push-Location $repoRoot
    try {
        & $DotnetPath publish $projectPath --configuration Release --output $publishRoot --verbosity minimal --disable-build-servers
        if ($LASTEXITCODE -ne 0) { throw 'ローカル用ビルドに失敗しました。' }
    } finally { Pop-Location }
}
if (-not (Test-Path -LiteralPath (Join-Path $publishRoot 'wwwroot\index.html'))) { throw 'プレビューの成果物がありません。-NoBuildを外して再実行してください。' }
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw 'ローカルサーバーにはPython 3が必要です。' }
Write-Host "ローカル確認: http://127.0.0.1:$Port/"
Write-Host 'このPCだけに接続します。終了はCtrl+Cです。公開リポジトリの更新やpushは行いません。'
& $python.Source (Join-Path $PSScriptRoot 'serve-preview.py') --root (Join-Path $publishRoot 'wwwroot') --port $Port
