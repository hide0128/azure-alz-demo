# Azure Landing Zone CI/CD Demo

Control 3.4 Landing Zone基盤の自動デプロイメントとプロビジョニングツールのデモプロジェクト

## 📋 概要

このプロジェクトは、Azure Landing Zoneの基盤リソース（VNet、NSG、Subnet等）をBicepテンプレートで管理し、GitHub Actionsを使用したCI/CDパイプラインで自動デプロイを行うデモです。

### 主な機能

- **Infrastructure as Code**: Bicepテンプレートによるインフラ管理
- **自動検証（CI）**: Pull Request時の自動ビルドとWhat-If分析
- **自動デプロイ（CD）**: mainブランチマージ時の自動デプロイ
- **多層防御**: Web層、App層、DB層のNSGによるネットワークセグメンテーション

## 🏗️ アーキテクチャ

### デプロイされるリソース

- **Virtual Network (VNet)**: 10.0.0.0/16
  - Web Subnet: 10.0.1.0/24 (HTTPS/HTTP許可)
  - App Subnet: 10.0.2.0/24 (Web層からのみ許可)
  - DB Subnet: 10.0.3.0/24 (App層からのみ許可)
  - Bastion Subnet: 10.0.255.0/26
- **Network Security Groups (NSG)**: 各層のセキュリティルール

### CI/CDワークフロー

```
Pull Request → CI (Bicep Build + What-If) → PR Merge → CD (Deploy to Azure)
```

## 🚀 セットアップ

### 前提条件

- Azure CLI (`az`)
- GitHub CLI (`gh`)
- Bicep CLI (Azure CLIに含まれる)
- Bashシェル環境

#### ツールのインストール

**Azure CLI**:
```bash
# Linux/WSL
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# macOS
brew install azure-cli

# バージョン確認
az --version
```

**GitHub CLI**:
```bash
# Linux/WSL
sudo apt update
sudo apt install gh

# macOS
brew install gh

# バージョン確認
gh --version
```

**Bicep CLI**:
```bash
# Azure CLIに含まれているので追加インストール不要
# 最新版へのアップグレード
az bicep upgrade

# バージョン確認
az bicep version
```

#### 認証設定

**Azure CLI**:
```bash
# デバイスコード認証（推奨）
az login --use-device-code

# アカウント確認
az account show

# サブスクリプション切り替え（必要に応じて）
az account set --subscription "your-subscription-id"
```

**GitHub CLI**:
```bash
# GitHub認証
gh auth login

# 認証状態確認
gh auth status

# リポジトリの確認
gh repo view
```

### 環境変数の設定

スクリプトは以下の環境変数をサポートしています：

```bash
# リポジトリディレクトリ（デフォルト: カレントディレクトリ）
export REPO_DIR=/path/to/azure-alz-demo

# リソースグループ名（デフォルト: rg-landingzone-demo）
export RESOURCE_GROUP=your-resource-group-name
```

### Azure設定手順

#### 1. Azure Service Principalの作成

GitHub ActionsからAzureへアクセスするために、Service Principalを作成します。

```bash
# Azureにログイン
az login

# サブスクリプションIDを取得
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Service Principalを作成（Contributorロール付与）
az ad sp create-for-rbac \
  --name "github-actions-alz-demo" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-landingzone-demo \
  --sdk-auth

# 上記コマンドの出力（JSON形式）を保存してください
# この出力全体がAZURE_CREDENTIALSシークレットの値になります
```

**出力例**:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

#### 2. GitHub Secretsの設定

以下のSecretをGitHubリポジトリに設定してください。

**設定方法**: GitHubリポジトリ → Settings → Secrets and variables → Actions → New repository secret

| Secret名 | 説明 | 値 |
|---------|------|----|
| `AZURE_CREDENTIALS` | Service Principalの認証情報 | 上記コマンドで出力されたJSON全体 |
| `RESOURCE_GROUP` | デプロイ先リソースグループ名 | `rg-landingzone-demo` |

**GitHub CLIを使用した設定例**:

