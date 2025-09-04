#!/bin/bash
# macOS .pkg 패키지 생성 스크립트
# WiFi IP 자동 전환 도구를 표준 macOS 설치 패키지로 생성

set -euo pipefail

# 색상 코드
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# 버전 정보
VERSION="1.0.0"
PACKAGE_NAME="WiFi-IP-AutoSwitch"
IDENTIFIER="com.mst.wifi-ip-autoswitch"

echo "=========================================="
echo "WiFi IP 자동 전환 - .pkg 패키지 생성"
echo "버전: $VERSION"
echo "=========================================="
echo

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/pkg-build"
PAYLOAD_DIR="$BUILD_DIR/payload"
SCRIPTS_DIR="$BUILD_DIR/scripts"
RESOURCES_DIR="$BUILD_DIR/resources"

# 빌드 디렉토리 정리 및 생성
log_info "빌드 디렉토리 준비 중..."
rm -rf "$BUILD_DIR"
mkdir -p "$PAYLOAD_DIR"
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$RESOURCES_DIR"

# 1. Payload 구성 (설치될 파일들)
log_info "Payload 구성 중..."

# /usr/local/bin에 설치될 파일들
mkdir -p "$PAYLOAD_DIR/usr/local/bin"
cp "$SCRIPT_DIR/settings/wifi-ip-switch.sh" "$PAYLOAD_DIR/usr/local/bin/"
chmod +x "$PAYLOAD_DIR/usr/local/bin/wifi-ip-switch.sh"

# GUI Uninstaller 앱 생성
mkdir -p "$PAYLOAD_DIR/Applications/Utilities/WiFi IP Uninstaller.app/Contents/MacOS"
mkdir -p "$PAYLOAD_DIR/Applications/Utilities/WiFi IP Uninstaller.app/Contents/Resources"

# Info.plist 생성
cat > "$PAYLOAD_DIR/Applications/Utilities/WiFi IP Uninstaller.app/Contents/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WiFi IP Uninstaller</string>
    <key>CFBundleIdentifier</key>
    <string>com.mst.wifi-ip-uninstaller</string>
    <key>CFBundleName</key>
    <string>WiFi IP Uninstaller</string>
    <key>CFBundleDisplayName</key>
    <string>WiFi IP Uninstaller</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.12</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST_EOF

# GUI 실행 스크립트 생성
cat > "$PAYLOAD_DIR/Applications/Utilities/WiFi IP Uninstaller.app/Contents/MacOS/WiFi IP Uninstaller" << 'GUI_EOF'
#!/bin/bash
# WiFi IP 자동 전환 - GUI 제거 앱

set -euo pipefail

# GUI 대화상자 함수들
show_dialog() {
    osascript -e "display dialog \"$1\" with title \"WiFi IP Uninstaller\" buttons {\"OK\"} default button \"OK\""
}

show_confirmation() {
    local result=$(osascript -e "display dialog \"$1\" with title \"WiFi IP Uninstaller\" buttons {\"취소\", \"제거\"} default button \"제거\"" 2>/dev/null || echo "User canceled")
    if [[ "$result" == *"제거"* ]]; then
        return 0
    else
        return 1
    fi
}

show_progress() {
    osascript -e "display notification \"$1\" with title \"WiFi IP Uninstaller\""
}

show_error() {
    osascript -e "display dialog \"오류: $1\" with title \"WiFi IP Uninstaller\" buttons {\"OK\"} default button \"OK\" with icon stop"
}

show_success() {
    osascript -e "display dialog \"$1\" with title \"WiFi IP Uninstaller\" buttons {\"OK\"} default button \"OK\" with icon note"
}

# 메인 제거 확인
if ! show_confirmation "WiFi IP 자동 전환 도구를 제거하시겠습니까?

제거될 항목:
• WiFi 설정 스크립트
• 관리자 권한 설정
• Hammerspoon 설정 (백업됨)
• 문서 파일들
• 이 제거 앱"; then
    exit 0
fi

