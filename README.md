# WiFi IP 자동 전환 도구 for MacOS

Hammerspoon을 이용한 macOS WiFi SSID 기반 자동 IP/DNS/게이트웨이 설정 도구입니다.
(아이폰 테더링시 IP를 정상적으로 잡지 못하는 경우 유용)

* 왜 Hammerspoon을 사용하는가?
  이외 다른 방법(IP/ARP 체크, 위치 변경 등)은 MacOS 보안 설정 또는 IP 변경 속도나 SSID 네이밍 파싱에 있어
  제한, 에러, 딜레이 등이 심해 속도면에서 빠르고 이질감 없는 방법을 선택하였습니다.


## 🌟 주요 기능

- **자동 IP 설정**: WiFi SSID 변경 시 미리 정의된 규칙에 따라 자동으로 IP 설정
- **유연한 규칙 시스템**: SSID별로 수동 IP 또는 DHCP 설정 가능
- **DNS 설정**: SSID별로 다른 DNS 서버 설정 가능
- **즉시 알림**: 설정 변경 시 macOS 알림으로 상태 확인

## 📋 시스템 요구사항

- **macOS**: 10.12 Sierra 이상
- **Hammerspoon**: 0.9.76 이상
- **관리자 권한**: 네트워크 설정 변경을 위해 필요
- **Location Services 권한 필수**: 정확한 SSID 네임 파싱을 위해 필요(미지정시 SSID 인식 불가, 스크립트 내 자동 추가 함수 포함)

## 🚀 설치 방법

### 1단계: Hammerspoon 설치

Hammerspoon이 설치되어 있지 않다면 먼저 설치하세요:

```bash
# Homebrew를 사용하는 경우
brew install --cask hammerspoon

# 또는 직접 다운로드
# https://www.hammerspoon.org/
```

### 2단계: 통합 설정 스크립트 🌟

```bash
# 설치 (기본값)
bash setup.sh

# 또는 명시적으로 설치
bash setup.sh install
```

> 💡**참고**:권한 설정이 안된 경우 자동으로 IP 변경되지 않습니다.<br>
특히 위치 권한 허용 윈도우는 스크립트에서 자동으로 호출되며 이를 거부하면 스크립트 작동 불가능합니다.<br>
(hs.location.start() 활용하여 위치 권한 강제 확보)

<br>
<p align="left">
<img width="295" height="372" alt="Screenshot 2025-09-05 at 10 00 29AM" src="https://github.com/user-attachments/assets/118d3fc2-959b-472e-8502-73380996d970" />
<img width="295" height="372" alt="Screenshot 2025-09-05 at 10 02 52AM" src="https://github.com/user-attachments/assets/4cc94a6b-f4bf-4615-bd12-8b409a60d86b" />
</p>
<br>

> 💡 **참고**: `setup.sh`가 자동으로 필요한 권한을 설정하고 설치를 진행하므로 별도의 `chmod` 명령이 필요하지 않습니다.

설치 스크립트는 다음 작업을 자동으로 수행합니다:
- ✅ 필수 파일 및 권한 확인 (`settings/` 폴더 내 파일들)
- ✅ WiFi 설정 스크립트를 `/usr/local/bin/`에 설치
- ✅ sudoers 권한 자동 설정 (패스워드 없이 네트워크 설정 변경)
- ✅ Hammerspoon 설정 파일 설치 (`settings/init.lua`)
- ✅ 기존 설정 자동 백업

## ⚙️ 설정 방법

설치 후 `~/.hammerspoon/init.lua` 파일을 편집하여 SSID별 규칙을 설정할 수 있습니다.

### 기본 설정 예시

```lua
local rules = {
  -- 1) iPhone 핫스팟 (SSID에 'iPhone'이 포함된 경우)
  {
    match = function(ssid)
      return ssid and ssid:lower():find("iphone", 1, true) ~= nil
    end,
    profile = {
      mode="manual",
      ip="172.20.10.5", 
      mask="255.255.255.0", 
      router="172.20.10.1",
      dns={"1.1.1.1", "8.8.8.8"}
    }
  },
  
  -- 2) 특정 SSID (office) 수정 후 사용
  {
    match = function(ssid) return ssid == "office" end,
    profile = {
      mode="manual",
      ip="192.168.153.105", 
      mask="255.255.255.0", 
      router="192.168.155.1",
      dns={"168.126.63.1", "168.126.63.2"}
    }
  },
  
  -- 3) 기타 모든 SSID는 DHCP
  {
    match = function(_) return true end,
    profile = { mode="dhcp" }
  }
}
```

### 새로운 규칙 추가하기

1. `~/.hammerspoon/init.lua` 파일 열기
2. `rules` 배열에 새로운 규칙 추가:

```lua
-- 회사 WiFi 설정 예시
{
  match = function(ssid) return ssid == "Company-WiFi" end,
  profile = {
    mode="manual",
    ip="10.0.1.100",
    mask="255.255.255.0",
    router="10.0.1.1",
    dns={"10.0.1.1", "8.8.8.8"}
  }
},
```

