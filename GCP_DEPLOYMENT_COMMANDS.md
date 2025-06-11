# GCP e2-medium 서버 배포 명령어 가이드

## 🔍 문제 원인: Docker Compose v2 사용

GCP 서버에서 **Docker Compose v2**를 사용하고 있습니다:
```bash
# ❌ 작동하지 않음 (v1 명령어)
docker-compose -f docker-compose.secure.yml up -d

# ✅ 올바른 명령어 (v2)
docker compose -f docker-compose.secure.yml up -d
```

## 🚀 정확한 배포 단계

### 1단계: 환경변수 설정
```bash
# .env 파일 생성
cat > .env << 'EOF'
POSTGRES_DB=kbo_elo_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=YourSecurePassword123!
POSTGRES_PORT=5432
MAIN_API_PORT=8000
LIVE_API_PORT=8001
FRONTEND_PORT=3000
SCHEDULER_PORT=8080
HTTP_PORT=80
HTTPS_PORT=443
TIMEZONE=Asia/Seoul
EOF
```

### 2단계: Docker 이미지 다운로드 (v2 명령어)
```bash
# 이미지 개별 다운로드로 문제 해결
docker pull minkoosong/kbo-postgres-data:17.2
docker pull minkoosong/kbo-api-main:latest
docker pull minkoosong/kbo-live-rating-api:latest
docker pull minkoosong/kbo-frontend:latest
docker pull minkoosong/kbo-unified-scheduler:v2
docker pull nginx:alpine
```

### 3단계: 서비스 시작 (v2 명령어)
```bash
# ✅ Docker Compose v2 명령어 사용
docker compose -f docker-compose.secure.yml up -d
```

### 4단계: 상태 확인
```bash
# 컨테이너 상태 확인
docker compose -f docker-compose.secure.yml ps

# 로그 확인
docker compose -f docker-compose.secure.yml logs -f

# 개별 서비스 로그 확인
docker compose -f docker-compose.secure.yml logs kbo-api-main
```

## 🔧 문제 해결 명령어들

### Docker Compose v2 명령어 비교표
| 작업 | v1 (구버전) | v2 (현재) |
|------|-------------|-----------|
| 시작 | `docker-compose up -d` | `docker compose up -d` |
| 중지 | `docker-compose down` | `docker compose down` |
| 상태 | `docker-compose ps` | `docker compose ps` |
| 로그 | `docker-compose logs` | `docker compose logs` |
| 재시작 | `docker-compose restart` | `docker compose restart` |

### 이미지 아키텍처 문제 해결
```bash
# AMD64 플랫폼 명시적 지정
docker pull --platform linux/amd64 minkoosong/kbo-api-main:latest

# 이미지 정보 확인
docker inspect minkoosong/kbo-api-main:latest | grep Architecture
```

### 네트워크 및 권한 문제 해결
```bash
# Docker 그룹 권한 확인
groups $USER

# Docker 서비스 재시작
sudo systemctl restart docker

# 권한 문제 시
sudo usermod -aG docker $USER
newgrp docker
```

## 📋 완전한 배포 스크립트

```bash
#!/bin/bash
# GCP e2-medium 완전 배포 스크립트

echo "🚀 KBO ELO System GCP 배포 시작..."

# 환경변수 설정
echo "📝 환경변수 설정..."
cat > .env << 'EOF'
POSTGRES_DB=kbo_elo_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=SecurePassword123!
POSTGRES_PORT=5432
MAIN_API_PORT=8000
LIVE_API_PORT=8001
FRONTEND_PORT=3000
SCHEDULER_PORT=8080
HTTP_PORT=80
HTTPS_PORT=443
TIMEZONE=Asia/Seoul
EOF

# 이미지 다운로드
echo "⬇️ Docker 이미지 다운로드..."
docker pull minkoosong/kbo-postgres-data:17.2
docker pull minkoosong/kbo-api-main:latest
docker pull minkoosong/kbo-live-rating-api:latest
docker pull minkoosong/kbo-frontend:latest
docker pull minkoosong/kbo-unified-scheduler:v2
docker pull nginx:alpine

# 서비스 시작 (v2 명령어)
echo "🐳 서비스 시작..."
docker compose -f docker-compose.secure.yml up -d

# 상태 확인
echo "🔍 서비스 상태 확인..."
sleep 30
docker compose -f docker-compose.secure.yml ps

# 접속 정보 출력
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP를 가져올 수 없음")
echo ""
echo "✅ 배포 완료!"
echo "🌐 웹사이트: http://$PUBLIC_IP"
echo "📖 API 문서: http://$PUBLIC_IP/docs"
echo ""
```

## 🎯 바로 실행할 명령어

**GCP 서버에서 바로 실행:**
```bash
# 1. 올바른 v2 명령어로 재시도
docker compose -f docker-compose.secure.yml up -d

# 2. 문제 지속 시 이미지 개별 다운로드 후 재시도
docker pull minkoosong/kbo-postgres-data:17.2 && \
docker pull minkoosong/kbo-api-main:latest && \
docker pull minkoosong/kbo-live-rating-api:latest && \
docker pull minkoosong/kbo-frontend:latest && \
docker pull minkoosong/kbo-unified-scheduler:v2 && \
docker compose -f docker-compose.secure.yml up -d
```

## 🔍 디버깅 명령어

```bash
# 상세 로그 확인
docker compose -f docker-compose.secure.yml logs --tail=50

# 특정 서비스 문제 확인
docker compose -f docker-compose.secure.yml logs kbo-postgres
docker compose -f docker-compose.secure.yml logs kbo-api-main

# 컨테이너 직접 접속
docker compose -f docker-compose.secure.yml exec kbo-postgres psql -U postgres -d kbo_elo_db

# 포트 확인
sudo netstat -tlnp | grep -E '(80|8000|8001|5432)'
```

---

**핵심 포인트**: `docker-compose` → `docker compose` (공백 추가)로 명령어 변경! 🎯