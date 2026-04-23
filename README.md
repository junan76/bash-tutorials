# Bash 脚本编程：交互式课程

为已经有命令行基础的学习者设计的 bash 脚本编程课程。每章末尾都会写一个真实可用的脚本，由本地评分系统自动评判。

## 快速开始

```bash
# 依赖
pip install pyyaml

# 看第一章题面
cat exercises/01-variables/README.md

# 写代码
$EDITOR exercises/01-variables/starter/rename.sh

# 评分
cd exercises/01-variables && make grade
```

## 仓库结构

```
grader/        # 通用评分引擎，与课程内容解耦
exercises/     # 章节练习
  01-variables/
    README.md  # 题面
    starter/   # 你要修改的代码
    solution/  # 参考答案
    tests/     # 公开的测试规约（YAML）
```

## 课程大纲

| # | 主题 | 章末交付物 |
|---|------|------------|
| 1 | 变量、引用、参数展开 | 批量文件重命名工具 |
| 2 | 条件判断 | 输入校验器 |
| 3 | 循环和数组 | 词频统计器 |
| 4 | 函数与作用域 | 可复用的工具库 |
| 5 | I/O 重定向、管道、文件描述符 | 日志分流器 |
| 6 | 进程与退出码 | 并行任务执行器 |
| 7 | 子 shell 与进程替换 | 命令输出对比工具 |
| 8 | 模式匹配 | 日志解析器 |
| 9 | 健壮的脚本（trap、getopts、shellcheck） | 幂等的备份脚本 |
| 10 | 综合项目 | 自选 |
