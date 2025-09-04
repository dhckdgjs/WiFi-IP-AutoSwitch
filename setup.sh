#!/bin/bash
# WiFi IP 자동 전환 - 통합 설정 스크립트
# 권한 설정 후 설치 또는 제거를 진행합니다

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

# 도움말 표시
show_help() {
    echo "WiFi IP 자동 전환 - 통합 설정 스크립트"
    echo
    echo "사용법:"
    echo "  bash setup.sh [옵션]"
    echo
    echo "옵션:"
    echo "  install, i     설치 (기본값)"
    echo "  uninstall, u   제거"
    echo "  help, h        이 도움말 표시"
    echo
    echo "예시:"
    echo "  bash setup.sh          # 설치"
    echo "  bash setup.sh install  # 설치"
    echo "  bash setup.sh uninstall # 제거"
}

# 명령어 파싱
COMMAND="${1:-install}"

case "$COMMAND" in
    help|h|-h|--help)
        show_help
        exit 0
        ;;
    install|i|"")
        ACTION="install"
        ACTION_NAME="설치"
        TARGET_SCRIPT="settings/install.sh"
        ;;
    uninstall|u|remove)
        ACTION="uninstall"
        ACTION_NAME="제거"
        TARGET_SCRIPT="settings/uninstall.sh"
        ;;
    *)
        log_error "알 수 없는 명령어: $COMMAND"
        echo
        show_help
        exit 1
        ;;
esac

echo "=========================================="
echo "WiFi IP 자동 전환 - $ACTION_NAME"
echo "=========================================="
echo

# 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 필수 파일 확인
if [[ ! -f "$SCRIPT_DIR/$TARGET_SCRIPT" ]]; then
    log_error "$TARGET_SCRIPT 파일이 없습니다."
    exit 1
fi

# 설치 시에만 wifi-ip-switch.sh 확인
if [[ "$ACTION" == "install" ]] && [[ ! -f "$SCRIPT_DIR/settings/wifi-ip-switch.sh" ]]; then
    log_error "settings/wifi-ip-switch.sh 파일이 없습니다."
    exit 1
fi

# 실행 권한 설정
log_info "실행 권한 설정 중..."
chmod +x "$SCRIPT_DIR/settings/install.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/settings/uninstall.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/settings/wifi-ip-switch.sh" 2>/dev/null || true
log_success "실행 권한 설정 완료"

echo
log_info "${ACTION_NAME}을 시작합니다..."
echo

# 해당 스크립트 실행
exec "$SCRIPT_DIR/$TARGET_SCRIPT"
