#!/bin/bash
# WiFi IP 자동 전환 제거 스크립트
# 설치된 파일들과 설정을 제거합니다

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

# 설치 경로
WIFI_SCRIPT_PATH="/usr/local/bin/wifi-ip-switch.sh"
HAMMERSPOON_DIR="$HOME/.hammerspoon"
HAMMERSPOON_CONFIG="$HAMMERSPOON_DIR/init.lua"
SUDOERS_FILE="/etc/sudoers.d/wifi-ip-switch"
BACKUP_DIR="$HOME/.wifi-ip-switch-uninstall-backup-$(date +%Y%m%d-%H%M%S)"

# 백업 디렉토리 생성
create_backup() {
    log_info "제거 전 백업 생성: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Hammerspoon 설정 백업
    if [[ -f "$HAMMERSPOON_CONFIG" ]]; then
        cp "$HAMMERSPOON_CONFIG" "$BACKUP_DIR/init.lua.backup"
        log_info "현재 init.lua 백업 완료"
    fi
    
    # WiFi 스크립트 백업
    if [[ -f "$WIFI_SCRIPT_PATH" ]]; then
        sudo cp "$WIFI_SCRIPT_PATH" "$BACKUP_DIR/wifi-ip-switch.sh.backup" 2>/dev/null || true
        log_info "현재 wifi-ip-switch.sh 백업 완료"
    fi
}

# 기존 백업 파일 찾기 및 복원 옵션 제공
find_and_restore_backup() {
    log_info "기존 백업 파일 검색 중..."
    
    # 백업 디렉토리 패턴으로 검색
    local backup_dirs=($(find "$HOME" -maxdepth 1 -type d -name ".wifi-ip-switch-backup-*" 2>/dev/null | sort -r))
    
    if [[ ${#backup_dirs[@]} -gt 0 ]]; then
        log_info "발견된 백업 디렉토리:"
        for i in "${!backup_dirs[@]}"; do
            echo "  $((i+1)). ${backup_dirs[$i]##*/}"
        done
        
        echo
        read -p "백업에서 복원하시겠습니까? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ ${#backup_dirs[@]} -eq 1 ]]; then
                restore_from_backup "${backup_dirs[0]}"
            else
                echo "복원할 백업을 선택하세요:"
                for i in "${!backup_dirs[@]}"; do
                    echo "  $((i+1)). ${backup_dirs[$i]##*/}"
                done
                
                read -p "번호 입력 (1-${#backup_dirs[@]}): " -r selection
                
                if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#backup_dirs[@]} ]]; then
                    restore_from_backup "${backup_dirs[$((selection-1))]}"
                else
                    log_warning "잘못된 선택입니다. 백업 복원을 건너뜁니다."
                fi
            fi
        fi
    else
        log_info "기존 백업 파일을 찾을 수 없습니다."
    fi
}

# 백업에서 복원
restore_from_backup() {
    local backup_dir="$1"
    log_info "백업에서 복원 중: $backup_dir"
    
    # Hammerspoon 설정 복원
    if [[ -f "$backup_dir/init.lua.backup" ]]; then
        mkdir -p "$HAMMERSPOON_DIR"
        cp "$backup_dir/init.lua.backup" "$HAMMERSPOON_CONFIG"
        log_success "init.lua 복원 완료"
    fi
    
    # WiFi 스크립트 복원 (있는 경우)
    if [[ -f "$backup_dir/wifi-ip-switch.sh.backup" ]]; then
        sudo cp "$backup_dir/wifi-ip-switch.sh.backup" "$WIFI_SCRIPT_PATH"
        sudo chmod +x "$WIFI_SCRIPT_PATH"
        log_success "wifi-ip-switch.sh 복원 완료"
    fi
}

# WiFi 스크립트 제거
remove_wifi_script() {
    log_info "WiFi IP 스위치 스크립트 제거 중..."
    
    if [[ -f "$WIFI_SCRIPT_PATH" ]]; then
        sudo rm -f "$WIFI_SCRIPT_PATH"
        log_success "WiFi 스크립트 제거 완료: $WIFI_SCRIPT_PATH"
    else
        log_info "WiFi 스크립트가 이미 제거되었거나 존재하지 않습니다."
    fi
}

# sudoers 권한 제거
remove_sudoers() {
    log_info "sudoers 권한 제거 중..."
    
    if [[ -f "$SUDOERS_FILE" ]]; then
        sudo rm -f "$SUDOERS_FILE"
        log_success "sudoers 권한 제거 완료: $SUDOERS_FILE"
    else
        log_info "sudoers 파일이 이미 제거되었거나 존재하지 않습니다."
    fi
}

# Hammerspoon 설정 처리
handle_hammerspoon_config() {
    log_info "Hammerspoon 설정 처리 중..."
    
    if [[ -f "$HAMMERSPOON_CONFIG" ]]; then
        echo
        log_warning "현재 Hammerspoon 설정 파일이 존재합니다:"
        log_warning "$HAMMERSPOON_CONFIG"
        echo
        echo "선택 옵션:"
        echo "1. 설정 파일 제거 (백업은 유지됨)"
        echo "2. 설정 파일 유지"
        echo "3. 기존 백업에서 복원 (있는 경우)"
        
        read -p "선택하세요 (1/2/3): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                rm -f "$HAMMERSPOON_CONFIG"
                log_success "Hammerspoon 설정 파일 제거 완료"
                ;;
            2)
                log_info "Hammerspoon 설정 파일을 유지합니다."
                ;;
            3)
                find_and_restore_backup
                ;;
            *)
                log_info "잘못된 선택입니다. 설정 파일을 유지합니다."
                ;;
        esac
    else
        log_info "Hammerspoon 설정 파일이 존재하지 않습니다."
    fi
}

