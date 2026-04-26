# Ubuntu 26.04 Custom for Orange Pi 5 / 5 Plus

自分好みにカスタマイズした、最新メインラインカーネル採用の Ubuntu イメージです。

## 特徴 (Features)
- **Kernel**: 自作カスタムカーネル (v7.0.x-rockchip)
  - `CONFIG_EXPERT=n` で安定性を確保
  - Rockchip RK3588 / RK3588S に最適化
  - 個人の使用環境に特化した最適化設定
- **OS**: Ubuntu 26.04 (Resolute)
- **軽量化**: 
  - 初期イメージサイズを 2GB 以下に抑えるため、**Snap アプリケーションをプリインストールしていません**。
  - 必要なアプリは起動後に手動で追加可能です。

## 使い方 (Usage)
1. Releases ページから `.img.xz` をダウンロードします。
2. SSD または microSD カードに書き込みます。

### 初期セットアップ (Initial Setup)
モデルによって起動時の挙動が異なります：

- **Orange Pi 5**: 
  初回起動時に GUI のセットアップ（oem-config）が開始されます。画面の指示に従ってユーザーを作成してください。
- **Orange Pi 5 Plus**: 
  セットアップウィザードが表示されない場合があります。その場合は以下でログインしてください。
  - **User**: `ubuntu` / **Pass**: `ubuntu`
  - ログイン後、すぐにパスワードの再設定が求められます。

### 推奨設定 (Recommended Commands)
デスクトップ環境を完全な状態にしたり、ブラウザを追加したりするには以下のコマンドを実行してください。

```bash
# デスクトップ環境を最新・標準状態にする
sudo apt update && sudo apt install ubuntu-desktop-minimal

# Firefox をインストールする
sudo snap install firefox
```

### オーディオ設定 
Audio outから音が出ない場合は、端末から `alsamixer` を起動し、`F6` キーで `Analog` または `rockchip,es8388` を選択して `Output 1` を６０〜６５に設定してください。

---
