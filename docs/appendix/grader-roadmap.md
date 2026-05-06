# Grader 开发路线

`grader/grade` 当前刻意保持最小——8 章主线全部用现有断言词汇表实现完毕。本文记录已经覆盖的能力、用过的断言模式，以及未来如果要扩展应该怎么走。

## 当前能力（2026-05-06）

- 退出码（`exit:`）
- stdout / stderr —— 精确、包含、正则
- 文件系统 —— 存在性、内容包含、内容正则
- `setup:` 钩子和 `timeout`
- 测试在干净 tmpdir 里运行；`$EXERCISE_DIR` 指向练习目录

**稳定承诺**：以上语义不会变更，未来只做加法。

## 主线 8 章对断言词汇表的实际用法

| 章 | 用到的断言模式（按使用强度） |
| --- | --- |
| 1 | `exit` + `stdout` 精确，纯函数足够 |
| 2 | `exit` + `stderr_contains` 测错误信息 |
| 3 | `setup:` 准备 fixture 树；`stdout` 测排序输出 |
| 4 | 多个 source 串起来；`stderr` 验证日志级别过滤 |
| 5 | `setup:` 造文件；`files:` 验证 manifest 内容；`stdout_matches` 测 sha256 hex |
| 6 | `setup:` 起后台进程；`timeout` 验证并发收紧时长 |
| 7 | `stderr_matches` 测 PS4 trace 格式；同一 spec 里多个子断言 |
| 8 | 跨章节 `source` 上游 `solution/`，验证集成 |

未出现"必须加新断言"的 case——证明词汇表设计得算够紧凑。

## 跨章节的改进项（nice-to-have）

- **stdout diff** —— 不一致时输出 unified diff，比当前 repr 双行更友好
- **`weight:` 字段** —— 让单个测试能拆出子分数（目前每个测试只能整数 points）
- **JSON 输出模式** —— 方便对接 CI / 进度看板
- **`-v` 模式** —— 打印每个测试的完整 stdout/stderr，调试用
- **`min_duration` / `max_duration`** —— 证明并发性（4 个 1 秒任务必须 ≤ 2 秒完成）。ch6 没用上是因为 timeout 反向证明已经够；如果未来加更深的并发题再考虑
- **一等的 `stdin:` 字段** —— 目前都在 `run:` 里用 shell 重定向，加这个字段更可读

## 已观望但**没必要做**的扩展

- **shellcheck 集成（`lint:` 字段）** —— 学生本地跑 `shellcheck solution/lib/*.sh` 就够了，没必要塞进每个 test spec。如果未来加 CI job 集中跑一次更合适
- **幂等性检查（`idempotent: true`）** —— ch8 的幂等测试用"显式跑两次比较 stdout"已经实现了，没必要让 grader 隐式做这事
- **禁用命令检查（`forbid: [sed, awk]`）** —— 没遇到真实需求。如果有就说明题面没说清楚，应该改题面而不是加机制

## 不会做的事

- **网络依赖**。grader 必须完全离线
- **章节专属逻辑**。新断言放进通用词汇表，不写 `if chapter == 8` 这种东西
- **测试框架抽象**。`grader/grade` 应该一坐能读完——一旦套上 unittest/pytest/类的层级，初衷就毁了

## 可视化模块（独立工作流）

Ch 5 和 Ch 7 计划配交互式可视化（管道/fd 数据流、进程树）。这部分是纯前端项目，预计单独建仓，不进 grader 的路线图。
