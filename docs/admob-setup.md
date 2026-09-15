# AdMob 콘솔 설정 체크리스트

계정: **developer.ygpark@gmail.com** → https://apps.admob.com
콘솔 클릭은 사람이 해야 하지만, 만들 것과 붙여넣을 곳은 전부 아래에 있다.
순서대로 하면 된다. ID가 왜 이렇게 나뉘어 보관되는지는 [ad-units.md](ad-units.md).

## 0. 개인정보처리방침 URL 먼저

AdMob GDPR 메시지와 양쪽 스토어 등록 모두 공개 URL을 요구한다.
문서는 `docs/privacy-policy.html`에 있다. 호스팅은 GitHub Pages가 제일 싸다:

1. 공개 리포 `pink-spider/pink-spider.github.io` 생성
2. `privacy-policy.html`을 리포 루트에 복사해 푸시
3. URL: `https://pink-spider.github.io/privacy-policy.html`

이 리포 하나가 Pink Spider 앱 전부(스도쿠 포함)의 방침·`app-ads.txt`
호스팅을 겸할 수 있다. 스토어의 "개발자 웹사이트"도 이 도메인으로 적는다.

## 1. 앱 2개 생성

콘솔 → 앱 → 앱 추가. **아직 스토어에 없으므로 "앱이 스토어에 등록되어
있나요? → 아니요"**로 만들고, 출시 후 스토어 연결만 추가하면 된다.

| 플랫폼 | 앱 이름 | 만들면 받는 것 |
|---|---|---|
| Android | Nonogram Daily | 앱 ID `ca-app-pub-…~…` |
| iOS | Nonogram Daily | 앱 ID `ca-app-pub-…~…` |

**앱 ID 2개(물결표 `~` 포함) → `scripts/bootstrap.sh` 상단**의
`ADMOB_APP_ID_ANDROID` / `ADMOB_APP_ID_IOS`에 붙여넣고 **재실행**:

```bash
./scripts/bootstrap.sh   # AndroidManifest.xml과 Info.plist에 패치된다
```

## 2. 광고 단위 6개 생성

각 앱 → 광고 단위 → 광고 단위 추가. 형식과 이름:

| 앱 | 형식 | 이름(콘솔 표시용) |
|---|---|---|
| Android | 배너 | nonogram-android-banner |
| Android | 전면 | nonogram-android-interstitial |
| Android | 보상형 | nonogram-android-rewarded |
| iOS | 배너 | nonogram-ios-banner |
| iOS | 전면 | nonogram-ios-interstitial |
| iOS | 보상형 | nonogram-ios-rewarded |

보상형 설정은 기본값(리워드 수량/항목은 앱이 안 읽는다)이면 된다.

**단위 ID 6개(슬래시 `/` 포함) → 시크릿 파일**에:

```bash
mkdir -p ~/.pink-spider/secrets/nonogram
cat > ~/.pink-spider/secrets/nonogram/ad-units.env <<'EOF'
AD_UNIT_ANDROID_BANNER=ca-app-pub-XXXX/YYYY
AD_UNIT_ANDROID_INTERSTITIAL=ca-app-pub-XXXX/YYYY
AD_UNIT_ANDROID_REWARDED=ca-app-pub-XXXX/YYYY
AD_UNIT_IOS_BANNER=ca-app-pub-XXXX/YYYY
AD_UNIT_IOS_INTERSTITIAL=ca-app-pub-XXXX/YYYY
AD_UNIT_IOS_REWARDED=ca-app-pub-XXXX/YYYY
EOF
chmod 600 ~/.pink-spider/secrets/nonogram/ad-units.env
```

## 3. Privacy & messaging (안 하면 EEA에서 광고가 아예 안 나간다)

콘솔 → 개인 정보 보호 및 메시지:

- **GDPR 메시지** 생성 → 대상 앱에 두 앱 모두 체크, 개인정보처리방침
  URL은 0번의 것 → 게시
- **IDFA 메시지**(iOS ATT 설명 화면) 생성 → iOS 앱에 게시

앱 쪽 UMP 코드는 이미 들어 있다. 메시지를 게시해야 동의창이 뜨기
시작한다 — 테스트 ID로는 절대 안 뜨던 이유가 이것.

## 4. app-ads.txt (권장)

콘솔 → 앱 → app-ads.txt 안내에서 한 줄을 복사해
`pink-spider.github.io` 리포 루트의 `app-ads.txt`로 푸시:

```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```

스토어 등록정보의 개발자 웹사이트가 `https://pink-spider.github.io`여야
AdMob 크롤러가 찾는다. 없어도 광고는 나가지만 일부 입찰이 빠진다.

## 5. 검증

```bash
cd apps/nonogram
flutter run --release -t lib/main_prod.dart $(tool/ad_units.sh) \
  --dart-define=UMP_TEST_DEVICE_IDS=<기기 해시>
```

- `tool/ad_units.sh`가 에러 없이 6개를 출력하는지
- EEA 시뮬레이션(UMP 디버그 지역 설정)에서 동의창이 뜨는지
- 배너·전면·보상형이 **테스트 광고 라벨을 달고** 나오는지
  (기기 해시를 등록했으니 실단위여도 테스트 광고가 나온다 — 실광고를
  직접 탭하면 계정 정지 위험, [ad-units.md](ad-units.md) 참고)

새 단위는 트래픽이 좀 쌓여야 실광고가 채워진다(보통 몇 시간~하루).
