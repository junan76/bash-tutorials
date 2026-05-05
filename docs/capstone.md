# Capstone 项目：`bkp`

本课程的所有章节练习不是孤立的小题——每一章你都会写 `bkp` 的一个模块，到第 8 章末尾你手里是一个真正能用的备份工具。

本页是 `bkp` 的**产品规约**：它做什么、内部怎么组织、每章承担哪一部分。后续每章的题面都会引用本页对应的章节，请把它当成贯穿整门课的"产品文档"。

## 这是什么

`bkp` 是一个**本地、增量、基于硬链接**的备份工具，灵感来自 [rsnapshot](https://rsnapshot.org/)：

- **本地** —— 不联网。源和目标都在同一台机器（或挂载的本地文件系统）
- **增量** —— 第二次开始，未变化的文件硬链接到上一个快照，几乎零额外磁盘
- **可校验** —— 每个快照配一份 sha256 manifest，能验证完整性
- **可并发** —— 一次 run 可以并行处理多个备份任务

预期规模：约 600–900 行 bash，分布在 `bkp` 主程序和 `lib/*.sh` 共 6–8 个模块里。

## 命令集

```bash
bkp init                              # 初始化 ~/.config/bkp/ 与快照根目录
bkp add <name> <src> [--exclude=PAT]  # 登记一个备份任务
bkp list                              # 列出所有任务及其上次运行状态
bkp run [name]                        # 跑一个任务（不带名字 = 跑全部）
bkp run --all --jobs=4                # 并发跑所有任务
bkp status [name]                     # 上次运行时间、快照数、占用磁盘
bkp diff <name> [snap1] [snap2]       # 两个快照之间变更了什么
bkp restore <name> <snap> <dest>      # 把某个快照解到指定位置
bkp prune <name>                      # 按保留策略清理老快照
bkp verify <name>                     # 用 manifest 校验快照完整性
```

## 存储模型

```
~/backups/
  <jobname>/
    snapshots/
      2026-05-04T10-00-00/      # 镜像源目录的快照
      2026-05-03T10-00-00/      # 大部分文件硬链接到 04 那份，节省空间
      latest -> 2026-05-04T10-00-00
    manifests/
      2026-05-04T10-00-00.txt   # path<TAB>size<TAB>sha256，每行一个文件
      2026-05-03T10-00-00.txt
    log                         # 历次 run 的日志
~/.config/bkp/bkp.conf          # 任务定义（见下）
```

快照目录就是源目录的一份完整镜像，`ls`/`cd` 就能直接浏览——这是硬链接快照的最大好处，跟 Time Machine 一样。

## 配置文件：配置即代码

`bkp.conf` 是一个会被 `source` 进主程序的 bash 脚本：

```bash
# ~/.config/bkp/bkp.conf

backup_root="$HOME/backups"
default_keep=14         # 保留最近 14 个快照

add_job notes \
  --src="$HOME/notes" \
  --exclude=".git" \
  --exclude="*.tmp"

add_job photos \
  --src="$HOME/Pictures" \
  --keep=30
```

为什么是 bash 文件而不是 YAML / INI：

- **零解析开销**——bash 自己读 bash，省一个 YAML parser 依赖
- **教学价值**——学生看到 `source` 的真正用途；`add_job` 是 ch4 写的函数，配置变成"DSL"
- **可表达性**——可以用 `$HOME`、命令替换、条件，写出"如果在公司机器就额外备份 X"这种逻辑

代价是配置文件可以执行任意代码。`bkp` 的目标用户是单人本地使用，这个权衡可以接受；规约里会明确"不要 source 来路不明的 conf 文件"。

## Manifest 格式

每个快照对应一份 manifest，每行一个文件：

```
photos/IMG_0001.jpg<TAB>4823344<TAB>e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
photos/IMG_0002.jpg<TAB>5102230<TAB>a7c8f9d0...
notes/README.md<TAB>1024<TAB>c8d9e0f1...
```

- `path` 相对快照根目录
- `size` 字节数
- `sha256` 文件内容的 SHA-256

`bkp diff` 用 `diff <(manifest A) <(manifest B)` 比较两份 manifest（这就是 ch6 进程替换的真实落点）。`bkp verify` 重新计算每个文件的 sha256 跟 manifest 比对，发现 bit rot 或意外改动。

## 快照机制

`bkp run` 的核心步骤：

1. 创建临时工作目录 `snapshots/.in-progress.<timestamp>/`（不在最终位置，方便 trap 清理）
2. 如果存在 `latest` 快照，`cp -al latest/. .in-progress.<timestamp>/` —— **硬链接**整棵树（瞬时、零额外空间）
3. 用 `rsync --link-dest=latest` 或手写 cp 把变化的文件实际拷贝过来（覆盖硬链接）
4. 计算 manifest 并写入 `manifests/<timestamp>.txt`
5. **原子地** `mv .in-progress.<timestamp> <timestamp>`，更新 `latest` 软链接
6. 失败时 trap 触发，删除 `.in-progress.*`

这是 rsnapshot 的标准招数，也是 ch8（健壮性）的高潮——**整个流程必须幂等**：跑两次的最终状态等于跑一次。

## 章节—模块分布

| Ch | 主题                              | bkp 增量                                                  | 引入的健壮性               |
| -- | --------------------------------- | --------------------------------------------------------- | -------------------------- |
| 1  | 变量、引用、参数展开              | `lib/path.sh`：路径规范化、`derive_snapshot_name`         | `set -e`、shebang 规范     |
| 2  | 条件、test、布尔逻辑              | `lib/check.sh`：preflight 检查（源、目标、锁）            | `set -u`                   |
| 3  | 循环、数组、模式匹配              | `lib/scan.sh` + `lib/filter.sh`：遍历 + include/exclude   | `nullglob`、glob 安全      |
| 4  | 函数、作用域、库复用              | `lib/log.sh` + `lib/lock.sh`：所有后续模块复用            | `trap`、`local`            |
| 5  | I/O 重定向、管道、文件描述符      | 主程序 I/O wiring + manifest 输出（含 sha256）            | `set -o pipefail`          |
| 6  | 进程、并发、进程替换              | `bkp run --all`、`bkp diff`                               | `wait -n`、退出码传播      |
| 7  | 调试与命令行参数解析              | `bkp` CLI dispatcher + `--debug` + `getopts`              | `bash -x`、`PS4`           |
| 8  | 综合：健壮性收尾与集成            | 整体审查、`bkp prune` / `verify` / `restore`、集成测试    | `shellcheck`、幂等、信号    |

**与原大纲的差异**：
- 原 ch7（子 shell 与进程替换）和原 ch8（模式匹配）作为独立章节被取消，分别融合进新 ch6 和新 ch3
- 健壮性从原 ch9 的"集中收尾"变成贯穿全程的渐进引入
- 新增 ch7（调试与 CLI 解析）—— 替代原 ch7 的位置

## 稳定接口约定（per-chapter 独立性）

每章的 grader 评测时，**上游模块用各章官方的 `solution/`**，而不是学生自己之前章节的产出。

举例：ch4 评测 `lib/log.sh` 时，集成测试里调用的 `lib/path.sh` 是 ch1 仓库提供的官方 solution，而不是学生 ch1 的 `starter/`。

好处：

- 章节可以**任意顺序**完成
- ch1 没做完不会卡住 ch4 的评分
- 学生能聚焦本章概念，不用 debug 自己之前章节的 bug

如果学生想验证"自己的 ch1 也能工作"，把自己的实现拷进 ch1 的 `solution/` 即可——grader 默认读那里。

## 故意不做的（scope 纪律）

- ❌ 网络传输（SSH、S3、rsync remote）—— 守在本地
- ❌ 加密（gpg）—— 不是 bash 教学的重点
- ❌ 块级 dedup —— 太复杂，跑题
- ❌ 数据库专项备份（pg_dump 等）—— 工具相关，不通用
- ❌ Windows 兼容 —— Linux/macOS only
- ❌ 自动调度（cron 集成）—— 是 OS 课的事

## 选做扩展（ch8 的"自选"加分项）

完成主线后，下面任选其一：

1. **加密** —— 用 `gpg` 把 manifest 与每个新文件加密
2. **远程目标** —— 用 `rsync over ssh` 把快照同步到远端
3. **简易 dedup** —— 跨任务的硬链接去重（同一文件出现在多个 src 时只存一份）
4. **Web UI** —— 用 `python3 -m http.server` 暴露快照浏览（给 ch5 视觉化做铺垫）

这些**不是**教学主线，是给学有余力的同学练手用。
