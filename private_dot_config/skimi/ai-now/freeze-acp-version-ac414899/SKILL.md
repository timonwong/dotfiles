---
name: freeze-acp-version
description: "需要冻结 ACP X.Y 版本并启动下一轮迭代时，按仓库规则创建 release 分支、空 commit 和下一版本 tag。"
---

# ACP 版本冻结流程

当需要冻结 ACP `X.Y` 并启动 `X.(Y+1)` 迭代时使用本流程。它从实际默认分支创建 `release-X.Y`，先发布下一迭代 tag，再创建并推送 iteration-start 空提交；对 `code.alauda.io` 还会触发并验证 release 分支的 Tekton Pipelines as Code 构建。

除非用户明确要求执行远端变更，或仓库规则已明确授权，先给出执行方案和待确认项，不要自行推送、创建远端 tag 或发表评论。

## 1. 先确认上下文和安全前提

确认以下信息后再执行：

- 待冻结版本 `X.Y`，以及按小版本递增得到的下一版本 `X.(Y+1)`。不得改动主版本或版本格式。
- 目标远端及名称，通常为 `origin`，但必须以仓库配置为准。
- 实际默认分支。只能在确认项目使用后选择 `main` 或 `master`，不能仅因分支存在而猜测。
- 工作区和暂存区是否干净。
- 远端 URL 的主机名，以及是否存在签名、分支保护、PR、审批、CI 或其他发布限制。
- 是否已明确要求推送。未明确时，只准备本地方案并请求确认。

建议检查：

```bash
git remote -v
git branch --list main master
git status --short
git remote get-url origin
```

若工作区或暂存区有改动，停止并让用户决定提交、暂存、丢弃或保留。不得把无关改动带入冻结分支或 iteration-start 提交。

从远端 URL 提取主机名以选择 tag 规则：

- `gitlab-ce.alauda.cn`：下一迭代 tag 为 `vX.(Y+1)`，例如 `v4.4`。
- `code.alauda.io`：下一迭代 tag 为 `vX.(Y+1).0-beta.0`，例如 `v4.4.0-beta.0`。
- 其他主机：不要臆测格式，先查仓库发布规则或请求确认。

以下命令以 `main` 为例。若确认默认分支为 `master`，将所有 `main` 替换为 `master`。

## 2. 从最新默认分支创建冻结分支

先同步默认分支，再从其当前 HEAD 创建名称严格为 `release-X.Y` 的分支：

```bash
git switch main
git pull --ff-only origin main
git switch -c release-X.Y
git log -1 --oneline release-X.Y
git branch --show-current
```

例如冻结 ACP 4.3：

```bash
git switch -c release-4.3
```

不要为了触发流水线而向 `release-X.Y` 增加额外提交。新建分支仅指向既有提交时，GitLab 的 branch-created push 可能 `commit_count=0`，通常不会自动创建 release 分支 PipelineRun。

## 3. 在默认分支创建并先推送下一迭代 tag

切回并同步默认分支。tag 必须指向此时默认分支的当前提交，且必须在 iteration-start 空提交之前创建和推送。这样由空提交触发的流水线能够取得 tag。

`gitlab-ce.alauda.cn`：

```bash
git switch main
git pull --ff-only origin main
git tag -a vX.Y -m "vX.Y iteration start"
git push origin vX.Y
```

`code.alauda.io`：

```bash
git switch main
git pull --ff-only origin main
git tag -a vX.Y.0-beta.0 -m "vX.Y.0-beta.0 iteration start"
git push origin vX.Y.0-beta.0
```

此处 `X.Y` 表示下一轮版本。例如从 ACP 4.3 启动 4.4 时，分别使用 `v4.4` 或 `v4.4.0-beta.0`。

创建后核对 tag 指向和精确注释：

```bash
git rev-parse <tag>^{}
git tag -n1 <tag>
```

注释必须严格是 `<tag> iteration start`，不得追加或改写。若远端 tag 已存在且指向不同提交，停止并请求确认，不得覆盖。

## 4. 创建 iteration-start 空提交

