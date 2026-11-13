# 部署公告说明

这个目录下有三个文件：

| 文件 | 作用 |
| --- | --- |
| `announcements.json` | 真正生效的公告源，后端按需拉取并缓存 30 分钟 |
| `announcements.json.example` | 写法样例，没有任何代码会读取它，只供复制参考 |
| `announcements.README.md` | 本说明 |

## 一条公告怎么到用户面前

1. 改 `announcements.json` 并 push 到 `main`。
2. `.github/workflows/docs.yml` 监听 `wiki/**`，自动构建并部署 GitHub Pages。
3. 线上地址：`https://tinypinglite.github.io/sakuramedia/announcements.json`。
4. 后端收到 `/status/announcements` 请求时按需拉取，缓存 30 分钟，失败 5 分钟后重试。
5. 前端登录后加载一次，之后每 30 分钟刷新一次。

所以从 push 到用户看到，最坏大约 1 小时。这不是实时通道，分钟级的紧急通知别指望它。

## 怎么加一条

复制 `announcements.json.example` 里最接近的一条，粘进 `announcements.json` 的 `announcements` 数组，然后改 `id`、文案、时间。

### 顶层字段

| 字段 | 必填 | 说明 | 写错的后果 |
| --- | --- | --- | --- |
| `schema_version` | 是 | 固定填 `1` | 不等于 1 时整份 feed 被拒，后端继续用旧缓存，5 分钟后重试 |
| `announcements` | 是 | 公告数组，可以是空数组 `[]` | 不是数组时整份 feed 被拒 |
| `updated_at` | 否 | 只写给人看，后端和前端都不读 | 没有影响 |

### 条目字段

| 字段 | 必填 | 默认 | 作用 | 写错的后果 |
| --- | --- | --- | --- | --- |
| `id` | 是 | — | 唯一标识；`critical` 靠它记录"已确认" | 空或重复时该条被跳过（重复保留先出现的） |
| `level` | 是 | — | `info` / `warning` / `critical`，只决定展示方式 | 非法值该条被跳过 |
| `title_i18n` | 是 | — | 标题，`{"zh-CN": "...", "en": "..."}` | 缺任一语言或为空，该条被跳过 |
| `body_i18n` | 是 | — | 正文，格式同上 | 同上 |
| `published_at` | 是 | — | ISO 8601 时间；到点才显示，可填未来做定时 | 格式非法该条被跳过 |
| `expires_at` | 否 | `null` | 到点自动消失；不填就一直显示 | 不晚于 `published_at` 时该条被跳过 |
| `component` | 否 | `all` | 用哪一端的版本去比对版本区间，见下节 | 非法值该条被跳过 |
| `affected_from_version` | 否 | `null` | 版本区间下界，**含** | 解析失败视为不设下界（会多显示） |
| `resolved_in_version` | 否 | `null` | 版本区间上界，**不含**，即修好问题的版本 | 解析失败视为不设上界（会多显示） |
| `link` | 否 | `null` | 详情里的按钮，用系统浏览器打开 | 不是 `https://` 该条被跳过 |

`title_i18n` / `body_i18n` 可以带别的语言，但前端只会二选一：中文环境取 `zh-CN`，其他取 `en`。

### `component` 到底管什么

它只做一件事：**选哪一端的版本号，去和 `affected_from_version` / `resolved_in_version` 比较**。

- `frontend`：用 App 自身的版本（package_info 里的版本号，比如 `0.16.0`）。
- `backend`：用服务器 `/status` 返回的后端版本。
- `all`：不比较版本，无条件显示；因此不允许带两个版本字段，带了一整条会被后端丢弃。

三个容易误解的点：

