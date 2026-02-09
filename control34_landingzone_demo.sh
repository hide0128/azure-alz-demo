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
REPO_DIR="${REPO_DIR:-$HOME/dev/azure-landingzone-demo}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-landingzone-demo}"
BRANCH_NAME="feature/demo-$(date +%Y%m%d-%H%M%S)"

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

# ==============================================================================
# デモ開始
# ==============================================================================

clear
print_header "Control 3.4 Landing Zone基盤 CI/CDデモ"

echo "このスクリプトは以下のデモを実行します："
echo ""
echo "  1. リポジトリ構成の確認（Bicep, Workflows）"
echo "  2. Landing Zone Bicepテンプレートの確認"
echo "  3. ローカルでのBicep検証（build, what-if）"
echo "  4. CI失敗デモ（意図的なエラー）"
echo "  5. CI成功デモ（エラー修正）"
echo "  6. CDによる自動デプロイ"
echo "  7. Azure環境の確認"
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

wait_for_enter

# ==============================================================================
# Phase 2: リポジトリ構成の確認
# ==============================================================================

print_header "Phase 2: リポジトリ構成の確認"

print_step "2.1" "ディレクトリ構造"
echo ""
if command -v tree &> /dev/null; then
    tree -L 3 -a --dirsfirst -I '.git|node_modules'
else
    find . -type f \( -name "*.bicep" -o -name "*.json" -o -name "*.yml" \) | grep -v node_modules | head -20
fi
echo ""

print_step "2.2" "Bicepファイル一覧"
ls -la bicep/
echo ""

print_step "2.3" "ワークフローファイル一覧"
ls -la .github/workflows/
echo ""

wait_for_enter

# ==============================================================================
# Phase 3: Bicepテンプレートの確認
# ==============================================================================

print_header "Phase 3: Landing Zone Bicepテンプレートの確認"

print_step "3.1" "main.bicep - パラメーター定義"
echo ""
echo "--- Parameters ---"
grep -A2 "^param " bicep/main.bicep | head -30
echo ""

print_step "3.2" "main.bicep - NSG定義（多層防御）"
echo ""
echo "--- Network Security Groups ---"
grep -B2 -A10 "resource nsg" bicep/main.bicep | head -40
echo ""

print_step "3.3" "main.bicep - VNet/Subnet定義"
echo ""
echo "--- Virtual Network ---"
grep -B2 -A20 "resource vnet" bicep/main.bicep | head -30
echo ""

print_step "3.4" "parameters.json"
echo ""
cat bicep/parameters.json
echo ""

wait_for_enter

# ==============================================================================
# Phase 4: CI/CDワークフローの確認
# ==============================================================================

print_header "Phase 4: CI/CDワークフローの確認"

print_step "4.1" "CI ワークフロー (ci.yml)"
echo ""
cat .github/workflows/ci.yml
echo ""

wait_for_enter

print_step "4.2" "CD ワークフロー (cd.yml)"
echo ""
cat .github/workflows/cd.yml
echo ""

wait_for_enter

# ==============================================================================
# Phase 5: ローカルでのBicep検証
# ==============================================================================

print_header "Phase 5: ローカルでのBicep検証"

print_step "5.1" "Bicep Build（構文チェック）"
echo ""
if az bicep build --file bicep/main.bicep; then
    print_success "Bicep Build 成功"
else
    print_warning "Bicep Build 失敗"
fi
echo ""

print_step "5.2" "What-If Analysis（変更プレビュー）"
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
# Phase 6: CI失敗デモ
# ==============================================================================

print_header "Phase 6: CI失敗デモ（意図的なエラー）"

print_step "6.1" "mainブランチを最新化"
git stash --include-untracked || true
git checkout main
git pull origin main || true

print_step "6.2" "featureブランチを作成"
git checkout -b "$BRANCH_NAME"
print_success "ブランチ作成: $BRANCH_NAME"

print_step "6.3" "意図的な構文エラーを追加"
echo ""
echo "以下の不完全な構文を追加します:"
echo "  resource broken"
echo ""

confirm_proceed

echo "resource broken" >> bicep/main.bicep

print_step "6.4" "ローカルでエラーを確認"
echo ""
if az bicep build --file bicep/main.bicep 2>&1; then
    print_warning "エラーが発生しませんでした"
else
    print_success "期待通りエラーが発生しました（BCP018: Expected the \"=\" character）"
fi
echo ""

print_step "6.5" "コミット＆プッシュ"
git add bicep/main.bicep
git commit -m "test: intentional syntax error for CI failure demo"
git push origin "$BRANCH_NAME"

print_success "プッシュ完了"
echo ""
print_info ">>> GitHubでPull Requestを作成してください"
print_info ">>> CIが失敗することを確認してください"

wait_for_enter

# ==============================================================================
# Phase 7: CI成功デモ
# ==============================================================================

print_header "Phase 7: CI成功デモ（エラー修正）"

print_step "7.1" "エラーを修正（mainブランチから復元）"
git checkout main -- bicep/main.bicep

print_step "7.2" "修正後のBicep Build確認"
if az bicep build --file bicep/main.bicep; then
    print_success "Bicep Build 成功"
else
    print_warning "Bicep Build 失敗"
    exit 1
fi

print_step "7.3" "修正をコミット＆プッシュ"
git add bicep/main.bicep
git commit -m "fix: remove intentional error"
git push origin "$BRANCH_NAME"

print_success "修正プッシュ完了"
print_info ">>> GitHubでCIが成功することを確認してください"
print_info ">>> PRをマージするとCDが実行されます"

wait_for_enter

# ==============================================================================
# Phase 8: デプロイ確認
# ==============================================================================

print_header "Phase 8: デプロイ確認"

echo "PRをマージしましたか？"
confirm_proceed

print_step "8.1" "リソースグループのリソース確認"
echo ""
az resource list --resource-group "$RESOURCE_GROUP" --output table || print_warning "リソース取得失敗"

print_step "8.2" "VNet詳細確認"
echo ""
az network vnet list --resource-group "$RESOURCE_GROUP" --output table || true

print_step "8.3" "NSG一覧確認"
echo ""
az network nsg list --resource-group "$RESOURCE_GROUP" --output table || true

print_step "8.4" "デプロイ履歴確認"
echo ""
az deployment group list --resource-group "$RESOURCE_GROUP" --output table || true

wait_for_enter

# ==============================================================================
# Phase 9: クリーンアップ
# ==============================================================================

print_header "Phase 9: クリーンアップ（オプション）"

echo "デモ用ブランチを削除しますか？ (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    git checkout main
    git branch -D "$BRANCH_NAME" || true
    git push origin --delete "$BRANCH_NAME" || true
    print_success "ブランチ削除完了"
fi

if git stash list | grep -q "stash@{0}"; then
    echo "退避した変更を復元しますか？ (y/n)"
    read -r restore_response
    if [[ "$restore_response" =~ ^[Yy]$ ]]; then
        git stash pop || true
        print_success "退避した変更を復元しました"
    fi
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
