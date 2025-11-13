太好了 — 我會幫你把「手機 vibe coding」的整套實務流程想清楚（從你用手機開 issue → 自動產生 PR → 你在手機 review → 重要 issue 同步更新 spec）。我會把流程、label 規則、Issue / Spec 範本、GitHub Actions（範例 YAML）、以及用 Gemini-CLI 的注意事項都寫出來，讓你能直接拿去套用或微調。

> 快摘要：流程重點是用 label 決定要不要自動產生 PR、以及要不要更新 spec。GitHub Actions 負責跑 Gemini-CLI（用 secrets 裝 API key）、把產生的變更 commit 到新分支，然後用 `create-pull-request` action 開 PR。Gemini-CLI 支援非互動模式（`-p` / prompt），也有能跳過互動確認的 headless flag（`--yolo`） — 在自動化時要小心權限與沙箱。相關細節我在文中有來源引用。([GitHub][1])

---

# 一、整體設計（high-level）

1. 你用手機（或桌面）在 repo 開一個 **Issue**（使用 Issue template），填入「要做什麼」和「重製輸入/輸出範例」，並選擇/系統加 label（例如 `vibe:auto-pr` / `vibe:spec-update` / `vibe:important`）。
2. GitHub Actions 偵測到 Issue（或 label 被加上）後：

   * 若含 `vibe:auto-pr` → 建一個 feature branch（例如 `vibe/issue-123-add-login`），用 Gemini-CLI 自動產生建議的程式碼改動到該 branch，commit，並自動建立 PR（draft 或 ready，視你要先跑測試還是直接 review）。
   * 若含 `vibe:spec-update`（代表重要 issue）→ 另外一條 workflow 更新 `/specs/...`（或 OpenAPI/MD）檔案，並建立 spec 更新 PR（把修改的 spec 作為主要 artifact）。
3. 你在手機上用 GitHub App 或瀏覽器 **review PR**（PR template + checklist 幫你快速判斷是否合併）。
4. 若 PR 合併且是重要功能 → CI 可自動把 spec 合併到 main，或把 spec 存成 release asset / changelog。

---

# 二、Label 與 Issue Template（建議）

**Label 建議**

* `vibe:auto-pr` — 這個 Issue 允許自動產生 PR（小功能、快捷修 bug）
* `vibe:spec-update` — 重要功能，需更新 spec（不可自動改架構）
* `vibe:important` — 高優先（用於 triage）
* `vibe:skip-auto` — 明確不要自動產生 PR

**Issue template（`.github/ISSUE_TEMPLATE/vibe-feature.md`）**

```md
---
name: Vibe feature / quick-fix
about: Create a mobile-friendly issue for Gemini auto-PR generation
labels: ''
---
## Title
<!-- 簡短描述 -->

## Problem / Request
<!-- 你要 Gemini 幫你做什麼？用手機輸入時盡量簡短、乾淨 -->

## Input / Output (example)
- input: ...
- expected output: ...

## Does this change architecture / spec? (select one)
- [ ] No (small change only)
- [ ] Yes — update spec (label: vibe:spec-update)

## Priority
- [ ] low
- [ ] medium
- [ ] high (label: vibe:important)

## Notes for the bot
<!-- optional: implementation hints, language, files to edit, do not touch -->
```

（用這個 template，在手機上填完就很容易由 Action 解析）

---

# 三、GitHub Actions 範例（核心流程）

下面給兩個 workflow 範例：**Auto-generate PR**（Issue → PR），以及 **Spec update**（重要 issue 時更新 spec）。你可以把它們放到 `.github/workflows/`。

> 前置：在 repository Secrets 裡新增 `GEMINI_API_KEY`（或 `GOOGLE_API_KEY`）與 `GITHUB_TOKEN`（內建），Gemini-CLI 的 API key 可放在 `secrets.GEMINI_API_KEY`。Gemini-CLI 官方建議用 `GEMINI_API_KEY` env var。([Google AI for Developers][2])

## 1) Auto-generate PR（`.github/workflows/auto-generate-pr.yml`）

