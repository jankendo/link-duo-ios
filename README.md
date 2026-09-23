# LINK DUO for iOS

SwiftUIで作った2人協力型のワード推理ゲームです。iPhone 1台をPass & Playで共有して遊べます。ゲーム中の通信、アカウント、外部APIは使わず、設定・途中のゲーム・成績は端末内に保存します。

## ゲーム内容

- 1,616語を収録。STANDARD / MIXED / CUSTOMの単語パック
- 毎回25語と配置、A/Bそれぞれの秘密マップを新しく生成
- 各マップはTARGET 9、DANGER 3。TARGETは3つ重なり、全体のTARGETは15
- ルール説明、初回チュートリアル、名前・難易度設定、途中復帰、ゲーム履歴、成績
- 秘密マップは650ms以上の長押し中のみ表示。指を離すと受け渡し画面に切り替え
- iOS 17以上。iPhoneは縦画面、iPadは全向きに対応

## Xcodeで開く

`LINKDUO.xcodeproj` をXcodeで開き、`LINKDUO` schemeを選択してください。Release構成は署名なしに設定しています。

## GitHub Actions IPA

`iOS Release IPA` workflowはiOS Simulator上でゲームロジックテストを実行した後、`macos-15` runnerで次の設定を使ってiPhone向けRelease Archiveを作成します。

```sh
xcodebuild archive -project LINKDUO.xcodeproj -scheme LINKDUO \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Archive内のアプリを`Payload/LINKDUO.app`としてIPAにパッケージし、ZIP構造を検証してから、`LINK-DUO-iOS-IPA`という名前で30日間Actions Artifactとして保存します。GitHub Actionsの完了したworkflow runからartifactをダウンロードできます。

このIPAは署名されていないビルドです。Xcodeプロジェクトとソースを検証するための成果物で、実機へ直接インストールしたりApp Storeへ提出したりするにはApple署名が必要です。
