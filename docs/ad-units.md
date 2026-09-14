# AdMob 광고 단위 ID

실제 단위 ID는 **리포에 없다.** 빌드할 때 `--dart-define`으로 넣는다.

```bash
cd apps/nonogram
flutter build appbundle --release -t lib/main_prod.dart $(tool/ad_units.sh)
```

`fastlane production`과 `scripts/build_ios.sh`는 이미 이렇게 부른다.
직접 `flutter build`를 칠 때만 신경 쓰면 된다.

## 왜 뺐나

단위 ID는 비밀번호가 아니라 **식별자**여서 그 자체로는 아무 권한이 없다.
문제는 방향이다. 남이 이 ID를 자기 앱에 박아 넣고 봇으로 노출·클릭을 만들면,
그 무효 트래픽은 **우리 게시자 계정에 쌓이고 정지되는 것도 우리 계정이다.**
피해자가 신고할 방법도 마땅치 않다.

앱 바이너리를 뜯으면 어차피 나오지만, 그건 한 명씩 하는 일이고
공개 리포는 크롤러가 긁어간다. 난이도의 차이가 크다.

**AdMob 앱 ID**(`ca-app-pub-…~…`, 물결표)는 뺄 수 없다.
`AndroidManifest.xml`과 `Info.plist`에 있어야 SDK가 초기화된다.
앱 ID만으로는 광고를 요청할 수 없어서 위험도가 다르다.

## 파일

```
~/.pink-spider/secrets/nonogram/ad-units.env    (600)
```

서명 키와 같은 곳이다([docs/android-signing.md](android-signing.md)).
`git clean -xdf`에 날아가지 않고 실수로 커밋할 수도 없다.

```properties
AD_UNIT_ANDROID_BANNER=ca-app-pub-<publisher>/<id>
AD_UNIT_ANDROID_INTERSTITIAL=...
AD_UNIT_ANDROID_REWARDED=...
AD_UNIT_IOS_BANNER=...
AD_UNIT_IOS_INTERSTITIAL=...
AD_UNIT_IOS_REWARDED=...
```

`$NONOGRAM_SECRETS/ad-units.env`가 있으면 그쪽을 먼저 쓴다(CI용).

잃어버렸으면 AdMob 콘솔 → 앱 → 광고 단위에서 다시 읽으면 된다.
**계정은 `developer.ygpark@gmail.com`이다**(Play Console과 다르다).

## 없을 때 어떻게 되나

`prod` 플레이버가 **Google 테스트 단위로 폴백한다.** 앱은 정상 동작하고
광고도 나오는데 수익이 0이다. 조용히 망가지는 종류라서 이중으로 막았다:

1. `tool/ad_units.sh`가 파일이 없으면 non-zero로 끝난다 →
   `fastlane production`과 `build_ios.sh`가 거기서 멈춘다.
2. `AppConfig.hasRealAdUnits`가 6개 다 들어왔는지 본다.

새로 클론한 사람이나 시크릿 없는 CI에서도 **빌드 자체는 된다**(테스트 광고로).
스토어에 올라가는 경로만 막힌다. 서명 키를 다루는 방식과 같은 원칙이다.

## 자기 클릭 주의

실기기에서 prod를 테스트할 때는 반드시 기기 해시를 넘긴다:

```bash
flutter run --release -t lib/main_prod.dart $(tool/ad_units.sh) \
  --dart-define=UMP_TEST_DEVICE_IDS=<해시>
```

등록된 기기는 실제 단위에서도 테스트 광고만 받는다.
안 넘기고 직접 탭하면 무효 트래픽으로 계정이 정지될 수 있다.