仅在 iteration tag 已成功推送后，仍在默认分支上创建空提交：

```bash
git commit --allow-empty -m "Start ACP X.Y iteration"
git show --stat --oneline HEAD
```

这里的 `X.Y` 也是下一轮版本。该提交必须使用 `--allow-empty`，不得含文件变更，不得以普通功能或修复提交代替。`git show --stat` 应显示没有文件变更。

## 5. 按规定顺序推送引用

已获明确授权执行远端操作时，严格按以下顺序推送：

1. 下一迭代 tag。
2. 含 iteration-start 空提交的默认分支。
3. `release-X.Y` 分支。

示例：

```bash
# gitlab-ce.alauda.cn
git push origin v4.4
git push origin main
git push origin release-4.3

# code.alauda.io
git push origin v4.4.0-beta.0
git push origin main
git push origin release-4.3
```

推送默认分支后确认本地和远端 HEAD 一致：

```bash
git rev-parse main
git ls-remote --heads origin main
```

不要推送未获用户或仓库规则授权的其他分支或 tag。绝不使用 `--force` 或 `--force-with-lease`。遇到权限不足、保护规则、审批要求或远端拒绝时，遵循仓库流程并明确报告尚未完成的步骤，不得绕过。

## 6. `code.alauda.io` 的 release PaC 触发和验证

仅当远端主机是 `code.alauda.io` 时，推送 `release-X.Y` 后，必须在该 release 分支最新 HEAD commit 的 GitLab 页面添加精确评论：

```text
/test branch:release-X.Y
```

例如：

```text
/test branch:release-4.3
```

此评论通过 Note Hook 触发 release 分支的 Tekton Pipelines as Code 构建。不可省略 `branch:`，不可改为 `/test release-X.Y`，也不可将评论添加到默认分支、tag 或其他 commit。默认分支上的 iteration-start 空提交只触发默认分支流程，不能代替 release build。

若无法访问 GitLab、找不到项目或无评论权限，明确说明 release PaC 触发尚未完成，不要改用其他评论内容或绕过权限。

评论后分别验证 default branch 与 release branch 的 PaC 状态。对 release 分支至少确认：

- GitLab webhook 的 `note_hooks` delivery 已产生。
- GitLab pipeline 或 status 显示由外部来源触发，例如 `source=external`。
- `acp-build` namespace 中存在实际的 PipelineRun，且其 event type、git revision 和 target branch 对应 `release-X.Y`。

不要只看 GitLab jobs，也不要只凭评论请求被接受就认定构建已触发。

## 7. 完成核对

本地和远端检查：

```bash
git branch --list release-X.Y
git show --stat --oneline main
git rev-parse main
git ls-remote --heads origin release-X.Y
git ls-remote --heads origin main
git rev-parse <tag>^{}
git tag -n1 <tag>
git ls-remote --tags origin <tag>
```

确认全部满足：

1. `release-X.Y` 从最新实际默认分支创建，且已按授权推送。
2. 下一迭代 tag 的格式和注释正确，指向空提交前的默认分支 HEAD，并先于空提交推送。
3. 默认分支包含新建的 `--allow-empty` iteration-start 提交，且该提交没有文件变更。
4. 默认分支已推送，远端 HEAD 与本地该空提交一致。
5. 没有推送未授权引用，也没有绕过保护、权限或审批规则。
6. 对 `code.alauda.io`，release HEAD 已有精确的 `/test branch:release-X.Y` 评论，且已确认实际 release PipelineRun 被创建。

---

<!-- nmem:skill-outcome-footer v1 -->
## Improving this skill

Nowledge Mem compiled this skill from the user's own experience. When you apply it, print one line so it keeps getting sharper (replace `<name>` with this skill's name from the frontmatter above):

    nmem-skill-used: <name>

If a step was wrong or missing, or it didn't work, also record that: call `report_skill_outcome` with `skill_id="skill_74a0ac414899"`, `skill_version=10`, an `outcome` of `completed` / `completed_with_deviation` / `failed` / `abandoned`, and a one-line note on what was off. This is the user's own feedback loop, not telemetry.
