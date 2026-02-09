# デプロビジョニング手順書

## 概要

本手順書は、Azure Landing Zone デモ環境（Control 3.4）で作成されたリソースを削除・クリーンアップするための手順を記載しています。

## 対象リソース一覧

### Azure リソース（リソースグループ: `rg-landingzone-demo`）

| リソース種別 | リソース名 | 説明 |
|---|---|---|
| Virtual Network | `vnet-lz-demo-dev` | Landing Zone VNet（10.0.0.0/16） |
| Subnet | `snet-web` | Webティアサブネット（10.0.1.0/24） |
| Subnet | `snet-app` | Appティアサブネット（10.0.2.0/24） |
| Subnet | `snet-db` | DBティアサブネット（10.0.3.0/24） |
| Subnet | `AzureBastionSubnet` | Bastionサブネット（10.0.255.0/26） |
| NSG | `nsg-lz-demo-dev-web` | Webティア用NSG |
| NSG | `nsg-lz-demo-dev-app` | Appティア用NSG |
| NSG | `nsg-lz-demo-dev-db` | DBティア用NSG |

### GitHub リソース

| リソース種別 | 名前 | 説明 |
|---|---|---|
| Secret | `AZURE_CREDENTIALS` | Azure認証情報 |
| Secret | `RESOURCE_GROUP` | デプロイ先リソースグループ名 |
| Branch | `feature/demo-*` | デモ用featureブランチ |

---

## 手順

### 前提条件

- Azure CLI がインストール済みであること
- Azure にログイン済みであること（`az login`）
- GitHub CLI（`gh`）がインストール済みであること（GitHub リソース削除時）
- 対象サブスクリプションが選択済みであること

```bash
# Azure ログイン確認
az account show --query '{name:name, id:id}' -o table

# サブスクリプション切り替え（必要な場合）
az account set --subscription "<サブスクリプションID>"
```

---

### Step 1: Azure リソースの削除

#### 方法A: リソースグループごと削除（推奨）

リソースグループ内のすべてのリソースを一括で削除します。

```bash
# 削除前にリソース一覧を確認
az resource list --resource-group rg-landingzone-demo --output table

# リソースグループを削除（確認プロンプトあり）
az group delete --name rg-landingzone-demo
```

> **注意**: リソースグループを削除すると、グループ内のすべてのリソースが削除されます。デモ以外のリソースが含まれていないことを必ず事前に確認してください。

#### 方法B: リソースを個別に削除

リソースグループを残しつつ、デモで作成したリソースのみを削除します。依存関係があるため、以下の順序で削除してください。

```bash
RESOURCE_GROUP="rg-landingzone-demo"

# 1. VNet を削除（サブネットも一緒に削除される）
az network vnet delete \
  --resource-group $RESOURCE_GROUP \
  --name vnet-lz-demo-dev

# 2. NSG を削除
az network nsg delete --resource-group $RESOURCE_GROUP --name nsg-lz-demo-dev-web
az network nsg delete --resource-group $RESOURCE_GROUP --name nsg-lz-demo-dev-app
az network nsg delete --resource-group $RESOURCE_GROUP --name nsg-lz-demo-dev-db
```

#### 削除確認

```bash
# リソースが残っていないことを確認
az resource list --resource-group rg-landingzone-demo --output table

# デプロイ履歴の確認（参考情報として残る）
az deployment group list --resource-group rg-landingzone-demo --output table
```

---

### Step 2: デプロイ履歴の削除（任意）

リソースグループを残す場合、デプロイ履歴をクリーンアップできます。

```bash
RESOURCE_GROUP="rg-landingzone-demo"

# デプロイ履歴一覧を確認
az deployment group list --resource-group $RESOURCE_GROUP --query '[].name' -o tsv

# 個別に削除
az deployment group list \
  --resource-group $RESOURCE_GROUP \
  --query '[].name' -o tsv | while read name; do
  echo "削除中: $name"
  az deployment group delete --resource-group $RESOURCE_GROUP --name "$name"
done
```

---

### Step 3: GitHub リソースのクリーンアップ

#### 3.1 デモ用ブランチの削除

```bash
# リモートのデモ用ブランチを一覧表示
git branch -r | grep 'feature/demo-'

# リモートブランチを削除
git branch -r | grep 'feature/demo-' | sed 's/origin\///' | while read branch; do
  echo "削除中: $branch"
  git push origin --delete "$branch"
done

# ローカルのデモ用ブランチを削除
git branch | grep 'feature/demo-' | while read branch; do
  echo "削除中: $branch"
  git branch -D "$branch"
done
```

#### 3.2 GitHub Secrets の削除（任意）

デモ環境を完全に撤去する場合、GitHub Secretsも削除します。

```bash
# リポジトリの Secrets 一覧を確認
gh secret list

# Secrets を削除
gh secret delete AZURE_CREDENTIALS
gh secret delete RESOURCE_GROUP
```

> **注意**: Secrets を削除すると、CI/CD ワークフローが動作しなくなります。再度デモを実施する場合は再設定が必要です。

---

### Step 4: Azure サービスプリンシパルの削除（任意）

デモ用に作成したサービスプリンシパルが不要な場合は削除します。

```bash
# サービスプリンシパルの確認（名前で検索）
az ad sp list --display-name "<サービスプリンシパル名>" --query '[].{name:displayName, appId:appId}' -o table

# サービスプリンシパルの削除
az ad sp delete --id "<appId>"
```

---

### Step 5: ローカル環境のクリーンアップ（任意）

```bash
# Bicep ビルドで生成された ARM テンプレートを削除
rm -f bicep/main.json

# git stash の確認と削除
git stash list
git stash clear  # すべての stash を削除する場合
```

---

## 削除順序のまとめ

依存関係を考慮した推奨削除順序:

```
1. Azure リソース（VNet → NSG、またはリソースグループ一括削除）
2. デプロイ履歴（任意）
3. GitHub デモ用ブランチ
4. GitHub Secrets（任意）
5. Azure サービスプリンシパル（任意）
6. ローカル環境のクリーンアップ（任意）
```

## トラブルシューティング

### リソースの削除が失敗する場合

```bash
# リソースのロック状態を確認
az lock list --resource-group rg-landingzone-demo --output table

# ロックがある場合は先に削除
az lock delete --name <ロック名> --resource-group rg-landingzone-demo
```

### NSG の削除が失敗する場合

NSG がサブネットに関連付けられていると削除できません。先に VNet（サブネット）を削除してから NSG を削除してください。

### リソースグループの削除に時間がかかる場合

リソースグループの削除は非同期で処理されます。`--no-wait` オプションを使用してバックグラウンドで実行できます。

```bash
az group delete --name rg-landingzone-demo --no-wait
```

状態確認:

```bash
az group show --name rg-landingzone-demo --query 'properties.provisioningState' -o tsv
```
