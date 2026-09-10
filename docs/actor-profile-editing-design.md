# 女优本地资料编辑设计

状态：第一版已实现

本文档记录后端支持“用户编辑女优资料”的第一版方案与当前实现。目标不是替换外部站点资料，而是在保留外部来源数据的前提下，增加用户自己的显示覆盖值。

本方案基于当前前后端代码整理，后端代码位于相邻的 `SakuraMediaBE` 仓库。

## 1. 已确认的产品范围

- 用户编辑的是当前系统已经存在的女优资料字段。
- 显示名称使用本地覆盖值，不修改外部来源名称。
- 头像通过上传本地图片设置，不接受远程图片 URL。
- 当前后端是单账号模型，因此本地编辑结果是全局生效的，不做按用户隔离。
- 不允许通过该功能修改女优身份、影片关联或订阅状态。

核心原则：

```text
外部来源值 = 用于识别、同步和保留来源事实
本地覆盖值 = 用于用户展示和用户自己的资料修正
最终展示值 = 有本地覆盖时使用本地覆盖，否则使用外部来源值
```

## 2. 字段定义

### 2.1 身份与系统字段

这些字段不是用户编辑内容：

| 字段 | 是否可编辑 | 原因 |
| --- | --- | --- |
| `id` | 否 | 数据库内部身份 |
| `javdb_id` | 否 | 外部来源身份和同步主键 |
| `javdb_type` | 否 | 外部来源类型，影响同步方式 |
| `movie_count` | 否 | 由影片关联计算 |
| `age` | 否 | 由 `birthday` 派生 |
| `is_subscribed` | 否 | 继续使用现有订阅接口 |
| `subscribed_at` | 否 | 订阅系统字段 |
| `subscribed_movies_synced_at` | 否 | 同步系统字段 |
| `subscribed_movies_full_synced_at` | 否 | 同步系统字段 |
| `field_owners` | 否 | 后端字段所有权内部状态 |
| `mutation_revision` | 否 | 并发控制版本号 |

`javdb_id` 和 `javdb_type` 不能开放编辑。修改这两个字段会让已有影片关联、外部同步和插件快照失去确定性，这已经不是“编辑资料”，而是“迁移或合并女优”。

### 2.2 外部来源字段

继续由来源插件维护，但不直接作为本地显示名称或头像的唯一来源：

| 字段 | 存储位置 | 对用户的含义 |
| --- | --- | --- |
| `name` | `actor.name` | 外部来源主名称，保留原值 |
| `alias_name` | `actor.alias_name` | 外部来源别名，保留原值 |
| `profile_image` | `actor.profile_image` | 外部来源头像，保留原值 |

这些字段仍然需要返回给管理界面，用于查看来源资料和排查同步问题，但用户编辑接口不接受 `name`、`alias_name`、`profile_image` 作为可写字段。

### 2.3 本地覆盖字段

在 `actor` 表增加两个明确的本地字段：

| 字段 | 类型 | 空值含义 | 用途 |
| --- | --- | --- | --- |
| `display_name_override` | `VARCHAR(255) NULL` | 没有本地名称覆盖 | 用户自定义显示名称 |
| `profile_image_override_id` | 可空外键，指向 `image.id` | 没有本地头像覆盖 | 用户上传的本地头像 |

不把这两个值塞进 `field_owners` JSON：它们是明确的一等数据，且头像是外键关系，单独建字段更容易查询、清理和保证一致性。

有效显示名称定义为：

```text
display_name_override 非空
    -> display_name_override
否则 alias_name 非空
    -> alias_name
否则
    -> name
```

有效头像定义为：

```text
profile_image_override_id 非空
    -> 本地覆盖头像
否则
    -> profile_image
```

第一版保留当前 `alias_name` 优先于 `name` 的显示行为，只新增本地名称覆盖层。

### 2.4 现有资料字段

以下字段可以通过用户编辑接口修改：

| 字段 | 类型与规则 | `null` 语义 |
| --- | --- | --- |
| `gender` | `0`、`1`、`2`；`0` 表示未知 | 不使用 `null`，未知使用 `0` |
| `birthday` | `YYYY-MM-DD` | 清空生日 |
| `height_cm` | 正整数，单位厘米 | 清空身高 |
| `bust_cm` | 正整数，单位厘米 | 清空胸围 |
| `waist_cm` | 正整数，单位厘米 | 清空腰围 |
| `hips_cm` | 正整数，单位厘米 | 清空臀围 |
| `cup` | 1 至 4 个英文字母，写入前转大写 | 清空罩杯 |
| `birthplace` | 去除首尾空白，最多 255 个字符 | 清空出生地 |
| `blood_type` | 去除首尾空白，最多 255 个字符 | 清空血型 |

