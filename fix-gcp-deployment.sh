#!/bin/bash
# GCP e2-medium 서버용 Docker 배포 문제 해결 스크립트

set -e

echo "🔧 GCP e2-medium Docker 배포 문제 해결 중..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. 시스템 정보 확인
log_info "시스템 정보 확인..."
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Architecture: $(uname -m)"
echo "Docker Version: $(docker --version 2>/dev/null || echo 'Docker 미설치')"
echo "Docker Compose Version: $(docker-compose --version 2>/dev/null || echo 'Docker Compose 미설치')"

# 2. Docker 재설치 (필요시)
if ! command -v docker &> /dev/null; then
    log_warning "Docker가 설치되지 않았습니다. 설치 중..."
    
    # Ubuntu/Debian용 Docker 설치
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        log_success "Docker 설치 완료"
    # CentOS/RHEL용 Docker 설치  
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        log_success "Docker 설치 완료"
    fi
fi

# 3. Docker Compose 최신 버전 설치
if ! command -v docker-compose &> /dev/null; then
    log_warning "Docker Compose 설치 중..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose 설치 완료"
fi

# 4. Docker 데몬 재시작
log_info "Docker 서비스 재시작..."
sudo systemctl restart docker
sleep 5

# 5. Docker 권한 확인
log_info "Docker 권한 확인..."
if ! docker ps &> /dev/null; then
    log_warning "Docker 권한 문제가 있습니다. 사용자를 docker 그룹에 추가..."
    sudo usermod -aG docker $USER
    log_warning "로그아웃 후 다시 로그인하거나 'newgrp docker' 명령을 실행하세요."
fi

# 6. 문제가 있는 이미지들을 개별적으로 pull
log_info "이미지 개별 다운로드 시도..."

pull_image_with_platform() {
    local image=$1
    local platform=${2:-"linux/amd64"}
    
    log_info "Pulling $image for $platform..."
    
    # 명시적으로 플랫폼 지정하여 pull
    if docker pull --platform="$platform" "$image"; then
        log_success "$image pull 성공"
        return 0
    else
        log_error "$image pull 실패"
        return 1
    fi
}

# AMD64 플랫폼으로 명시적 pull
pull_image_with_platform "minkoosong/kbo-postgres-data:17.2" "linux/amd64"
pull_image_with_platform "minkoosong/kbo-api-main:latest" "linux/amd64"
pull_image_with_platform "minkoosong/kbo-live-rating-api:latest" "linux/amd64"
pull_image_with_platform "minkoosong/kbo-frontend:latest" "linux/amd64"
pull_image_with_platform "minkoosong/kbo-unified-scheduler:v2" "linux/amd64"
pull_image_with_platform "nginx:alpine" "linux/amd64"

# 7. 환경변수 설정 확인
log_info "환경변수 설정 확인..."
if [ ! -f ".env" ]; then
    log_warning ".env 파일이 없습니다. 기본값으로 생성..."
    cat > .env << 'EOF'
POSTGRES_DB=kbo_elo_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_PORT=5432
MAIN_API_PORT=8000
LIVE_API_PORT=8001
FRONTEND_PORT=3000
SCHEDULER_PORT=8080
HTTP_PORT=80
HTTPS_PORT=443
TIMEZONE=Asia/Seoul
EOF
    log_success ".env 파일 생성 완료"
fi

# 8. Docker 이미지 상태 확인
log_info "다운로드된 이미지 확인..."
docker images | grep -E "(kbo|nginx)" || log_warning "KBO 관련 이미지가 없습니다."

# 9. Docker Compose 구문 검증
log_info "docker-compose.yml 구문 검증..."
if [ -f "docker-compose.secure.yml" ]; then
    docker-compose -f docker-compose.secure.yml config > /dev/null && log_success "docker-compose.secure.yml 구문 정상" || log_error "docker-compose.secure.yml 구문 오류"
fi

# 10. 메모리 및 디스크 공간 확인
log_info "시스템 리소스 확인..."
echo "메모리: $(free -h | grep Mem | awk '{print $2 " 총, " $7 " 사용 가능"}')"
echo "디스크: $(df -h / | tail -1 | awk '{print $2 " 총, " $4 " 사용 가능"}')"

# 11. 네트워크 연결 테스트
log_info "Docker Hub 연결 테스트..."
if curl -sSf https://registry-1.docker.io/v2/ > /dev/null; then
    log_success "Docker Hub 연결 정상"
else
    log_error "Docker Hub 연결 실패 - 네트워크 문제일 수 있습니다"
fi

echo ""
echo "============================================"
log_success "GCP Docker 환경 점검 완료!"
echo "============================================"
echo ""
echo "📋 다음 단계:"
echo "1. 새 터미널 세션을 시작하거나 'newgrp docker' 실행"
echo "2. docker-compose -f docker-compose.secure.yml up -d 실행"
echo "3. 문제 지속 시 개별 이미지 확인: docker images"
echo ""
echo "💡 GCP e2-medium 권장 설정:"
echo "   - 메모리: 최소 4GB (현재 시스템과 비교)"
echo "   - 디스크: 최소 20GB 여유 공간"
echo "   - 방화벽: 80, 443 포트 개방"
echo ""