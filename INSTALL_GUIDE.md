# 🚀 빠른 설치 가이드

## 1단계: Hammerspoon 설치 확인

```bash
# Hammerspoon이 설치되어 있는지 확인
ls /Applications/ | grep Hammerspoon

# 없다면 설치
brew install --cask hammerspoon
```

## 2단계: 통합 설정 스크립트

```bash
# 설치 (기본값)
bash setup.sh

# 제거
bash setup.sh uninstall

# 도움말
bash setup.sh help
```

## 3단계: Hammerspoon 실행

- Spotlight 검색 (⌘ + Space) → "Hammerspoon" 입력 → 실행
- 또는 Applications 폴더에서 Hammerspoon 실행

## 4단계: 테스트

1. WiFi를 다른 네트워크로 변경
2. 자동으로 IP가 설정되는지 확인
3. 알림이 표시되는지 확인

## ⚙️ 설정 변경

`~/.hammerspoon/init.lua` 파일을 편집하여 SSID별 규칙 수정

## 🔧 문제 해결

- **권한 오류**: `bash setup.sh`로 실행 (자동으로 권한 설정됨)
- **제거 시 권한 오류**: `bash setup.sh uninstall`로 실행
- **Hammerspoon 오류**: Hammerspoon Console에서 오류 확인
- **네트워크 설정 안됨**: 네트워크 서비스 이름 확인

## 📞 도움말

자세한 내용은 `README.md` 파일을 참조하세요.
