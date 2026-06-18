---
name: markdown-to-confluence
description: "将 Markdown 转换、校验并发布为 Confluence 页面时使用，适配 confluence-mark/mark 工具流程。"
---

# Markdown To Confluence

## When to use

当需要把 Markdown 内容转换、校验并发布为 Confluence 页面，或读取、编辑、校验、发布 Confluence 草稿时使用本技能。它指导代理按 confluence-mark/mark 工具约定完成安全、可复核、可回滚的页面更新。

适用于：

- 用户提供 Markdown，要求创建或更新 Confluence 页面。
- 用户要求把本地文档、说明、Runbook、设计稿发布到 Confluence。
- 用户要求读取现有 Confluence 页面后，用 Markdown 修改内容。
- 用户要求先生成 Confluence 草稿，确认后再发布。
- 需要在发布前检查转换后的 Confluence Storage Format、预览或 diff 是否符合预期。
- 需要处理图片、附件、内部链接、代码块、表格、宏、目录等 Confluence 发布细节。

不适用于：

- 只需要润色 Markdown，不涉及 Confluence。
- 用户只要普通 HTML、PDF、Notion 或 GitHub Wiki 输出。
- 没有目标 space、parent page、page title、page id 或可推断的页面位置，且不能安全创建草稿。
- 涉及敏感权限变更、删除页面、移动页面、归档页面、批量替换大量页面时，应先让用户确认范围和影响。

开始前尽量收集：

- Markdown 内容或文件路径。
- 目标 Confluence space key。
- 页面 title。
- parent page id 或已有 page id。
- 操作类型：create、update、draft、publish。
- 是否允许覆盖现有页面。
- 是否需要保留现有页面的某些区域。
- 附件、图片路径、链接改写规则。
- 是否需要保留或生成目录、页面属性、标签、宏。

如果关键信息缺失，先根据上下文推断。无法安全推断时，只询问完成当前动作所需的最少问题。

## Procedure

1. 明确目标和安全边界
   - 判断目标是新建页面、更新页面、生成草稿、发布已有草稿，还是只做转换和校验。
   - 对更新操作，优先通过 page id 定位页面。没有 page id 时，用 space key 和 title 搜索并确认唯一页面。
   - 对新建操作，必须确认 space key 和 parent page id，避免创建到错误位置。
   - 明确是否允许直接发布。默认先创建草稿或预览，除非用户明确要求直接发布。
   - 记录计划修改范围，例如整页替换、替换某个章节、插入某段内容、只更新附件或链接。

2. 读取并锁定现有状态
   - 更新页面前先读取原页面内容、metadata、version、ancestors、title、space、attachments 以及必要的 labels。
   - 记录当前 version，用于并发控制，避免覆盖他人修改。
   - 如果只替换某个章节，先定位章节边界。优先使用稳定标记、标题层级或明确锚点，不要重写整页。
   - 若页面包含宏、附件、特殊布局、页面属性、手工维护区域、include excerpt、评论锚点或未知 Storage XML，保留未要求修改的内容。
   - 如果读取到的页面和用户描述不一致，暂停并说明差异，等待确认。

3. 准备 Markdown
   - 保持标题层级合理。通常页面 title 不需要再作为正文 H1 重复出现，除非用户明确要求。
   - 对局部更新，保证片段的标题层级能嵌入目标页面，不破坏后续章节结构。
   - 将相对链接、图片路径、附件引用转换为 Confluence 可访问形式。
   - 检查表格、代码块、任务列表、提示块、锚点链接、目录、脚注和列表嵌套。
   - 避免使用目标工具不支持的 Markdown 扩展。必要时改写为兼容语法。
   - 对需要保留原样的代码、配置、日志、命令输出，不做智能改写，只做转义和格式保护。

4. 处理链接、图片和附件
   - 本地图片必须先上传为附件，或转换为用户确认可访问的绝对 URL。不要把本地文件路径发布为图片链接。
   - 附件上传前检查同名文件是否已存在。可能覆盖时先确认，或使用带版本、日期、哈希的唯一文件名。
   - 内部 Confluence 链接优先使用页面链接、page id 或工具支持的内部链接语法，避免易失效的裸 URL。
   - 外部链接保持完整 URL，并检查明显的断链、空链接、相对路径和未解析变量。
   - 对 Mermaid、PlantUML、draw.io 等图形内容，只有在目标 Confluence 支持对应宏时才保留为宏。否则转换为图片附件或代码块，并告知用户。

5. 转换为 Confluence 内容
   - 使用 confluence-mark/mark 工具执行 Markdown 到 Confluence 内容的转换。
   - 保留 fenced code block 和语言名。
   - 表格必须检查列数一致性，避免转换后错位。复杂合并单元格应改为普通表格或列表。
   - 对 Confluence macro 使用工具支持的语法。不要手写不确定的 Storage XML。
   - 对 callout、提示块、目录、任务列表等不完全兼容语法，转换为 Confluence 支持的 info、note、warning、toc、task list 等形式，或降级为普通 Markdown/引用块。
   - 如果转换失败，不要直接发布手写 Storage Format。先缩小失败片段，改写 Markdown，再重新转换。

