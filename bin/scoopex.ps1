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
    $outDir = ""
    if($Path.EndsWith('/') -or $Path.EndsWith('\\')) {
        $outDir = $Path
    }else{
        $outDir = Split-Path $Path -Parent
    }
    # Write-Host "path: $Path, outDir: $outDir"
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


function Get-GitHubProxy2 {
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
function Get-GitHubProxy {
    # request
    $response = Invoke-WebRequest -Uri "https://api.akams.cn/github" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.5615.49 Safari/537.36" -TimeoutSec 30
    $json = $response.Content | ConvertFrom-Json
    $proxies = $json.data

    # check
    if ($proxies.Count -eq 0) {
        Write-Warning "No Proxy Available!"
        return $null
    }

    # format output
    $i = 1
    $proxies_show = @()
    $proxies | ForEach-Object {
        $index = $i++
        $url = $_.url
        $ip = $_.ip
        $latency = $_.latency
        $speed = $_.speed
        $proxies_show += [PSCustomObject]@{Index = $index; Url = $url; Ip = $ip; Latency = $latency; Speed = $speed }
    }
    return $proxies_show
}

function Select-GitHubProxy {
    try {
        Write-Host "[scoopex] Method 1 - Loading GitHub Proxy..."
        $proxies_show = Get-GitHubProxy
        if ( $null -eq $proxies_show -OR $proxies_show.Count -eq 0) {
            Write-Host "[scoopex] Method 2 - Loading GitHub Proxy..."
            $proxies_show = Get-GitHubProxy2
        }
        if ( $null -eq $proxies_show -OR $proxies_show.Count -eq 0) {
            Write-Warning "[scoopex] No Proxy Available!"
            return $null
        }
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
        [string]$Name,
        [string]$Bucket
    )
    $apps = Get-OnlineScoopApp $Name
    if ($apps.Count -eq 0) {
        return $null
    } 
    # $apps | Out-GridView -PassThru | Select-Object -First 1
    $apps_show = @()
    $i = 0
    $apps | ForEach-Object {
        if($Bucket -and $Bucket.Length -gt 0) {
            if(!$_.Repository.ToLower().EndsWith($Bucket.ToLower())) {
                return
            }
        }
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

function Get-CleanUrlContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Content
    )
    # reg match "url": "https://github.com/
    if($Content -match '"url":\s*"(https?:\/\/[^\/]+)\/https:\/\/github\.com\/([^"]+)"') {
        $Content = $Content -replace '"url":\s*"https?:\/\/[^\/]+\/https:\/\/github\.com\/([^"]+)"', '"url": "https://github.com/$1"'
    }
    # reg match "url": "https://raw.githubusercontent.com/
    if($Content -match '"url":\s*"(https?:\/\/[^\/]+)\/https:\/\/raw\.githubusercontent\.com\/([^"]+)"') {
        $Content = $Content -replace '"url":\s*"https?:\/\/[^\/]+\/https:\/\/raw\.githubusercontent\.com\/([^"]+)"', '"url": "https://raw.githubusercontent.com/$1"'
    }
    return $Content
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
function Get-MirrorUrlContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [Parameter(Mandatory = $true)]
        [string]$Mirror
    )
    # reg match "url": "https://github.com/
    if($Content -match '"url":\s*"https:\/\/github\.com\/([^"]+)"') {
        $Content = $Content -replace '"url":\s*"https:\/\/github\.com\/([^"]+)"', ('"url": "' + $Mirror + '/https://github.com/$1"')
    }
    # reg match "url": "https://raw.githubusercontent.com/
    if($Content -match '"url":\s*"https:\/\/raw\.githubusercontent\.com\/([^"]+)"') {
        $Content = $Content -replace '"url":\s*"https:\/\/raw\.githubusercontent\.com\/([^"]+)"', ('"url": "' + $Mirror + '/https://raw.githubusercontent.com/$1"')
    }
    return $Content
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
        Write-Host "[scoopex] Convert Url: $rawUrl"
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
        Write-Host "[scoopex] Convert Url: $rawUrl"
    }

    return $rawUrl
}

function Get-OnlineList{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $file = $scoopdir + '/buckets/online/app.json'
    if(!(Test-Path $file)){
        return $null
    }
    $json = Get-Content $file | ConvertFrom-Json
    if(!$json){
        return $null
    }
    $apps = $json.Apps | Where-Object { $_.Name -eq $Name }
    if($null -ne $apps -AND $apps.Count -gt 0){
        return $apps[0]
    }
    return $null
}
function List-OnlineList{
    $file = $scoopdir + '/buckets/online/app.json'
    if(!(Test-Path $file)){
        return @()
    }
    $json = Get-Content $file | ConvertFrom-Json
    if(!$json){
        return @()
    }
    return @($json.Apps)
}