本地名称规则：

- 去除首尾空白。
- 非空时最多 255 个字符。
- 空字符串按清除本地覆盖处理，最终恢复来源名称。
- 不做唯一性约束；两个女优可以有相同的本地显示名称。

现有资料字段的 `null` 只表示“用户明确清空该字段”，不会自动恢复来源值。原因是当前模型没有保存每个字段的来源快照，不能在本地清空后可靠地还原旧来源值。

## 3. 数据库与模型改动

### 3.1 `actor` 表

新增：

```text
display_name_override       VARCHAR(255) NULL
profile_image_override_id   INTEGER/BIGINT NULL REFERENCES image(id)
```

外键使用 `ON DELETE SET NULL`，避免删除图片记录时留下失效外键。

`mutation_revision` 在本地资料编辑接口中覆盖完整的本地女优资料状态，包括：

- 可编辑的现有资料字段；
- `display_name_override`；
- `profile_image_override_id`。

每次成功改变上述任一值，版本号加一。来源同步继续沿用现有来源写入路径和版本语义；它只更新来源字段，不会改变本地覆盖字段。

### 3.2 模型层约束

- `Actor` 增加本地覆盖字段和有效值访问方式。
- 现有 `avatar_url` 或资源序列化逻辑必须读取有效头像，而不是始终读取来源头像。
- 来源头像仍保存在现有的 `profile_image` 字段中，不能因为存在本地覆盖就丢弃来源头像。
- 本地覆盖头像使用独立路径，不能复用按 `javdb_id` 生成的来源图片路径。
- 直接修改受保护字段的模型保护逻辑要覆盖两个新增字段，写入统一经过服务层。

建议本地头像路径格式：

```text
actors/manual/{actor_id}-{uuid}.webp
```

路径中不使用用户原始文件名，也不使用 `javdb_id`，避免路径冲突和来源刷新覆盖本地文件。

## 4. 来源同步规则

这是本功能最重要的兼容点。新增接口本身并不能保证本地编辑生效，所有来源写入路径都必须遵守下面的规则。

### 4.1 名称同步

来源同步继续更新：

- `name`
- `alias_name`

来源同步永远不修改 `display_name_override`。

因此：

- 没有本地名称覆盖时，来源名称变化会反映到 `display_name`；
- 有本地名称覆盖时，来源名称仍然更新并保留，但 `display_name` 继续显示本地值；
- 用户清除本地名称覆盖后，立即按最新的 `alias_name` / `name` 计算显示名称。

当前代码中的 `ActorOwnershipGateway` 负责结构化字段的来源/手工所有权；名称和来源头像仍由导入路径直接写入原字段，但不会触及独立的本地覆盖字段。

### 4.2 头像同步

来源同步继续更新 `profile_image`，但永远不修改 `profile_image_override_id`。

因此：

- 没有本地头像覆盖时，展示来源头像；
- 有本地头像覆盖时，来源头像可以在后台继续刷新，但展示仍使用本地头像；
- 用户删除本地头像覆盖后，立即回退到当前最新的来源头像。

来源图片和本地图片必须是两个独立的 `Image` 记录。来源刷新不能覆盖本地文件，也不能因为清理旧来源图片而误删本地头像。

### 4.3 结构化字段同步

现有的 `field_owners` 和 `mutation_revision` 继续用于：

- `gender`
- `birthday`
- `height_cm`
- `bust_cm`
- `waist_cm`
- `hips_cm`
- `cup`
- `birthplace`
- `blood_type`

用户写入后，将对应字段标记为 `host:manual`。来源同步只能更新没有 `host:manual` 所有权的字段。

这里仍然采用“字段级所有权”，不能因为用户改了生日，就阻止来源更新身高或其他没有被用户改过的字段。

## 5. API 设计

### 5.1 修改资料

```http
PATCH /actors/{actor_id}
Content-Type: application/json
```

请求体使用稀疏更新：未出现的字段保持不变。

```json
{
  "expected_revision": 12,
  "display_name_override": "本地显示名",
  "birthday": "1998-04-12",
  "height_cm": 160,
  "bust_cm": null,
  "birthplace": "东京"
}
```

字段规则：

- `expected_revision` 必填，用于乐观并发控制。
- `display_name_override` 传 `null` 或空字符串时清除本地名称覆盖。
- 现有资料字段传 `null` 时清空该字段，并保留 `host:manual` 所有权。
- 请求中不接受 `id`、`javdb_id`、`javdb_type`、`name`、`alias_name`、`profile_image`、订阅字段或统计字段。
- 一次请求中多个字段必须在同一个事务中成功或失败，不能部分保存。
- 成功后返回完整的当前女优详情，包括新的 `mutation_revision`。

