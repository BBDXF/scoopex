# scoopex
A enhance script for scoop, add online app search, url clean mirror, scoop github proxy, bucket modify... functions.

Features:
- `scoopex install https://github.com/xxx/xxx.json` 支持直接安装在线json
- `scoopex mirror ` 支持设置github proxy
- `scoopex online true; scoopex install xxxx` 支持通过`scoop.sh`搜索软件源，然后直接安装（无需添加bucket)
- `scoopex download/search xxxx` 支持在线方式下载`scoop.sh`上的软件，查看bucket等信息


```bash
Scoopex v1.1.0
Scoopex is the enhanced extension of Scoop, it provides more functions to support url mirror, url clean and online app mode.

Usage: scoopex <command> [<args>]
Commands:
  mirror  => List and set the mirror url.
  online <true/false> => Set the online mode. also can set using scoop config online.
  clean <true/false>  => Set the url clean mode. also can set using scoop config clean.
  error-run <true/false> => Set the error case process action. also can set using scoop config error-run.
  install <app> => Install the app using config online mode.
  download <app> => Download the app using config online mode.
  update <app>  => Update the app using config online mode.
  search <app>  => Search the app using online mode.
  status => Show the scoopex status and scoop status.
  ...

Beside above scoopex commands, it support call all scoop commands directly. You can use it replace scoop command.
```

添加为bucket
```bash
scoop bucket add scoopex https://github.com/BBDXF/scoopex
scoop install scoopex
```

# Note
- 这里提供了我个人开发的工具的bucket包。
	- scooptools
	- scoopex
- 这里提供scoopex的源代码地址。

# Author
BBDXF