function Set-OnlineList{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    $file = $scoopdir + '/buckets/online/app.json'
    if(!(Test-Path $file)){
        '{ "Count": 0, "Apps": [] }' | Out-File $file -Encoding UTF8
    }
    $json = Get-Content $file | ConvertFrom-Json
    if(!$json){
        $json = @{
            Count = 0
            Apps = @()
        }
    }
    # duplicate, get it's index in Apps array.
    for($i=0; $i -lt $json.Apps.Count; $i++){
        if($json.Apps[$i].Name -eq $Name){
            if($json.Apps[$i].Url -ne $Url){
                $json.Apps[$i].Url = $Url
                $json | ConvertTo-Json | Out-File $file -Encoding UTF8                
            }
            return
        }
    }
    # add item
    $json.Count++
    $json.Apps += [PSCustomObject]@{Name = $Name; Url = $Url}
    $json | ConvertTo-Json | Out-File $file -Encoding UTF8
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
    Set-OnlineList $app_name $Url
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
    Write-Host "Scoopex is the enhanced extension of Scoop, it provides more functions to support url mirror, url clean, bucket mirror and online app mode."
    Write-Host ""
    Write-Host "Usage: scoopex <command> [<args>]"
    Write-Host "Commands:"
    Write-Host "  init    => Init the scoopex config using default setting."
    Write-Host "  mirror  => List and select the mirror url."
    Write-Host "  online <true/false>    => Set the online mode. also can set using scoop config online."
    Write-Host "  clean <true/false>     => Set the url clean mode. also can set using scoop config clean."
    Write-Host "  install <app>  => Install the app using config setting."
    Write-Host "  download <app> => Download the app using config setting."
    Write-Host "  update <app>   => Update the app using config setting."
    Write-Host "  search <app>   => Search the app using config setting."
    Write-Host "  status         => Show the scoopex status and scoop status."
    Write-Host "  ..."
    Write-Host "  app-bucket <app> <bucket> => Set/get the app bucket. app can be *, means all. if bucket is not set, it will use online."
    Write-Host "  fix-bucket                => Math app with local bucket app list. if found, change app bucket to local bucket. otherwise, change app bucket to online."
    Write-Host "  mirr-bucket <bucket> <true/false/url> => Set/get the bucket git url. true will add mirror. false will remove mirror. url will set the mirror url."
    Write-Host "  ..."
    Write-Host ""
    Write-Host "Beside above scoopex commands, it support call all scoop commands directly. You can use it replace scoop command." -ForegroundColor Blue
    Write-Host ""
    Write-Host "By BBDXF" -ForegroundColor Red
    Write-Host "https://github.com/BBDXF" -ForegroundColor Red
    Write-Host "https://gitcode.com/mycat" -ForegroundColor Red
    Write-Host "https://bbdxf.blog.csdn.net" -ForegroundColor Red
    exit 0
}

$proxy = get_config 'proxy'
if ($null -ne $proxy) {
    Write-Warning "[scoopex] The scoop proxy is enabled, may conflex with scoopex functions."
}

$default_mirror = "https://gh-proxy.com"
$mirror = get_config 'mirror'
if ($null -eq $mirror) {
    Write-Host "[scoopex] Mirror is not set!" -ForegroundColor Yellow
}
elseif (!$mirror.StartsWith("https://")) {
    Write-Warning "[scoopex] Mirror url is illegal! Use 'scoopex mirror' to change it!"
    exit 1
}
# Write-Host "[scoopex] Current Mirror: $mirror" 

# if online is False, just use clean url function
$online = get_config 'online'
if ($null -eq $online) {
    $online = $false
    $null = set_config 'online' $false
}
# Write-Host "[scoopex] Online Mode: $online"  

$clean = get_config 'clean'
if ($null -eq $clean) {
    $clean = $false
    $null = set_config 'clean' $false
}
# Write-Host "[scoopex] Url Clean Mode: $clean"

# pre-action variables
$pre_json_content = ""


