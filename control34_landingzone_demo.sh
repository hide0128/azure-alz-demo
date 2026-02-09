#!/bin/bash
# ==============================================================================
# Control 3.4 Landing Zone基盤 CI/CDデモスクリプト
# Azure Specialization Audit - Automated Deployment and Provisioning Tools
# ==============================================================================

set -e

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 設定
REPO_DIR="${REPO_DIR:-$(pwd)}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-landingzone-demo}"
BRANCH_NAME="feature/demo-$(date +%Y%m%d-%H%M%S)"
PR_URL=""

# ヘルパー関数
print_header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

wait_for_enter() {
    echo ""
    echo -e "${YELLOW}>>> Enterキーを押して続行...${NC}"
    read -r
}

confirm_proceed() {
    echo ""
    echo -e "${YELLOW}>>> 続行しますか？ (y/n)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "中断しました。"
        exit 0
    fi
}

# GitHub Actions の最新実行URLを表示
show_workflow_url() {
    local workflow_name="$1"
    local branch="$2"
    sleep 3
    local run_url
    run_url=$(gh run list --workflow="$workflow_name" --branch="$branch" --limit=1 --json url --jq '.[0].url' 2>/dev/null || true)
    if [ -n "$run_url" ]; then
        echo ""
        echo -e "${CYAN}  >>> GitHub Actions: ${run_url}${NC}"
        echo ""
    fi
}

# ==============================================================================
# デモ開始
# ==============================================================================

clear
print_header "Control 3.4 Landing Zone基盤 CI/CDデモ"

echo "このスクリプトは以下のデモを実行します："
echo ""
echo "  1. 環境確認（Azure CLI, リソースグループ）"
echo "  2. リポジトリ・テンプレート・ワークフロー確認"
echo "  3. ローカルでのBicep検証（build, what-if）"
echo "  4. CI失敗デモ（意図的エラー → PR自動作成）"
echo "  5. CI成功デモ（エラー修正 → CI通過確認）"
echo "  6. CDデプロイ（PR自動マージ → Azure反映確認）"
echo "  7. クリーンアップ"
echo ""
echo "リポジトリ: $REPO_DIR"
echo "リソースグループ: $RESOURCE_GROUP"
echo ""

confirm_proceed

# ==============================================================================
# Phase 1: 環境確認
# ==============================================================================

print_header "Phase 1: 環境確認"

print_step "1.1" "リポジトリディレクトリに移動"
cd "$REPO_DIR"
print_success "ディレクトリ: $(pwd)"

print_step "1.2" "Azure CLI ログイン確認"
if az account show > /dev/null 2>&1; then
    ACCOUNT_NAME=$(az account show --query name -o tsv)
    print_success "Azureにログイン済み: $ACCOUNT_NAME"
else
    print_warning "Azureにログインしていません"
    echo "az login --use-device-code を実行してください"
    exit 1
fi

print_step "1.3" "リソースグループの確認"
if az group show --name "$RESOURCE_GROUP" > /dev/null 2>&1; then
    print_success "リソースグループ存在確認: $RESOURCE_GROUP"
else
    print_warning "リソースグループが存在しません: $RESOURCE_GROUP"
    print_info "リソースグループを作成します（リージョン: japaneast）"
    az group create --name "$RESOURCE_GROUP" --location japaneast --output none
    print_success "リソースグループを作成しました: $RESOURCE_GROUP"
fi

print_step "1.4" "GitHub CLI 確認"
if gh auth status > /dev/null 2>&1; then
    print_success "GitHub CLI 認証済み"
else
    print_warning "GitHub CLI にログインしていません"
    echo "gh auth login を実行してください"
    exit 1
fi

wait_for_enter

# ==============================================================================
# Phase 2: リポジトリ・テンプレート・ワークフロー確認
# ==============================================================================

print_header "Phase 2: リポジトリ・テンプレート・ワークフロー確認"

print_step "2.1" "ディレクトリ構造"
echo ""
if command -v tree &> /dev/null; then
    tree -L 3 -a --dirsfirst -I '.git|node_modules|.claude'
else
    find . -type f \( -name "*.bicep" -o -name "*.json" -o -name "*.yml" \) | grep -v node_modules | head -20
fi
echo ""

