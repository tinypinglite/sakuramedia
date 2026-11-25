---
name: sakuramedia-acquire
description: 为 SakuraMedia 补片：查片、检查是否已入库、搜索下载候选、提交下载、跟进状态、触发导入，并在导入失败时查找元数据候选重试。用户说“查一下/补一下某部片”“为什么这个番号没入库”“下载完成后帮我导入”“导入失败帮我重试”时使用。所有写操作必须在用户明确确认后执行。
---

# SakuraMedia Acquire

目标是把一部影片从“本地没有”推进到“已入库可播放”，或明确告诉用户卡在哪一步。

## 连接信息

本 skill 要求宿主 Agent 为本次进程提供两个环境变量：

- `SAKURAMEDIA_BASE_URL`
- `SAKURAMEDIA_API_KEY`



不要把 API key 打印到回复里。

先验证连接：

```bash
python3 scripts/sakuramedia_acquire.py check
```

## 工作流

### 1. 查片并生成计划

```bash
python3 scripts/sakuramedia_acquire.py plan --query ABC-123
```

输出可能的状态：

- `ambiguous`：搜索到多部影片，让用户确认精确番号，不要猜。
- `already_available`：已经有可播放媒体，停止，不重复下载。
- `ready`：有影片信息和候选资源，展示前几个候选及 `selection_evaluation`。

计划会落盘并返回 `plan_id`。后续步骤复用这个 `plan_id`，不要重新搜索后偷偷换候选。

### 2. 让用户确认候选

展示：

- 番号、标题
- 候选标题、大小、做种数、索引器、下载器
- 策略是否放行，以及拒绝原因
- 是否已有同片下载任务

用户确认后再提交。用户明确说“你看着选，直接下”时，可以选择 `recommended_candidate_index`，但仍要报告实际选了哪个。

### 3. 提交下载

```bash
python3 scripts/sakuramedia_acquire.py submit \
  --plan-id <plan_id> --candidate-index 0 --confirm
```

返回 `download_task`。写操作必须有 `--confirm`。

### 4. 跟进状态

```bash
python3 scripts/sakuramedia_acquire.py status --movie-number ABC-123
```

不要在单次调用里无限等待。做有限轮询，然后返回当前阶段；用户之后可以继续问。

### 5. 导入

下载完成后，如果自动导入还没触发：

```bash
python3 scripts/sakuramedia_acquire.py import --task-id 123 --confirm
```

记录返回的 `task_run_id`。查看任务运行：

```bash
python3 scripts/sakuramedia_acquire.py task-run --task-run-id 456
```

### 6. 导入失败修复

列出失败项：

```bash
python3 scripts/sakuramedia_acquire.py failures --task-run-id 456
```

搜索元数据候选：

```bash
python3 scripts/sakuramedia_acquire.py metadata-candidates \
  --task-run-id 456 --item-id <item_id> --movie-number ABC-123
```

让用户确认候选后重试：

```bash
python3 scripts/sakuramedia_acquire.py retry \
  --task-run-id 456 --item-id <item_id> --candidate-id <candidate_id> --confirm
```

### 7. 验证结果

```bash
python3 scripts/sakuramedia_acquire.py verify --movie-number ABC-123
```

只有 `playable=true` 才能说“已入库可播放”。否则报告当前卡点。

## 硬规则

- 不删除下载任务、不删除文件、不拉黑资源、不改订阅、不做批量维护。
- 写操作必须显式 `--confirm`。
- 提交下载前必须确认候选；没有候选时不要假装能下载。
- 接口超时后先查状态，不盲目重复提交。
- 已有可播放媒体时停止，不重复下载。
- 导入失败时先给出失败项和候选，不要盲目重试同一个候选。
- 不把 API key、完整磁力链接或大段原始 JSON 原样贴给用户。
