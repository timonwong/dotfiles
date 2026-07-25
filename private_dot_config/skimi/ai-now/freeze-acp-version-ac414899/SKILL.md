---
name: freeze-acp-version
description: "需要冻结 ACP X.Y 版本并启动下一轮迭代时，按仓库规则创建 release 分支、空 commit 和下一版本 tag。"
---

# ACP 版本冻结流程

当需要冻结 ACP `X.Y` 版本并启动下一轮迭代时，按以下顺序执行。除非用户明确要求实际执行，否则输出可执行方案并说明需要确认的前置条件；不要擅自执行会改变远端仓库的操作。

## 1. 确认上下文

先确认以下信息：

- 目标仓库及其远端名称，通常为 `origin`，但以仓库实际配置为准。
- 待冻结的 ACP 版本 `X.Y`，例如 `4.3`。
- 下一轮版本 `X.Y+1`，例如 `4.4`。按 ACP 的小版本递增规则计算，不要改动主版本或格式。
- 项目实际使用的主分支。仅在仓库确实存在并且项目使用时选择 `main` 或 `master`，不得自行假设。
- 当前工作区和暂存区状态。
- 用户或仓库规则是否要求推送其他引用、使用特定签名方式，或遵守额外的保护与审批流程。
- 远端 URL 主机。处理 iteration tag 时，必须根据 GitLab 地址选择 tag 格式：`gitlab-ce.alauda.cn` 使用两段式版本号 `vX.Y`；`code.alauda.io` 使用完整预发布版本号 `vX.Y.0-beta.0`。
- 远端是否为 `code.alauda.io`；如果是，推送冻结分支后还必须在 GitLab 上对该 commit 添加评论 `/test branch:release-X.Y`，以触发 Tekton PaC 对 release 分支的构建。

建议先检查：

```bash
git remote -v
git branch --list main master
git status --short
```

如果 `main` 和 `master` 都存在，必须根据项目配置、默认分支或明确仓库规则确认实际主分支；不能仅凭分支存在与否随意选择。

## 2. 创建冻结分支

从主分支的最新状态创建 `release-X.Y` 分支。先同步并切换到实际主分支；以下以 `main` 为例，若主分支是 `master`，将命令中的 `main` 替换为 `master`：

```bash
git switch main
git pull --ff-only origin main
git switch -c release-X.Y
```

例如冻结 ACP 4.3 时：

```bash
git switch main
git pull --ff-only origin main
git switch -c release-4.3
```

如果工作区有未提交改动，先停止并让用户决定是提交、暂存、丢弃还是保留；不要把无关改动带入冻结分支。分支名称必须严格为 `release-X.Y`，版本号必须与待冻结版本一致。

创建后检查分支指向：

```bash
git log -1 --oneline release-X.Y
git branch --show-current
```

## 3. 在主分支准备下一版本迭代 tag

切回主分支，并确保基于最新主分支创建下一轮迭代 tag。iteration tag 的格式必须根据远端 GitLab 地址选择：

- 当远端 URL 主机为 `gitlab-ce.alauda.cn` 时，使用两段式 tag `vX.Y+1`，tag message 必须严格为 `vX.Y+1 iteration start`。
- 当远端 URL 主机为 `code.alauda.io` 时，使用完整预发布 tag `vX.Y+1.0-beta.0`，tag message 必须严格为 `vX.Y+1.0-beta.0 iteration start`。

iteration tag 必须先创建并推送；随后才能创建并推送 iteration start 空提交。这样可确保由该空提交触发的流水线运行时一定能够获取到该 tag。

例如 ACP 4.3 冻结后启动 4.4：

在 `gitlab-ce.alauda.cn` 远端：

```bash
git switch main
git pull --ff-only origin main
git tag -a v4.4 -m "v4.4 iteration start"
git push origin v4.4
```

在 `code.alauda.io` 远端：

```bash
git switch main
git pull --ff-only origin main
git tag -a v4.4.0-beta.0 -m "v4.4.0-beta.0 iteration start"
git push origin v4.4.0-beta.0
```

tag 应指向创建 tag 时主分支的当前提交。创建后确认 tag 名称和说明文字完全匹配：

对于 `gitlab-ce.alauda.cn`：

```bash
git rev-parse vX.Y+1^{}
git tag -n1 vX.Y+1
```