# init
if($args[0] -eq 'init') {
    # default config for scoopex
    $null = set_config 'online' $true
    $null = set_config 'clean' $true
    if(get_config 'proxy') {
        Write-Host "[scoopex] The scoop proxy is enabled, may conflex with scoopex mirror. disable scoopex mirror function." -ForegroundColor Yellow
        $null = set_config 'mirror' $null
    }else{
        $null = set_config 'mirror' $default_mirror
        Write-Host "[scoopex] Set default mirror: $default_mirror" -ForegroundColor Yellow
    }
    # default config for scoop
    $null = set_config 'aria2-enabled' $false
    $null = set_config 'autostash_on_conflict' $true
    $null = set_config 'force_update' $true
    # $null = set_config 'use_sqlite_cache' $false

    # proxy: [username:password@]host:port
    # autostash_on_conflict: $true|$false
    # force_update: $true|$false
    # scoop_repo: http://github.com/ScoopInstaller/Scoop
    # scoop_branch: master|develop
    # root_path: $Env:UserProfile\scoop
    # global_path: $Env:ProgramData\scoop
    # use_external_7zip: $true|$false
    # use_sqlite_cache: $true|$false   

    Get-MakeFullPath "$scoopdir/buckets/online/bucket/"

    Write-Host "[scoopex] Init done. User 'scoopex status' to check." -ForegroundColor Green
    exit 0
}