# Hammerspoon 재시작
restart_hammerspoon() {
    log_info "Hammerspoon 재시작 중..."
    
    if pgrep -f "Hammerspoon" > /dev/null; then
        # Hammerspoon 설정 다시 로드 (여러 방법 시도)
        if osascript -e 'tell application "Hammerspoon" to reload config' 2>/dev/null; then
            log_success "Hammerspoon 설정 다시 로드 완료"
        elif hs -c 'hs.reload()' 2>/dev/null; then
            log_success "Hammerspoon 설정 다시 로드 완료 (CLI 사용)"
        else
            # 파일 변경으로 자동 리로드 트리거
            if [[ -f "$HAMMERSPOON_CONFIG" ]]; then
                touch "$HAMMERSPOON_CONFIG"
                log_success "Hammerspoon 설정 파일 업데이트 완료 (자동 리로드 대기중)"
            else
                log_info "Hammerspoon 설정 다시 로드 시도 완료"
            fi
        fi
    else
        log_info "Hammerspoon이 실행되고 있지 않습니다."
    fi
}

# 로그 파일 정리
clean_logs() {
    log_info "로그 파일 정리 중..."
    
    local log_file="/var/log/ssid-ip-switcher.log"
    if [[ -f "$log_file" ]]; then
        read -p "로그 파일을 제거하시겠습니까? ($log_file) (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo rm -f "$log_file"
            log_success "로그 파일 제거 완료"
        else
            log_info "로그 파일을 유지합니다."
        fi
    else
        log_info "로그 파일이 존재하지 않습니다."
    fi
}

# 완료 메시지
show_completion_message() {
    log_success "=========================================="
    log_success "WiFi IP 자동 전환 제거가 완료되었습니다!"
    log_success "=========================================="
    echo
    log_info "📁 제거 전 백업: $BACKUP_DIR"
    echo
    log_info "제거된 항목:"
    log_info "- ❌ /usr/local/bin/wifi-ip-switch.sh"
    log_info "- ❌ /etc/sudoers.d/wifi-ip-switch"
    echo
    log_info "📝 참고사항:"
    log_info "- Hammerspoon 설정은 사용자 선택에 따라 처리되었습니다"
    log_info "- 백업 파일들은 안전하게 보관되어 있습니다"
    log_info "- 필요시 백업에서 수동으로 복원할 수 있습니다"
    echo
    log_warning "⚠️  Hammerspoon을 완전히 제거하려면 별도로 제거해주세요:"
    log_warning "   brew uninstall --cask hammerspoon"
}

# 메인 실행 함수
main() {
    echo "=========================================="
    echo "WiFi IP 자동 전환 제거 스크립트"
    echo "=========================================="
    echo
    
    # 제거 확인
    log_warning "이 스크립트는 다음 항목들을 제거합니다:"
    log_warning "- WiFi IP 스위치 스크립트 (/usr/local/bin/wifi-ip-switch.sh)"
    log_warning "- sudoers 권한 설정 (/etc/sudoers.d/wifi-ip-switch)"
    log_warning "- Hammerspoon 설정 (선택사항)"
    echo
    
    read -p "제거를 계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "제거를 취소합니다."
        exit 0
    fi
    
    # 제거 단계별 실행
    create_backup
    remove_wifi_script
    remove_sudoers
    handle_hammerspoon_config
    restart_hammerspoon
    clean_logs
    show_completion_message
}

# 스크립트 실행
main "$@"
