# nonogram-app — Nonogram Daily (Pink Spider 퍼즐 앱 2호)

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![AdMob](https://img.shields.io/badge/AdMob-EA4335?logo=googleadmob&logoColor=white)](https://admob.google.com)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey?logo=android&logoColor=white)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue)](LICENSE)

인앱결제 없이 AdMob 광고만으로 운영하는 노노그램(그림 로직 퍼즐) 앱.
[sudoku-app](https://github.com/Pink-Spider/sudoku-app)의 공통 엔진과 코어 패키지 위에
노노그램 룰 패키지를 얹어 만든 두 번째 앱이다.

<p>
  <a href="https://apps.apple.com/app/id6811762171"><img src="docs/marketing/app-store-badge-ko-kr-black.svg" alt="App Store에서 다운로드" height="40" align="middle"></a>
  <a href="https://play.google.com/store/apps/details?id=io.pinkspider.nonogram"><img src="https://play.google.com/intl/ko/badges/static/images/badges/ko_badge_web_generic.png" alt="Google Play에서 다운로드" height="60" align="middle"></a>
</p>

## 구조 (Dart pub workspace)

```
packages/
  puzzle_engine/    룰 비의존 프레임워크: GridPuzzle, GameSession(undo/실수/힌트), DailySeed
  rules_nonogram/   노노그램 규칙: LineSolver(한 줄 추론), 유일해·난이도 판정, 도형 라이브러리, 시드 기반 생성기
  core_ads/         AdService 추상화 + AdMob 구현, UMP 동의, 적응형 배너, InterstitialGate(빈도 제어)
  core_analytics/   AnalyticsService / RemoteConfigService 추상화 (Firebase는 아직 미연결)
  core_ui/          테마, PuzzleColors, 공통 위젯
apps/
  nonogram/         Flutter 앱 (Riverpod, CustomPainter 보드, 데일리 퍼즐, 튜토리얼, 통계·스트릭, 4개 언어)
```

`puzzle_engine`과 `core_*`는 sudoku-app에서 복사해 왔다. 공유 패키지가 아니라서
한쪽을 고치면 다른 쪽에도 같은 수정을 넣고 `diff -rq`로 맞춘다.

## 시작하기 (Mac)

```bash
./scripts/bootstrap.sh        # pub get → android/ios 생성 → AdMob 앱ID·iOS 설정 패치 → gen-l10n → analyze → test
cd apps/nonogram
flutter run -t lib/main_dev.dart
```

`main_dev.dart`(테스트 광고 단위) / `main_prod.dart`(실제 광고 단위) 두 엔트리포인트로
플레이버를 나눈다. 실제 광고 단위 ID는 리포에 없다 — [docs/ad-units.md](docs/ad-units.md).

## 게임 설계

- **퍼즐은 그림에서 나온다.** 랜덤 비트맵은 풀고 나면 얼룩이라 보람이 없다.
  `ShapeLibrary`의 도형(현재 48개)에서 clue를 읽어 퍼즐을 만들고, 다 풀면 그림이 드러난다.
- **추측이 필요한 퍼즐은 내보내지 않는다.** 솔버에 탐색 폴백이 없다.
  라인 논리만으로 못 푸는 도형은 테스트(`shapes_test.dart`)에서 탈락한다.
- **난이도 = 보드 크기.** easy 5×5 / medium 10×10 / hard 15×15 / expert 20×20.
- **X 표시는 답이 아니라 메모다.** 빈 칸에 X를 남겨 둔 채로도 완성으로 판정한다.

새 도형은 `packages/rules_nonogram/tool/shape_lab.dart`에서 먼저 돌려 본다.
라인 논리가 멈추는 칸을 지도로 보여 준다.

```bash
cd packages/rules_nonogram
dart run tool/shape_lab.dart
```

## 광고 설계

- 리워드: 힌트(퍼즐당 무료 1회 후 광고), 실수 3회 소진 시 이어하기, "광고 보고 1시간 광고 제거"
- 전면: 퍼즐을 끝내고 나갈 때만. `InterstitialGate`가 2판마다·최소 120초 간격·세션 시작 60초 유예로 제어
- 배너: 하단 적응형, 광고 제거 시간 동안 숨김
- 위 숫자는 전부 `RemoteConfigKeys.defaults` 값이다
- 앱 코드는 `google_mobile_ads`를 직접 import하지 않는다 — `AdService`만 사용

광고 시작 순서(UMP 동의 → ATT → SDK 초기화)는
`apps/nonogram/lib/app/bootstrap.dart`의 `_startAds()`에 있다. sudoku-app과 같은
이유로 순서 자체가 요구사항이다.

## 스토어 아이덴티티

- 스토어 이름: **Nonogram Daily: Picture Cross**
- 부제(App Store): Reveal a picture every day
- 기기 표시 이름: Nonogram Daily / 번들 ID·패키지명: `io.pinkspider.nonogram`
- 개인정보처리방침: <https://pink-spider.github.io/nonogram-privacy/>
- **"Picross"·「ピクロス」는 닌텐도 상표라 쓰지 않는다.** en은 "Picture Cross",
  ja는 ノノグラム.

문구·설문 답변·에셋 규격은 [docs/store-listing.md](docs/store-listing.md).

## 릴리스

**릴리스 빌드는 반드시 실기기나 에뮬레이터에서 실행해 본다.** debug 빌드는 R8을
돌리지 않아서 릴리스에서만 나는 시작 크래시를 못 잡는다(sudoku-app이 이걸로
Play 심사에서 거부됐다).

```bash
cd apps/nonogram
flutter build apk --release -t lib/main_prod.dart $(tool/ad_units.sh)
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

스토어 에셋:

```bash
cd apps/nonogram
tool/screenshots.sh          # 지원 언어 전부, 1320x2868 (ASC 6.9" 규격)
tool/gen_store_assets.sh     # Play 아이콘 512 + 피처 그래픽 1024x500
```

iOS (App Store Connect API 키 필요):

```bash
scripts/upload_ios.sh [build-number]     # 빌드 → TestFlight 업로드
scripts/build_ios.sh [build-number]      # Transporter용 서명 IPA
```

같은 버전에 빌드 번호를 재사용할 수 없다. 올릴 때마다
`apps/nonogram/pubspec.yaml`의 `+N`을 올린다.

Android 서명은 [docs/android-signing.md](docs/android-signing.md),
Play 업로드는 fastlane으로 한다. 빌드 후 초안(draft)으로만 올라가고, 출시는 콘솔에서 직접 한다.

```bash
cd apps/nonogram/android
fastlane internal       # 내부 테스트 트랙
fastlane production     # 프로덕션 (초안)
```

서비스 계정 설정은 [docs/play-api-automation.md](docs/play-api-automation.md).

## 라이선스

[GPL-3.0](LICENSE). Copyright (c) 2026 Yungoo Park (Pink Spider).