# mirror
if ($args[0] -eq 'mirror') {
    $ghmirror = Select-GitHubProxy
    if ($ghmirror) {
        Write-Host "Current Github Mirror: $($ghmirror.Url)" -ForegroundColor Green
        Invoke-Expression "scoop config mirror $($ghmirror.Url)"
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


# status
if ($args[0] -eq 'status') {
    Write-Host "Scoopex Status:"
    Write-Host "  Mirror Url: $mirror"
    Write-Host "  Online Mode: $online"  
    Write-Host "  Url Clean Mode: $clean"
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
    $app_bucket = ""
    $app_name = $app
    # bucket/app
    if($app -match '^([^/]+)/([^/]+)$'){
        $app_bucket = $matches[1]
        $app_name = $matches[2]
    }else{
        $app_bucket = ""
        $app_name = $app
    }
    $rlst = Select-OnlineScoopApp $app_name $app_bucket 
    if ($rlst) {
        $rlst | Format-List | Out-Host
        exit 0
    }
    # if no reslut, use local scoop search 
    Write-Host "[scoopex] No result found, use local scoop search." -ForegroundColor Red
}

function Get-ScoopInstalledApps {
    $apps = @()
    $dir = appsdir $false
    if (Test-Path $dir) {
        # Get-ChildItem $dir | Where-Object { $_.psiscontainer -and $_.name -ne 'scoop' } | ForEach-Object { $_.name }
        foreach($app_dir in (Get-ChildItem $dir)){
            if($app_dir.psiscontainer -and $app_dir.name -ne 'scoop'){
                $apps += $app_dir.name
            }
        }
    }
    return $apps
}

function Set-BucketAppUrlByConfig(){
    param(
        [Parameter(Mandatory = $true)]
        [string]$app_bucket_file
    )
    # modify bucket/xxx.json url
    $Content = Get-Content $app_bucket_file -Raw
    $old_content = $Content
    if($clean -eq $true) {
        $Content = Get-CleanUrlContent $Content
        Write-Host "[scoopex] Clean App Url..." -ForegroundColor Yellow
    }
    if ($null -ne $mirror) {
        $Content = Get-MirrorUrlContent $Content $mirror
        Write-Host "[scoopex] Add Mirror for App Url..." -ForegroundColor Yellow
    }
    Set-Content -Path $app_bucket_file -Value $Content -Encoding UTF8
    return $old_content
}

# install/download/update
if ($args[0] -eq 'install' -OR $args[0] -eq 'download') {
    if ( $args.Count -ne 2) {
        Write-Host "Usage: scoopex $($args[0]) <app>"
        exit 1
    }
    $app_url = $args[1]
    $app_name = ""
    $app_bucket = ""
    $app_bucket_file = ""
    # url method
    if ($app_url.StartsWith("https://") -OR $app_url.StartsWith("http://")) {
        $appTmp = Get-LocalTmpBucketApp $app_url ""
        if ($appTmp) {
            $app_name = $appTmp.Name
            $app_bucket_file = $appTmp.File
            $app_bucket = "online"
        }
    }
    else {
        # app name method
        $app = $app_url
        # bucket/app
        if($app -match '^([^/]+)/([^/]+)$'){
            $app_bucket = $matches[1]
            $app_name = $matches[2]
            $app_bucket_file = $scoopdir +"/buckets/$app_bucket/bucket/$app_name.json"
        }else{
            $app_bucket = ""
            $app_name = $app
            $app_bucket_file = ""
        }

        # scoop app
        $scoop_apps = Get-ScoopInstalledApps
        # Write-Host "[scoopex] Scoop Apps: $scoop_apps"
        if ($scoop_apps -contains $app_name) {
            # bucket test
            $install_file = (appsdir $false) + "/$app_name/current/install.json"
            if (Test-Path $install_file) {
                $install_json = Get-Content $install_file | ConvertFrom-Json
                if ($install_json -and $install_json.bucket) {
                    $app_bucket = $install_json.bucket
                    $app_bucket_file = $scoopdir +"/buckets/$app_bucket/bucket/$app_name.json"
                    Write-Host "[scoopex] Found App '$app_name' in Bucket '$app_bucket'" -ForegroundColor Green
                    if($app_bucket -eq "online"){
                        # online/xxx
                        $online_app = Get-OnlineList $app_name
                        if ($null -ne $online_app) {
                            Write-Host "[scoopex] Update App '$app_name' from https://scoop.sh." -ForegroundColor Green
                            $null = Get-LocalTmpBucketApp $online_app.Url $app_name
                        }
                    }
                }
            }
        }else{
            # scoop.sh online search
            $rlst = Select-OnlineScoopApp $app_name $app_bucket
            # Write-Host "[scoopex] Online Search Result: $rlst"
            if ($rlst) {
                $rlst | Format-List | Out-Host
                $url = $rlst.Repository + '/blob/master/' + $rlst.FilePath
                $appTmp = Get-LocalTmpBucketApp $url $rlst.Name
                if ($appTmp) {
                    $app_name = $appTmp.Name
                    $app_bucket_file = $appTmp.File
                    $app_bucket = "online"
                }
            }
        }
        
    }

    # modify bucket/xxx.json url
    if ($null -ne $app_bucket -AND $app_bucket -ne "") {
        $pre_json_content = Set-BucketAppUrlByConfig $app_bucket_file
    }

    # install online/xxx
    if ($null -ne $app_bucket -AND $app_bucket -ne "") {    
        Write-Host "[scoopex] scoop $($args[0]) '$app_bucket/$app_name'" -ForegroundColor Green
        Invoke-Expression "scoop $($args[0]) $app_bucket/$app_name"

        # restore bucket/xxx.json url
        if ($null -ne $pre_json_content -AND $pre_json_content -ne "") {
            Set-Content -Path $app_bucket_file -Value $pre_json_content -Encoding UTF8
        }
    }
    exit 0
}

if($args[0] -eq 'update') {
    if($args.Count -eq 2 ) {
        $app = $args[1]
        if( $app -eq 'all' -OR $app -eq '*' ){
            $app = $null
        }
        if(is_scoop_outdated){
            Write-Host "[scoopex] Scoop is outdated, update it first." -ForegroundColor Yellow
            Invoke-Expression "scoop update"
        }
        # scoop app
        $scoop_apps = Get-ScoopInstalledApps
        # Write-Host "[scoopex] Scoop Apps: $scoop_apps"
        foreach($app_name in $scoop_apps) {
            if($null -ne $app -AND $app -ne $app_name){
                continue
            }
            # bucket test
            $install_file = (appsdir $false) + "/$app_name/current/install.json"
            if (Test-Path $install_file) {
                $install_json = Get-Content $install_file | ConvertFrom-Json
                if ($install_json -and $install_json.bucket) {
                    $app_bucket = $install_json.bucket
                    $app_bucket_file = $scoopdir +"/buckets/$app_bucket/bucket/$app_name.json"
                    if($app_bucket -eq "online"){
                        # online/xxx
                        $online_app = Get-OnlineList $app_name
                        if ($null -ne $online_app) {
                            Write-Host "[scoopex] Update App '$app_name' from https://scoop.sh." -ForegroundColor Green
                            $null = Get-LocalTmpBucketApp $online_app.Url $app_name
                        }
                    }
                    $null = Set-BucketAppUrlByConfig $app_bucket_file
                    Write-Host "[scoopex] Process '$app_name' in Bucket '$app_bucket'" -ForegroundColor Green
                }
            }
        }
    }
    # continue to use scoop update
}

# app-bucket <app> <bucket>
if ($args[0] -eq 'app-bucket') {
    $apps = @()
    $bucket = ""
    if ( $args.Count -eq 1 -OR (  $args.Count -eq 2 -AND ($args[1] -eq "*" -OR $args[1] -eq "all") )) {
        # list all app bucket
        Write-Host "App Bucket List:"
        $apps = Get-ScoopInstalledApps
        foreach($app in $apps) {
            $install_file = (appsdir $false) + "/$app/current/install.json"
            if (Test-Path $install_file) {
                $install_json = Get-Content $install_file | ConvertFrom-Json
                if ($install_json -and $install_json.bucket) {
                    $bucket = $install_json.bucket
                    Write-Host ("  {0,-18}: {1}" -f $app, $bucket)
                }
            }
        }
        exit 0
    }
    
    # set app bucket
    $app = $args[1]
    if ( $args.Count -eq 3) {
        $bucket = $args[2]
    }
    if($app -eq "*" -OR $app -eq "all") {
        $apps = Get-ScoopInstalledApps
    }else{
        $apps = @($app)
    }
    foreach($app in $apps) {
        $install_file = (appsdir $false) + "/$app/current/install.json"
        if (Test-Path $install_file) {
            $install_json = Get-Content $install_file | ConvertFrom-Json
            if ($install_json -and $install_json.bucket) {
                $bucket_old = $install_json.bucket
                if($null -ne $bucket -AND $bucket -ne ""){
                    Write-Host ("  App {0,-18}: {1,-12} => {2,-12}" -f $app, $bucket_old, $bucket) -ForegroundColor Green
                    $install_json.bucket = $bucket
                    $install_json | ConvertTo-Json | Out-File $install_file -Encoding UTF8
                }else{
                    Write-Host ("  App {0,-18}: {1,-12}" -f $app, $bucket_old)
                }
            }
        }else{
            Write-Host ("  App {0,-18} package is broken!" -f $app) -ForegroundColor Red
        }
    }
    exit 0
}

function Get-AppInBucket{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $offical_buckets = @("main", "extras", "versions", "nonportable", "nirsoft", "sysinternals")
    # find in offical buckets
    foreach($bucket in $offical_buckets) {
        $app_file = $scoopdir + "/buckets/$bucket/bucket/$Name.json"
        if (Test-Path $app_file) {
            return $bucket
        }
    }
    # find in other buckets
    $buckets = Get-ChildItem $scoopdir/buckets -Directory
    foreach($bucket in $buckets) {
        if($bucket.Name -in $offical_buckets){
            continue
        }
        $app_file = $bucket.FullName + "/bucket/$Name.json"
        if (Test-Path $app_file) {
            return $bucket.Name
        }
    }
    return $null
}

# fix-bucket
if ($args[0] -eq 'fix-bucket') {
    foreach($app in (Get-ScoopInstalledApps)) {
        $bucket = Get-AppInBucket $app
        if($null -ne $bucket -AND $bucket -ne ""){
            $install_file = (appsdir $false) + "/$app/current/install.json"
            if (Test-Path $install_file) {
                $install_json = Get-Content $install_file | ConvertFrom-Json
                $bucket_old = $install_json.bucket
                if ($install_json -and $install_json.bucket) {
                    if($bucket_old -ne $bucket){
                        Write-Host ("  App {0,-18}: {1,-12} => {2,-12}" -f $app, $bucket_old, $bucket) -ForegroundColor Green
                        $install_json.bucket = $bucket
                        $install_json | ConvertTo-Json | Out-File $install_file -Encoding UTF8
                    }else{
                        Write-Host ("  App {0,-18}: {1,-12} keep." -f $app, $bucket_old, $bucket) -ForegroundColor Gray
                    }
                }
            }
        }else{
            Write-Host ("  App {0,-18} bucket not found, set to 'online'" -f $app) -ForegroundColor Red
            $install_file = (appsdir $false) + "/$app/current/install.json"
            if (Test-Path $install_file) {
                $install_json = Get-Content $install_file | ConvertFrom-Json
                $install_json.bucket = "online"
                $install_json | ConvertTo-Json | Out-File $install_file -Encoding UTF8
            }
        }
    }
    exit 0
}

function Get-GitRepoUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    # cd to the directory
    Push-Location $Path
    try {
        # git config --get remote.origin.url
        $remoteUrl = git config --get remote.origin.url
        if ($remoteUrl) {
            return $remoteUrl
        }
    }
    finally {
        # back to the original directory
        Pop-Location
    }
    return $null
}

function Set-GitRepoUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    # cd to the directory
    Push-Location $Path
    try {
        # git remote set-url origin <url>
        git remote set-url origin $Url
        return $true
    }
    finally {
        # back to the original directory
        Pop-Location
    }
    return $false
}

