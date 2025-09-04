#!/bin/bash
# WiFi IP 자동 전환 설치 스크립트
# Hammerspoon + WiFi SSID 기반 IP/DNS 자동 설정

set -euo pipefail

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 설치 경로
WIFI_SCRIPT_PATH="/usr/local/bin/wifi-ip-switch.sh"
HAMMERSPOON_DIR="$HOME/.hammerspoon"
SUDOERS_FILE="/etc/sudoers.d/wifi-ip-switch"
BACKUP_DIR="$HOME/.wifi-ip-switch-backup-$(date +%Y%m%d-%H%M%S)"

# 필수 파일 확인
check_required_files() {
    log_info "필수 파일 확인 중..."
    
    if [[ ! -f "$SCRIPT_DIR/wifi-ip-switch.sh" ]]; then
        log_error "wifi-ip-switch.sh 파일이 없습니다."
        exit 1
    fi
    
    if [[ ! -f "$SCRIPT_DIR/init.lua" ]]; then
        log_error "init.lua 파일이 없습니다."
        exit 1
    fi
    
    log_success "필수 파일 확인 완료"
}

# 관리자 권한 확인
check_admin_privileges() {
    log_info "관리자 권한 확인 중..."
    
    if ! groups "$USER" | grep -q admin; then
        log_error "현재 사용자가 admin 그룹에 속하지 않습니다."
        log_error "관리자 권한이 있는 계정으로 실행해주세요."
        exit 1
    fi
    
    log_success "관리자 권한 확인 완료"
}

# Hammerspoon 설치 확인
check_hammerspoon() {
    log_info "Hammerspoon 설치 확인 중..."
    
    if [[ ! -d "/Applications/Hammerspoon.app" ]]; then
        log_warning "Hammerspoon이 설치되어 있지 않습니다."
        log_info "Hammerspoon을 먼저 설치해주세요: https://www.hammerspoon.org/"
        
        read -p "Hammerspoon이 설치되어 있습니까? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "설치를 중단합니다."
            exit 1
        fi
    fi
    
    log_success "Hammerspoon 확인 완료"
}

# 백업 디렉토리 생성
create_backup() {
    log_info "백업 디렉토리 생성: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # 기존 Hammerspoon 설정 백업
    if [[ -f "$HAMMERSPOON_DIR/init.lua" ]]; then
        cp "$HAMMERSPOON_DIR/init.lua" "$BACKUP_DIR/init.lua.backup"
        log_info "기존 init.lua 백업 완료"
    fi
    
    # 기존 wifi-ip-switch.sh 백업
    if [[ -f "$WIFI_SCRIPT_PATH" ]]; then
        sudo cp "$WIFI_SCRIPT_PATH" "$BACKUP_DIR/wifi-ip-switch.sh.backup"
        log_info "기존 wifi-ip-switch.sh 백업 완료"
    fi
}

# WiFi 스크립트 설치
install_wifi_script() {
    log_info "WiFi IP 스위치 스크립트 설치 중..."
    
    # /usr/local/bin 디렉토리 생성 (없는 경우)
    sudo mkdir -p /usr/local/bin
    
    # 스크립트 복사 및 권한 설정
    sudo cp "$SCRIPT_DIR/wifi-ip-switch.sh" "$WIFI_SCRIPT_PATH"
    sudo chmod +x "$WIFI_SCRIPT_PATH"
    sudo chown root:wheel "$WIFI_SCRIPT_PATH"
    
    log_success "WiFi 스크립트 설치 완료: $WIFI_SCRIPT_PATH"
}

# sudoers 권한 설정
setup_sudoers() {
    log_info "sudoers 권한 설정 중..."
    
    # sudoers.d 디렉토리가 없으면 생성
    sudo mkdir -p /etc/sudoers.d
    
    # 기존 파일이 있으면 백업
    if [[ -f "$SUDOERS_FILE" ]]; then
        sudo cp "$SUDOERS_FILE" "$BACKUP_DIR/wifi-ip-switch.sudoers.backup"
        log_info "기존 sudoers 파일 백업 완료"
    fi
    
    # sudoers 파일 생성
    echo "# WiFi IP Switch - Allow admin group to run wifi-ip-switch.sh without password" | sudo tee "$SUDOERS_FILE" > /dev/null
    echo "%admin ALL=(ALL) NOPASSWD: $WIFI_SCRIPT_PATH" | sudo tee -a "$SUDOERS_FILE" > /dev/null
    
    # 권한 설정 (Hammerspoon이 파일 존재를 확인할 수 있도록 읽기 권한 추가)
    sudo chmod 644 "$SUDOERS_FILE"
    sudo chown root:wheel "$SUDOERS_FILE"
    
    # sudoers 파일 문법 검사
    if ! sudo visudo -c -f "$SUDOERS_FILE"; then
        log_error "sudoers 파일 문법 오류가 발생했습니다."
        sudo rm -f "$SUDOERS_FILE"
        exit 1
    fi
    
    # 파일 존재 및 내용 확인
    if [[ -f "$SUDOERS_FILE" ]] && grep -q "wifi-ip-switch.sh" "$SUDOERS_FILE"; then
        log_success "sudoers 권한 설정 완료"
        log_info "파일 위치: $SUDOERS_FILE"
        log_info "파일 권한: $(ls -la $SUDOERS_FILE 2>/dev/null || echo '확인 불가')"
    else
        log_error "sudoers 파일 생성에 실패했습니다."
        exit 1
    fi
}

