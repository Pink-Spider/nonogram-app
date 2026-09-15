# 스토어 등록 정보 (ASC + Play Console)

콘솔에 붙여넣을 문구와 설문 답변. sudoku-app의 같은 문서에서 형식을 가져왔다.
**앱 동작이 바뀌면 여기부터 고치고** 개인정보처리방침
(<https://pink-spider.github.io/nonogram-privacy/>)과 함께 맞출 것.

## 에셋

| 파일 | 크기 | 어디에 |
|---|---|---|
| `apps/nonogram/build/screenshots/<locale>-*.png` | 1320×2868 | ASC 6.9" / Play 폰 |
| iPad 11" 샷 | 1668×2420 | Play 7"·10" 태블릿 (**필수**) |
| iPad 13" 샷 | 2064×2752 | ASC iPad 13" (**필수**) |
| `apps/nonogram/build/store/icon-512.png` | 512×512 | Play 아이콘 |
| `apps/nonogram/build/store/feature-graphic.png` | 1024×500 | Play 피처 그래픽 (필수) |

```bash
cd apps/nonogram
tool/screenshots.sh                          # 폰 1320x2868
tool/screenshots.sh "iPad Pro 11-inch (M4)"  # Play 태블릿 1668x2420
tool/screenshots.sh "iPad Pro 13-inch (M4)"  # ASC iPad 2064x2752
tool/gen_store_assets.sh                     # Play 아이콘 + 피처 그래픽
```

스크린샷 하네스는 `NoopAdService`라 광고가 안 찍힌다(테스트 광고가 박힌
스크린샷은 심사에서 문제가 된다). 기기별 필수 규칙·해상도 함정은 sudoku-app
`docs/store-listing.md` 참고 — 전부 거기서 한 번 밟은 지뢰다.

## 공통

- 번들 ID / 패키지명: `io.pinkspider.nonogram`
- 지원 URL: <https://pink-spider.github.io/nonogram-privacy/>
- 개인정보처리방침 URL: <https://pink-spider.github.io/nonogram-privacy/>
- **개발자 웹사이트: `https://pink-spider.github.io`** — app-ads.txt
  (`pub-6329038356545416`, 이미 배포됨)의 유일한 연결 고리. 양쪽 리스팅에 필수.
- 카테고리: 게임 → 퍼즐 (Play) / 게임, 퍼즐·보드 (ASC)
- 저작권: `2026 Yungoo Park`
- 가격: 무료, 인앱결제 없음, 광고 포함

## 이름에 관한 주의

**ja에서 「ピクロス(Picross)」는 닌텐도 상표다.** 앱 내 타이틀과 스토어명
모두 ノノグラム 계열을 쓴다. en의 "Picross"도 마찬가지로 피하고
"Picture Cross"(일반명)를 쓴다.

## App Store Connect

**이름 (30자)** `Nonogram Daily: Picture Cross`
**부제 (30자)** `Reveal a picture every day`

**키워드 (100자, 쉼표 구분, 공백 없이)**

```
nonogram,picture,cross,griddler,logic,puzzle,pixel,daily,brain,offline,hanjie,picgrid,free,zen
```

**프로모션 텍스트 (170자)**

```
Every puzzle hides a picture. Solve with pure logic, watch it appear,
and come back tomorrow for a new daily challenge. No sign-up, plays
offline.
```

**설명**

```
Nonogram Daily is the classic picture-cross puzzle: use the numbers to
fill the right squares, and a hidden picture appears.

EVERY PUZZLE IS A PICTURE
No random noise. Every board is a hand-drawn picture — solve it and see
what you drew, from hearts and boats to owls and lighthouses.

A NEW PUZZLE EVERY DAY
Everyone gets the same daily challenge, so you can compare how you did.

FOUR BOARD SIZES
5x5 to learn, 10x10 and 15x15 to relax, 20x20 for experts. Every puzzle
is solvable by pure logic — no guessing, ever.

HINTS THAT TEACH
Stuck? A hint points at a line and explains what the numbers prove, so
you finish knowing something you did not know before.

BUILT FOR COMFORTABLE PLAY
- Drag to paint several squares in one stroke
- X marks for squares you know are blank
- Undo, erase, and mistake tracking
- A hands-on tutorial if nonograms are new to you
- Stats and a daily streak
- Light and dark themes, automatic save

FREE AND OFFLINE
No account, no sign-up, and no internet needed to play.

Ads keep the app free. Watch one if you want an extra hint, another
chance after running out of mistakes, or an hour with no ads at all.
```

## Google Play Console

**앱 이름 (30자)** `Nonogram Daily: Picture Cross`

**간단한 설명 (80자)** — `new`/`free` 같은 홍보성 단어 금지(sudoku가 경고 받음)

```
Picture-cross logic puzzles. Solve with the numbers and reveal the picture.
```

**자세한 설명** — ASC 설명과 동일.

## 현지화 문구

### 한국어

- 이름 `노노그램 데일리: 네모로직`
- 부제 `매일 그림 하나를 완성하세요`
- 간단한 설명 `숫자로 푸는 네모로직. 논리로 칸을 채우면 그림이 나타납니다.`
- 키워드 `노노그램,네모로직,로직,퍼즐,그림,픽셀,데일리,두뇌,오프라인,논리`

```
노노그램 데일리는 클래식 네모로직(노노그램) 퍼즐입니다. 숫자를 단서로
알맞은 칸을 칠하면 숨은 그림이 나타납니다.

모든 퍼즐이 그림입니다
무작위 패턴이 아닙니다. 모든 보드는 사람이 그린 그림이고, 다 풀면 하트,
돛단배, 부엉이, 등대 같은 그림이 공개됩니다.

매일 새로운 퍼즐
전 세계 이용자가 같은 오늘의 퍼즐을 풉니다.

4가지 보드 크기
입문용 5x5부터 전문가용 20x20까지. 모든 퍼즐은 추측 없이 순수한 논리만으로
풀리도록 검증되어 있습니다.

가르쳐 주는 힌트
막히면 힌트가 줄을 짚어 주고, 숫자가 무엇을 증명하는지 설명합니다.

편안한 플레이
- 드래그로 여러 칸을 한 번에 칠하기
- 비어 있다고 확신하는 칸에는 X 표시
- 되돌리기, 지우기, 실수 횟수 표시
- 노노그램이 처음이어도 손잡고 알려주는 튜토리얼
- 통계와 데일리 스트릭
- 라이트/다크 테마, 자동 저장

무료, 오프라인
계정도 가입도 필요 없고 인터넷 없이 즐길 수 있습니다.

광고 덕분에 앱을 무료로 유지합니다. 힌트를 더 받거나, 실수를 모두 쓴 뒤
이어서 하거나, 1시간 동안 광고를 끄고 싶을 때만 시청하면 됩니다.
```

### 日本語

- 名前 `ノノグラム デイリー: お絵かきロジック`
- サブタイトル `毎日ひとつ、絵を完成させよう`
- 簡単な説明 `数字を手がかりに解くお絵かきロジック。解くと絵が現れます。`
- キーワード `ノノグラム,お絵かきロジック,ロジック,パズル,イラストロジック,脳トレ,オフライン,数字`

```
ノノグラム デイリーは、クラシックなお絵かきロジック(ノノグラム)パズル
です。数字を手がかりに正しいマスを塗ると、隠された絵が現れます。

すべてのパズルが絵になる
ランダムな模様ではありません。どの盤面も手描きの絵で、解き終えると
ハートやヨット、フクロウ、灯台などの絵が完成します。

毎日新しい問題
世界中のプレイヤーが同じ「今日の問題」に挑戦します。

4つの盤面サイズ
入門の5x5からエキスパートの20x20まで。すべての問題は推測なし、
純粋なロジックだけで解けることを検証済みです。

教えてくれるヒント
行き詰まったら、ヒントが行や列を示し、数字が何を証明するのかを説明します。

快適に遊べる工夫
- ドラッグで複数のマスを一気に塗れる
- 空白と確信したマスにはX印
- 元に戻す、消去、ミス回数の表示
- 初めてでも安心のチュートリアル
- 統計と連続クリア記録
- ライト/ダークテーマ、自動保存

無料・オフライン
アカウント登録は不要で、インターネットがなくても遊べます。

広告のおかげでアプリを無料で提供できます。ヒントの追加、ミス超過後の
コンティニュー、1時間の広告非表示が必要なときだけご覧ください。
```

### Deutsch

- Name `Nonogramm Daily: Bilderrätsel`
- Untertitel `Jeden Tag ein Bild enthüllen`
- Kurzbeschreibung `Nonogramm-Logikrätsel. Mit den Zahlen lösen und das Bild enthüllen.`
- Keywords `nonogramm,bilderrätsel,logik,rätsel,pixel,täglich,gehirn,offline,griddler,puzzle`

```
Nonogramm Daily ist das klassische Bilderrätsel: Nutzen Sie die Zahlen,
um die richtigen Felder zu füllen, und ein verborgenes Bild erscheint.

JEDES RÄTSEL IST EIN BILD
Kein zufälliges Rauschen. Jedes Brett ist ein gezeichnetes Bild — lösen
Sie es und sehen Sie Herzen, Boote, Eulen oder Leuchttürme entstehen.

JEDEN TAG EIN NEUES RÄTSEL
Alle bekommen dasselbe Tagesrätsel.

VIER BRETTGRÖSSEN
5x5 zum Lernen, 10x10 und 15x15 zum Entspannen, 20x20 für Experten.
Jedes Rätsel ist rein logisch lösbar — niemals raten.

TIPPS, DIE ETWAS BEIBRINGEN
Wenn Sie nicht weiterkommen, zeigt ein Tipp die Reihe und erklärt, was
die Zahlen beweisen.

ANGENEHM ZU SPIELEN
- Mehrere Felder mit einer Wischgeste füllen
- X-Markierungen für sicher leere Felder
- Rückgängig, Löschen und Fehleranzeige
- Ein Tutorial zum Mitmachen für Neulinge
- Statistiken und Tagesserie
- Helles und dunkles Design, automatisches Speichern

KOSTENLOS UND OFFLINE
Kein Konto, keine Anmeldung, keine Internetverbindung nötig.

Werbung hält die App kostenlos. Sehen Sie eine an, wenn Sie einen
zusätzlichen Tipp möchten, nach aufgebrauchten Fehlern weiterspielen
wollen oder eine Stunde ohne Werbung wünschen.
```

## App Store: 앱 개인정보 / Play: 데이터 보안 / 등급

**sudoku와 완전히 동일하다** (같은 SDK 구성, 계정 없음, Firebase 없음):

- ASC 앱 개인정보: 추적 **예**. 대략적 위치·기기 ID·제품 상호작용·광고 데이터,
  전부 `타사 광고` / `신원에 연결 안 됨` / `추적 목적으로 사용됨`.
- 연령 등급 4+ (광고만 "예").
- Play 데이터 보안: 수집 예(AdMob), 제3자 공유 예, 전송 중 암호화 예,
  삭제 요청은 해당 없음(계정 없음). 위치(대략)·앱 상호작용·기기 ID,
  목적은 광고 또는 마케팅.
- Play 광고 ID 선언: **예**, 목적 광고 또는 마케팅만.
- 광고 포함 예, 타겟 연령 13+ (아동 대상 아님), 콘텐츠 등급 전체 이용가.

## 계정

- **Play Console: `ceo@pink-spider.io`** (developer.ygpark@gmail.com은 권한 없음)
- **AdMob: `developer.ygpark@gmail.com`**
- App Store Connect: ParkYungoo (팀 Z53YTTRR32)

## 제출 전 체크 (sudoku 거부 이력에서)

- 릴리스 APK를 기기/에뮬레이터에서 실행 확인 (R8 크래시는 debug에서 재현 불가)
- 런처 아이콘·이름이 스토어와 일치하는지 눈으로 확인
- AdMob 앱을 만들었으면 리스팅 공개 후 "스토어 추가"로 연결해야 광고 제한이 풀린다
