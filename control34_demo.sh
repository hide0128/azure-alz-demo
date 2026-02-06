#!/bin/bash
# ==============================================================================
# Control 3.4 CI/CD ライブデモスクリプト
# Azure Specialization Audit - Automated Deployment and Provisioning Tools
# ==============================================================================

set -e  # エラー時に停止

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 設定 - 必要に応じて変更
REPO_DIR="$HOME/dev/azure-alz-demo"
RESOURCE_GROUP="rg-cicd-demo"
BRANCH_NAME="feature/demo-$(date +%Y%m%d-%H%M%S)"

# ==============================================================================
# ヘルパー関数
# ==============================================================================

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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# ==============================================================================
# デモ開始
# ==============================================================================

clear
print_header "Control 3.4 CI/CD ライブデモ"

echo "このスクリプトは以下のデモを実行します："
echo ""
echo "  1. リポジトリ構成の確認"
echo "  2. Bicepテンプレートの確認"
echo "  3. CI/CDワークフローの確認"
echo "  4. ローカルでのBicep検証"
echo "  5. 意図的なエラーによるCI失敗デモ"
echo "  6. エラー修正によるCI成功デモ"
echo "  7. Azure環境へのデプロイ"
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
pwd
print_success "ディレクトリ: $(pwd)"

print_step "1.2" "Gitステータス確認"
git status
print_success "Gitリポジトリ確認完了"

print_step "1.3" "Azure CLI ログイン確認"
if az account show > /dev/null 2>&1; then
    ACCOUNT_NAME=$(az account show --query name -o tsv)
    print_success "Azureにログイン済み: $ACCOUNT_NAME"
else
    print_warning "Azureにログインしていません"
    echo "以下のコマンドでログインしてください："
    echo "  az login --tenant ec31467b-d661-4fea-864c-0585de871a9a --use-device-code"
    exit 1
fi

wait_for_enter

# ==============================================================================
# Phase 2: リポジトリ構成の確認
# ==============================================================================

print_header "Phase 2: リポジトリ構成の確認"

print_step "2.1" "ディレクトリ構造"
echo ""
echo "--- ディレクトリ構造 ---"
if command -v tree &> /dev/null; then
    tree -L 3 -a --dirsfirst -I '.git|node_modules'
else
    find . -type f \( -name "*.bicep" -o -name "*.json" -o -name "*.yml" \) | head -20
fi
echo ""

print_step "2.2" "Bicepファイル一覧"
echo ""
ls -la bicep/
echo ""

print_step "2.3" "ワークフローファイル一覧"
echo ""
ls -la .github/workflows/
echo ""

print_success "リポジトリ構成確認完了"
wait_for_enter

# ==============================================================================
# Phase 3: Bicepテンプレートの確認
# ==============================================================================

print_header "Phase 3: Bicepテンプレートの確認"

print_step "3.1" "main.bicep の内容（先頭50行）"
echo ""
echo "--- bicep/main.bicep ---"
head -50 bicep/main.bicep
echo "..."
echo ""

print_step "3.2" "parameters.json の内容"
echo ""
echo "--- bicep/parameters.json ---"
cat bicep/parameters.json
echo ""

print_step "3.3" "@secure() デコレーターの確認（機密情報保護）"
echo ""
grep -n "@secure()" bicep/main.bicep || echo "（@secure()が見つかりません）"
echo ""

print_success "Bicepテンプレート確認完了"
wait_for_enter

# ==============================================================================
# Phase 4: CI/CDワークフローの確認
# ==============================================================================

print_header "Phase 4: CI/CDワークフローの確認"

print_step "4.1" "CI ワークフロー (ci.yml)"
echo ""
echo "--- .github/workflows/ci.yml ---"
cat .github/workflows/ci.yml
echo ""

wait_for_enter

print_step "4.2" "CD ワークフロー (cd.yml)"
echo ""
echo "--- .github/workflows/cd.yml ---"
cat .github/workflows/cd.yml
echo ""

print_success "CI/CDワークフロー確認完了"
wait_for_enter

# ==============================================================================
# Phase 5: ローカルでのBicep検証
# ==============================================================================

print_header "Phase 5: ローカルでのBicep検証"

print_step "5.1" "Bicep Build（構文チェック）"
echo ""
echo "コマンド: az bicep build --file bicep/main.bicep"
echo ""
if az bicep build --file bicep/main.bicep; then
    print_success "Bicep Build 成功"
else
    print_error "Bicep Build 失敗"
fi
echo ""

print_step "5.2" "What-If Analysis（変更プレビュー）"
echo ""
echo "コマンド: az deployment group what-if ..."
echo ""
print_info "※ GitHub Secretsを使用するため、ローカルでは一部パラメーターが必要です"
echo ""

confirm_proceed

az deployment group what-if \
    --resource-group "$RESOURCE_GROUP" \
    --template-file bicep/main.bicep \
    --parameters bicep/parameters.json \
    --parameters vmAdminUsername=azureadmin \
    --parameters vmAdminPassword='Demo@Password123!' \
    || print_warning "What-If でエラーが発生しました（ポリシー制約の可能性）"