print_step "2.2" "Bicepテンプレート - 主要リソース"
echo ""
echo "--- パラメーター ---"
grep -A2 "^param " bicep/main.bicep | head -20
echo ""
echo "--- 定義リソース ---"
grep "^resource " bicep/main.bicep
echo ""

print_step "2.3" "CI/CDワークフロー構成"
echo ""
echo "--- CI (ci.yml) ---"
echo "  トリガー: Pull Request → bicep/** 変更時"
echo "  ステップ: Bicep Build → What-If Analysis"
echo ""
echo "--- CD (cd.yml) ---"
echo "  トリガー: main マージ → bicep/** 変更時"
echo "  ステップ: Bicep Deploy → Outputs表示"
echo ""
print_info "詳細を見ますか？"
echo -e "${YELLOW}>>> CI/CDワークフローの詳細を表示しますか？ (y/n)${NC}"
read -r show_detail
if [[ "$show_detail" =~ ^[Yy]$ ]]; then
    echo ""
    echo "=== ci.yml ==="
    cat .github/workflows/ci.yml
    echo ""
    echo "=== cd.yml ==="
    cat .github/workflows/cd.yml
fi

wait_for_enter

# ==============================================================================
# Phase 3: ローカルでのBicep検証
# ==============================================================================

print_header "Phase 3: ローカルでのBicep検証"

print_step "3.1" "Bicep Build（構文チェック）"
echo ""
if az bicep build --file bicep/main.bicep; then
    print_success "Bicep Build 成功"
else
    print_warning "Bicep Build 失敗"
fi
echo ""

print_step "3.2" "What-If Analysis（変更プレビュー）"
echo ""
print_info "作成予定のリソースを確認します"

confirm_proceed

az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --template-file bicep/main.bicep \
    --parameters bicep/parameters.json \
    || print_warning "What-If でエラーが発生しました"

wait_for_enter

# ==============================================================================
# Phase 4: CI失敗デモ
# ==============================================================================

print_header "Phase 4: CI失敗デモ（意図的なエラー → PR自動作成）"

print_step "4.1" "mainブランチを最新化"
# bicep/ 配下に変更がある場合のみ stash
if ! git diff --quiet -- bicep/ 2>/dev/null; then
    git stash push -m "demo-backup" -- bicep/
fi
git checkout main
git pull origin main || true

print_step "4.2" "featureブランチを作成"
git checkout -b "$BRANCH_NAME"
print_success "ブランチ作成: $BRANCH_NAME"

print_step "4.3" "意図的な構文エラーを追加"
echo ""
echo "以下の不完全な構文を追加します:"
echo "  resource broken"
echo ""

confirm_proceed

echo "resource broken" >> bicep/main.bicep

print_step "4.4" "ローカルでエラーを確認"
echo ""
if az bicep build --file bicep/main.bicep 2>&1; then
    print_warning "エラーが発生しませんでした"
else
    print_success "期待通りエラーが発生しました（BCP018: Expected the \"=\" character）"
fi
echo ""

print_step "4.5" "コミット＆プッシュ"
git add bicep/main.bicep
git commit -m "test: intentional syntax error for CI failure demo"
git push origin "$BRANCH_NAME"

print_success "プッシュ完了"

print_step "4.6" "Pull Request を自動作成"
PR_URL=$(gh pr create \
    --title "test: CI/CD demo - $(date +%Y%m%d-%H%M%S)" \
    --body "Control 3.4 Landing Zone CI/CDデモ用のPRです。" \
    --base main \
    --head "$BRANCH_NAME" 2>&1)

print_success "PR作成完了: $PR_URL"

echo ""
print_info "CIワークフローが実行されます（失敗することを確認）"
show_workflow_url "ci.yml" "$BRANCH_NAME"

wait_for_enter

# ==============================================================================
# Phase 5: CI成功デモ
# ==============================================================================

print_header "Phase 5: CI成功デモ（エラー修正）"

print_step "5.1" "エラーを修正"
sed -i '/^resource broken$/d' bicep/main.bicep

# CDトリガー用のタイムスタンプ更新（存在しない場合は末尾に追加）
if grep -q "^// Trigger CD -" bicep/main.bicep; then
    sed -i "s|^// Trigger CD -.*|// Trigger CD - $(date)|" bicep/main.bicep
else
    echo "// Trigger CD - $(date)" >> bicep/main.bicep
fi

