# PotPlayer Personal Lazy Pack（自用版）

这是一个面向 64 位 Windows 的 PotPlayer 个人播放器环境懒人包。它把 [PotPlayer](https://potplayer.tv/)、[LAV Filters](https://github.com/Nevcairiel/LAVFilters)、[madVR](https://www.videohelp.com/software/madVR) 和 [XySubFilter](https://github.com/pinterf/xy-VSFilter) x64 放在同一个固定目录中，并提供两个辅助脚本：

- Restore.cmd：在目标电脑上恢复组件注册和配置。
- Pack-LazyPack.cmd / Pack-LazyPack.ps1：把当前目录重新打包成 ZIP。

本项目是根据本人当前播放器环境整理的自用版，不是通用安装程序，也不会替代 PotPlayer、LAV、madVR 或 XySubFilter 官方安装包。

## 适用设备

当前配置主要在以下设备上整理和验证：

- 设备：ThinkBook 16+
- 处理器：Intel(R) Core(TM) UltraX7 358H
- 显卡：Intel(R) Arc(TM) B390 GPU
- 内存：32.0 GB RAM

由于这是自用版，其他电脑即使能够运行，也可能需要根据硬件、驱动、Windows 版本和显示设备重新调整参数。尤其是显卡、HDR、显示输出和 madVR 渲染设置，不保证跨设备完全一致。

## 快速开始

### 1. 解压到固定目录

恢复器严格要求根目录为：

    D:\Potplayer

压缩包应直接解压到 D:\，最终结构必须是：

    D:\Potplayer\Restore.cmd
    D:\Potplayer\Config\
    D:\Potplayer\LAVFilters\
    D:\Potplayer\madVR\
    D:\Potplayer\Potplayer\
    D:\Potplayer\xyVSFilterSubFilter\

不要多套一层目录。例如下面这种结构是错误的：

    D:\Potplayer\Potplayer\Restore.cmd

如果希望使用其他盘符或其他目录，需要同步修改恢复脚本中的固定路径检查以及配置文件中的绝对路径；默认版本不会自动迁移路径。

### 2. 运行恢复器

右键 D:\Potplayer\Restore.cmd，选择“以管理员身份运行”，或者直接双击让脚本自动请求 UAC 提权。

恢复完成后脚本会询问是否启动 PotPlayer：

- 输入 Y：启动 D:\Potplayer\Potplayer\PotPlayerMini64.exe。
- 输入 N、其他字符或直接回车：只完成恢复并退出。

## Restore.cmd 会做什么

恢复器按固定顺序执行以下工作：

1. 检查管理员权限，并在需要时通过 UAC 重新启动自身。
2. 确认脚本目录就是 D:\Potplayer。
3. 在任何系统修改前检查全部核心文件；缺少任意文件都会集中报告并终止。
4. 关闭正在运行的 PotPlayerMini64.exe 和 madHcCtrl.exe，并确认它们已经退出。
6. 按顺序静默注册 LAV Splitter、LAV Video、LAV Audio。
7. 导入并验证 Config\\LAV.reg。
8. 调用 madVR\\install.bat，随后验证 madVR x64 COM 注册指向本包中的 madVR64.ax；验证通过后再导入 Config\\madVR.reg。
9. 只注册 xyVSFilterSubFilter\\x64\\XySubFilter.dll，再导入 Config\\XySubFilter.reg。
10. 检查 settings.bin、PotPlayer 程序和 INI 文件，以及三组配置根键和代表性 COM 路径。
11. 写入恢复日志，并在成功时返回退出码 0。

脚本可以重复运行。每次运行都会重新注册组件、重新导入母版配置，并创建新的时间戳备份目录，不会覆盖之前的备份。

## 核心文件检查

恢复前会一次性检查以下材料：

    Potplayer\PotPlayerMini64.exe
    Potplayer\PotPlayerMini64.ini

    LAVFilters\LAVVideo.ax
    LAVFilters\LAVAudio.ax
    LAVFilters\LAVSplitter.ax

    madVR\install.bat
    madVR\madVR64.ax
    madVR\settings.bin

    xyVSFilterSubFilter\x64\XySubFilter.dll

    Config\LAV.reg
    Config\madVR.reg
    Config\XySubFilter.reg

其中 settings.bin 只做存在性检查，恢复器不会复制或修改它；它会随 madVR 目录一起保留。

## 恢复前自动备份

如果目标电脑当前已经存在以下注册表树，脚本会先导出到新的时间戳目录：

    HKCU\Software\LAV
    HKCU\Software\madshi\madVR
    HKCU\Software\Gabest\XySubFilter

备份目录示例：


注册表键不存在时会显示 SKIP；键存在但导出失败时会立即终止恢复，以避免在没有退路的情况下继续覆盖配置。

## 明确不会修改的内容

Restore.cmd 有意不处理以下项目：

- 不导入 PotPlayer-Override.reg。
- 不导入 PotPlayer 注册表，也不执行 PotPlayer 安装程序。
- 不恢复播放历史、USB 设备 ID 或其他个人使用记录。
- 不修改 Windows 文件关联、默认播放器、HDR、显卡驱动或显示设置。
- 不注册 xyVSFilterSubFilter\\x86。
- 不复制或改写 madVR settings.bin。

PotPlayer 的主要配置由旁边的 PotPlayerMini64.ini 提供。只要目录结构正确，启动 PotPlayer 时会读取该 INI 文件。

## 日志与故障排查

每次运行都会追加写入：

    D:\Potplayer\Restore.log

日志包含时间戳、阶段、组件、返回码以及最终状态。控制台和日志使用英文 ASCII 状态，便于在不同 Windows 代码页下阅读：

    [PASS]  成功
    [WARN]  警告，不一定阻止继续
    [SKIP]  按设计跳过，例如注册表键不存在
    [FAIL]  失败并终止

遇到失败时，先检查以下项目：

1. 路径是否严格为 D:\Potplayer，而不是其他盘符或多套一层目录。
2. 13 个核心文件是否完整，尤其是 madVR\\install.bat、madVR\\madVR64.ax 和 settings.bin。
3. 是否允许 UAC 提权，以及是否有其他 PotPlayer/madVR 进程无法关闭。
4. Restore.log 中最后一个 [FAIL] 阶段及其返回码。
5. 如果只想查看失败信息，不要删除日志；下一次运行会继续追加新的时间戳分隔段。

恢复失败时，脚本返回退出码 1。修复缺失文件、权限或正在运行的进程后，可以直接再次运行 Restore.cmd。

## 目录结构

    Potplayer/
    ├─ Restore.cmd                  # 一键恢复器
    ├─ Pack-LazyPack.cmd            # 双击打包入口
    ├─ Pack-LazyPack.ps1            # 打包实现
    ├─ Config/
    │  ├─ LAV.reg
    │  ├─ madVR.reg
    │  └─ XySubFilter.reg
    ├─ LAVFilters/
    ├─ madVR/
    ├─ Potplayer/
    │  ├─ PotPlayerMini64.exe
    │  └─ PotPlayerMini64.ini
    └─ xyVSFilterSubFilter/
       └─ x64/
          └─ XySubFilter.dll

运行后还可能出现以下本地文件或目录：

    Restore.log                    # 恢复日志，不打进发布包

## 自己重新打包

如果你已经在 D:\Potplayer 中调整好了当前配置，可以重新生成懒人包。

### 方式一：双击 CMD

运行：

    D:\Potplayer\Pack-LazyPack.cmd

脚本会检查核心文件，显示复制和压缩进度，并在完成后验证 ZIP 内容。默认输出：

    D:\PotPlayer-Lazy-Pack.zip

成功或失败后窗口都会停留并显示：

    Please press any key to exit...

### 方式二：PowerShell

在 PowerShell 中执行：

    Set-Location D:\Potplayer
    .\Pack-LazyPack.ps1

打包脚本默认：

- 源目录固定为 D:\Potplayer。
- 发布 ZIP 不包含仓库元数据、README、日志、备份和打包辅助脚本。
- 运行时 ZIP 只包含 Restore.cmd 以及组件和配置目录。

- 输出 ZIP 大小和 SHA-256，便于校验文件传输是否完整。

打包完成后，把 D:\PotPlayer-Lazy-Pack.zip 复制到目标电脑，解压到 D:\，再按上面的“快速开始”运行 Restore.cmd。

## 系统要求与注意事项

- 64 位 Windows。
- 系统自带 CMD、PowerShell、reg.exe 和 regsvr32.exe。
- 恢复 LAV、madVR 和 XySubFilter 通常需要管理员权限。
- 目标机器应允许 UAC 提权和组件注册。
- 本项目只保存和恢复个人播放器环境；请不要把包含个人隐私、播放历史或其他敏感数据的文件上传到公开仓库。
- 其他硬件上的表现不保证与 ThinkBook 16+ / Intel Arc B390 / UltraX7 358H 完全一致。

## 许可证与第三方组件

本仓库的脚本和配置仅代表个人使用方案。[PotPlayer](https://potplayer.tv/)、[LAV Filters](https://github.com/Nevcairiel/LAVFilters)、[madVR](https://www.videohelp.com/software/madVR)、[XySubFilter](https://github.com/pinterf/xy-VSFilter) 及其附带文件分别由各自作者或项目维护，版权和许可证归原作者所有。使用、分发或公开发布完整懒人包前，请自行确认相关组件的许可证、商标和再分发条款。

### Release ZIP 内容

运行时 Release 压缩包只包含 Restore.cmd、Config、LAVFilters、madVR、Potplayer 和 xyVSFilterSubFilter。
压缩包不会包含 .git、.gitignore、README.md、打包脚本、Check-Package.ps1、Backup-Before-Restore 或 Restore.log。
GitHub 仓库保留文档和打包辅助脚本；二进制 Release 压缩包只提供恢复所需的运行时文件。
