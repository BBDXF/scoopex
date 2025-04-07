# scoopex script to support mirror and online fucntions
# By BBDXF


. "$PSScriptRoot\..\..\scoop\current\lib\core.ps1"
# . "$PSScriptRoot\..\lib\manifest.ps1" # 'generate_user_manifest' 'Get-Manifest'
# . "$PSScriptRoot\..\lib\install.ps1"
# . "$PSScriptRoot\..\lib\buckets.ps1"

function Get-MakeFullPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    $outDir = Split-Path $OutputFile -Parent
    if (!(Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
}

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

function Get-HttpGetJson {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [hashtable]$Headers = @{}
    )

    $Headers2 = @{
        "User-Agent"   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.5615.49 Safari/537.36"
        "Accept"       = " */*"
        "Content-Type" = "application/json"
    }
    $Headers2 = Merge-Hashtables $Headers2 $Headers

    try {
        # GET
        $response = Invoke-RestMethod -Uri $Url -Method Get -Headers $Headers2

        if (!$response) { return $null }
        return $response
    }
    catch {
        # Write-Error "Http Get Error: $_" -ErrorAction Continue
        return $null
    }
    return $null
}
function Send-HttpPostJson {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [hashtable]$Headers = @{},
        [hashtable]$Body = @{}
    )

    $Headers2 = @{
        "User-Agent"   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.5615.49 Safari/537.36"
        "Accept"       = " */*"
        "Content-Type" = "application/json"
    }
    $Headers2 = Merge-Hashtables $Headers2 $Headers

    try {
        # body to json
        $jsonBody = $Body | ConvertTo-Json

        # POST
        $response = Invoke-RestMethod -Uri $Url -Method Post -Headers $Headers2 -Body $jsonBody

        if (!$response) { return $null }
        return $response
    }
    catch {
        # Write-Error "Http Post Error: $_" -ErrorAction Continue
        return $null
    }
    return $null
}


function Get-GitHubProxy {
    $url = "https://status.akams.cn/status/services"
    $resp = Get-HttpGet $url
    if (!$resp) { return $null }
    $html = $resp.Content 
    $gh_index_start = $html.IndexOf("window.preloadData")
    $gh_index_end = $html.IndexOf("</script>", $gh_index_start)
    # $html | Out-File -FilePath "C:\MyTools\github.html" -Encoding utf8
    $gh_index1 = $html.IndexOf("'name':'GitHub \u516C\u76CA\u4EE3\u7406'", $gh_index_start)
    # Write-Host "start: $gh_index_start, end: $gh_index_end, index: $gh_index1"

    $i = 1
    $proxies_show = @()
    while ($gh_index1 -gt 0 -and $gh_index1 -lt $gh_index_end) {
        $gh_index2 = $html.IndexOf("'url':'", $gh_index1)
        $gh_index3 = $html.IndexOf("'", $gh_index2 + 7)
        if($gh_index2 -gt 0 -and $gh_index3 -gt 0) {
            $gh_url = $html.Substring($gh_index2 + 7, $gh_index3 - $gh_index2 - 7)
            $decode_url = [System.Text.RegularExpressions.Regex]::Unescape($gh_url)
            # Write-Host "GitHub Proxy: $decode_url"
            $proxies_show += [PSCustomObject]@{Index = $i++; Url = $decode_url }
            $gh_index1 = $gh_index3+1
        }else{
            break
        }
    }
    return $proxies_show
    # # request
    # $response = Invoke-WebRequest -Uri "https://api.akams.cn/github" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.5615.49 Safari/537.36" -TimeoutSec 30
    # $json = $response.Content | ConvertFrom-Json
    # $proxies = $json.data

    # # check
    # if ($proxies.Count -eq 0) {
    #     Write-Warning "No Proxy Available!"
    #     return $null
    # }

    # # format output
    # $i = 1
    # $proxies_show = @()
    # $proxies | ForEach-Object {
    #     $index = $i++
    #     $url = $_.url
    #     $ip = $_.ip
    #     $latency = $_.latency
    #     $speed = $_.speed
    #     $proxies_show += [PSCustomObject]@{Index = $index; Url = $url; Ip = $ip; Latency = $latency; Speed = $speed }
    # }
}