print_step "5.2" "修正後のBicep Build確認"
if az bicep build --file bicep/main.bicep; then
    print_success "Bicep Build 成功"
else
    print_warning "Bicep Build 失敗"
    exit 1
fi

print_step "5.3" "修正をコミット＆プッシュ"
git add bicep/main.bicep
git commit -m "fix: remove intentional error"
git push origin "$BRANCH_NAME"

print_success "修正プッシュ完了"
print_info "CIワークフローが実行されます（成功することを確認）"
show_workflow_url "ci.yml" "$BRANCH_NAME"

wait_for_enter

# ==============================================================================
# Phase 6: CDデプロイ（PR自動マージ → Azure反映確認）
# ==============================================================================

print_header "Phase 6: CDデプロイ（PRマージ → Azure反映確認）"

print_step "6.1" "CIの完了を待機"
echo ""
print_info "CIワークフローの完了を確認中..."

# 最新のCI実行を取得して完了を待つ
CI_RUN_ID=$(gh run list --workflow=ci.yml --branch="$BRANCH_NAME" --limit=1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)
if [ -n "$CI_RUN_ID" ]; then
    gh run watch "$CI_RUN_ID" --exit-status 2>/dev/null && \
        print_success "CIが正常に完了しました" || \
        print_warning "CIが失敗しました。続行する場合は手動で確認してください"
else
    print_warning "CI実行が見つかりません。手動で確認してください"
fi

echo ""
confirm_proceed

print_step "6.2" "PRを自動マージ"
if gh pr merge "$BRANCH_NAME" --merge --delete-branch; then
    print_success "PRマージ完了（ブランチ自動削除）"
else
    print_warning "自動マージに失敗しました。手動でマージしてください"
    print_info "PR: $PR_URL"
    confirm_proceed
fi

# --- CDワークフロー監視 ---
print_step "6.3" "CDワークフローの実行状況を監視"
echo ""