例如：

```bash
git rev-parse v4.4^{}
git tag -n1 v4.4
```

tag message 必须完全是 `vX.Y+1 iteration start`，不能改写、追加或使用其他措辞。

对于 `code.alauda.io`：

```bash
git rev-parse vX.Y+1.0-beta.0^{}
git tag -n1 vX.Y+1.0-beta.0
```

例如：

```bash
git rev-parse v4.4.0-beta.0^{}
git tag -n1 v4.4.0-beta.0
```

tag message 必须完全是 `vX.Y+1.0-beta.0 iteration start`，不能改写、追加或使用其他措辞。

如果远端 tag 已存在但指向不同提交，不要覆盖；先停止并请求确认。

## 4. 在主分支创建迭代起点空提交

完成 iteration tag 的创建和推送后，在主分支当前状态创建迭代起点空提交。空提交只能使用 `--allow-empty` 创建，不得用普通提交或混入功能、修复及其他文件改动：

```bash
git commit --allow-empty -m "Start ACP X.Y+1 iteration"
```

例如 ACP 4.3 冻结后启动 4.4：

```bash
git commit --allow-empty -m "Start ACP 4.4 iteration"
```

这里的关键要求是该提交必须是 **empty commit**。提交说明可以按仓库既有提交规范调整，但不得替代空提交，也不得在该提交中加入文件变更。创建后确认：

```bash
git show --stat --oneline HEAD
```

输出应显示该提交没有文件变更。

## 5. 推送规定的引用

完成顺序必须是：

1. 推送 iteration tag：`gitlab-ce.alauda.cn` 远端推送 `vX.Y+1`；`code.alauda.io` 远端推送 `vX.Y+1.0-beta.0`。
2. 创建并推送包含 iteration start 空提交的主分支。
3. 推送 `release-X.Y` 分支。

例如在 `gitlab-ce.alauda.cn` 远端：

```bash
git push origin v4.4
git push origin main
git push origin release-4.3
```

例如在 `code.alauda.io` 远端：

```bash
git push origin v4.4.0-beta.0
git push origin main
git push origin release-4.3
```

如果主分支为 `master`，将主分支推送命令改为：

```bash
git push origin master
```

创建 iteration start 的 empty commit 后，必须将包含该提交的主分支推送到目标远端仓库，并确认远端主分支已指向该提交。不得只推送 release 分支或 tag 而遗漏该空提交。推送后核对：

```bash
git rev-parse main
git ls-remote --heads origin main
```

本地 `git rev-parse main` 与远端 `git ls-remote --heads origin main` 返回的提交 ID 必须一致。主分支为 `master` 时，将命令中的 `main` 替换为 `master`。如果推送失败、被分支保护阻止或远端拒绝更新，不要绕过限制；应明确说明 iteration start 空提交尚未成功推送。

如果用户没有明确提出推送要求，且仓库也没有明确的远程发布规则，这是**未明确推送要求**的情况；只给出本地执行方案并请求确认，**不要自行推送**。

当目标远端的 URL 主机为 `code.alauda.io` 时，推送 `release-X.Y` 分支后，必须在 GitLab 上对该 release 分支最新 commit 添加以下精确评论：

```text
/test branch:release-X.Y
```

例如冻结 ACP 4.3 时，应对 `release-4.3` 分支最新 commit 添加：

```text
/test branch:release-4.3
```

该评论用于触发 Tekton PaC 对 release 分支的构建。应确认评论添加到了刚推送的 `release-X.Y` commit，而不是主分支、tag 或其他 commit；如果无法访问 GitLab、找不到对应项目或没有评论权限，必须明确说明该触发步骤尚未完成，不要用其他评论内容替代，也不要绕过权限或保护规则。

除上述必须推送的 `release-X.Y` 分支、主分支空提交和 iteration tag 外，不要推送用户或仓库规则未授权的其他引用。特别是：

- 不要推送未获明确要求或仓库规则授权的其他分支或 tag。
- 不要使用 `--force` 或 `--force-with-lease` 绕过保护。
- 如果主分支保护要求 Pull Request、审批或 CI，通过仓库规定的流程处理，并明确说明当前推送步骤尚未完成。
- 如果远端 tag 已存在但指向不同提交，不要覆盖；先停止并请求确认。
- 如果权限不足、保护规则阻止推送或远端拒绝更新，不要绕过限制。