# mirr-bucket <bucket> <true/false/url>
if ($args[0] -eq 'mirr-bucket') {
    if ( $args.Count -eq 1) {
        # list all bucket git url
        Write-Host "Bucket Git Url List:"
        $buckets = Get-ChildItem "$scoopdir/buckets/" -Directory
        foreach($bucket in $buckets) {
            $repo_url = Get-GitRepoUrl $bucket.FullName
            if($null -ne $repo_url -AND $repo_url -ne ""){
                Write-Host ("  {0,-12} => {1}" -f $bucket.Name, $repo_url) -ForegroundColor Green
            }else{
                Write-Host ("  {0,-12} is not git repo!" -f $bucket.Name) -ForegroundColor Red
            }
        }
        exit 0
    }

    # set bucket git url
    $bucket = $args[1]
    $val = ""
    if ( $args.Count -eq 3) {
        $val = $args[2]
    }
    $buckets = @()
    if($bucket -eq "*" -OR $bucket -eq "all") {
        $buckets = Get-ChildItem "$scoopdir/buckets/" -Directory | ForEach-Object { $_.Name }
    }else{
        $buckets = @($bucket)
    }
    foreach($bucket_name in $buckets) {
        $repo_url = $null
        if(Test-Path "$scoopdir/buckets/$bucket_name"){
            $repo_url = Get-GitRepoUrl "$scoopdir/buckets/$bucket_name"
        }
        if($null -ne $repo_url -AND $repo_url -ne ""){
            if($args.Count -eq 2){
                Write-Host ("  {0,-12} => {1}" -f $bucket_name, $repo_url) -ForegroundColor Green
            }else{
                if($val -eq "true" -AND $mirror -ne ""){
                    $repo_url_new = Get-CleanUrl $repo_url
                    $repo_url_new = Get-MirrorUrl $repo_url_new
                    if($repo_url_new -ne $repo_url){
                        $null = Set-GitRepoUrl "$scoopdir/buckets/$bucket_name" $repo_url_new
                        Write-Host ("  Bucket {0,-12}: {1} => {2}" -f $bucket_name,$repo_url, $repo_url_new) -ForegroundColor Green
                    }else{
                        Write-Host ("  Bucket {0,-12}: {1}, keep." -f $bucket_name,$repo_url) -ForegroundColor Gray
                    }
                }elseif($val -eq "false"){
                    $repo_url_new = Get-CleanUrl $repo_url
                    if($repo_url_new -ne $repo_url){
                        $null = Set-GitRepoUrl "$scoopdir/buckets/$bucket_name" $repo_url_new
                        Write-Host ("  Bucket {0,-12}: {1} => {2}" -f $bucket_name,$repo_url, $repo_url_new) -ForegroundColor Green
                    }else{
                        Write-Host ("  Bucket {0,-12}: {1}, keep." -f $bucket_name,$repo_url) -ForegroundColor Gray
                    }
                }elseif($val.StartsWith("https://") -OR $val.StartsWith("http://")){
                    $repo_url_new = Get-CleanUrl $val
                    $repo_url_new = Get-MirrorUrl $repo_url_new
                    if($repo_url_new -ne $repo_url){
                        $null = Set-GitRepoUrl "$scoopdir/buckets/$bucket_name" $repo_url_new
                        Write-Host ("  Bucket {0,-12}: {1} => {2}" -f $bucket_name,$repo_url, $repo_url_new) -ForegroundColor Green
                    }else{
                        Write-Host ("  Bucket {0,-12}: {1}, keep." -f $bucket_name,$repo_url) -ForegroundColor Gray
                    }
                }else{
                    Write-Host ("  Bucket {0,-12}: git url '{1}' invalied." -f $bucket_name, $val) -ForegroundColor Red
                }

            }
        }else{
            Write-Host ("  Bucket {0,-12} is not git repo!" -f $bucket_name) -ForegroundColor Red
        }
    }
    exit 0
}

# default call scoop function
$cmds = "scoop $args"
Write-Host "[scoopex] Run: '$cmds'" -ForegroundColor Green
Invoke-Expression $cmds

# post action
if ($args[0] -eq 'install' -OR $args[0] -eq 'download' -OR $args[0]) {
    if ($null -ne $pre_json_content -AND $pre_json_content -ne "") {
        Set-Content -Path $app_file -Value $pre_json_content -Encoding UTF8
        Write-Host "[scoopex] Restore file: $app_file" -ForegroundColor Yellow
    }
}