冲突时返回 `409 Conflict`，错误码建议为：

```text
actor_revision_conflict
```

冲突响应至少包含服务端当前版本，客户端应重新读取详情后让用户决定是否再次提交，不能静默覆盖后台的新值。

### 5.2 上传本地头像

```http
PUT /actors/{actor_id}/profile-image?expected_revision=12
Content-Type: multipart/form-data
```

表单字段：

```text
file: 图片文件
```

约束：

- 只接受 JPEG、PNG、WebP。
- 文件大小上限第一版定为 10 MiB。
- 必须实际解码图片，不能只相信客户端 MIME 类型或文件扩展名。
- 最大边长第一版限制为 4096 像素。
- 读取 EXIF 方向后再处理，避免手机照片方向错误。
- 服务端统一转成 WebP，最大边长压缩到 1024 像素，质量使用现有图片处理能力可接受的固定值。
- 使用随机文件名和独立本地路径，不保留用户原始文件名。

上传流程：

1. 写入临时文件并完成大小、格式、解码和尺寸检查。
2. 生成新的 `Image` 记录及本地最终文件。
3. 在数据库事务中更新 `profile_image_override_id` 并递增版本号。
4. 事务提交后再清理旧的本地覆盖图片；清理前重新检查图片是否仍被其他记录引用。
5. 任一步失败都不能留下可被展示的半成品记录或孤立文件。

上传成功返回完整的当前女优详情。

### 5.3 删除本地头像覆盖

```http
DELETE /actors/{actor_id}/profile-image?expected_revision=13
```

行为：

- 清空 `profile_image_override_id`；
- 递增版本号；
- 立即恢复展示来源头像；
- 事务提交后清理旧的本地图片记录和文件（仅在无其他引用时）。

该接口不是删除来源头像，来源头像始终保留并继续参与同步。

### 5.4 返回资源

现有资源继续保留来源字段，新增用于展示和编辑状态的字段：

```json
{
  "id": 1,
  "javdb_id": "abc123",
  "name": "来源主名称",
  "alias_name": "来源别名",
  "display_name": "本地显示名",
  "display_name_override": "本地显示名",
  "profile_image": {"medium": "/..."},
  "has_profile_image_override": true,
  "birthday": "1998-04-12",
  "age": 28,
  "height_cm": 160,
  "bust_cm": null,
  "waist_cm": 56,
  "hips_cm": 84,
  "cup": "C",
  "birthplace": "东京",
  "blood_type": "A",
  "mutation_revision": 13,
  "manual_fields": ["birthday", "height_cm"]
}
```

约定：

- `display_name` 是所有面向用户的列表、详情和影片关联展示应使用的有效名称。
- `profile_image` 是有效头像，优先本地覆盖头像。
- `display_name_override` 仅用于编辑界面判断是否设置了本地名称。
- `has_profile_image_override` 用于编辑界面展示“已使用本地头像”和决定是否显示恢复操作。
- `manual_fields` 只返回字段名，不把 `field_owners` 内部实现暴露给前端。
- `mutation_revision` 只在详情和写接口响应中必须返回；列表可以按现有性能需要决定是否返回。

现有 `ActorResource`、`ActorDetailResource` 以及影片详情中涉及女优的资源都必须使用同一套有效名称和有效头像规则。不能只修女优详情页，否则列表、影片详情和“热门女优”等页面会出现同一女优显示不一致。

## 6. 图片清理与失败处理

当前图片清理逻辑已经检查 `Movie` 和 `Actor.profile_image` 等引用。增加本地头像后必须把 `Actor.profile_image_override_id` 加入引用检查。

需要覆盖的异常场景：

- 图片解码失败；
- 图片超过大小或尺寸限制；
- 数据库写入失败；
- 文件落盘成功但数据库提交失败；
- 数据库提交成功但旧文件清理失败；
- 重复上传同一图片；
- 删除本地覆盖后来源头像为空。

清理失败不能回滚已经成功的用户编辑；应记录可重试的清理任务或日志。第一版不需要引入新的异步任务系统，可以先沿用现有图片清理服务的可重试方式。

## 7. 并发与权限

- 继续使用现有认证依赖。
- 当前系统是单账号，所有已认证客户端看到同一份本地覆盖结果。
- PATCH、上传和删除头像都必须进行版本检查。
- 两个客户端同时编辑时只允许一个请求成功，另一个返回 `409`。
- 不使用“后写覆盖前写”的静默策略，避免用户无意覆盖另一端的编辑。