## 6. 完成核对

本地核对：

```bash
git branch --list release-X.Y
git show --stat --oneline main
git rev-parse main
```

在 `gitlab-ce.alauda.cn` 远端核对：

```bash
git rev-parse vX.Y+1^{}
git tag -n1 vX.Y+1
git ls-remote --tags origin vX.Y+1
```

在 `code.alauda.io` 远端核对：

```bash
git rev-parse vX.Y+1.0-beta.0^{}
git tag -n1 vX.Y+1.0-beta.0
git ls-remote --tags origin vX.Y+1.0-beta.0
```

远端分支核对：

```bash
git ls-remote --heads origin release-X.Y
git ls-remote --heads origin main
```

主分支为 `master` 时，将核对命令中的 `main` 替换为 `master`。确认 iteration tag 已先于 iteration start 空提交推送；确认远端主分支的提交 ID 与本地迭代起点空提交的提交 ID 一致，以证明该 empty commit 已成功推送。

确认以下条件全部满足：

1. `release-X.Y` 分支存在，并已推送到目标远端。
2. 当远端为 `gitlab-ce.alauda.cn` 时，`vX.Y+1` iteration tag 存在，tag message 与精确格式 `vX.Y+1 iteration start` 完全匹配，并已先于空提交推送到目标远端；当远端为 `code.alauda.io` 时，`vX.Y+1.0-beta.0` iteration tag 存在，tag message 与精确格式 `vX.Y+1.0-beta.0 iteration start` 完全匹配，并已先于空提交推送到目标远端。
3. 主分支包含新创建的空提交；该提交没有文件变更。
4. 主分支上的该空提交已成功推送到目标远端，且远端主分支指向该提交。
5. 当远端为 `code.alauda.io` 时，GitLab 上已对 `release-X.Y` 最新 commit 添加精确评论 `/test branch:release-X.Y`，用于触发 Tekton PaC 构建。
6. 没有推送用户或仓库规则未授权的其他引用。

## 决策规则

- `main` 和 `master` 只能选择仓库实际使用的主分支；仓库只有 `master` 时必须使用 `git switch master`。
- 冻结 ACP 4.3 时，冻结分支必须是 `release-4.3`，创建命令必须为 `git switch -c release-4.3`（在正确的主分支最新状态上执行）。
- 根据远端 GitLab 地址选择 iteration tag：`gitlab-ce.alauda.cn` 使用两段式 `vX.Y`，例如下一轮 ACP 2.8 使用 `v2.8`，tag message 为 `v2.8 iteration start`；`code.alauda.io` 使用完整预发布格式 `vX.Y.0-beta.0`，例如下一轮 ACP 2.8 使用 `v2.8.0-beta.0`，tag message 为 `v2.8.0-beta.0 iteration start`。
- iteration tag 必须在创建并推送后，才能创建和推送 iteration start 空提交。
- 空提交必须使用 `git commit --allow-empty`，并保持空白，不得用普通提交替代。
- 冻结完成后，按 iteration tag、主分支空提交、`release-X.Y` 分支的顺序推送，并确认各项均已成功推送；除此之外的推送范围只能依据用户指示或明确项目规则确定。
- 当远端为 `code.alauda.io` 时，推送 `release-X.Y` 分支后必须在 GitLab 上对该分支最新 commit 添加 `/test branch:release-X.Y` 评论，以触发 Tekton PaC 构建。
- 分支保护、权限、审批、签名和发布限制必须遵守仓库现有规则；未明确提供的限制不得擅自绕过，也不得自行补充为强制规则。

---

<!-- nmem:skill-outcome-footer v1 -->
## Improving this skill

Nowledge Mem compiled this skill from the user's own experience. When you apply it, print one line so it keeps getting sharper (replace `<name>` with this skill's name from the frontmatter above):

    nmem-skill-used: <name>

If a step was wrong or missing, or it didn't work, also record that: call `report_skill_outcome` with `skill_id="skill_74a0ac414899"`, `skill_version=9`, an `outcome` of `completed` / `completed_with_deviation` / `failed` / `abandoned`, and a one-line note on what was off. This is the user's own feedback loop, not telemetry.