function Select-GitHubProxy {
    try {
        $proxies_show = Get-GitHubProxy
        $proxies_show | Format-Table | Out-Host
        # User select
        $index = Read-Host "Input your choice (1-$($proxies_show.Count))"
        # $index = '1'
        $selectedIndex = 0
        if ([int]::TryParse($index, [ref]$selectedIndex) -and $selectedIndex -ge 1 -and $selectedIndex -le $proxies_show.Count) {
            return $proxies_show[$selectedIndex - 1]
        }
        else {
            Write-Error "Invalied index!"
        }
    }
    catch {
        # Write-Error "Http request failed: $_" -ErrorAction Continue
    }
    return $null
}


<#
.SYNOPSIS
Search app using onling mode scoop API.

.DESCRIPTION
This function use scoop.sh API to search all releated app and buckets.
User can install use scoop install command with json url to use it.

.EXAMPLE
$apps = Get-OnlineScoopApp 'ffmpeg'
if ($apps) {
    $apps | Out-GridView
}

.INPUTS
[string]$Name: app name to search.

.OUTPUTS
[array]$apps: array of app info.
Keys: Score, Id, Name, Version, Description, Homepage, License, Notes, Repository, FilePath, Stars, Committed.

.NOTES
The key need update with scoop.sh API.
Author: BBDXF
#>
function Get-OnlineScoopApp {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    try {
        # request
        $url = "https://scoopsearch.search.windows.net/indexes/apps/docs/search?api-version=2020-06-30"
        $headers = @{ 
            "origin"  = "https://scoop.sh"
            "referer" = "https://scoop.sh"
            "api-key" = "DC6D2BBE65FC7313F2C52BBD2B0286ED"
        }
        $body = @{
            "count"      = $true
            "search"     = $Name
            "searchMode" = "all"
            "filter"     = "Metadata/DuplicateOf eq null"
            "orderby"    = "search.score() desc, Metadata/OfficialRepositoryNumber desc, NameSortable asc"
            "skip"       = 0
            "top"        = 20
            "select"     = "Id,Name,NamePartial,NameSuffix,Description,Notes,Homepage,License,Version,Metadata/Repository,Metadata/FilePath,Metadata/OfficialRepository,Metadata/RepositoryStars,Metadata/Committed,Metadata/Sha"
        }
        $json = Send-HttpPostJson -Url $url -Headers $headers -Body $body
        if (!$json) {
            Write-Warning "No App Available!"
            return $null
        }
        $apps = @()
        $json.value | ForEach-Object {
            $score = $_.'@search.score'
            $id = $_.Id
            $name = $_.Name
            $version = $_.Version 
            $description = $_.Description
            $homepage = $_.Homepage
            $license = $_.License
            $notes = $_.Notes
            $repository = $_.Metadata.Repository
            $filePath = $_.Metadata.FilePath
            $repositoryStars = $_.Metadata.RepositoryStars
            $committed = $_.Metadata.Committed

            $apps += [PSCustomObject]@{ Score = $score; Id = $id; Name = $name; Version = $version; Description = $description; Homepage = $homepage; License = $license; Notes = $notes; Repository = $repository; FilePath = $filePath; Stars = $repositoryStars; Committed = $committed }
        }
        return $apps
    }
    catch {
        # Write-Error "Http request failed: $_" -ErrorAction Continue
    }
    return $null
}

function Select-OnlineScoopApp {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $apps = Get-OnlineScoopApp $Name
    if ($apps.Count -eq 0) {
        return $null
    } 
    # $apps | Out-GridView -PassThru | Select-Object -First 1
    $apps_show = @()
    $i = 0
    $apps | ForEach-Object {
        $i++
        $apps_show += [PSCustomObject]@{Index = $i; Name = $_.Name; Version = $_.Version; Stars = $_.Stars; UpdateDate = $_.Committed.Substring(0, 10); 
            License = $_.License; Repository = $_.Repository; Description = $_.Description;  
        }
    }
    $apps_show | Format-Table | Out-Host
    # User select
    $index = Read-Host "Input your choice (1-$($apps_show.Count))"
    # $index = '1'
    $selectedIndex = 0
    if ([int]::TryParse($index, [ref]$selectedIndex) -and $selectedIndex -ge 1 -and $selectedIndex -le $apps_show.Count) {
        return $apps[$selectedIndex - 1]
    }
    else {
        Write-Warning "Invalied index!"
    }
    return $null
}