print_info "CDワークフローの開始を待機中..."
MAX_WAIT=30
WAIT_COUNT=0
RUN_ID=""
while [ -z "$RUN_ID" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    RUN_ID=$(gh run list --workflow=cd.yml --branch=main --limit=1 --json databaseId,status,createdAt --jq '.[0].databaseId' 2>/dev/null || true)
    if [ -z "$RUN_ID" ]; then
        sleep 2
        WAIT_COUNT=$((WAIT_COUNT + 1))
        printf "."
    fi
done
echo ""

if [ -n "$RUN_ID" ]; then
    print_info "CDワークフロー実行ID: $RUN_ID"
    show_workflow_url "cd.yml" "main"

    # ワークフローの完了を待つ
    gh run watch "$RUN_ID" --exit-status 2>/dev/null && \
        print_success "CDワークフローが正常に完了しました" || \
        print_warning "CDワークフローの結果を確認してください"

    echo ""
    gh run view "$RUN_ID" 2>/dev/null || true
else
    print_warning "CDワークフローが見つかりません。手動で確認してください。"
fi

echo ""

# --- デプロイ結果の可視化 ---
print_step "6.4" "リソースのデプロイ状況を確認中..."
echo ""

# リソースが反映されるまで待機
MAX_RESOURCE_WAIT=12
RESOURCE_WAIT=0
RESOURCE_COUNT=0
while [ "$RESOURCE_COUNT" -eq 0 ] && [ "$RESOURCE_WAIT" -lt "$MAX_RESOURCE_WAIT" ]; do
    RESOURCE_COUNT=$(az resource list --resource-group "$RESOURCE_GROUP" --query 'length(@)' -o tsv 2>/dev/null || echo "0")
    if [ "$RESOURCE_COUNT" -eq 0 ]; then
        printf "  リソースの反映を待機中."
        sleep 5
        RESOURCE_WAIT=$((RESOURCE_WAIT + 1))
        printf "."
    fi
done
echo ""

if [ "$RESOURCE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}  ┌──────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}  │          デプロイ済みリソース一覧 ($RESOURCE_COUNT リソース)              │${NC}"
    echo -e "${GREEN}  └──────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # 各リソースの状態を個別に表示
    while IFS=$'\t' read -r rname rtype rstate; do
        if [ "$rstate" = "Succeeded" ]; then
            echo -e "  ${GREEN}✓${NC} ${CYAN}$rname${NC}"
            echo -e "    種類: $rtype  状態: ${GREEN}$rstate${NC}"
        else
            echo -e "  ${RED}✗${NC} ${CYAN}$rname${NC}"
            echo -e "    種類: $rtype  状態: ${RED}$rstate${NC}"
        fi
    done < <(az resource list --resource-group "$RESOURCE_GROUP" \
        --query '[].{name:name, type:type, state:provisioningState}' \
        -o tsv 2>/dev/null)
    echo ""
else
    print_warning "リソースが見つかりません"
fi

print_step "6.5" "VNet詳細確認"
echo ""
# VNet名を動的に取得
VNET_DETECTED=$(az network vnet list -g "$RESOURCE_GROUP" --query '[0].name' -o tsv 2>/dev/null)
if [ -n "$VNET_DETECTED" ]; then
    VNET_TMP=$(mktemp)
    az network vnet show -g "$RESOURCE_GROUP" -n "$VNET_DETECTED" \
        --query '{name:name, addressSpace:addressSpace.addressPrefixes[0], subnets:subnets[].{name:name, prefix:addressPrefix, nsg:networkSecurityGroup.id}}' \
        -o json > "$VNET_TMP" 2>/dev/null

    VNET_NAME=$(jq -r '.name' "$VNET_TMP")
    VNET_ADDR=$(jq -r '.addressSpace' "$VNET_TMP")
    echo -e "  ${CYAN}VNet:${NC} $VNET_NAME  ${CYAN}アドレス空間:${NC} $VNET_ADDR"
    echo ""
    echo -e "  ${CYAN}サブネット構成:${NC}"
    echo -e "  ┌─────────────────────────┬──────────────────┬─────────────────────┐"
    echo -e "  │ サブネット名            │ アドレス範囲     │ NSG                 │"
    echo -e "  ├─────────────────────────┼──────────────────┼─────────────────────┤"
    while IFS=$'\t' read -r sname sprefix snsg; do
        nsg_short=$(basename "$snsg" 2>/dev/null || echo "-")
        printf "  │ %-23s │ %-16s │ %-19s │\n" "$sname" "$sprefix" "$nsg_short"
    done < <(jq -r '.subnets[] | [.name, .prefix, (.nsg // "-")] | @tsv' "$VNET_TMP")
    echo -e "  └─────────────────────────┴──────────────────┴─────────────────────┘"
    echo ""
    rm -f "$VNET_TMP"
else
    print_warning "VNetが見つかりません"
fi

print_step "6.6" "NSGルール確認"
echo ""
for NSG_NAME in $(az network nsg list --resource-group "$RESOURCE_GROUP" --query '[].name' -o tsv 2>/dev/null); do
    TIER=$(echo "$NSG_NAME" | rev | cut -d'-' -f1 | rev)
    echo -e "  ${CYAN}[$TIER]${NC} $NSG_NAME"
    az network nsg rule list --resource-group "$RESOURCE_GROUP" --nsg-name "$NSG_NAME" \
        --query '[].{name:name, priority:priority, access:access, direction:direction, srcAddr:sourceAddressPrefix, dstPort:destinationPortRange, protocol:protocol}' \
        -o table 2>/dev/null | while IFS= read -r line; do
        echo "    $line"
    done
    echo ""
done

print_step "6.7" "デプロイ履歴確認"
echo ""
DEPLOY_NAME=$(az deployment group list -g "$RESOURCE_GROUP" --query '[0].name' -o tsv 2>/dev/null)
if [ -n "$DEPLOY_NAME" ]; then
    # デプロイ情報を一時ファイルに保存（パイプの出力抑制を回避）
    DEPLOY_TMP=$(mktemp)
    az deployment group show -g "$RESOURCE_GROUP" -n "$DEPLOY_NAME" \
        --query 'properties.{state:provisioningState, timestamp:timestamp, duration:duration, outputs:outputs}' \
        -o json > "$DEPLOY_TMP" 2>/dev/null

    DEPLOY_STATE=$(jq -r '.state' "$DEPLOY_TMP")
    DEPLOY_TIME=$(jq -r '.timestamp' "$DEPLOY_TMP")
    DEPLOY_DURATION=$(jq -r '.duration' "$DEPLOY_TMP")

    echo -e "  ${CYAN}デプロイ名:${NC}   $DEPLOY_NAME"
    if [ "$DEPLOY_STATE" = "Succeeded" ]; then
        echo -e "  ${CYAN}状態:${NC}         ${GREEN}$DEPLOY_STATE ✓${NC}"
    else
        echo -e "  ${CYAN}状態:${NC}         ${RED}$DEPLOY_STATE ✗${NC}"
    fi
    echo -e "  ${CYAN}完了時刻:${NC}     $DEPLOY_TIME"
    echo -e "  ${CYAN}所要時間:${NC}     $DEPLOY_DURATION"
    echo ""

    # デプロイOutputsのサマリ
    echo -e "  ${CYAN}デプロイOutputs:${NC}"
    jq -r '.outputs | to_entries[] |
        if .value.type == "String" then
            "    \(.key): \(.value.value)"
        else
            "    \(.key):", (.value.value | to_entries[] | "      \(.key): \(.value | split("/") | .[-1])")
        end' "$DEPLOY_TMP" 2>/dev/null
    echo ""

    rm -f "$DEPLOY_TMP"
else
    print_warning "デプロイ履歴が見つかりません"
fi

wait_for_enter

# ==============================================================================
# Phase 7: クリーンアップ（オプション）
# ==============================================================================

print_header "Phase 7: クリーンアップ（オプション）"

# ローカルブランチが残っている場合のみ削除
git checkout main
git pull origin main || true

if git branch --list "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    echo "ローカルのデモ用ブランチを削除しますか？ (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        git branch -D "$BRANCH_NAME" || true
        print_success "ローカルブランチ削除完了"
    fi
fi

if git stash list | grep -q "demo-backup"; then
    echo "退避した変更を復元しますか？ (y/n)"
    read -r restore_response
    if [[ "$restore_response" =~ ^[Yy]$ ]]; then
        git stash pop || true
        print_success "退避した変更を復元しました"
    fi
fi

# --- リソースグループ削除（デプロビジョニング） ---
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  デプロビジョニング: リソースグループの削除${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "リソースグループ「${RESOURCE_GROUP}」を削除しますか？"
echo -e "${RED}  ※ この操作により以下の全リソースが完全に削除されます:${NC}"

# 削除対象リソースの一覧表示
az resource list --resource-group "$RESOURCE_GROUP" \
    --query '[].{name:name, type:type}' -o tsv 2>/dev/null | while IFS=$'\t' read -r rname rtype; do
    echo -e "    ${RED}✗${NC} $rname ($rtype)"
done

echo ""
echo -e "${YELLOW}>>> リソースグループを削除しますか？ (yes/no)${NC}"
echo -e "${YELLOW}    ※ 削除する場合は「yes」と入力してください${NC}"
read -r delete_response
if [ "$delete_response" = "yes" ]; then
    print_info "リソースグループを削除中... (バックグラウンドで実行)"
    if az group delete --name "$RESOURCE_GROUP" --yes --no-wait; then
        print_success "リソースグループの削除を開始しました: $RESOURCE_GROUP"
        print_info "削除完了まで数分かかる場合があります"
        print_info "確認コマンド: az group show --name $RESOURCE_GROUP 2>/dev/null || echo '削除完了'"
    else
        print_warning "リソースグループの削除に失敗しました"
    fi
else
    print_info "リソースグループの削除をスキップしました"
    print_info "手動で削除する場合: az group delete --name $RESOURCE_GROUP --yes"
fi

# ==============================================================================
# 完了
# ==============================================================================

print_header "デモ完了"

echo "Control 3.4 Landing Zone基盤 CI/CDデモが完了しました。"
echo ""
echo "デモで確認した内容："
echo "  ✓ Landing Zone Bicepテンプレート（VNet, Subnet, NSG）"
echo "  ✓ 多層防御のNSGルール（Web→App→DBのみ許可）"
echo "  ✓ CI/CDワークフロー（GitHub Actions）"
echo "  ✓ CIによる自動検証（build, what-if）"
echo "  ✓ CDによる自動デプロイ"
echo ""
echo "スクリーンショット取得推奨箇所："
echo "  - Bicepテンプレート（main.bicep）"
echo "  - GitHub Secrets設定"
echo "  - CI失敗/成功のログ"
echo "  - Azure Portal: VNet, NSG, デプロイ履歴"
echo ""
print_success "お疲れ様でした！"