6. 生成草稿或应用更新
   - 优先生成草稿或预览结果，除非用户明确要求直接发布。
   - 更新页面时必须带上正确 version 或工具要求的并发控制字段。
   - 对局部更新，只替换目标区域，减少无关 diff。
   - 对整页更新，确认是否保留原页面 labels、attachments、ancestors、restrictions、页面属性和未修改宏。
   - 创建页面时，确认 title 在目标 parent 下不冲突。若存在同名页面，列出候选并请求选择，不要猜测。

7. 发布前校验
   - 校验转换输出可被 Confluence 接受。
   - 检查标题、层级、链接、图片、附件、表格、代码块、宏、目录和锚点。
   - 检查是否误删原页面内容，尤其是未修改区域、评论锚点、宏、页面属性和附件引用。
   - 如果工具支持 diff 或 preview，展示关键 diff 给用户确认。重点说明新增、删除、替换、附件变化和宏变化。
   - 如果只有草稿，说明草稿状态、预览地址或后续发布步骤。
   - 如果校验发现警告，不要把警告当作成功发布。说明风险并请求用户决定修复、降级或继续。

8. 发布
   - 用户要求或确认后再发布。
   - 发布前如发现 version 冲突，重新读取页面，合并最新改动后再提交。
   - 发布时使用明确的 edit message，例如 `Update page from Markdown source`，必要时包含来源文件或变更摘要。
   - 发布成功后返回 page title、space、page id、URL、version、操作类型，以及是否有未处理事项。
   - 如发布失败，返回失败阶段、错误摘要、已完成的安全动作、是否创建了草稿或附件，以及建议的下一步。

## Decision rules

- 默认安全策略：先 draft 或 preview，后 publish。
- 已有页面更新：必须先 read，再 prepare，再 convert，再 diff 或 preview，再 update。
- 新建页面：必须确认 space 和 parent，避免创建到错误位置。
- 直接发布：只有在用户明确要求且目标页面定位清晰、转换校验通过时执行。
- 局部更新优先：用户只要求改某一节时，不要整页重写。
- 页面存在同名冲突：不要猜测，列出候选并请求选择。
- 批量页面：先处理一个样例页面并确认格式，再批量执行。
- 工具转换失败：不要直接发布手写 Storage Format。先隔离失败片段，改写 Markdown，再重新转换。
- 并发版本冲突：重新读取页面，合并用户修改后再提交。
- 附件冲突：不要静默覆盖同名附件，除非用户明确允许。
- 不支持的宏或 Markdown 扩展：优先转换为受支持宏，其次转换为图片或普通文本，并在结果中说明降级。
- 权限、删除、移动、归档、批量替换等高影响操作：必须先让用户确认范围和影响。

## Markdown 转换注意事项

- 标题：正文从 H2 或合适层级开始，避免重复页面标题。
- 代码块：保留 fenced code block 和语言名，不要改写代码内容。
- 表格：避免复杂合并单元格。必要时改为普通表格或列表。
- 链接：内部 Confluence 链接优先使用页面链接，外部链接保持完整 URL。
- 图片：本地图片需要上传为附件后再引用。
- 附件：确认文件名唯一，避免意外覆盖同名附件。
- Mermaid、PlantUML、draw.io：只有在目标 Confluence 支持对应宏时才保留，否则转换为图片或代码块。
- HTML：避免混用原始 HTML，除非工具和目标站点明确支持。
- Callout：将不兼容的提示块转换为 Confluence info、note、warning 等支持的 macro，或改为普通引用块。
- 锚点：检查标题自动生成锚点和手写锚点是否仍可跳转。
- 目录：如果页面需要目录，使用工具支持的 toc macro 或目标站点支持的等价形式。

## 输出格式

完成后向用户返回：

- 操作结果：converted、drafted、created、updated、published 或 failed。
- 页面：title、space、page id、URL。
- version：更新后的版本号，若只是草稿则说明草稿状态。
- 修改摘要：新增、删除、替换、附件上传、链接改写、宏处理。
- 校验摘要：链接、图片、表格、代码块、宏、目录是否通过。
- 风险或待办：无法转换的语法、缺失附件、需要人工确认的页面冲突、转换降级、未发布草稿。

## 最小执行模板

1. 读取或确认目标页面。
2. 记录页面 version 和修改范围。
3. 清理 Markdown，并处理链接、图片、附件。
4. 用 mark 工具转换为 Confluence 内容。
5. 创建草稿或更新草稿。
6. 校验 preview 或 diff。
7. 用户确认后发布。
8. 返回 URL、version、修改摘要和校验结果。

## 禁忌

- 不要在未读取现有页面的情况下覆盖更新。
- 不要在未确认目标 space 或 parent 的情况下新建页面。
- 不要把本地文件路径当成可访问图片链接发布。
- 不要静默覆盖同名附件。
- 不要忽略 Confluence version 冲突。
- 不要把转换警告当作成功发布。
- 不要在用户只要求草稿时直接发布。
- 不要手写不确定的 Storage XML 并直接发布。
- 不要在用户只要求局部修改时重写整页。
- 不要对高影响操作进行未确认的批量执行。
