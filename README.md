# 声笔输入法

用lua重新实现的声笔系列码，不依赖魔改的声笔librime和定制的前端，而直接使用原版的librime和原版的前端，可以完全兼容非声笔的rime输入方案。lua版声笔完全开放码表，具有极高的定制能力，可以让用户随心所欲地满足自己的输入需求。

## 安装方法

### 在Windows上

建议采用小狼毫0.15.0版，下载地址 https://github.com/rime/weasel/releases/tag/0.15.0 。安装小狼毫后，再到 https://github.com/sbsrf/sbsrf/releases 下载声笔输入法压缩包。将压缩包解压后，将文件squirrel、weasel和trime以外的所有文件复制到小狼毫用户rime中，同时将weasel目录里的weasel.custom.yaml也复制进去，重新部署一下就可以使用了。

### 在Android上

建议采用同文v3.2.16，下载地址 https://github.com/osfans/trime/releases/tag/v3.2.16 。安装同文后，再到 https://github.com/sbsrf/sbsrf/releases 下载声笔输入法压缩包。将压缩包解压后，将文件squirrel、weasel和trime以外的所有文件复制到同文用户设定中，同时将trime目录里的所有目录和文件也复制进去，重新部署一下就可以使用了。如果使用异常，请重启一下手机，一般就没有问题了。如果发现声笔的主题切换不出来，那么就将主题同时复制一份到build文件夹。

### 在MacOS上

建议采用鼠须管0.16.2版，下载地址 https://github.com/rime/squirrel/releases/tag/0.16.2 。安装小狼毫后，再到 https://github.com/sbsrf/sbsrf/releases 下载声笔输入法压缩包。将压缩包解压后，将文件squirrel、weasel和trime以外的所有文件复制到鼠须管用户设定中，同时将squirrel目录里的squirrel.custom.yaml也复制进去，重新部署一下就可以使用了。

### 在iOS上

在 App Store 搜索「仓输入法」并安装最新版即可。安装后，在设置中启用「仓输入法」键盘，此时注意不要错误地启用了「声笔 - 仓输入法」这个键盘（它是适用于声笔 9 的魔改声笔 librime，与声笔 10 不兼容）。安装完毕后，再到 https://github.com/sbsrf/sbsrf/releases 下载声笔输入法压缩包。打开「Wi-Fi 上传方案」功能，并将压缩包解压后除文件squirrel、weasel和trime以外的所有文件上传，然后重新部署一下就可以使用了。

仓输入法内置了两款适配声笔的皮肤（分别叫「声笔 46」和「声笔 trime」），需要在「键盘设置」——「键盘布局」中启用。

### 在Linux上

前端可以采用 [ibus-rime](https://github.com/rime/ibus-rime) 或者 [fcitx5-rime](https://github.com/fcitx/fcitx5-rime)。注意运行声笔系列码的 lua 脚本至少需要 librime 1.8.5，如果你使用的 Linux 发行版包管理器中的 librime 大于等于 1.8.5 则可以直接安装，否则需要自己编译安装 librime（编译时建议使用最新的发行版 [librime 1.10.0](https://github.com/rime/librime/tree/1.10.0)。

安装完毕后，再到 https://github.com/sbsrf/sbsrf/releases 下载声笔输入法压缩包。将压缩包解压后，将文件squirrel、weasel和trime以外的所有文件复制到用户目录中，重新部署一下就可以使用了。

## 使用方法

声笔输入法的具体使用方法详见 https://sbxlm.gitee.io/about/ ，网站上还包括声笔在线体验、声笔在线练习和声笔词库迁移工具等。
