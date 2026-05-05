# Bash 脚本编程：交互式课程

为已有命令行基础的学习者设计的 bash 脚本编程课程。整门课围绕一个 capstone 项目 [`bkp`](capstone.md)（增量备份工具）展开——每章的练习都是构建它的一个模块。

## 学习路径

1. 先读 [`capstone.md`](capstone.md) 了解最终要做的工具长什么样
2. 阅读对应章节的讲义，建立概念框架
3. 进入 `exercises/NN-topic/` 完成本章对应的模块
4. 运行 `make grade` 自动评分，全部通过即完成本章

讲义（本站）侧重 **"为什么 / 怎么想"**；章末"实验"小节是 **"做什么 / 评分项"**。

## 章节列表

| #   | 主题                                                                  | bkp 增量                                  |
| --- | --------------------------------------------------------------------- | ----------------------------------------- |
| 1   | [变量、引用、参数展开](chapters/01-variables.md)                      | `lib/path.sh`                             |
| 2   | 条件、test、布尔逻辑                                                  | `lib/check.sh`                            |
| 3   | 循环、数组、模式匹配                                                  | `lib/scan.sh` + `lib/filter.sh`           |
| 4   | 函数、作用域、库复用                                                  | `lib/log.sh` + `lib/lock.sh`              |
| 5   | I/O 重定向、管道、文件描述符                                          | 主程序 I/O + manifest                     |
| 6   | 进程、并发、进程替换                                                  | `bkp run --all` + `bkp diff`              |
| 7   | 调试与命令行参数解析                                                  | `bkp` CLI dispatcher + `--debug`          |
| 8   | 综合：健壮性收尾与集成                                                | `prune`/`verify`/`restore` + 集成测试     |

健壮性（`set -euo pipefail`、`trap`、shellcheck、幂等）贯穿全程而不是单列一章——每章渐进引入一项。

## 环境准备

完整的环境搭建步骤见仓库根目录的 `README.md`。简而言之：

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

`pyyaml` 是评分器的唯一依赖；`mkdocs` 与 `mkdocs-material` 仅用于本讲义站点的本地预览，不影响评分。

## 本地预览本站

```bash
make docs-serve   # http://127.0.0.1:8000
```