1. **它不改变后端返回什么。** 后端只按时间过滤，`component` 和版本区间都是客户端拿到数据后自己筛的。所以它既不是权限，也不区分平台。
2. **两个版本字段都可以不写。** 不写就表示对该端的所有版本显示，但保留了以后补上边界的能力。
3. **版本号格式有要求。** 只认 `X.Y.Z` 或 `X.Y.Z-beta.N`，可带 `v` 前缀；`0.15`、`1.0.0.0`、`0.16.0-rc.1` 都解析不了。解析失败的方向一律是"多显示"：当前版本解析不了就全部显示，边界解析不了就当这个边界不存在。

同一份公告只改 `component` 的对照（`affected_from_version: 0.10.0`，`resolved_in_version: 0.15.0`）：

| component | 后端 0.14.0，App 0.14.0 | 后端 0.15.0，App 0.14.0 | 后端 0.15.0，App 0.16.0 |
| --- | --- | --- | --- |
| `all` | 显示 | 显示 | 显示 |
| `backend` | 显示 | 不显示 | 不显示 |
| `frontend` | 显示 | 显示 | 不显示 |

## 示例里的 5 条分别演示什么

| id | level / component | 版本范围 | 用户看到什么 |
| --- | --- | --- | --- |
| `example-2026-11-14-welcome` | info / all | — | 左下角版本号弹层里的公告区，带未读圆点 |
| `example-2026-11-14-frontend-warning` | warning / frontend | 0.10.0 ≤ v < 0.16.0 | 同上，但只对旧客户端显示 |
| `example-2026-11-14-backend-critical` | critical / backend | 0.10.0 ≤ v < 0.15.0 | 登录后强制弹窗，必须点"知道了" |
| `example-2026-12-01-scheduled` | info / all | — | 12-01 08:00Z 自动出现，12-02 08:00Z 自动消失 |
| `example-backend-all-versions` | warning / backend | 不设边界 | 对该端所有版本显示 |

## 三种等级的实际差别

- `critical`：登录后阻塞式弹窗，点遮罩、按返回都关不掉，只能点"知道了"。同一台设备同一个 `id` 只弹一次；想重新提醒必须换 `id`。
- `warning` / `info`：只出现在左下角版本号弹层的"公告"区块，未读时版本号旁有个小圆点；打开弹层即全部标记已读（按时间戳，不是逐条）。

## 定时和过期

`published_at` 写未来时间就是定时公告，`expires_at` 到点自动下线，两者都不需要二次推送。但 feed 必须在预定时间之前已经被后端拉取过，所以定时公告要提前 30~60 分钟推送。

## 三个最容易踩的坑

1. 版本号解析不出来时前端宁可显示也不隐藏——版本边界写错不会"少弹"，会"多弹"。
2. 删掉一条公告后，已缓存的后端实例最多还会显示 30 分钟。
3. 用户确认过的 `critical` 不会因为删除重建而重新弹，必须换新 `id`。

## 提交前本地校验

在 `SakuraMediaBE` 目录执行，用真实 schema 校验，能提前发现会被后端静默丢弃的条目：

```bash
cd ~/Documents/Code/MyCode/SakuraMediaBE
FEED=../sakuramedia/wiki/public/announcements.json uv run python - <<'PY'
import json, os
from src.schema.system.announcements import StatusAnnouncementResource
feed = json.load(open(os.environ["FEED"]))
print("schema_version", feed["schema_version"])
for raw in feed["announcements"]:
    item = StatusAnnouncementResource.model_validate(raw)
    print("OK", item.id, item.level.value, item.component.value)
PY
```

任何一条不合法都会直接抛异常。日志里那句 `No /data directory found` 是后端本地运行的正常提示，可以忽略。

## 其他开关

后端支持两个环境变量：

- `SAKURAMEDIA_ANNOUNCEMENTS_ENABLED=false`：关闭公告拉取。
- `SAKURAMEDIA_ANNOUNCEMENTS_URL`：换成自己的 feed 地址。

## 注意

`public/` 下的文件会被原样发布到站点根目录，所以 `announcements.json.example` 和本说明也会公开可访问（例如 `https://tinypinglite.github.io/sakuramedia/announcements.README.md`）。它们不参与任何逻辑，介意的话可以挪出 `public/`。