```yaml
name: Vibe: auto-generate PR from Issue

on:
  issues:
    types: [opened, labeled]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  generate-pr:
    runs-on: ubuntu-latest
    if: github.event.issue.pull_request == null
    steps:
      - name: Check labels
        id: labels
        uses: actions/github-script@v7
        with:
          script: |
            const labels = (context.payload.issue.labels || []).map(l=>l.name);
            core.setOutput("labels", JSON.stringify(labels));
            // proceed only if vibe:auto-pr present and vibe:skip-auto not present
            const ok = labels.includes("vibe:auto-pr") && !labels.includes("vibe:skip-auto");
            core.setOutput("should_run", ok ? "true" : "false");

      - name: Exit if not auto-pr
        if: steps.labels.outputs.should_run != 'true'
        run: |
          echo "Not labeled for auto-pr. Exiting."
          exit 0

      - name: Checkout repo
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Setup Node (for gemini-cli)
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install gemini-cli
        run: npm install -g @google/gemini-cli
      - name: Prepare prompt and run Gemini
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
          ISSUE_NUMBER: ${{ github.event.issue.number }}
          ISSUE_TITLE: ${{ github.event.issue.title }}
          ISSUE_BODY: ${{ github.event.issue.body }}
        run: |
          # build a compact prompt using the issue body & title
          PROMPT="Fix/implement for issue #$ISSUE_NUMBER: $ISSUE_TITLE\n\n$ISSUE_BODY\n\nConstraints: produce a git patch or change files in-place. Keep tests if applicable. Use project's conventions."
          # run non-interactive; --yolo can be used but be cautious (security). Use -p to pass prompt in non-interactive mode.
          # we capture output to a file for inspection; adapt flags to your gemini-cli version.
          gemini -p "$PROMPT" --non-interactive > /tmp/gemini_output.txt || true
          # (optional) parse gemini_output.txt to extract patch or files, or let Gemini actually edit the workspace (requires proper config)
          cat /tmp/gemini_output.txt

      - name: Commit changes and create a PR
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "chore(vibe): implement suggestion for issue #${{ github.event.issue.number }}"
          branch: "vibe/issue-${{ github.event.issue.number }}-${{ github.event.issue.title | slugify }}"
          title: "feat: fix/implement — issue #${{ github.event.issue.number }} — ${{ github.event.issue.title }}"
          body: |
            Auto-generated PR from issue #${{ github.event.issue.number }}.
            Please review and add changes. Source: GitHub Issue.
```

**說明 / 注意**

* 我把 `gemini -p`（非互動）和 `--non-interactive` 放進範例；實際 flag 依你安裝的 gemini-cli 版本稍微調整（官方文件有 `-p` / non-interactive 範例）。([Google Codelabs][3])
* `--yolo`（自動接受執行）可用於完全 headless，但風險高；建議在 staging repo 或 sandbox branch 先測試，再放到 production。([部落格][4])
* 如果 Gemini 不能直接改檔（或你不想讓 agent 寫檔），策略是讓它輸出 **patch/PR diff**（或 code blocks），然後在 Action 裡把 patch 應用到工作區（`git apply`）再 commit。

## 2) Spec update workflow（`.github/workflows/spec-update.yml`）

```yaml
name: Vibe: update spec for important issues

on:
  issues:
    types: [labeled]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  update-spec:
    runs-on: ubuntu-latest
    steps:
      - name: Only run on 'vibe:spec-update' label
        uses: actions/github-script@v7
        id: checklabel
        with:
          script: |
            const labels = (context.payload.issue.labels || []).map(l=>l.name);
            core.setOutput('run', labels.includes('vibe:spec-update') ? 'true' : 'false');
      - name: Exit if not spec-update
        if: steps.checklabel.outputs.run != 'true'
        run: exit 0

      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node and install gemini-cli
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm install -g @google/gemini-cli

      - name: Generate spec changes (draft)
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
          ISSUE_NUMBER: ${{ github.event.issue.number }}
          ISSUE_TITLE: ${{ github.event.issue.title }}
          ISSUE_BODY: ${{ github.event.issue.body }}
        run: |
          PROMPT="Update the spec files for issue #$ISSUE_NUMBER ($ISSUE_TITLE). Current spec files located in /specs. Proposed edits only; include changelog entry."
          gemini -p "$PROMPT" --non-interactive > /tmp/spec_proposal.md || true
          # Append the proposal to a temp specs file for human review
          mkdir -p specs/proposals
          cp /tmp/spec_proposal.md specs/proposals/issue-${ISSUE_NUMBER}-proposal.md
          git add specs/proposals/issue-${ISSUE_NUMBER}-proposal.md
          git commit -m "chore(spec): proposal for issue #${ISSUE_NUMBER}" || true

      - name: Create PR for spec update
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "feat(spec): proposal for issue #${{ github.event.issue.number }}"
          branch: "vibe/spec-proposal-${{ github.event.issue.number }}"
          title: "spec: proposal — issue #${{ github.event.issue.number }} — ${{ github.event.issue.title }}"
          body: |
            Proposed spec update for issue #${{ github.event.issue.number }}.
            Please review the file under `specs/proposals/`.
```

---

# 四、PR / Review 建議（讓手機 review 流暢）

