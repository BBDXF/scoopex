
Write-Host "Scoopex for scoop install tool. By BBDXF" -ForegroundColor Cyan
Write-Host "Steps:" -ForegroundColor Yellow
Write-Host "0. Use admin to run powershell cmd: 'Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser'." -ForegroundColor Red
Write-Host "1. Select a GitHub Proxy/Mirror." -ForegroundColor Yellow
Write-Host "2. Custom Scoop Config For Installer." -ForegroundColor Yellow
Write-Host "3. Install Scoop, include git, 7z." -ForegroundColor Yellow
Write-Host "4. Install Scoopex." -ForegroundColor Yellow
Write-Host "5. Exit." -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
Write-Host ""

$github_proxy = ""
$scoop_dir = ""

# app
$scoop_ps_url = "https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1"
$scoopex_url = "https://www.github.com/BBDXF/scoopex"

function Merge-Hashtables {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Map1,
        
        [Parameter(Mandatory)]
        [hashtable]$Map2
    )
    $merged = $Map1.Clone()
    $Map2.GetEnumerator() | ForEach-Object {
        $merged[$_.Key] = $_.Value
    }
    return $merged
}
function Get-HttpGet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [hashtable]$Headers = @{}
    )
    $Headers2 = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.5615.49 Safari/537.36"
        "Accept"     = " */*" 
    }
    $Headers2 = Merge-Hashtables $Headers2 $Headers
    try {
        # GET
        $response = Invoke-WebRequest -Uri $Url -Method Get -Headers $Headers2
        if (!$response) { return $null }
        return $response
    }
    catch {
        #    Write-Error "Http Get Error: $_" -ErrorAction Continue
        return $null
    }
    return $null
}
function Get-GitHubProxy2 {
    $url = "https://status.akams.cn/status/services"
    $resp = Get-HttpGet $url
    if (!$resp) { return $null }
    $html = $resp.Content 
    $gh_index_start = $html.IndexOf("window.preloadData")
    $gh_index_end = $html.IndexOf("</script>", $gh_index_start)
    $gh_index1 = $html.IndexOf("'name':'GitHub \u516C\u76CA\u4EE3\u7406'", $gh_index_start)

    $i = 1
    $proxies_show = @()
    while ($gh_index1 -gt 0 -and $gh_index1 -lt $gh_index_end) {
        $gh_index2 = $html.IndexOf("'url':'", $gh_index1)
        $gh_index3 = $html.IndexOf("'", $gh_index2 + 7)
        if($gh_index2 -gt 0 -and $gh_index3 -gt 0) {
            $gh_url = $html.Substring($gh_index2 + 7, $gh_index3 - $gh_index2 - 7)
            $decode_url = [System.Text.RegularExpressions.Regex]::Unescape($gh_url)
            if( $decode_url.EndsWith('/') -or $decode_url.EndsWith('\\') ){
                $decode_url = $decode_url.Substring(0, $decode_url.Length - 1)
            }
            # Write-Host "GitHub Proxy: $decode_url"
            $proxies_show += [PSCustomObject]@{Index = $i++; Url = $decode_url }
            $gh_index1 = $gh_index3+1
        }else{
            break
        }
    }
    return $proxies_show
}

Write-Host "1. Select Github Proxy:" -ForegroundColor Yellow

$proxies_show = Get-GitHubProxy2
if (!$proxies_show) {
    Write-Host "Failed to get GitHub proxy." -ForegroundColor Red
    return
}

$proxies_show | Format-Table -AutoSize 
Write-Host "Select a number (1-$($proxies_show.Count)): " -NoNewline -ForegroundColor Yellow
$selected_index = Read-Host
if ($selected_index -lt 1 -or $selected_index -gt $proxies_show.Count) {
    Write-Host "Invalid number." -ForegroundColor Red
    return
}
$github_proxy = $proxies_show[$selected_index - 1].Url
Write-Host "Selected GitHub Proxy: $github_proxy" -ForegroundColor Green

Invoke-Expression "cls"

Write-Host ""
Write-Host "2. Custom Scoop Config For Installer:" -ForegroundColor Yellow

$scoop_dir = Read-Host "Enter the Scoop directory (default is 'C:/Scoop')"
if ($null -eq $scoop_dir -OR $scoop_dir -eq "") { 
    $scoop_dir = "C:/Scoop" 
}
$scoop_root = "$scoop_dir/root"
$scoop_global = "$scoop_dir/global"
$scoop_cache = "$scoop_dir/cache"

Write-Host "Current Scoop Installer Config:" -ForegroundColor Yellow
Write-Host "GitHub Proxy: $github_proxy" -ForegroundColor Green
Write-Host "SCOOP:        $scoop_root" -ForegroundColor Green
Write-Host "SCOOP_GLOBAL: $scoop_global" -ForegroundColor Green
Write-Host "SCOOP_CACHE:  $scoop_cache" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to continue..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

Write-Host "Prepare environment..." -ForegroundColor Green

try{
    New-Item -ItemType Directory -Path $scoop_root -Force | Out-Null
    [Environment]::SetEnvironmentVariable("SCOOP", $scoop_root, "User")
    $env::SCOOP = $scoop_root

    New-Item -ItemType Directory -Path $scoop_global -Force | Out-Null
    [Environment]::SetEnvironmentVariable("SCOOP_GLOBAL", $scoop_global, "User")
    $env::SCOOP_GLOBAL = $scoop_global

    New-Item -ItemType Directory -Path $scoop_cache -Force | Out-Null
    [Environment]::SetEnvironmentVariable("SCOOP_CACHE", $scoop_cache, "User")
    $env::SCOOP_CACHE = $scoop_cache
}
catch{
    Write-Host "Failed to create Scoop directory." -ForegroundColor Red
    return 
}

Write-Host ""
Write-Host "3. Install Scoop, include git, 7z." -ForegroundColor Yellow
Write-Host "Download Scoop Installer using github proxy..." -ForegroundColor Green
$content = (Get-HttpGet "$github_proxy/$scoop_ps_url").Content
if (!$content) {
    Write-Host "Failed to download Scoop Installer." -ForegroundColor Red
    return
}

$content = $content -replace "(https://github\.com/ScoopInstaller)", "$github_proxy/$1"
Invoke-Expression $content

$env:PATH += ";$scoop_root/shims"

Write-Host "Install git, 7z ..." -ForegroundColor Green

Invoke-Expression "scoop config scoop_repo $github_proxy/https://github.com/ScoopInstaller/Scoop"
Invoke-Expression "scoop config aria2-enabled false"
Invoke-Expression "scoop update"

# git proxy
$git_json = "$scoop_root/buckets/main/bucket/git.json"
if(Test-Path $git_json) {
    $git_content = Get-Content $git_json -Raw
    $git_content = $git_content -replace '"url":\s*"https:\/\/github\.com\/([^"]+)"', ('"url": "' + $github_proxy + '/https://github.com/$1"')
    Set-Content $git_json -Value $git_content -Encoding UTF8
}else{
    Write-Host "Failed to find git.json." -ForegroundColor Red
}

Invoke-Expression "scoop install git 7z"

Invoke-Expression "cls"
Write-Host "4. Install Scoopex." -ForegroundColor Yellow
Invoke-Expression "scoop bucket add bbdxf $github_proxy/$scoopex_url"
Invoke-Expression "scoop install scoopex"
Invoke-Expression "scoopex init"
Invoke-Expression "scoop config mirror $github_proxy"

Write-Host "Scoopex Installed." -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