<#

.EXAMPLE
$Url = "https://someproxy.com/https://github.com/some/repo"
$Url = Get-CleanUrl $Url
Write-Host "Clean Url: $Url"

#>
function Get-CleanUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    # url blacklist
    $blacklist = @(
        "https://github.com",
        "https://raw.githubusercontent.com"
    ) 
    $url_new = $Url
    # if contains but not startswith, remove prefix.
    foreach ($item in $blacklist) {
        if ($Url -match [regex]::Escape($item)) {
            $url_new = $Url -replace "^.*(?=$([regex]::Escape($item)))"
            break
        }
    }
    return $url_new
}

<#
.SYNOPSIS
Get the url with github mirror.

.DESCRIPTION
It will auto clean the url and add mirror prefix.
The mirror is from scoop config mirror.

.EXAMPLE
Get-MirrorUrl -Url "https://gh.com/https://github.com/BBDXF/Scooptools"

#>
function Get-MirrorUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url 
    )
    # mirror from scoop config mirror settings
    $url_clean = Get-CleanUrl $Url
    $mirror = get_config 'mirror'
    # $mirror = "https://fastgit.com"
    if ($mirror) {
        if (!$mirror.EndsWith('/')) {
            $mirror = "$mirror/"
        }
    }
    else {
        $mirror = ""
    }
    $mirror_url = "$mirror$url_clean"
    return $mirror_url
}

function Get-HttpJsonToFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [string]$OutputFile
    )
    try {
        $Headers = @{
            "Content-Type" = "text/plain; charset=utf-8" 
        }
        $json = Get-HttpGet $Url $Headers
        if (!$json) {
            # Write-Warning "Url not Available for $Url ."
            return $null
        }
        Get-MakeFullPath $OutputFile
        $json.Content | Out-File $OutputFile -Encoding UTF8
        return $json.Content | ConvertFrom-Json
    }
    catch {
        # Write-Error "Http Get Error: $_" -ErrorAction Continue
    }
    return $null
}

