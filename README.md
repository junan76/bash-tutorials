# Bash 脚本编程：交互式课程

为已经有命令行基础的学习者设计的 bash 脚本编程课程。每章末尾都会写一个真实可用的脚本，由本地评分系统自动评判。

## 快速开始

```bash
# 1. 创建并激活 venv（grader + 讲义站点共用一个）
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. 看第一章讲义与题面（启动本地 docs 站点）
make docs-serve   # 浏览器打开 http://127.0.0.1:8000
# 或直接读 markdown：
# less docs/chapters/01-variables.md

# 3. 写代码
$EDITOR exercises/01-variables/starter/lib/path.sh

# 4. 评分
cd exercises/01-variables && make grade
```

只想做练习不想看讲义？只装 `pyyaml` 也够（`pip install pyyaml`），但题面与要求都在 `docs/chapters/` 下，建议至少打开对应的 markdown 文件。

## 讲义站点（本地预览）

章节讲义用 [mkdocs](https://www.mkdocs.org/) 编译成 HTML，本地预览：

```bash
make docs-serve   # http://127.0.0.1:8000
make docs         # 编译静态 HTML 到 ./site
```

## 仓库结构

```
grader/        # 通用评分引擎，与课程内容解耦
exercises/     # 章节练习——只放代码
  01-variables/
    starter/   # 你要修改的代码
    solution/  # 参考答案
    tests/     # 公开的测试规约（YAML）
    Makefile   # make grade
docs/          # 所有学习者面向的文字内容（mkdocs 源文件）
  index.md
  chapters/    # 每章一个页面：讲义 + 题面 + 评分项
  appendix/
mkdocs.yml     # mkdocs 配置
requirements.txt
```

## 课程大纲

整门课围绕一个 capstone 项目 `bkp`（增量备份工具）展开——每章构建它的一个模块，到第 8 章末尾就是一个能用的工具。完整规约见 [`docs/capstone.md`](docs/capstone.md)。

| #   | 主题                              | bkp 增量                                              |
| --- | --------------------------------- | ----------------------------------------------------- |
| 1   | 变量、引用、参数展开              | `lib/path.sh`                                         |
| 2   | 条件、test、布尔逻辑              | `lib/check.sh`                                        |
| 3   | 循环、数组、模式匹配              | `lib/scan.sh` + `lib/filter.sh`                       |
| 4   | 函数、作用域、库复用              | `lib/log.sh` + `lib/lock.sh`                          |
| 5   | I/O 重定向、管道、文件描述符      | `lib/manifest.sh`（sha256 清单生成与验证）            |
| 6   | 进程、并发、进程替换              | `bkp run --all` + `bkp diff`                          |
| 7   | 调试与命令行参数解析              | `bkp` CLI dispatcher + `--debug`                      |
| 8   | 综合：健壮性收尾与集成            | 整体打磨 + `prune`/`verify`/`restore` + 集成测试       |

健壮性（`set -euo pipefail`、`trap`、shellcheck、幂等）不是单独一章，而是**贯穿全程**：ch1 引入 `set -e`、ch2 加 `set -u`、ch4 加 `trap`、ch5 加 `pipefail`、ch7 加 shellcheck，ch8 集大成。
