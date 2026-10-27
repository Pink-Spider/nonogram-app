# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

노노그램(피크로스) 앱. 인앱결제 없이 AdMob 광고만으로 수익을 내는 Pink Spider
퍼즐 앱의 2호다. 1호는 `../sudoku-app`.

**엔진(`puzzle_engine`)과 코어(`core_ads`/`core_ui`/`core_analytics`)는
sudoku-app에서 복사해 왔다.** 같은 모노레포에 넣는 안도 있었지만 별도 리포로
갔다. 대신 **core 쪽 개선은 양쪽에 따로 반영해야 한다** — AdMob SDK 업그레이드,
UMP 정책 변경, 새 Play 요구사항이 오면 두 번 고쳐야 한다는 뜻이다.
네 패키지 모두 `lib`이 sudoku-app과 파일 단위로 동일하다(2026-10-27 확인).
고친 뒤에는 `diff -rq packages/<pkg>/lib ../sudoku-app/packages/<pkg>/lib`로 맞출 것.

## 현재 상태 (2026-10-27)

- **양대 스토어에 출시됐다** (0.1.0+3). App Store는 2026-09-16 공개
  (<https://apps.apple.com/app/id6811762171>), Play는 프로덕션 177개국
  (<https://play.google.com/store/apps/details?id=io.pinkspider.nonogram>).
  README의 스토어 배지가 이 두 링크를 쓴다.
- AdMob 앱 ID는 실제 값이다(`scripts/bootstrap.sh` 상단과 두 매니페스트).
  광고 단위 6개는 리포 밖 `ad-units.env`에 있다.
  두 앱 모두 AdMob 콘솔에서 스토어 리스팅에 연결했다(2026-10-27).
- 릴리스 빌드 스크립트(`fastlane build`, `upload_ios.sh`, `build_ios.sh`)는
  전부 `tool/ad_units.sh`를 거친다. 파일이 없으면 빌드가 실패한다 —
  prod가 조용히 Google 테스트 단위로 폴백해 수익 0으로 나가는 것을 막는다.
- Play 업로드용 서비스 계정 `nonogram-publisher@pink-spider-play.iam.gserviceaccount.com`
  (노노그램 전용)이 Play Console에서 Nonogram Daily 권한을 받았다(2026-10-27).
  `fastlane internal|production`으로 업로드할 수 있다. 실제 업로드는 아직 한 번도 안 해 봤다.
- **리포는 public이다**(2026-10-27). 비밀 값(키 ID, 광고 단위, 개인 이메일)을
  커밋하지 않는다. 히스토리에서 지우려면 리포를 다시 만들어야 했다.
- 서명 키는 있다(노노그램 전용, 스도쿠와 다른 키).
- **계정이 서비스마다 다르다.** Play Console은 `ceo@pink-spider.io`,
  AdMob은 `developer.ygpark@gmail.com`(Play 권한 없음). `docs/store-listing.md` 참고.

## 게임 설계

- **난이도 = 보드 크기.** easy 5×5 / medium 10×10 / hard 15×15 / expert 20×20.
  노노그램 난이도는 실제로 크기가 좌우한다. 5×5를 전문가용으로 만들 수는 없다.
- **퍼즐은 그림에서 나온다.** 랜덤 비트맵은 얼룩이라 풀어도 보람이 없다.
  `ShapeLibrary`에 크기별 도형이 있고, 거기서 clue를 읽어 퍼즐을 만든다.
- **추측이 필요한 퍼즐은 내보내지 않는다.** 솔버에 탐색 폴백을 일부러 안 넣었다.
  라인 논리로 못 풀면 그 도형은 버린다.

## 구조

루트 `pubspec.yaml`이 Dart pub 워크스페이스라 락파일이 루트 하나뿐이다.
패키지를 새로 만들면 루트 `workspace:` 목록에 넣어야 pub get이 잡는다.

- `packages/puzzle_engine` 순수 Dart. sudoku-app과 거의 같지만 **`PuzzleRule.isCorrect`
  훅을 추가했다** — 아래 "엔진 수정" 참고.
- `packages/rules_nonogram` 순수 Dart. 전부가 `LineSolver` 위에 서 있다.
  - `LineSolver` 한 줄의 clue + 현재 상태 → 확정 칸. 배치를 전부 열거하면
    20칸에서 터지므로 메모이제이션으로 "채움 가능/빈칸 가능"만 계산한다.
  - `NonogramSolver` 행↔열 번갈아 훑기. 유일해 검증과 난이도 판정.
  - `ShapeLibrary` 도형 48개(5×5 12 / 10×10 12 / 15×15 9 / 20×20 15).
  - `NonogramGenerator` 도형 선택 → clue 생성 → 풀리는지 확인. 시드 결정론.
  - `NonogramRule` `PuzzleRule` 구현.
- `packages/core_ads` 앱은 `AdService`만 쓴다(`google_mobile_ads` 직접 import 금지).
- `apps/nonogram` Riverpod 2. 보드는 `NonogramBoard` `CustomPainter` 하나.
- l10n: `flutter gen-l10n`, ARB는 `apps/nonogram/lib/l10n/`. en/ko/ja/de.
  **ja에 「ピクロス」, en에 "Picross"를 쓰지 않는다** — 닌텐도 상표다.
  ja는 ノノグラム, en은 "Picture Cross"를 쓴다.
- 앱 동작(수집 데이터, 광고, 기능)이 바뀌면 `docs/store-listing.md`와
  개인정보처리방침(`docs/privacy-policy.html`)을 함께 고친다.

## 셀 값

`Cell.unknown(0)` / `Cell.filled(1)` / `Cell.crossed(2)`.

`solution`에는 0과 1만 들어간다. **X 표시(2)는 답이 아니라 주석이다** — "여기는
비었다"는 플레이어의 기록이고, 노노그램은 X를 치면서 푸는 게임이다.

## 엔진 수정 — `PuzzleRule.isCorrect`

`GameSession.place`가 원래 `value == solution[index]`로 정답을 판정했다.
그러면 `crossed(2)`는 solution에 없는 값이라 **모든 X가 실수로 찍힌다.**

그래서 `PuzzleRule.isCorrect(index, value, solution)` 훅을 추가했다.
기본 구현은 기존과 같은 정확 일치라 스도쿠 동작은 그대로고,
`NonogramRule`이 `Cell.matchesSolution`으로 재정의한다.

**`isSolved`도 같은 훅을 탄다** (2026-09-14). 원래 `board == solution`
완전 일치였는데, 그러면 빈 칸에 X를 남겨둔 채로는 절대 완성이 안 된다 —
TestFlight 첫 실기기 테스트에서 바로 걸린 버그. X를 지워야 통과되는
증상이 보이면 이 판정이 훅을 안 타고 있는 것이다.

**sudoku-app의 puzzle_engine에도 같은 훅이 들어가 있다** — 원래는 여기서만
만들었고 문서만 "스도쿠에 먼저"라고 잘못 적혀 있었는데, 2026-09-14에 실제로
이식해서 두 엔진의 lib이 파일 단위로 동일해졌다. 엔진을 고치면 반드시
`diff -r`로 두 리포를 다시 맞출 것.

## 룰 인스턴스는 퍼즐 크기와 맞아야 한다

`PuzzleRule.size`는 인스턴스마다 고정인데 노노그램은 난이도마다 보드가 다르다.
`puzzleRuleProvider`가 주는 기본 인스턴스를 그대로 쓰면 size 10 룰이 5×5 보드를
훑다가 배열 밖을 읽는다. 그래서:

- `startNew`는 `NonogramRule.forDifficulty(difficulty)`로 만든다
- `resume`은 저장된 JSON의 `puzzle.size`를 먼저 읽어 그 크기로 만든다
  (`GamePersistence.loadSession`이 `PuzzleRule Function(int size)`를 받는다)

`GameSession`은 `rule.size`를 쓰지 않고 `puzzle.size`로 동작하므로 가변 크기가 문제없다.

## 도형 추가 규칙

`test/shapes_test.dart`가 게이트다. 새 도형은 전부 통과해야 한다:

- **라인 논리만으로 풀려야 한다** — 추측이 필요하면 탈락
- **밀도 20~85%** — 너무 비면 안 읽히고 너무 차면 추론할 게 없다
- **네 변 중 셋 이상에 닿아야 한다** — 안 그러면 그림이 여백에 떠 있고
  화면 가장자리에 `0` clue만 줄줄이 나온다

처음엔 네 변을 **전부** 강제했는데 그림이 뭉개졌다(고양이가 고양이로 안 보였다).
규칙이 그림을 망치면 규칙이 틀린 거다. 셋으로 완화했다.

도형을 바꾸면 데일리 퍼즐이 바뀌므로 `NonogramGenerator.algorithmVersion`을 올린다.

`packages/rules_nonogram/tool/shape_lab.dart`가 실험대다. 후보 도형을 넣고
돌리면 게이트 통과 여부와, 못 풀 경우 **라인 논리가 어느 칸에서 멈췄는지
지도로** 보여준다. shapes.dart에 넣기 전에 여기서 반복할 것.

## 릴리스 빌드는 반드시 기기에서 확인

`flutter analyze`와 테스트가 통과해도 **debug 빌드는 R8을 안 돌려서**
릴리스에서만 죽는 부류를 못 잡는다. sudoku-app이 이것 때문에 Play 심사에서
거부됐다(R8이 `androidx.work`의 Room 클래스를 난독화해 시작 즉시 크래시).
그 keep 규칙은 `android/app/proguard-rules.pro`에 이미 들어 있다.

```bash
cd apps/nonogram
flutter build apk --release -t lib/main_prod.dart $(tool/ad_units.sh)
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb logcat -c && adb shell am start -n io.pinkspider.nonogram/.MainActivity
adb shell pidof io.pinkspider.nonogram    # 비어 있으면 죽은 것
```

런처 아이콘도 눈으로 확인할 것. 스토어 등록정보와 다르면 "혼동을 야기하는
주장"으로 거부된다. `tool/gen_icons.sh`가 iOS와 Android를 모두 만든다.

## iOS 릴리스

표시 이름 **Nonogram Daily**, 번들 ID `io.pinkspider.nonogram`, 배포 타깃
iOS 15.0. App Store Connect가 15 미만 업로드를 거부하는데 flutter create
템플릿은 13.0을 내놓으므로 bootstrap이 pbxproj를 직접 패치한다
(`flutter build`는 pbxproj를 재생성하지 않는다).

- `scripts/upload_ios.sh [빌드번호]` — 빌드 + TestFlight 업로드. App Store
  Connect API 키 필요: `~/.appstoreconnect/private_keys/AuthKey_<ID>.p8` +
  `ASC_KEY_ID`/`ASC_ISSUER_ID`. 두 ID는 리포 밖 `asc.env`(시크릿 폴더)에 있고
  스크립트가 자동으로 읽는다. **리포가 public이라 ID 값을 리포에 적지 않는다.**
  아카이브가 "sandbox is not
  in sync with Podfile.lock"으로 죽으면 `(cd ios && pod install)` 후 재시도.
- **앱 레코드는 만들어져 있다**(2026-09-14, Apple ID 6811762171, 웹 UI에서
  생성 — API로는 못 만든다). TestFlight 내부 그룹 "Internal Testers"
  (자동 배포 켬, 테스터 2명 — 명단은 ASC에서 확인. 개인 이메일은 리포에 적지 않는다),
  빌드 3까지 올라가 있다(`apps/nonogram/pubspec.yaml`의 `0.1.0+3`).
  재업로드 때는 빌드번호만 올리면 된다.
- `scripts/build_ios.sh [빌드번호]` — Transporter용 서명 IPA. 같은
  버전+빌드번호는 재업로드가 거부되므로 올릴 때마다 빌드번호를 올린다.
- `tool/screenshots.sh [시뮬레이터]` — 지원 로케일 전부의 스토어 스크린샷을
  integration_test로 캡처해 `build/screenshots/`에 저장. 기본 기기는 6.9"
  요구사항(1320×2868)을 만족하는 iPhone 17 Pro Max. Play도 같은 파일을 받는다.
- `tool/gen_store_assets.sh` — Play 등록에 필요한 512 아이콘과 1024×500
  피처 그래픽(`build/store/`).
- `scripts/check_app_name.sh "이름"` — App Store 이름 선점 1차 확인.
  미국 스토어에 실제 출시된 앱만 보이므로 참고용이다.

## 시크릿

```
~/.pink-spider/secrets/nonogram/     (700)
  upload-keystore.jks                 업로드 키 — 잃으면 앱 업데이트 불가
  key.properties
  ad-units.env                        광고 단위 6개 (유출되면 AdMob 계정 정지 위험)
  play-store-key.json                 nonogram-publisher 서비스 계정 키 (프로덕션 업로드 가능)
  asc.env                             App Store Connect API 키 ID 2개 (upload_ios.sh)
```

**리포 밖에 둔다.** gitignore만으로는 `git clean -xdf`에 날아간다.
gradle과 Appfile이 `$NONOGRAM_SECRETS` → `~/.pink-spider/secrets/nonogram/` →
예전 리포 내 경로 순으로 찾는다.

서명 지문(SHA-256): `docs/android-signing.md`. 광고 단위 ID 발급·주입 방식:
`docs/ad-units.md`. Play 업로드 자동화(fastlane supply, 서비스 계정):
`docs/play-api-automation.md`. 스토어 문구·설문 답변·에셋 크기:
`docs/store-listing.md`.

## 명령

```bash
./scripts/bootstrap.sh                          # 최초 1회 (idempotent), analyze + 전체 테스트까지 돈다
flutter pub get                                 # 루트
flutter analyze                                 # 루트에서 워크스페이스 전체

# 테스트 — 순수 Dart 패키지는 dart test, Flutter 패키지는 flutter test
(cd packages/puzzle_engine && dart test)
(cd packages/rules_nonogram && dart test)
(cd packages/core_ads && flutter test)
(cd apps/nonogram && flutter gen-l10n && flutter test)

# 하나만
(cd packages/rules_nonogram && dart test test/shapes_test.dart)
(cd packages/rules_nonogram && dart test -n "<테스트 이름 일부>")
(cd apps/nonogram && flutter test test/streak_test.dart --plain-name "<이름>")

(cd packages/rules_nonogram && dart run tool/shape_lab.dart)   # 도형 실험대
(cd apps/nonogram && flutter run -t lib/main_dev.dart)
(cd apps/nonogram/android && fastlane production)   # 서비스 계정 키 있어야 동작
```

## 다음 단계 (우선순위 순)

1. 다음 Android 버전은 `fastlane internal`로 올려서 업로드 경로를 처음 검증한다.
2. 도형 추가는 출시 후에도 계속 (전 사이즈 두 자릿수까지 채웠지만
   많을수록 좋다). `tool/shape_lab.dart`로 실험.

완성 시 그림 공개(SolvedCard), 통계 화면, 데일리 스트릭은 구현됨.
스트릭의 "오늘 아직 안 풀었을 때" 규칙은 `features/stats/streak.dart`의
`currentStreak` 참고.