function ConvertTo-RawUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GitHubUrl
    )
    $rawUrl = $GitHubUrl
    Write-Host "[scoopex] Origin Url: $rawUrl"
    # https://github.com/BBDXF/scoopplus/blob/master/wails.json
    # https://raw.githubusercontent.com/BBDXF/scoopplus/refs/heads/master/wails.json
    if ($rawUrl -match 'github\.com') {
        if ($rawUrl -match '/master/' -AND $rawUrl -notmatch '/blob/master/') {
            $rawUrl = $rawUrl -replace '/master/', '/blob/master/'
        }
        # if ($rawUrl -match '/main/' -AND $rawUrl -notmatch '/blob/main/') {
        #     $rawUrl = $rawUrl -replace '/main/', '/blob/main/'
        # }
        $rawUrl = $rawUrl -replace 'github\.com', 'raw.githubusercontent.com' `
            -replace '/blob/', '/refs/heads/' 
    }
    # https://gitee.com/mars4312/tv-box/blob/master/xiaoyu.txt
    # https://gitee.com/mars4312/tv-box/raw/master/xiaoyu.txt
    if ($rawUrl -match 'gitee\.com') {
        if ($rawUrl -match '/master/' -AND $rawUrl -notmatch '/blob/master/') {
            $rawUrl = $rawUrl -replace '/master/', '/blob/master/'
        }
        # if ($rawUrl -match '/main/' -AND $rawUrl -notmatch '/blob/main/') {
        #     $rawUrl = $rawUrl -replace '/main/', '/blob/main/'
        # }
        $rawUrl = $rawUrl -replace '/blob/', '/raw/'
    }

    return $rawUrl
}

function Get-LocalTmpBucketApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [string]$Name
    )
    $app_name = $Name
    if ($null -eq $app_name -OR $app_name -eq "") {
        $app_name = $Url -replace ".*\/", ""
        $app_name = $app_name -replace "\.json$", ""
    }
    $rawurl = ConvertTo-RawUrl $Url
    $clean_mode = get_config 'clean'
    if ($null -eq $clean_mode) { $clean_mode = $false }
    if ($clean_mode -eq $true) {
        $rawurl = Get-CleanUrl $rawurl
        Write-Host "[scoopex] Clean  Url: $rawurl"
    }
    $mirror = get_config 'mirror'
    if ($null -ne $mirror) {
        $rawurl = Get-MirrorUrl $rawurl
        Write-Host "[scoopex] Mirror Url: $rawurl"
    }
    $file = $scoopdir + '/buckets/online/bucket/' + $app_name + '.json'
    Write-Host "[scoopex] Download '$app_name' to '$file'"
    if ($null -eq (Get-HttpJsonToFile $rawurl $file)) {
        Write-Warning "[scoopex] Download '$app_name' failed."
        return $null
    }
    return [PSCustomObject]@{ Name = $app_name; File = $file; Url = $rawurl; }
}
 

# powershell 安全选项
# mirror 安装scoop, 7zip, git
# app bucket 修改
# scoop url, bucket url mirror 修改
# mirror install/download/update
# url clean/mirror
# 常用功能，default config. msi,innosetup 等包的安装
# 推荐app list和bucket list

if ($args.Count -eq 0) {
    Write-Host "Scoopex v1.1.0"
    Write-Host "Scoopex is the enhanced extension of Scoop, it provides more functions to support url mirror, url clean and online app mode."
    Write-Host ""
    Write-Host "Usage: scoopex <command> [<args>]"
    Write-Host "Commands:"
    Write-Host "  mirror  => List and set the mirror url."
    Write-Host "  online <true/false> => Set the online mode. also can set using scoop config online."
    Write-Host "  clean <true/false>  => Set the url clean mode. also can set using scoop config clean."
    Write-Host "  error-run <true/false> => Set the error case process action. also can set using scoop config error-run."
    Write-Host "  install <app> => Install the app using config online mode."
    Write-Host "  download <app> => Download the app using config online mode."
    Write-Host "  update <app>  => Update the app using config online mode."
    Write-Host "  search <app>  => Search the app using online mode."
    Write-Host "  status => Show the scoopex status and scoop status."
    Write-Host "  ..."
    Write-Host ""
    Write-Host "Beside above scoopex commands, it support call all scoop commands directly. You can use it replace scoop command." -ForegroundColor Blue
    exit 0
}

$proxy = get_config 'proxy'
if ($null -ne $proxy) {
    Write-Warning "[scoopex] The scoop proxy is enabled, may conflex with scoopex functions."
}

$default_mirror = "https://gh-proxy.com"
$mirror = get_config 'mirror'
if ($null -eq $mirror) {
    $mirror = $default_mirror
    set_config 'mirror' $default_mirror
    Write-Warning "[scoopex] Mirror is not set! Use default setting $default_mirror."
}
if (!$mirror.StartsWith("https://")) {
    $mirror = $default_mirror
    Write-Warning "[scoopex] Mirror url is illegal! Use default setting $default_mirror."
}
# Write-Host "[scoopex] Current Mirror: $mirror" 

# if online is False, just use clean url function
$online = get_config 'online'
if ($null -eq $online) {
    $online = $false
    set_config 'online' $false
}
# Write-Host "[scoopex] Online Mode: $online"  

$clean = get_config 'clean'
if ($null -eq $clean) {
    $clean = $false
    set_config 'clean' $false
}
# Write-Host "[scoopex] Url Clean Mode: $clean"

$error_run = get_config 'error-run'
if ($null -eq $error_run) {
    $error_run = $true
    set_config 'error-run' $true
}
# Write-Host "[scoopex] Error Run Mode: $error_run"

# mirror
if ($args[0] -eq 'mirror') {
    $ghmirror = Select-GitHubProxy
    if ($ghmirror) {
        Write-Host "Current Select Mirror: $($ghmirror.Url)"
        Invoke-Expression "scoop config mirror $($ghmirror.Url)"
        Invoke-Expression "scoop config online true" 
    }
    exit 0 
}

# online
if ($args[0] -eq 'online') {
    if ( $args.Count -ne 2) {
        Invoke-Expression "scoop config online"
        exit 0
    }
    $val = $args[1]
    Invoke-Expression "scoop config online $val"
    exit 0
}

# clean
if ($args[0] -eq 'clean') {
    if ( $args.Count -ne 2) {
        Invoke-Expression "scoop config clean"
        exit 0
    }
    $val = $args[1]
    Invoke-Expression "scoop config clean $val"
    exit 0  
}

# error-run
if ($args[0] -eq 'error-run') {
    if ( $args.Count -ne 2) {
        Invoke-Expression "scoop config error-run"
        exit 0
    }
    $val = $args[1]
    Invoke-Expression "scoop config error-run $val"
    exit 0  
}

# status
if ($args[0] -eq 'status') {
    Write-Host "Scoopex Status:"
    Write-Host "  Mirror Url: $mirror"
    Write-Host "  Online Mode: $online"  
    Write-Host "  Url Clean Mode: $clean"
    Write-Host "  Error Run Mode: $error_run"
    Write-Host ""
    Write-Host "Scoop Status:"
    Invoke-Expression "scoop status"
    exit 0
}

# search
if ($args[0] -eq 'search') {
    if ( $args.Count -ne 2) {
        Write-Host "Usage: scoopex search <app>"
        exit 1
    }
    $app = $args[1]
    $rlst = Select-OnlineScoopApp $app 
    if ($rlst) {
        $rlst | Format-List | Out-Host
        exit 0
    }
    # if no reslut, use local scoop search 
    if ($error_run -eq $false) {
        exit 1
    }
    Write-Warning "[scoopex] No result found, use local scoop search."
}


# install/download/update
if ($args[0] -eq 'install' -OR $args[0] -eq 'download' -OR $args[0] -eq 'update') {
    if ( $args.Count -ne 2) {
        Write-Host "Usage: scoopex $($args[0]) <app>"
        exit 1
    }
    $app_url = $args[1]
    $app_name = ""
    $app_file = ""
    # url method
    if ($app_url.StartsWith("https://") -OR $app_url.StartsWith("http://")) {
        $app = Get-LocalTmpBucketApp $app_url ""
        if ($app) {
            $app_name = $app.Name
            $app_file = $app.File
        }
    }
    else {
        # app name method
        if ($online -eq $true) {
            $app = $app_url
            $rlst = Select-OnlineScoopApp $app 
            if ($rlst) {
                $rlst | Format-List | Out-Host
                $url = $rlst.Repository + '/blob/master/' + $rlst.FilePath
                $app = Get-LocalTmpBucketApp $url $rlst.Name
                if ($app) {
                    $app_name = $app.Name
                    $app_file = $app.File
                }
            }
        }
    }
    # install online/xxx
    if ($null -ne $app_name -AND $app_name -ne "") {    
        Write-Host "[scoopex] scoop download 'online/$app_name'" -ForegroundColor Green
        Invoke-Expression "scoop download online/$app_name"
        # install/update online/xxx
        if ($args[0] -eq 'install') {
            Write-Host "[scoopex] scoop install 'online/$app_name'" -ForegroundColor Green
            Invoke-Expression "scoop install online/$app_name"
        }
        if ($args[0] -eq 'update') {
            Write-Host "[scoopex] scoop update 'online/$app_name'" -ForegroundColor Green
            Invoke-Expression "scoop update online/$app_name"
        }
        exit 0
    }

    if ($error_run -eq $false) {
        exit 0
    }
}


# default call scoop function
$cmds = "scoop $args"
Write-Host "[scoopex] Run: $cmds" -ForegroundColor Green
Invoke-Expression $cmds