# Hammerspoon 설정 설치
install_hammerspoon_config() {
    log_info "Hammerspoon 설정 설치 중..."
    
    # .hammerspoon 디렉토리 생성
    mkdir -p "$HAMMERSPOON_DIR"
    
    # init.lua 복사
    cp "$SCRIPT_DIR/init.lua" "$HAMMERSPOON_DIR/init.lua"
    
    log_success "Hammerspoon 설정 설치 완료"
}

# Hammerspoon 재시작
restart_hammerspoon() {
    log_info "Hammerspoon 재시작 중..."
    
    # Hammerspoon이 실행 중인지 확인
    if pgrep -f "Hammerspoon" > /dev/null; then
        # Hammerspoon 설정 다시 로드 (여러 방법 시도)
        if osascript -e 'tell application "Hammerspoon" to reload config' 2>/dev/null; then
            log_success "Hammerspoon 설정 다시 로드 완료"
        elif hs -c 'hs.reload()' 2>/dev/null; then
            log_success "Hammerspoon 설정 다시 로드 완료 (CLI 사용)"
        else
            # 파일 변경으로 자동 리로드 트리거
            touch "$HAMMERSPOON_DIR/init.lua"
            log_success "Hammerspoon 설정 파일 업데이트 완료 (자동 리로드 대기중)"
        fi
    else
        log_warning "Hammerspoon이 실행되고 있지 않습니다."
        log_info "Hammerspoon을 수동으로 실행해주세요."
        
        # Hammerspoon 자동 실행 시도
        if open -a Hammerspoon 2>/dev/null; then
            log_success "Hammerspoon 실행 완료"
            sleep 2  # 실행 대기
        else
            log_warning "Hammerspoon 자동 실행 실패. 수동으로 실행해주세요."
        fi
    fi
}

# Hammerspoon 권한 설정 안내
show_permissions_guide() {
    log_info "=========================================="
    log_info "중요: Hammerspoon 권한 설정"
    log_info "=========================================="
    echo
    log_warning "⚠️  Hammerspoon이 정상 작동하려면 다음 권한이 필요합니다:"
    echo
    log_info "1. 🔒 접근성 권한:"
    log_info "   - 시스템 설정 > 개인정보 보호 및 보안 > 접근성"
    log_info "   - Hammerspoon을 허용 목록에 추가"
    echo
    log_info "2. 📍 위치 서비스 권한:"
    log_info "   - 시스템 설정 > 개인정보 보호 및 보안 > 위치 서비스"
    log_info "   - Hammerspoon을 허용 목록에 추가"
    log_info "   - 이 권한이 없으면 WiFi SSID를 읽을 수 없습니다!"
    echo
    log_info "📝 권한 설정 후:"
    log_info "1. Hammerspoon을 완전히 종료하고 다시 실행"
    log_info "2. 첫 실행 시 권한 요청 팝업이 나타나면 '허용' 클릭"
    log_info "3. Hammerspoon Console에서 다음 명령어로 테스트:"
    log_info "   hs.wifi.currentNetwork()"
    echo
}

# 설치 완료 메시지
show_completion_message() {
    log_success "=========================================="
    log_success "WiFi IP 자동 전환 설치가 완료되었습니다!"
    log_success "=========================================="
    echo
    log_info "📁 백업 위치: $BACKUP_DIR"
    log_info "⚙️  설정 파일: $HAMMERSPOON_DIR/init.lua"
    log_info "🔧 스크립트: $WIFI_SCRIPT_PATH"
    echo
    log_info "🔍 현재 설정된 규칙:"
    log_info "- iPhone이 포함된 SSID: 172.20.10.6 (수동 IP)"
    log_info "- yongin SSID: 192.168.153.106 (수동 IP)"
    log_info "- 기타 SSID: DHCP"
    echo
    log_warning "⚠️  SSID별 설정을 변경하려면 init.lua 파일의 rules 섹션을 수정하세요."
    echo
}

# 메인 실행 함수
main() {
    echo "=========================================="
    echo "WiFi IP 자동 전환 설치 스크립트"
    echo "=========================================="
    echo
    
    # 설치 확인
    read -p "설치를 계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "설치를 취소합니다."
        exit 0
    fi
    
    # 설치 단계별 실행
    check_required_files
    check_admin_privileges
    check_hammerspoon
    create_backup
    install_wifi_script
    setup_sudoers
    install_hammerspoon_config
    restart_hammerspoon
    show_completion_message
    show_permissions_guide
}

# 스크립트 실행
main "$@"