* PR template 加 checklist（功能正確 / unit tests / doc / performance / backward-compatible）。
* 將 auto-generated PR 預設為 **Draft**，讓你用手機先看檔案改動，再按「Ready for review」。這樣可以避免 agent 直接推送未測試的變更到正式 PR。
* 必要時在 workflow 加上自動測試步驟（run unit tests）；失敗則標 PR 為 `ci:failed` 並留言。
* Review 時重點檢查：API 變更、有無破壞相容性、是否需要更新 spec（如果是重要改動但沒標 `vibe:spec-update`，把 label 加上並觸發 spec workflow）。

---

# 五、Spec 管理實作建議（格式與版本）

* 將所有 spec 放到 `/specs/`（例如 `specs/openapi.yaml` 或 `specs/features/*.md`）。
* 每個重要功能在 specs 下有自己的檔案（`specs/feature-<slug>.md`），PR 合併時同時更新對應 spec 檔案。
* 在 spec 裡加入一段 `meta`（author、date、issue link、version），方便追蹤。
* 當 issue 被標為 `vibe:spec-update` 時，workflow 先產生 spec **proposal PR**（人 Review），不直接合併。合併時再把 spec 合入主線。

---

# 六、Gemini-CLI 實務注意事項（安全與穩定）

1. **驗證與金鑰**：在 CI / Actions 裡把 `GEMINI_API_KEY` 存在 repo secrets，Gemini-CLI 會讀 `GEMINI_API_KEY` 或 `GOOGLE_API_KEY`。([Google AI for Developers][2])
2. **非互動模式**：可以用 `-p` 或 `--non-interactive` 傳 prompt，使 CLI 在 pipeline 中可 headless 運行；若要讓 agent 修改檔案自動 commit，`--yolo` 可以跳過提示，但請先在 sandbox 測試，並限制 token 與 repo 權限。([Google Codelabs][3])
3. **安全性**：Gemini-CLI 曾被討論過執行不安全命令的風險（請定期更新至官方修補版本，並在不信任 repo 或未知內容時避免啟用自動執行）。在公開 repo 或多人的 repo，盡量先把 agent 產生的改動改為「proposal」而非直接寫入。（注意官方有 patch 及建議做 sandboxing）。([TechRadar][5])
4. **版本差異**：不同版本的 gemini-cli 旗標/行為會有差異。Action 內的安裝命令 `npm install -g @google/gemini-cli` 是常見做法（或用 `npx` 即時執行），但實際使用前請先 local 測試 CLI flags。([NPM][6])

---

# 七、手機使用流程建議（讓一切在手機上順暢）

* **開 Issue（手機）**：用你設計的 Issue template 填好最關鍵資訊 → 勾選是否需要 spec 更新 → 點送出。當你要開快速修 bug 時，直接加 `vibe:auto-pr` label（或在 template 裡預設）。
* **自動 PR**：Action 在幾分鐘內建立 PR（或 proposal），你會收到通知或在 GitHub App 看到 PR。
* **Review（手機）**：在 PR 裡使用 GitHub App 的「Files changed」檢視、Comment、Apply suggestion（若你想直接修改），最後 approve / merge（或按 Ready for review）。
* **若是重要功能**：你在 review 時若覺得 spec 需要改動，把 label 加 `vibe:spec-update` → 會觸發 spec proposal PR → 合併後再合併實作 PR（或反之，依你團隊流程）。

---

# 八、額外建議與最佳實踐

* **Conventional commits**：Action commit message 用 conventional format（`feat:`, `fix:`），方便自動化與 release notes。
* **小步快合併**：agent 產生大改時分多個小 PR，降低風險。
* **測試閘道**：CI（unit/integration）通過才把 PR 從 draft 轉 ready（可以在 Actions 裡設定 comment 或用 `pull-request` API）
* **審核黑白名單**：對於自動修改代碼的路徑設白名單（例如只允許 agent 編輯 `src/features/` 但不編輯 `infra/`）。
* **Audit trail**：保留 agent 輸出 (artifacts 或 `specs/proposals/`)，方便審計與回滾。

[1]: https://github.com/google-gemini/gemini-cli?utm_source=chatgpt.com "google-gemini/gemini-cli: An open-source AI agent that ..."
[2]: https://ai.google.dev/gemini-api/docs/api-key?utm_source=chatgpt.com "Using Gemini API keys | Google AI for Developers"
[3]: https://codelabs.developers.google.com/gemini-cli-hands-on?utm_source=chatgpt.com "Hands-on with Gemini CLI"
[4]: https://www.leeboonstra.dev/genai/gemini_cli_github_actions/?utm_source=chatgpt.com "Unleashing Gemini CLI Power in GitHub Actions and Beyond"
[5]: https://www.techradar.com/pro/security/google-gemini-security-flaw-could-have-let-anyone-access-systems-or-run-code?utm_source=chatgpt.com "Google Gemini security flaw could have let anyone access systems or run code"
[6]: https://www.npmjs.com/package/%40google/gemini-cli?utm_source=chatgpt.com "google/gemini-cli"