```bash
# AZURE_CREDENTIALSの設定（JSONをファイルから読み込む場合）
gh secret set AZURE_CREDENTIALS < azure-credentials.json

# または、直接JSON文字列を指定
gh secret set AZURE_CREDENTIALS --body '{"clientId":"...","clientSecret":"...",...}'

# リソースグループ名の設定
gh secret set RESOURCE_GROUP --body "rg-landingzone-demo"

# 設定確認
gh secret list
```

#### 3. リソースグループの作成

デプロイ先のリソースグループを事前に作成します。

```bash
az group create \
  --name rg-landingzone-demo \
  --location japaneast \
  --tags Environment=demo Project=landing-zone
```

#### 4. 設定の確認

```bash
# Service Principalの確認
az ad sp list --display-name "github-actions-alz-demo" --output table

# ロール割り当ての確認
az role assignment list \
  --all \
  --assignee $(az ad sp list --display-name "github-actions-alz-demo" --query [0].appId -o tsv) \
  --output table

# GitHub Secretsの確認
gh secret list
```

## 📖 使用方法

### デモスクリプトの実行

```bash
# リポジトリディレクトリに移動
cd /path/to/azure-alz-demo

# デモスクリプトを実行（カレントディレクトリを使用）
./control34_landingzone_demo.sh

# または、環境変数で指定
export REPO_DIR=/path/to/azure-alz-demo
export RESOURCE_GROUP=rg-custom-name
./control34_landingzone_demo.sh
```

### デモの流れ

1. **環境確認**: Azure CLI、GitHub CLIの認証確認
2. **リポジトリ確認**: ディレクトリ構造、Bicepテンプレート、ワークフローの確認
3. **ローカル検証**: Bicep Build、What-If Analysis
4. **CI失敗デモ**: 意図的なエラーでCI失敗を確認
5. **CI成功デモ**: エラー修正でCI成功を確認
6. **CDデプロイ**: PRマージ後の自動デプロイを確認
7. **クリーンアップ**: リソースグループの削除（オプション）

### 手動デプロイ

```bash
# Bicepテンプレートのビルド
az bicep build --file bicep/main.bicep

# What-If分析（変更内容のプレビュー）
az deployment group what-if \
  --resource-group rg-landingzone-demo \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters.json

# デプロイ実行
az deployment group create \
  --resource-group rg-landingzone-demo \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters.json
```

## 📁 ディレクトリ構造

```
.
├── .github/
│   └── workflows/
│       ├── ci.yml          # CI ワークフロー（PR時の検証）
│       └── cd.yml          # CD ワークフロー（デプロイ）
├── bicep/
│   ├── main.bicep          # メインBicepテンプレート
│   ├── main.json           # コンパイル済みARMテンプレート
│   └── parameters.json     # パラメータファイル
├── docs/
│   └── deprovisioning-guide.md  # デプロビジョニングガイド
├── control34_landingzone_demo.sh  # デモ実行スクリプト
└── README.md
```

## 🧪 テストとデバッグ

### Bicepテンプレートの検証

```bash
# 構文チェック
az bicep build --file bicep/main.bicep

# リンティング
az bicep lint --file bicep/main.bicep
```

### ワークフローのテスト

```bash
# CI実行状況の確認
gh run list --workflow=ci.yml

# CD実行状況の確認
gh run list --workflow=cd.yml

# 特定の実行ログを表示
gh run view <run-id>
```

## 🗑️ クリーンアップ

### リソースグループの削除

```bash
# 即座に削除
az group delete --name rg-landingzone-demo --yes

# バックグラウンドで削除
az group delete --name rg-landingzone-demo --yes --no-wait

# 削除状況の確認
az group show --name rg-landingzone-demo 2>/dev/null || echo "削除完了"
```

詳細は [デプロビジョニングガイド](docs/deprovisioning-guide.md) を参照してください。

## 🔧 トラブルシューティング

### Azure CLIの認証エラー

```bash
az login --use-device-code
az account show

# サブスクリプションが正しいか確認
az account list --output table

# 必要に応じてサブスクリプション切り替え
az account set --subscription "your-subscription-id"
```