# 관리자 권한 확인 및 요청
if [[ $EUID -ne 0 ]]; then
    show_dialog "관리자 권한이 필요합니다. 다음 대화상자에서 암호를 입력해주세요."
    
    show_progress "제거를 시작합니다..."
    
    # Hammerspoon 설정 백업 (권한 불필요)
    USER_HOME="$HOME"
    HAMMERSPOON_CONFIG="$USER_HOME/.hammerspoon/init.lua"
    backup_file=""
    if [[ -f "$HAMMERSPOON_CONFIG" ]]; then
        backup_file="$HAMMERSPOON_CONFIG.removed-$(date +%Y%m%d-%H%M%S)"
        mv "$HAMMERSPOON_CONFIG" "$backup_file" 2>/dev/null || true
        show_progress "Hammerspoon 설정 백업 완료"
    fi
    
    # 모든 관리자 권한 필요 작업을 한 번에 실행
    admin_commands=""
    
    # WiFi 스크립트 제거
    if [[ -f "/usr/local/bin/wifi-ip-switch.sh" ]]; then
        admin_commands+="rm -f /usr/local/bin/wifi-ip-switch.sh; "
    fi
    
    # sudoers 설정 제거
    if [[ -f "/etc/sudoers.d/wifi-ip-switch" ]]; then
        admin_commands+="rm -f /etc/sudoers.d/wifi-ip-switch; "
    fi
    
    # 설치된 파일들 제거
    if [[ -d "/usr/local/share/wifi-ip-autoswitch" ]]; then
        admin_commands+="rm -rf /usr/local/share/wifi-ip-autoswitch; "
    fi
    
    # 자기 자신 제거
    admin_commands+="rm -rf '/Applications/Utilities/WiFi IP Uninstaller.app'"
    
    # 한 번의 권한 요청으로 모든 작업 실행
    if [[ -n "$admin_commands" ]]; then
        osascript -e "do shell script \"$admin_commands\" with administrator privileges"
        show_progress "모든 파일 제거 완료"
    fi
    
    show_success "WiFi IP 자동 전환 도구가 성공적으로 제거되었습니다!

제거된 항목:
• WiFi 설정 스크립트
• 관리자 권한 설정  
• Hammerspoon 설정 (백업됨)
• 문서 파일들
• 제거 앱

Hammerspoon은 수동으로 제거해주세요."
    exit 0
fi

# 아래 코드는 sudo로 실행될 때만 사용됨 (실제로는 위의 개별 명령어들이 실행됨)

# 현재 사용자 확인
if [[ -n "${SUDO_USER:-}" ]]; then
    CURRENT_USER="$SUDO_USER"
elif [[ -n "${USER:-}" ]]; then
    CURRENT_USER="$USER"
else
    CURRENT_USER=$(stat -f "%Su" /dev/console)
fi

USER_HOME=$(eval echo "~$CURRENT_USER")
HAMMERSPOON_CONFIG="$USER_HOME/.hammerspoon/init.lua"
SUDOERS_FILE="/etc/sudoers.d/wifi-ip-switch"

show_progress "제거를 시작합니다..."

# WiFi 스크립트 제거
if [[ -f "/usr/local/bin/wifi-ip-switch.sh" ]]; then
    rm -f "/usr/local/bin/wifi-ip-switch.sh"
    show_progress "WiFi 설정 스크립트 제거 완료"
fi

# sudoers 설정 제거
if [[ -f "$SUDOERS_FILE" ]]; then
    rm -f "$SUDOERS_FILE"
    show_progress "관리자 권한 설정 제거 완료"
fi

# Hammerspoon 설정 백업 후 제거
if [[ -f "$HAMMERSPOON_CONFIG" ]]; then
    backup_file="$HAMMERSPOON_CONFIG.removed-$(date +%Y%m%d-%H%M%S)"
    if [[ "$CURRENT_USER" != "root" ]]; then
        sudo -u "$CURRENT_USER" mv "$HAMMERSPOON_CONFIG" "$backup_file" 2>/dev/null || mv "$HAMMERSPOON_CONFIG" "$backup_file"
    else
        mv "$HAMMERSPOON_CONFIG" "$backup_file"
    fi
    show_progress "Hammerspoon 설정 백업 완료"
fi

# 설치된 파일들 제거
if [[ -d "/usr/local/share/wifi-ip-autoswitch" ]]; then
    rm -rf "/usr/local/share/wifi-ip-autoswitch"
    show_progress "문서 파일 제거 완료"
fi

# 자기 자신 제거 (마지막에)
rm -rf "/Applications/Utilities/WiFi IP Uninstaller.app"

show_success "WiFi IP 자동 전환 도구가 성공적으로 제거되었습니다!

제거된 항목:
• WiFi 설정 스크립트
• 관리자 권한 설정  
• Hammerspoon 설정 (백업됨)
• 문서 파일들
• 제거 앱

Hammerspoon은 수동으로 제거해주세요."

GUI_EOF

chmod +x "$PAYLOAD_DIR/Applications/Utilities/WiFi IP Uninstaller.app/Contents/MacOS/WiFi IP Uninstaller"

# 앱 아이콘 생성 (간단한 텍스트 기반 아이콘)
cat > "$PAYLOAD_DIR/Applications/Utilities/WiFi IP Uninstaller.app/Contents/Resources/AppIcon.icns" << 'ICON_EOF'
# 실제 아이콘 파일이 없으므로 빈 파일로 생성
# 나중에 실제 아이콘을 추가할 수 있음
ICON_EOF