print_success "ローカル検証完了"
wait_for_enter

# ==============================================================================
# Phase 6: CI失敗デモ（意図的なエラー）
# ==============================================================================

print_header "Phase 6: CI失敗デモ（意図的なエラー）"

print_step "6.1" "mainブランチを最新化"
git checkout main
git pull origin main

print_step "6.2" "featureブランチを作成"
git checkout -b "$BRANCH_NAME"
print_success "ブランチ作成: $BRANCH_NAME"

print_step "6.3" "意図的なエラーを追加"
echo ""
echo "以下のエラーコードをmain.bicepに追加します："
echo ""
cat << 'ERRORCODE'
// === 意図的なエラー（デモ用） ===
resource invalid 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'test'
}
ERRORCODE
echo ""

confirm_proceed

cat >> bicep/main.bicep << 'EOF'

// === 意図的なエラー（デモ用） ===
resource invalid 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'test'
}
EOF

print_step "6.4" "ローカルでエラーを確認"
echo ""
echo "コマンド: az bicep build --file bicep/main.bicep"
echo ""
if az bicep build --file bicep/main.bicep 2>&1; then
    print_warning "エラーが発生しませんでした"
else
    print_success "期待通りエラーが発生しました"
fi
echo ""

print_step "6.5" "コミット＆プッシュ"
git add bicep/main.bicep
git commit -m "test: intentional error for CI failure demo"
git push origin "$BRANCH_NAME"

print_success "プッシュ完了"
echo ""
print_info ">>> GitHubでPull Requestを作成してください"
print_info ">>> URL: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/compare/main...$BRANCH_NAME"
echo ""
print_info ">>> CIが失敗し、PRがマージ不可になることを確認してください"

wait_for_enter

# ==============================================================================
# Phase 7: CI成功デモ（エラー修正）
# ==============================================================================

print_header "Phase 7: CI成功デモ（エラー修正）"

print_step "7.1" "エラーを修正（mainブランチから復元）"
git checkout main -- bicep/main.bicep

print_step "7.2" "修正後のBicep Build確認"
echo ""
if az bicep build --file bicep/main.bicep; then
    print_success "Bicep Build 成功"
else
    print_error "Bicep Build 失敗"
    exit 1
fi
echo ""

print_step "7.3" "修正をコミット＆プッシュ"
git add bicep/main.bicep
git commit -m "fix: remove intentional error"
git push origin "$BRANCH_NAME"

print_success "修正プッシュ完了"
echo ""
print_info ">>> GitHubでCIが成功し、PRがマージ可能になることを確認してください"
print_info ">>> PRをマージすると、CDが自動実行されます"

wait_for_enter

# ==============================================================================
# Phase 8: デプロイ確認（オプション）
# ==============================================================================

print_header "Phase 8: デプロイ確認（オプション）"

echo "PRをマージしましたか？"
confirm_proceed

print_step "8.1" "リソースグループのリソース確認"
echo ""
echo "コマンド: az resource list --resource-group $RESOURCE_GROUP"
echo ""
az resource list --resource-group "$RESOURCE_GROUP" --output table || print_warning "リソース取得に失敗"

print_step "8.2" "デプロイ履歴の確認"
echo ""
az deployment group list --resource-group "$RESOURCE_GROUP" --output table || print_warning "デプロイ履歴取得に失敗"

wait_for_enter

# ==============================================================================
# Phase 9: クリーンアップ（オプション）
# ==============================================================================

print_header "Phase 9: クリーンアップ（オプション）"

echo "デモ用ブランチを削除しますか？"
echo "  ローカル: $BRANCH_NAME"
echo "  リモート: origin/$BRANCH_NAME"
echo ""
echo -e "${YELLOW}>>> 削除しますか？ (y/n)${NC}"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    git checkout main
    git branch -D "$BRANCH_NAME" || true
    git push origin --delete "$BRANCH_NAME" || true
    print_success "ブランチ削除完了"
else
    print_info "ブランチは保持されます"
fi

# ==============================================================================
# 完了
# ==============================================================================

print_header "デモ完了"

echo "Control 3.4 CI/CDデモが完了しました。"
echo ""
echo "デモで確認した内容："
echo "  ✓ リポジトリ構成（Bicep, Workflows）"
echo "  ✓ Bicepテンプレート（@secure()による機密情報保護）"
echo "  ✓ CI/CDワークフロー（ci.yml, cd.yml）"
echo "  ✓ ローカルでのBicep検証（build, what-if）"
echo "  ✓ CIによる自動検証（失敗→修正→成功）"
echo "  ✓ CDによる自動デプロイ"
echo ""
echo "スクリーンショット取得推奨箇所："
echo "  - GitHub リポジトリ構成"
echo "  - GitHub Secrets 設定画面"
echo "  - ブランチ保護規則設定画面"
echo "  - CI失敗時のPR画面"
echo "  - CI成功時のPR画面"
echo "  - CD実行ログ"
echo "  - Azure Portal リソース一覧"
echo ""
print_success "お疲れ様でした！"
