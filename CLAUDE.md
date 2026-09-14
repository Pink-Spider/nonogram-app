# CLAUDE.md — nonogram-app

노노그램(피크로스) 앱. 인앱결제 없이 AdMob 광고만으로 수익을 내는 Pink Spider
퍼즐 앱의 2호다. 1호는 `../sudoku-app`.

**엔진(`puzzle_engine`)과 코어(`core_ads`/`core_ui`/`core_analytics`)는
sudoku-app에서 복사해 왔다.** 같은 모노레포에 넣는 안도 있었지만 별도 리포로
갔다. 대신 **core 쪽 개선은 양쪽에 따로 반영해야 한다** — AdMob SDK 업그레이드,
UMP 정책 변경, 새 Play 요구사항이 오면 두 번 고쳐야 한다는 뜻이다.

## 현재 상태 (2026-09-14)

- `./scripts/bootstrap.sh` 통과. `flutter analyze` 0건, 테스트 150개 통과
  (puzzle_engine 14 / rules_nonogram 118 / core_ads 4 / apps_nonogram 14).
- 릴리스 APK가 에뮬레이터에서 **크래시 없이 실행**되고 배너 광고가 뜬다.
- **AdMob 앱 ID가 아직 Google 테스트 ID다.** 콘솔에 앱을 안 만들었다.
  수익 0이고 UMP 동의창도 안 뜬다. `scripts/bootstrap.sh` 상단에서 교체.
- **광고 단위 ID 없음.** prod가 조용히 테스트 단위로 폴백하므로 릴리스
  스크립트가 막는다(`tool/ad_units.sh`).
- Play Console·App Store 등록 전. 서비스 계정도 없다.
- 서명 키는 있다(노노그램 전용, 스도쿠와 다른 키).

## 게임 설계

- **난이도 = 보드 크기.** easy 5×5 / medium 10×10 / hard 15×15 / expert 20×20.
  노노그램 난이도는 실제로 크기가 좌우한다. 5×5를 전문가용으로 만들 수는 없다.
- **퍼즐은 그림에서 나온다.** 랜덤 비트맵은 얼룩이라 풀어도 보람이 없다.
  `ShapeLibrary`에 크기별 도형이 있고, 거기서 clue를 읽어 퍼즐을 만든다.
- **추측이 필요한 퍼즐은 내보내지 않는다.** 솔버에 탐색 폴백을 일부러 안 넣었다.
  라인 논리로 못 풀면 그 도형은 버린다.

## 구조

- `packages/puzzle_engine` 순수 Dart. sudoku-app과 거의 같지만 **`PuzzleRule.isCorrect`
  훅을 추가했다** — 아래 "엔진 수정" 참고.
- `packages/rules_nonogram` 순수 Dart. 전부가 `LineSolver` 위에 서 있다.
  - `LineSolver` 한 줄의 clue + 현재 상태 → 확정 칸. 배치를 전부 열거하면
    20칸에서 터지므로 메모이제이션으로 "채움 가능/빈칸 가능"만 계산한다.
  - `NonogramSolver` 행↔열 번갈아 훑기. 유일해 검증과 난이도 판정.
  - `ShapeLibrary` 도형 21개(5×5 8 / 10×10 6 / 15×15 4 / 20×20 3).
  - `NonogramGenerator` 도형 선택 → clue 생성 → 풀리는지 확인. 시드 결정론.
  - `NonogramRule` `PuzzleRule` 구현.
- `packages/core_ads` 앱은 `AdService`만 쓴다(`google_mobile_ads` 직접 import 금지).
- `apps/nonogram` Riverpod 2. 보드는 `NonogramBoard` `CustomPainter` 하나.
- l10n: `flutter gen-l10n`, ARB는 `apps/nonogram/lib/l10n/`. en/ko/ja/de.

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

**sudoku-app의 puzzle_engine에도 같은 훅이 들어가 있다**(거기서 먼저 고쳤다).
두 리포의 엔진을 비교할 일이 있으면 이 차이를 먼저 확인할 것.

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

## 시크릿

```
~/.pink-spider/secrets/nonogram/     (700)
  upload-keystore.jks                 업로드 키 — 잃으면 앱 업데이트 불가
  key.properties
  ad-units.env                        (아직 없음)
  play-store-key.json                 (아직 없음)
```

**리포 밖에 둔다.** gitignore만으로는 `git clean -xdf`에 날아간다.
gradle과 Appfile이 `$NONOGRAM_SECRETS` → `~/.pink-spider/secrets/nonogram/` →
예전 리포 내 경로 순으로 찾는다.

서명 지문(SHA-256): `docs/android-signing.md`.

## 명령

```bash
./scripts/bootstrap.sh                          # 최초 1회 (idempotent)
flutter pub get                                 # 루트
(cd packages/rules_nonogram && dart test)
(cd apps/nonogram && flutter gen-l10n && flutter test)
(cd apps/nonogram && flutter run -t lib/main_dev.dart)
(cd apps/nonogram/android && fastlane production)   # 광고 ID 있어야 동작
```

## 다음 단계 (우선순위 순)

1. AdMob 콘솔에 앱 생성 → 실제 앱 ID 2개를 `bootstrap.sh`에 넣고 재실행,
   광고 단위 6개를 `ad-units.env`에
2. **완성 시 그림 공개 화면** — 노노그램의 보상인데 아직 없다.
   지금은 다 풀어도 격자만 사라진다.
3. 도형 추가. 20×20이 3개뿐이라 expert 데일리가 사흘이면 반복된다.
4. Play Console / App Store 등록 → 서비스 계정 권한 → fastlane 업로드
5. 통계 화면, 데일리 스트릭