# /usr/local/share에 설치될 설정 파일들
mkdir -p "$PAYLOAD_DIR/usr/local/share/wifi-ip-autoswitch/docs"
cp "$SCRIPT_DIR/settings/init.lua" "$PAYLOAD_DIR/usr/local/share/wifi-ip-autoswitch/"
if [[ -d "$SCRIPT_DIR/Manual" ]]; then
    cp "$SCRIPT_DIR/Manual/README.md" "$PAYLOAD_DIR/usr/local/share/wifi-ip-autoswitch/docs/" 2>/dev/null || true
    cp "$SCRIPT_DIR/Manual/INSTALL_GUIDE.md" "$PAYLOAD_DIR/usr/local/share/wifi-ip-autoswitch/docs/" 2>/dev/null || true
elif [[ -d "$SCRIPT_DIR/설치 설명서" ]]; then
    cp "$SCRIPT_DIR/설치 설명서/README.md" "$PAYLOAD_DIR/usr/local/share/wifi-ip-autoswitch/docs/" 2>/dev/null || true
    cp "$SCRIPT_DIR/설치 설명서/INSTALL_GUIDE.md" "$PAYLOAD_DIR/usr/local/share/wifi-ip-autoswitch/docs/" 2>/dev/null || true
fi

# 2. 설치 스크립트 생성
log_info "설치 스크립트 생성 중..."

cat > "$SCRIPTS_DIR/postinstall" << 'EOF'
#!/bin/bash
# WiFi IP 자동 전환 - 설치 후 스크립트

set -euo pipefail

# 현재 사용자 확인 (여러 방법으로 시도)
if [[ -n "${SUDO_USER:-}" ]]; then
    CURRENT_USER="$SUDO_USER"
elif [[ -n "${USER:-}" ]]; then
    CURRENT_USER="$USER"
else
    # 마지막 수단: 현재 로그인한 사용자 찾기
    CURRENT_USER=$(stat -f "%Su" /dev/console)
fi

USER_HOME=$(eval echo "~$CURRENT_USER")
HAMMERSPOON_DIR="$USER_HOME/.hammerspoon"
HAMMERSPOON_CONFIG="$HAMMERSPOON_DIR/init.lua"
SUDOERS_FILE="/etc/sudoers.d/wifi-ip-switch"

echo "WiFi IP 자동 전환 설치를 완료하는 중..."

# sudoers 설정
echo "# WiFi IP 자동 전환 스크립트 권한
$CURRENT_USER ALL=(root) NOPASSWD: /usr/local/bin/wifi-ip-switch.sh
$CURRENT_USER ALL=(root) NOPASSWD: /usr/sbin/networksetup" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

# Hammerspoon 디렉토리 생성
if [[ "$CURRENT_USER" != "root" ]]; then
    sudo -u "$CURRENT_USER" mkdir -p "$HAMMERSPOON_DIR" || mkdir -p "$HAMMERSPOON_DIR"
else
    mkdir -p "$HAMMERSPOON_DIR"
fi

# 기존 설정 백업
if [[ -f "$HAMMERSPOON_CONFIG" ]]; then
    backup_file="$HAMMERSPOON_CONFIG.backup-$(date +%Y%m%d-%H%M%S)"
    if [[ "$CURRENT_USER" != "root" ]]; then
        sudo -u "$CURRENT_USER" cp "$HAMMERSPOON_CONFIG" "$backup_file" || cp "$HAMMERSPOON_CONFIG" "$backup_file"
    else
        cp "$HAMMERSPOON_CONFIG" "$backup_file"
    fi
    echo "기존 Hammerspoon 설정을 백업했습니다: $backup_file"
fi

# 새 설정 파일 복사
if [[ "$CURRENT_USER" != "root" ]]; then
    sudo -u "$CURRENT_USER" cp "/usr/local/share/wifi-ip-autoswitch/init.lua" "$HAMMERSPOON_CONFIG" || cp "/usr/local/share/wifi-ip-autoswitch/init.lua" "$HAMMERSPOON_CONFIG"
    sudo -u "$CURRENT_USER" chmod 644 "$HAMMERSPOON_CONFIG" || chmod 644 "$HAMMERSPOON_CONFIG"
else
    cp "/usr/local/share/wifi-ip-autoswitch/init.lua" "$HAMMERSPOON_CONFIG"
    chmod 644 "$HAMMERSPOON_CONFIG"
fi