3. Hammerspoon 설정 다시 로드: `⌘ + Space` → "Hammerspoon" → "Reload Config"

### 규칙 매칭 옵션

```lua
-- 정확한 SSID 매칭
match = function(ssid) return ssid == "정확한이름" end

-- 부분 문자열 포함 (대소문자 구분 없음)
match = function(ssid) 
  return ssid and ssid:lower():find("부분문자열", 1, true) ~= nil 
end

-- 패턴 매칭 (정규식)
match = function(ssid) 
  return ssid and ssid:match("^Company%-.*") ~= nil 
end

-- 여러 SSID 중 하나
match = function(ssid) 
  local allowed = {"WiFi1", "WiFi2", "WiFi3"}
  for _, name in ipairs(allowed) do
    if ssid == name then return true end
  end
  return false
end
```

## 🔧 사용법

### 기본 사용법
1. **자동 실행**: Hammerspoon이 실행 중이면 WiFi 연결 시 자동으로 작동
2. **수동 테스트**: WiFi를 다른 네트워크로 변경해보세요
3. **상태 확인**: 설정 변경 시 macOS 알림이 표시됩니다
4. **로그 확인**: `/var/log/ssid-ip-switcher.log`에서 변경 이력 확인 가능

### 설정 스크립트 사용법
```bash
# 도움말 보기
bash setup.sh help

# 설치 (기본값)
bash setup.sh
bash setup.sh install

# 제거
bash setup.sh uninstall
```

## 🛠️ 문제 해결

### Hammerspoon이 작동하지 않는 경우

```bash
# Hammerspoon 프로세스 확인
ps aux | grep Hammerspoon

# 수동으로 Hammerspoon 실행
open -a Hammerspoon
```

### 권한 문제가 발생하는 경우

```bash
# sudoers 설정 확인
sudo cat /etc/sudoers.d/wifi-ip-switch

# 스크립트 권한 확인
ls -la /usr/local/bin/wifi-ip-switch.sh
```

### 설정이 적용되지 않는 경우

1. Hammerspoon 설정 다시 로드
2. `~/.hammerspoon/init.lua` 파일 문법 확인
3. Hammerspoon Console에서 오류 메시지 확인

### 네트워크 서비스 이름이 다른 경우

`settings/init.lua` 파일 상단의 SERVICE 변수를 확인하고 수정하세요:

```bash
# 사용 가능한 네트워크 서비스 목록 확인
networksetup -listallnetworkservices
```

```lua
-- init.lua에서 서비스 이름 변경
local SERVICE = "Wi-Fi"  -- 또는 "WiFi", "AirPort" 등
```

## 📁 파일 구조

```
WiFi-IP-Switch/
├── setup.sh                # 🌟 통합 설정 스크립트 (메인)
├── settings/               # 설정 파일들
│   ├── install.sh          # 설치 스크립트
│   ├── uninstall.sh        # 제거 스크립트
│   ├── wifi-ip-switch.sh   # 네트워크 설정 스크립트
│   └── init.lua            # Hammerspoon 설정 파일
└── 설치 설명서/            # 문서
    ├── README.md           # 상세 가이드
    └── INSTALL_GUIDE.md    # 빠른 설치 가이드
```

## 🔄 제거 방법

```bash
# 통합 스크립트로 제거 (권한 문제 없음)
bash setup.sh uninstall
```

또는 수동으로 제거:

```bash
# 파일 제거
sudo rm -f /usr/local/bin/wifi-ip-switch.sh
sudo rm -f /etc/sudoers.d/wifi-ip-switch

# Hammerspoon 설정 백업 후 제거
mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.backup
```

> 💡 **참고**: 모든 설정 파일들이 `settings/` 폴더에 정리되어 있어 관리가 용이합니다.

## 📝 로그 확인

```bash
# 설정 변경 이력 확인
tail -f /var/log/ssid-ip-switcher.log

# Hammerspoon 콘솔 로그 확인
# Hammerspoon → Help → Console
```

## ⚠️ 주의사항

- **보안**: sudoers 파일을 수정하므로 신뢰할 수 있는 환경에서만 사용하세요
- **백업**: 설치 전 네트워크 설정을 백업해두는 것을 권장합니다
- **테스트**: 중요한 환경에서 사용하기 전에 충분히 테스트하세요
- **수정**: 패키지 설치 후 조건 수정을 할 경우 ~/.hammerspoon/init.lua 파일을 직접 수정하세요
- **배포**: create-pkg.sh 사용하면 편하게 패키지 생성 가능합니다

## 🤝 기여하기

버그 리포트나 기능 제안은 이슈로 등록해주세요.

## 📄 라이센스

MIT License

---

**⭐ 도움이 되었다면 스타를 눌러주세요!**