## 8. 不在第一版范围内的内容

以下内容明确不随本次功能加入：

- 修改 `javdb_id`、`javdb_type`；
- 合并或拆分女优；
- 修改影片与女优关联；
- 在此接口修改订阅状态；
- 接受外部头像 URL；
- 用户自定义任意 JSON 字段；
- 描述、标签、社交账号等当前模型没有的新增资料字段；
- 每个登录用户拥有不同的显示名称或头像；
- 资料修改历史、撤销和审计后台；
- 立即恢复结构化字段的来源快照。

其中，显示名称和头像支持立即恢复来源值，是因为来源值仍然单独保存；结构化字段目前没有来源快照，因此 `null` 的语义只定义为“清空并继续由本地手工字段占有”。

## 9. 已落地结构

第一版已经按下面的边界落地：

1. 数据库迁移、`Actor` 模型字段和有效值计算。
2. 名称、头像覆盖与来源同步解耦；来源仍更新原字段，不触碰本地覆盖字段。
3. 图片引用检查和清理同时覆盖来源头像与本地头像。
4. 资料 PATCH、头像上传、头像恢复接口统一使用 `mutation_revision` 做乐观并发控制。
5. 所有女优资源投影、影片详情和热门女优响应统一返回有效显示名称与有效头像。
6. 前端详情页接入桌面编辑入口，移动端复用同一套自适应底部抽屉表单。

## 10. 验收清单

以下是功能边界清单；已完成自动化验证的项目标记为 `[x]`，未在本轮单独覆盖的边界保留为待补充项。

### 数据与接口

- [x] PATCH 只修改请求中出现的字段。
- [x] 版本冲突返回 `409`，且不会产生部分更新。
- [x] 认证依赖仍由现有演员路由统一提供。
- [ ] 旧数据迁移后的空覆盖字段、全部非法输入组合需要继续扩展测试。

### 来源同步

- [x] 来源名称变化不会覆盖本地显示名称。
- [x] 清除本地名称后按当前来源名称回退。
- [x] 删除本地头像后恢复来源头像。
- [ ] 来源头像覆盖期间的来源刷新、全部结构化字段同步组合需要继续扩展测试。

### 图片

- [x] 有效 PNG 可上传，并统一生成独立的本地 WebP 头像。
- [x] 上传替换和删除后旧本地图片不会继续展示，且无引用记录会被清理。
- [ ] JPEG/WebP、损坏图片、尺寸/大小超限和数据库失败场景需要继续扩展测试。

### 展示一致性

- [x] 女优列表和详情使用 `display_name` 与有效头像。
- [x] 影片详情中的女优卡片使用 `display_name` 与有效头像。
- [x] 热门女优响应使用 `display_name` 与有效头像。
- [ ] 其他推荐入口的全量展示回归仍需在真实数据环境补验。

本轮自动化验证：后端受影响测试 40 个通过，后端 Ruff 通过；前端演员 API、桌面/移动详情及受影响展示测试 26 个通过，Flutter analyze 无 error。编辑弹层已用 1280×1000 桌面和 390×844 移动尺寸实际渲染检查。

## 11. 当前代码定位

维护或继续扩展时优先检查这些位置：

- 后端模型：`SakuraMediaBE/src/model/catalog/actors.py`
- 后端资源 schema：`SakuraMediaBE/src/schema/catalog/actors.py`
- 后端路由：`SakuraMediaBE/src/api/routers/catalog/actors.py`
- 后端服务：`SakuraMediaBE/src/service/catalog/actor_service.py`
- 后端迁移：`SakuraMediaBE/src/start/migrations/versions/20260910_02_add_actor_local_profile.py`
- 字段所有权：`SakuraMediaBE/src/service/catalog/actor_ownership_gateway.py`
- 来源导入：`SakuraMediaBE/src/service/catalog/catalog_import_service.py`
- 图片模型与清理：`SakuraMediaBE/src/model/catalog/images.py`、`SakuraMediaBE/src/service/catalog/image_cleanup_service.py`
- 前端女优 API：`lib/features/actors/data/api/actors_api.dart`
- 前端女优 DTO：`lib/features/actors/data/dto/actor_list_item_dto.dart`、`lib/features/actors/data/dto/actor_detail_dto.dart`
- 前端编辑表单：`lib/features/actors/presentation/widgets/actor_profile_editor.dart`

字段和接口行为以后端 schema、相邻测试及本文的字段定义为准；如果代码发生变化，应同步更新本文的边界说明。
