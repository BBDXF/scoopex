# scoopex
A enhance script for scoop, add online app search, url clean mirror, scoop github proxy, bucket modify... functions.

Features:
- `scoopex install`
	- `scoopex install 7zip` 同时支持 online 设定
	- `scoopex install bucket/7zip` Done
	- `scoopex install https://xxxxx/7zip.json`
- `scoopex mirror`
	- 获取大佬们分享的Github Mirror/Proxy 地址，然后设置到scoopex中，方便后续使用
    - 支持通过 `scoop config mirror xxxx` 方式自己手动设置为私有地址
	- 开启后，支持 `scoopex install https://xxxx/xx.json` 方式的github地址自动添加github mirror
	- 开启后，支持 `https://xxxx/xx.json` 中APP下载 `URL` 中的github地址自动添加github mirror
- `scoopex online true` 支持通过`scoop.sh`搜索软件源，然后直接安装（无需添加bucket)
	- 开启后，通过scoop.sh搜索，在本地缓存 `online` bucket进行安装和更新，无需 `scoop bucket add xxx yyy` 方式添加本地bucket。
- `scoopex clean true` 开启针对github地址的clean行为
	- 主要是为了解决部分cn bucket主动添加了很多不可用的github proxy问题
	- 支持 `scoopex install xxx`和 `bucket/xxx.json`中的APP下载用的URL地址。
- `scoopex download/search xxxx` 支持在线方式下载`scoop.sh`上的软件，查看bucket等信息
- `scoopex app-bucket` 便利小工具，支持单个或者批量修改APP对应的bucket, 不用卸载软件，就可以切换bucket使用。
- `scoopex fix-bucket` 便利小工具，当APP的bucket被改的乱七八糟时，此工具可单独或者批量尝试恢复本地对应的最佳bucket.
- `scoopex mirr-bucket` 便利小工具，针对China区域不能正常上网情况下，不用删除bucket就可以修改bucket的远程git地址的问题.可单个或者批量。


使用以上功能，完全可以抛弃传统的bucket更新功能，直接使用online方式管理和更新APP，十分方便。  
你也可以只使用scoop自身的功能，当遇到问题时，再使用本工具解决。完全不影响。  

# How to use
```bash
Scoopex is the enhanced extension of Scoop, it provides more functions to support url mirror, url clean, bucket mirror and online app mode.

Usage: scoopex <command> [<args>]
Commands:
  init    => Init the scoopex config using default setting.
  mirror  => List and select the mirror url.
  online <true/false>    => Set the online mode. also can set using scoop config online.
  clean <true/false>     => Set the url clean mode. also can set using scoop config clean.
  install <app>  => Install the app using config setting.
  download <app> => Download the app using config setting.
  update <app>   => Update the app using config setting.
  search <app>   => Search the app using config setting.
  status         => Show the scoopex status and scoop status.
  ...
  app-bucket <app> <bucket> => Set/get the app bucket. app can be *, means all. if bucket is not set, it will use online.
  fix-bucket                => Math app with local bucket app list. if found, change app bucket to local bucket. otherwise, change app bucket to online.
  mirr-bucket <bucket> <true/false/url> => Set/get the bucket git url. true will add mirror. false will remove mirror. url will set the mirror url.
  ...

Beside above scoopex commands, it support call all scoop commands directly. You can use it replace scoop command.

By BBDXF
https://github.com/BBDXF
https://gitcode.com/mycat
https://bbdxf.blog.csdn.net
```

可用Github Proxy 查找网站:
https://github.akams.cn/

添加为bucket
```bash
scoop bucket add bbdxf https://github.com/BBDXF/scoopex

# 获取github proxy: https://github.akams.cn/
# scoop bucket add bbdxf https://gh-proxy.com/https://github.com/BBDXF/scoopex
# scoop bucket add bbdxf https://ghproxy.net/https://github.com/BBDXF/scoopex

scoop install scoopex

scoopex init

# do anything
```


# scoop install for chinese region
```bash
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Invoke-RestMethod -Uri https://raw.githubusercontent.com/BBDXF/scoopex/refs/heads/main/bin/scoopex-install.ps1 | Invoke-Expression
# Invoke-RestMethod -Uri https://gh-proxy.com/https://raw.githubusercontent.com/BBDXF/scoopex/refs/heads/main/bin/scoopex-install.ps1 | Invoke-Expression
# Invoke-RestMethod -Uri https://ghproxy.net/https://raw.githubusercontent.com/BBDXF/scoopex/refs/heads/main/bin/scoopex-install.ps1 | Invoke-Expression
```

# Note
- 这里也提供了我个人开发的工具的bucket包。
	- scooptools
	- scoopex   它几乎可以完全替代scooptools了。
- 这里提供scoopex的源代码地址。

# Author
BBDXF
