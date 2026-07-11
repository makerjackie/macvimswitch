# MacVimSwitch

> 이 프로젝트의 코드는 [macism](https://github.com/laishulu/macism) 부분을 제외하고 모두 AI가 생성했습니다. 작성자는 Swift를 모릅니다.

[中文](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [한국어](README_KO.md)

MacVimSwitch는 Vim 사용자와 중국어·일본어·한국어 등 CJK 입력기를 자주 전환하는 사용자를 위해 설계된 macOS 입력 소스 자동 전환 도구입니다. Esc 키로 노멀 모드로 돌아갈 때 입력기가 여전히 CJK 상태로 남아 있는 불편함을 없애 줍니다.

## 주요 기능

- 한 번 설치하면 여러 Vim 기반 애플리케이션의 한/영 전환 문제를 한꺼번에 해결할 수 있으며 설정도 매우 간단합니다. 이것이 다른 솔루션과 비교했을 때 가장 큰 장점입니다.
- Esc 키를 누르면 ABC 영어 입력 소스로 자동 전환되며, 동작시킬 애플리케이션을 여러 개 지정할 수 있습니다(예: VSCode, Terminal, Obsidian, Cursor, Xcode).
- Shift 키로 ABC 영어 입력 소스와 중국어·일본어·한국어·베트남어 등 원하는 입력 소스를 전환합니다.
  - 어떤 CJKV 입력기든 사용할 수 있습니다. 예: Sogou, iFlytek, WeChat, Google 일본어 입력기, 두벌식/세벌식 등.
  - 사용 전에 입력기 설정에서 "Shift로 중/영 전환"과 같은 옵션을 꺼 두면 충돌을 피할 수 있습니다.
- Shift 키를 사용하고 싶지 않다면, macOS 기본 기능인 CapsLock 짧은 클릭으로 입력 소스 전환, 길게 눌러 CapsLock을 사용할 수 있습니다.
- 추천: [inputsource.pro](https://inputsource.pro/)와 같은 앱을 함께 사용하면 더욱 편리합니다. 예를 들어 브라우저에서는 기본 입력기를 중국어로, Vim에서는 영어로 지정해 두면 수동 전환이 거의 필요 없습니다.
- 소개 영상: https://www.bilibili.com/video/BV1DRwTeKEcx/

<img width="383" alt="Image" src="https://github.com/user-attachments/assets/0eb4b7a0-c229-4334-b1ff-cd78dd477196" />

## v0.7.6 주요 변경 사항

- Shift가 macOS의 기본 “이전 입력 소스 선택” 단축키를 사용해 이전 CJKV 입력기와 텍스트 입력 세션을 복원합니다. 메뉴 막대는 바뀌었지만 실제 입력은 영어로 남는 문제를 수정했습니다.
- 업데이트 확인이 GitHub 익명 API 제한에 의존하지 않으며 최신 DMG를 직접 다운로드합니다.
- 릴리스는 Developer ID Application으로 서명되고 Apple 공증을 받습니다. Bundle ID는 `com.jackiexiao.macvimswitch`로 유지됩니다.
- v0.7.6 이후의 공식 서명 버전 간 업데이트에서는 보조 기능 권한을 반복해서 승인할 필요가 없습니다. 이전 ad-hoc 서명 버전에서 처음 이전할 때만 한 번 다시 승인해야 할 수 있습니다.

## 설치 방법

### 수동 설치
[GitHub Releases](https://github.com/Jackiexiao/macvimswitch/releases)에서 내려받아 직접 설치하세요.

### Homebrew 설치
```shell
brew tap Jackiexiao/tap
brew install --cask macvimswitch
```

## 사용 방법

1. 최초 실행:
   - 압축을 풀고 MacVimSwitch를 실행합니다.
   - 안내에 따라 보조 기능 권한을 부여합니다.
   - 시스템 설정 → 보안 및 개인 정보 보호 → 개인 정보 보호 → 보조 기능 으로 이동합니다.
   - MacVimSwitch를 추가하고 활성화합니다.
   - 앱을 다시 시작합니다(메뉴 막대에 아이콘이 표시됩니다).

2. 첫 설정 시 중요한 사항:
   - 입력기 설정에서 "Shift로 한/영 전환"과 같은 옵션을 꺼 두어 충돌을 피합니다.
   - 상태 표시줄 메뉴에서 원하는 CJK 입력기를 선택합니다.
   - macOS의 "이전 입력 소스 선택" 키보드 단축키가 활성화되어 있는지 확인합니다(기본적으로 활성화). "설정 → 키보드 → 단축키 → 입력 소스"에서 찾을 수 있습니다.
   - 단축키 조합은 원하는 대로 설정해도 됩니다. macism이 해당 값을 읽어 필요할 때 에뮬레이션으로 실행합니다. 단축키가 반드시 활성화되어 있어야 합니다.

3. 메뉴 막대 옵션:
   - 메뉴 막대의 키보드 아이콘을 클릭하면 다음 작업을 할 수 있습니다.
     - 사용 설명 보기
     - 선호하는 CJK 입력기 선택
     - Shift 키 전환 기능 켜기/끄기
     - Esc 키 전환을 적용할 앱 선택(여러 개 선택 가능. 기본으로 Terminal, VSCode, MacVim, Windsurf, Obsidian, Warp에서 동작)
     - 로그인 시 자동 실행 켜기/끄기
     - 앱 종료

## MacVimSwitch의 장점

다른 입력 소스 전환 솔루션과 비교했을 때 MacVimSwitch는 다음과 같은 이점이 있습니다.

1. 범용 호환성
   - VSCode, Terminal, Obsidian, Cursor, Windsurf, Warp 등 모든 앱에서 사용할 수 있습니다.
   - 앱별로 추가 설정이 필요 없습니다.
   - 에디터마다 별도의 플러그인을 설치할 필요도 없습니다.

2. 간편한 설정
   - 특정 앱에서만 동작하도록 제한할 수 있습니다.
   - Sogou, iFlytek, WeChat, Google 일본어 입력기, 두벌식/세벌식 등 원하는 CJK 입력기를 쉽게 지정할 수 있습니다.

3. 다른 솔루션과의 비교
- [이 글](https://jdhao.github.io/2021/02/25/nvim_ime_mode_auto_switch/)은 여러 Vim용 입력기 전환 도구를 정리했지만, 대부분 추가 설정이 필요하고 모든 앱에서 사용하기 어렵다는 단점이 있습니다.
- [smartim](https://github.com/ybian/smartim)은 Mac용 Vim(플러그인을 지원하는 버전)에서 동작하지만 여러 앱에서 사용할 수는 없습니다.
- [imselect](https://github.com/daipeihust/im-select)는 명령줄에서 입력기를 전환합니다. 여러 앱에서 사용하려면 각 앱에 추가 설정이 필요하고 때로는 지연이 발생합니다.
- [vim-xkbswitch](https://github.com/lyokha/vim-xkbswitch)는 Vim 플러그인으로, 여러 앱에서 사용하려면 역시 추가 설정이 필요합니다.
- Karabiner: 단축키를 자유롭게 지정할 수 있지만, 지연이 생기거나 설정이 번거로울 수 있습니다.

## 개발자 가이드

### 배포 절차

1. GitHub 저장소 생성
```bash
# 1. github.com/jackiexiao/macvimswitch 에 새 저장소 생성
# 2. 저장소를 클론하고 초기화
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```

2. 배포 파일 준비
```bash
# 필요한 파일 추가
git add macvimswitch.swift README.md README_CN.md LICENSE
git commit -m "Initial commit"
git push origin main
```

3. 릴리스 생성
```bash
# 버전에 태그 지정
git tag -a v1.0.0
git push origin v1.0.0
```
GitHub Actions 워크플로가 자동으로 다음을 수행합니다.
- 앱 빌드
- 앱(.app)과 소스(.tar.gz)가 포함된 릴리스 생성
- Homebrew formula 업데이트용 SHA256 값을 계산해 표시

4. Homebrew Tap 만들기
```bash
# 1. (없다면) github.com/jackiexiao/homebrew-tap 저장소 생성
# 2. 저장소 클론
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap

# 3. GitHub Release에 표시된 SHA256 값으로 macvimswitch.rb 업데이트
# 4. formula 커밋 및 푸시
git add macvimswitch.rb
git commit -m "MacVimSwitch formula를 v1.0.0으로 업데이트"
git push origin main
```

### 로컬 개발

로컬에서 빌드하고 테스트하려면:
```bash
./build.sh
pkill -f MacVimSwitch
# 수동 테스트 방법 1:
./dist/MacVimSwitch.app/Contents/MacOS/MacVimSwitch

# 수동 테스트 방법 2:
# dist/MacVimSwitch.app을 더블클릭해 실행하는 경우
# 첫 번째 실행: 기존 권한을 제거
open dist/MacVimSwitch.app
# 두 번째 실행: 권한을 부여
open dist/MacVimSwitch.app
# 세 번째 실행: 앱을 재시작하여 정상 권한 확보
open dist/MacVimSwitch.app
```

릴리스용 빌드:
```bash
./build.sh --create-dmg
tccutil reset All com.jackiexiao.macvimswitch # 권한 초기화
# open MacVimSwitch.dmg
```

`git push --tag v1.0.0`을 실행하면 GitHub Actions 워크플로가 자동으로 빌드를 수행합니다.

macOS에서 GitHub Actions 워크플로를 로컬로 디버깅하고 싶다면 다음을 사용할 수 있습니다.
```
brew install act
act -l
act push -e .github/workflows/push.event.json --container-architecture linux/amd64
```

### 기여하기

1. 저장소를 포크합니다.
2. 기능 브랜치를 생성합니다 (`git checkout -b feature/amazing-feature`).
3. 변경 사항을 커밋합니다 (`git commit -m '새로운 기능 추가'`).
4. 브랜치를 푸시합니다 (`git push origin feature/amazing-feature`).
5. Pull Request를 생성합니다.

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.

## 감사의 말

- 입력기 전환 솔루션을 제공한 [macism](https://github.com/laishulu/macism)
