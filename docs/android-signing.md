# Android 릴리스 서명

## ⚠️ 먼저 백업할 것

```
~/.pink-spider/secrets/nonogram/
  upload-keystore.jks    업로드 키
  key.properties         별칭과 비밀번호
  play-store-key.json    Play Developer API 서비스 계정 (docs/play-api-automation.md)
```

**리포 안이 아니라 홈 디렉터리에 있다.** 예전에는 `android/`에 두고 gitignore로
막았는데, `git clean -xdf`가 gitignore된 파일을 지운다. 빌드 산출물 정리 한 번에
키스토어가 날아가는 구조여서 리포 밖으로 뺐다. 덤으로 실수 커밋도 불가능해졌다.

이 맥이 죽으면 같이 사라진다. 1Password 같은 곳에 지금 넣어둘 것.
디렉터리 권한은 700, 파일은 600.

잃어버렸을 때: Play 앱 서명에 가입되어 있으면 Google에 업로드 키 재설정을
요청할 수 있다(앱 서명 키는 Google이 보관하므로 앱은 살아남는다). 가입되어
있지 않으면 **그 앱은 영영 업데이트할 수 없고** 새 패키지명으로 다시 출시해야
한다. 그래서 신규 앱은 Play 앱 서명에 반드시 가입한다(요즘은 기본값).

현재 키 지문(SHA-256):

```
8A:10:4B:AE:07:56:CA:E5:EF:C3:67:1F:14:AD:B4:05:FC:99:CB:F5:DF:69:BF:14:06:FA:1F:55:EE:5C:8E:4F
```

- 형식 PKCS12(JKS는 폐기 예정), RSA 2048, 별칭 `upload`
- 유효기간 10000일 (2054-01까지). Play는 2033-10 이후까지 유효할 것을 요구한다.
- 앱마다 별도 키를 쓴다. firedom 등 다른 앱 키를 재사용하지 않는다.

## 빌드

```bash
cd apps/nonogram
flutter build appbundle --release -t lib/main_prod.dart
# → build/app/outputs/bundle/release/app-release.aab
```

Play에는 APK가 아니라 **AAB**를 올린다. 파일이 50MB 정도로 크게 보이지만
모든 ABI가 들어 있기 때문이고, Play가 기기별로 쪼개서 배포하므로 실제 다운로드
용량은 그보다 훨씬 작다.

## 어떻게 연결돼 있나

`android/app/build.gradle.kts`가 `key.properties`를 세 곳에서 순서대로 찾는다:

1. `$NONOGRAM_SECRETS/key.properties` — CI나 다른 위치를 쓸 때
2. `~/.pink-spider/secrets/nonogram/key.properties` — 이 맥의 기본값
3. `android/key.properties` — 예전 위치. 아직 읽지만 새로 만들지 마라

찾으면 `signing: using <경로>`를 빌드 로그에 남긴다. 하나도 **없으면 디버그 키로
서명하고 경고만 남긴다** — 새로 클론했거나 시크릿이 없는 CI에서도 빌드는 되게
하기 위해서다. 대신 그 산출물은 Play에 못 올린다. 업로드가 "서명이 잘못됐다"고
거부되면 이 경고부터 확인할 것.

`key.properties` 형식:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/Users/<너>/.pink-spider/secrets/nonogram/upload-keystore.jks
```

`storeFile`은 **절대경로**로 쓴다. 예전엔 `android/app/` 기준 상대경로였는데
키스토어가 리포 밖으로 나가면서 바뀌었다.

### 서명 확인

빌드된 AAB가 정말 업로드 키로 서명됐는지 보는 게 가장 확실하다:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep SHA256
```

위의 지문과 다르면 디버그 키로 서명된 것이다.

## R8 (코드 축소)

릴리스 빌드는 `isMinifyEnabled`로 R8을 켠다. `app/proguard-rules.pro`에 세 덩어리:

- `com.google.android.gms.ads.**`, `com.google.android.ump.**` — 광고·UMP SDK가
  자기 클래스를 리플렉션으로 참조한다.
- `io.flutter.embedding.**` — 매니페스트와 생성 코드에서 참조된다.
- `-dontwarn com.google.android.play.core.**` — Flutter 임베딩이 쓰지도 않는
  지연 컴포넌트 API를 참조해서, 이게 없으면 R8이 "Missing class"로 **빌드를
  실패시킨다**. 실제로 처음 빌드가 여기서 깨졌다.

## 새 키가 필요할 때 (2호 앱 등)

```bash
cd apps/<앱>/android
PW="$(openssl rand -base64 24 | tr -d '/+=' | head -c 28)"
keytool -genkeypair -keystore app/upload-keystore.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
  -storepass "$PW" -keypass "$PW" \
  -dname "CN=Yungoo Park, OU=Pink Spider, O=Pink Spider, L=Seoul, C=KR"
cat > key.properties <<EOF
storePassword=$PW
keyPassword=$PW
keyAlias=upload
storeFile=upload-keystore.jks
EOF
chmod 600 key.properties app/upload-keystore.jks
```

만든 직후 `git check-ignore -v android/key.properties android/app/*.jks`로
무시되는지 확인하고, 바로 백업할 것.
