markdown

# Ubuntu 26.04 Custom for Orange Pi 5 / 5 Plus

自分好みにカスタマイズした、最新メインラインカーネル採用の Ubuntu イメージです。

## 特徴 (Features)
- **Kernel**: 自作カスタムカーネル (v7.0.0-rockchip)
  - `CONFIG_EXPERT=n` で安定性を確保
  - Rockchip RK3588 に最適化
  - 私の使用する環境にどこどん最適化(汎用性なし）
- **OS**: Ubuntu 26.04 (Resolute)
- **軽量化**: 
  - 初期状態では **Snap アプリケーション（Firefox等）をインストールしていません**。
  - これによりイメージサイズを 2GB 以下に抑え、動作を軽量化しています。

## 使い方 (Usage)
1. Releases ページから `.img.xz` をダウンロードします。
2. SSD または microSD カードに書き込みます。
3. 初回起動時に GUI のセットアップ（oem-config）が開始されます。

### Snap アプリを使いたい場合
インターネットに接続後、以下のコマンドで手動インストールしてください。
```bash
sudo snap install firefox
```
---