### GitHub CLIの認証エラー

```bash
gh auth login
gh auth status

# 再認証が必要な場合
gh auth refresh
```

### GitHub Actions認証エラー

**エラー**: `Error: Login failed with Error: AADSTS7000215: Invalid client secret provided`

**原因**: AZURE_CREDENTIALSシークレットが正しく設定されていない、またはService Principalのシークレットが期限切れ

**解決方法**:
```bash
# Service Principalを再作成
az ad sp create-for-rbac \
  --name "github-actions-alz-demo" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-landingzone-demo \
  --sdk-auth

# 新しい出力をGitHub Secretに再設定
gh secret set AZURE_CREDENTIALS < azure-credentials.json
```

**エラー**: `Error: No subscriptions found for ***`

**原因**: Service Principalにサブスクリプションへのアクセス権限がない

**解決方法**:
```bash
# ロール割り当ての確認
APP_ID=$(az ad sp list --display-name "github-actions-alz-demo" --query [0].appId -o tsv)
az role assignment list --assignee $APP_ID --output table

# Contributorロールを割り当て
az role assignment create \
  --role Contributor \
  --assignee $APP_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-landingzone-demo
```

**エラー**: `AuthorizationFailed: The client does not have authorization to perform action`

**原因**: Service PrincipalにContributorロールが割り当てられていない

**解決方法**:
```bash
# リソースグループレベルでContributorロールを割り当て
APP_ID=$(az ad sp list --display-name "github-actions-alz-demo" --query [0].appId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az role assignment create \
  --role Contributor \
  --assignee $APP_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-landingzone-demo
```

### GitHub Secretsの設定ミス

```bash
# Secretsの一覧確認
gh secret list

# AZURE_CREDENTIALSの削除と再設定
gh secret remove AZURE_CREDENTIALS
gh secret set AZURE_CREDENTIALS < azure-credentials.json

# RESOURCE_GROUPの設定
gh secret set RESOURCE_GROUP --body "rg-landingzone-demo"

# 設定確認
gh secret list
```

### Bicepビルドエラー

**一般的なエラー**:
```bash
# 構文チェック
az bicep build --file bicep/main.bicep

# 詳細なエラー表示
az bicep build --file bicep/main.bicep --verbose
```

**エラー**: `BCP018: Expected the "=" character`
- リソース定義の構文エラー
- 不完全な行がないか確認

**エラー**: `BCP057: The name does not exist in the current context`
- 変数やパラメータの参照ミス
- スコープの確認

**Bicep CLIのアップグレード**:
```bash
az bicep upgrade
az bicep version
```

### リソースグループが削除中でエラー

```bash
# リソースグループの状態確認
az group show --name rg-landingzone-demo --query properties.provisioningState -o tsv

# 削除が完了するまで待機
while az group exists --name rg-landingzone-demo --output tsv; do
  echo "Waiting for deletion..."
  sleep 10
done

# 削除完了後に再作成
az group create --name rg-landingzone-demo --location japaneast
```

### GitHub Actionsワークフローのデバッグ

```bash
# ワークフロー実行ログの確認
gh run view <run-id> --log

# 失敗したジョブの確認
gh run view <run-id> --log-failed

# ワークフローの再実行
gh run rerun <run-id>

# 特定のジョブのみ再実行
gh run rerun <run-id> --job <job-id>
```

### Permissions エラー

**エラー**: `Error: Resource 'Microsoft.Resources/deployments' was disallowed by policy`

**解決方法**:
- Azure Policy の確認と調整
- 組織の管理者に権限を確認

**エラー**: `AuthorizationFailed: The client '***' does not have authorization`

**解決方法**:
```bash
# 適切なロールを割り当て
az role assignment create \
  --role Contributor \
  --assignee $APP_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-landingzone-demo
```

## 📚 参考資料

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [GitHub Actions Documentation](https://docs.github.com/actions)
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)

## 📝 ライセンス

このプロジェクトはデモ目的で作成されています。

## 🤝 コントリビューション

このプロジェクトはデモンストレーション用です。