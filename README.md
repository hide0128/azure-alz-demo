# Azure Landing Zone CI/CD Demo

Control 3.4 Landing Zone 基盤の自動デプロイメントとプロビジョニングツールのデモプロジェクト。

## 概要

Azure Landing Zone の基盤リソース（VNet・NSG・Subnet）を Bicep テンプレートで管理し、GitHub Actions による CI/CD パイプラインで自動デプロイを行います。

### 主な機能

- **Infrastructure as Code**: Bicep テンプレートによるインフラ管理
- **自動検証（CI）**: Pull Request 時の自動ビルドと What-If 分析
- **自動デプロイ（CD）**: main ブランチマージ時の自動デプロイ
- **多層防御**: Web/App/DB 層の NSG によるネットワークセグメンテーション
- **環境分離**: dev / stg / prd ごとに独立したパラメータファイル

## アーキテクチャ

```
Pull Request → CI (Bicep Build + What-If) → PR Merge → CD (Deploy to Azure)
```

デプロイされるリソース:

| リソース | 名前パターン | 説明 |
|---|---|---|
| Virtual Network | `vnet-lz-demo-{env}` | アドレス空間は環境ごとに異なる |
| Subnet: Web | `snet-web` | HTTPS/HTTP を外部から許可 |
| Subnet: App | `snet-app` | Web 層からのみ許可 |
| Subnet: DB | `snet-db` | App 層からのみ許可 |
| Subnet: Bastion | `AzureBastionSubnet` | 管理者専用 |
| NSG x3 | `nsg-lz-demo-{env}-{tier}` | 各層のセキュリティルール |

## ディレクトリ構造

```
.
├── .devcontainer/
│   ├── devcontainer.json       # Dev Container 設定
│   └── Dockerfile              # 開発環境イメージ定義
├── .github/
│   └── workflows/
│       ├── ci.yml              # CI ワークフロー（PR 時）
│       └── cd.yml              # CD ワークフロー（デプロイ）
├── bicep/
│   ├── main.bicep              # メイン Bicep テンプレート
│   ├── parameters.dev.json     # dev 環境パラメータ
│   ├── parameters.stg.json     # stg 環境パラメータ
│   └── parameters.prd.json     # prd 環境パラメータ
├── docs/
│   ├── demo-guide.md           # デモ手順の詳細ガイド
│   └── deprovisioning-guide.md # リソース削除手順
├── control34_landingzone_demo.sh  # CI/CD デモスクリプト
└── README.md
```

> `bicep/main.json`（ARM テンプレートのコンパイル済み出力）は `.gitignore` で管理対象外です。

## セットアップ

### 方法 A: Dev Container を使う（推奨）

Docker と VS Code があれば、ツールのインストール不要で開発環境が整います。

1. [Docker Desktop](https://www.docker.com/products/docker-desktop/) をインストール
2. VS Code に [Dev Containers 拡張機能](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) をインストール
3. VS Code でこのフォルダを開く
4. 右下のポップアップ「Reopen in Container」をクリック

詳細は、このリポジトリの親ディレクトリ（`/dev/docs/dev-environment.md`）を参照してください。

---

### 方法 B: ローカルにインストールする

**必要なツールとバージョン**:

| ツール | 最低バージョン | インストール |
|---|---|---|
| Azure CLI | 2.55.0+ | `brew install azure-cli` / [公式](https://aka.ms/installazurecli) |
| GitHub CLI | 2.40.0+ | `brew install gh` / [公式](https://cli.github.com/) |
| Bicep CLI | v0.40.2 | `az bicep install --version v0.40.2` |
| Git | 2.40.0+ | [公式](https://git-scm.com/) |

> スクリプト起動時にバージョンチェックが自動実行されます。

---

### Azure 認証設定

```bash
# Azure にログイン
az login --use-device-code

# サブスクリプション確認
az account show
```

### GitHub 認証設定

```bash
gh auth login
gh auth status
```

### Azure Service Principal の作成

GitHub Actions から Azure へアクセスするために必要です。

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az ad sp create-for-rbac \
  --name "github-actions-alz-demo" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-landingzone-demo \
  --sdk-auth
```

出力された JSON を GitHub Secrets に設定してください:

```bash
gh secret set AZURE_CREDENTIALS < azure-credentials.json
gh secret set RESOURCE_GROUP --body "rg-landingzone-demo"
```

### リソースグループの作成

```bash
az group create \
  --name rg-landingzone-demo \
  --location japaneast \
  --tags Environment=demo Project=landing-zone
```

## 使い方

### デモスクリプトの実行

```bash
./control34_landingzone_demo.sh
```

スクリプトは起動時に依存ツールのバージョンを自動チェックします。  
詳しいデモの流れは [docs/demo-guide.md](docs/demo-guide.md) を参照してください。

### 手動でデプロイする

```bash
# Bicep テンプレートの検証
az bicep build --file bicep/main.bicep
az bicep lint --file bicep/main.bicep

# デプロイ内容のプレビュー（dev 環境）
az deployment group what-if \
  --resource-group rg-landingzone-demo \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters.dev.json

# デプロイ実行（dev 環境）
az deployment group create \
  --resource-group rg-landingzone-demo \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters.dev.json
```

環境別パラメータファイル:

| 環境 | ファイル | VNet アドレス空間 |
|---|---|---|
| dev | `bicep/parameters.dev.json` | 10.0.0.0/16 |
| stg | `bicep/parameters.stg.json` | 10.1.0.0/16 |
| prd | `bicep/parameters.prd.json` | 10.2.0.0/16 |

### GitHub Actions の確認

```bash
gh run list --workflow=ci.yml
gh run list --workflow=cd.yml
gh run view <run-id> --log
```

## クリーンアップ

```bash
# リソースグループをまとめて削除
az group delete --name rg-landingzone-demo --yes --no-wait
```

詳細な手順は [docs/deprovisioning-guide.md](docs/deprovisioning-guide.md) を参照してください。

## トラブルシューティング

### Azure CLI 認証エラー

```bash
az login --use-device-code
az account list --output table
az account set --subscription "your-subscription-id"
```

### GitHub Actions 認証エラー

**`AADSTS7000215: Invalid client secret`**  
→ Service Principal を再作成し、`AZURE_CREDENTIALS` を再設定してください。

**`No subscriptions found`**  
→ Service Principal に Contributor ロールが割り当てられているか確認してください:
```bash
APP_ID=$(az ad sp list --display-name "github-actions-alz-demo" --query [0].appId -o tsv)
az role assignment list --assignee $APP_ID --output table
```

### Bicep ビルドエラー

```bash
# 詳細なエラー表示
az bicep build --file bicep/main.bicep --verbose

# Bicep CLI の更新
az bicep install --version v0.40.2
```

### コンテナが起動しない（Dev Container 使用時）

1. Docker Desktop が起動しているか確認
2. VS Code: `Ctrl+Shift+P` → `Dev Containers: Rebuild Container Without Cache`

## 参考資料

- [Azure Bicep ドキュメント](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [GitHub Actions ドキュメント](https://docs.github.com/actions)
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
