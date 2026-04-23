# Grader

通用的 shell 练习自动评分引擎。和具体课程内容解耦——课程升级时只需要改 `exercises/`，不需要动这里的代码。

## 用法

```bash
./grader/grade exercises/01-variables
```

或者从练习目录里：

```bash
cd exercises/01-variables && make grade
```

依赖：Python 3.8+ 和 PyYAML。

## 测试规约格式

每个 `tests/*.yml` 是一个测试用例。完整字段：

```yaml
name: 描述性的测试名（会显示在结果里）
points: 2
timeout: 10                    # 可选，默认 10 秒

# 可选：在 tmpdir 里跑，用来准备测试环境
setup: |
  mkdir photos
  touch photos/IMG_001.jpg

# 必需：被测命令。在 tmpdir 里执行。$EXERCISE_DIR 指向练习目录
run: bash "$EXERCISE_DIR/starter/rename.sh" strip-prefix IMG_ photos

expect:
  exit: 0                      # 期望的退出码

  # —— 对 stdout/stderr，三选一 ——
  stdout: "exact match"        # 完全匹配（trailing newline 不敏感）
  stdout_contains: "substring"
  stdout_matches: "regex"      # MULTILINE 模式

  stderr_contains: "Usage"

  # —— 文件系统状态 ——
  files:
    - path: photos/001.jpg
      exists: true
    - path: photos/IMG_001.jpg
      exists: false
    - path: log.txt
      contains: "processed"
    - path: out.csv
      matches: "^name,age$"
```

## 设计原则

- **每个测试在独立 tmpdir 里跑**，互不干扰。
- **`$EXERCISE_DIR` 环境变量**让测试能引用学习者的脚本，而 cwd 是干净的 tmpdir。
- **没有隐藏测试**——所有 `.yml` 都暴露给学习者，规约即文档。
- **不绑定 bash**——`run:` 是任意 shell 命令，理论上可以用来评分任何 CLI 工具。

## 添加一章新练习

```
exercises/
  NN-topic/
    README.md       # 题面（用中文，给学习者看）
    starter/        # 学习者起点（脚本里 exit 1 + 提示）
    solution/       # 参考答案（不强制，方便维护者验证）
    tests/
      01_basic.yml
      02_edge.yml
    Makefile        # 一行：grade: ; @../../grader/grade .
```