echo "설치가 완료되었습니다!"
echo
echo "다음 단계:"
echo "1. Hammerspoon 설치 (없는 경우): brew install --cask hammerspoon"
echo "2. Hammerspoon 실행: Spotlight(⌘+Space) → 'Hammerspoon'"
echo "3. WiFi 네트워크 변경하여 테스트"
echo
echo "설정 변경: ~/.hammerspoon/init.lua 파일 편집"
echo "문서 위치: /usr/local/share/wifi-ip-autoswitch/docs/"
echo
echo "제거 방법: Applications/Utilities에서 'WiFi IP Uninstaller' 실행"

exit 0
EOF

chmod +x "$SCRIPTS_DIR/postinstall"

# 3. 제거 스크립트 생성
cat > "$SCRIPTS_DIR/preinstall" << 'EOF'
#!/bin/bash
# WiFi IP 자동 전환 - 설치 전 스크립트 (기존 설치 정리)

USER_HOME=$(eval echo "~$SUDO_USER")
HAMMERSPOON_CONFIG="$USER_HOME/.hammerspoon/init.lua"
SUDOERS_FILE="/etc/sudoers.d/wifi-ip-switch"

# 기존 설치 정리
if [[ -f "/usr/local/bin/wifi-ip-switch.sh" ]]; then
    echo "기존 설치를 정리하는 중..."
    rm -f "/usr/local/bin/wifi-ip-switch.sh" || true
    rm -f "$SUDOERS_FILE" || true
fi

exit 0
EOF

chmod +x "$SCRIPTS_DIR/preinstall"

# 4. Welcome 문서 생성
cat > "$RESOURCES_DIR/Welcome.txt" << 'EOF'
WiFi IP 자동 전환 도구에 오신 것을 환영합니다!

이 도구는 WiFi SSID 변경 시 자동으로 IP 설정을 변경해주는 macOS용 도구입니다.

주요 기능:
• WiFi SSID 기반 자동 IP 설정
• 수동 IP 또는 DHCP 설정 지원
• DNS 서버 자동 변경
• macOS 알림으로 상태 확인

설치 후:
1. Hammerspoon을 설치하세요 (brew install --cask hammerspoon)
2. Hammerspoon을 실행하세요
3. WiFi 네트워크를 변경하여 테스트하세요

자세한 사용법은 /usr/local/share/wifi-ip-autoswitch/docs/ 를 참조하세요.
EOF

# 5. ReadMe 생성
cat > "$RESOURCES_DIR/ReadMe.txt" << 'EOF'
시스템 요구사항:
• macOS 10.12 Sierra 이상
• 관리자 권한
• Hammerspoon (별도 설치 필요)

설치되는 파일:
• /usr/local/bin/wifi-ip-switch.sh
• /etc/sudoers.d/wifi-ip-switch
• ~/.hammerspoon/init.lua
• /usr/local/share/wifi-ip-autoswitch/

제거 방법:
1. GUI 제거 (권장): Applications/Utilities → "WiFi IP Uninstaller" 실행
2. 또는 수동 제거:
   sudo rm -f /usr/local/bin/wifi-ip-switch.sh
   sudo rm -rf "/Applications/Utilities/WiFi IP Uninstaller.app"
   sudo rm -f /etc/sudoers.d/wifi-ip-switch
   rm -f ~/.hammerspoon/init.lua
   sudo rm -rf /usr/local/share/wifi-ip-autoswitch/
EOF

# 6. 패키지 빌드
log_info "패키지 빌드 중..."

PKG_FILE="$SCRIPT_DIR/${PACKAGE_NAME}-v${VERSION}.pkg"

pkgbuild \
    --root "$PAYLOAD_DIR" \
    --scripts "$SCRIPTS_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location "/" \
    "$PKG_FILE"

# 7. 패키지 정보 확인
if [[ -f "$PKG_FILE" ]]; then
    log_success "패키지 생성 완료!"
    echo
    log_info "📦 패키지 파일: $PKG_FILE"
    log_info "📏 파일 크기: $(du -h "$PKG_FILE" | cut -f1)"
    echo
    log_info "🚀 사용 방법:"
    echo "1. .pkg 파일을 다른 맥으로 전송"
    echo "2. 더블클릭하여 설치"
    echo "3. 설치 마법사를 따라 진행"
    echo
    log_warning "⚠️  참고사항:"
    echo "• 개발자 서명이 없어 보안 경고가 나올 수 있습니다"
    echo "• '시스템 환경설정 → 보안 및 개인정보 보호'에서 '확인 없이 열기' 클릭"
else
    echo "❌ 패키지 생성 실패"
    exit 1
fi

# 빌드 디렉토리 정리
log_info "빌드 파일 정리 중..."
rm -rf "$BUILD_DIR"

log_success "패키지 생성 완료! 🎉"
