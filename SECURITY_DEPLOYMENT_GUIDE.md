# KBO ELO System - 보안 배포 가이드

## 🔒 보안 문제 분석

### 현재 Docker 설정 파일의 보안 취약점

**❌ 발견된 문제점들:**

1. **하드코딩된 비밀번호** (`docker-compose.yml`, `docker-compose.production.yml`, `deploy-to-ec2.sh`)
   ```yaml
   POSTGRES_PASSWORD: postgres  # ⚠️ 평문 비밀번호
   ```

2. **데이터베이스 연결 문자열 노출**
   ```yaml
   DATABASE_URL: postgresql://postgres:postgres@kbo-postgres:5432/kbo_elo_db
   ```

3. **기본 계정 사용**
   - 사용자명: `postgres`
   - 비밀번호: `postgres`

## ✅ 보안 해결 방안

### 1. 환경변수 기반 설정 사용

#### 보안 강화된 docker-compose.secure.yml 생성됨 ✓

**주요 개선사항:**
- 모든 민감 정보를 환경변수로 분리
- 필수 환경변수 검증 (`${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}`)
- 기본값 제공으로 편의성 유지

### 2. 환경변수 설정 방법

#### Option 1: .env 파일 사용 (권장)

```bash
# .env 파일 생성
cp .env.example .env

# 보안 값들 설정
vi .env
```

**.env 파일 예시:**
```bash
POSTGRES_DB=kbo_elo_db
POSTGRES_USER=kbo_admin
POSTGRES_PASSWORD=SecurePassword123!@#
POSTGRES_PORT=5432

MAIN_API_PORT=8000
LIVE_API_PORT=8001
FRONTEND_PORT=3000
SCHEDULER_PORT=8080

HTTP_PORT=80
HTTPS_PORT=443

TIMEZONE=Asia/Seoul
```

#### Option 2: 시스템 환경변수 사용

```bash
# 환경변수 직접 설정
export POSTGRES_PASSWORD="SecurePassword123!@#"
export POSTGRES_USER="kbo_admin"

# docker-compose 실행
docker-compose -f docker-compose.secure.yml up -d
```

#### Option 3: 실행시 환경변수 전달

```bash
# 한번에 환경변수와 함께 실행
POSTGRES_PASSWORD="SecurePassword123!@#" \
POSTGRES_USER="kbo_admin" \
docker-compose -f docker-compose.secure.yml up -d
```

## 🚀 Public Repository 업로드 전략

### ✅ 안전하게 업로드할 수 있는 파일들

```bash
docker-deployment/
├── docker-compose.secure.yml     # ✅ 환경변수 사용
├── nginx-production.conf          # ✅ 비밀정보 없음
├── .env.example                   # ✅ 예시 파일만
├── SECURITY_DEPLOYMENT_GUIDE.md   # ✅ 이 가이드
└── deploy-to-ec2-secure.sh        # ✅ 보안 버전 (아래 생성)
```

### ❌ 업로드하면 안되는 파일들

```bash
├── docker-compose.yml             # ❌ 하드코딩된 비밀번호
├── docker-compose.production.yml  # ❌ 하드코딩된 비밀번호  
├── deploy-to-ec2.sh               # ❌ 평문 비밀번호 포함
├── .env                          # ❌ 실제 비밀번호 (있다면)
└── *.key, *.pem                  # ❌ 인증서/키 파일들
```

## 🔧 EC2 보안 배포 스크립트

### deploy-to-ec2-secure.sh (생성 예정)

```bash
#!/bin/bash
# KBO ELO System - 보안 강화 EC2 배포 스크립트

set -e

echo "🔒 KBO ELO System 보안 배포 시작..."

# 환경변수 검증
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "❌ 오류: POSTGRES_PASSWORD 환경변수가 설정되지 않았습니다."
    echo "사용법: POSTGRES_PASSWORD='your_password' ./deploy-to-ec2-secure.sh"
    exit 1
fi

# 나머지 배포 로직...
```

## 📋 배포 단계별 보안 체크리스트

### Phase 1: 개발 준비
- [ ] `docker-compose.secure.yml` 사용
- [ ] `.env.example`에서 `.env` 생성
- [ ] 강력한 비밀번호 설정
- [ ] `.env` 파일을 `.gitignore`에 추가

### Phase 2: Repository 업로드
- [ ] 보안 파일들만 선별하여 업로드
- [ ] 하드코딩된 비밀번호 파일들 제외
- [ ] README에 보안 가이드 링크 추가

### Phase 3: EC2 배포
- [ ] EC2에서 환경변수 설정
- [ ] 보안 그룹에서 필요한 포트만 개방
- [ ] SSH 키 기반 접속 설정
- [ ] 정기적인 보안 업데이트

## 🛡️ 추가 보안 권장사항

### 1. 비밀번호 정책
```bash
# 강력한 비밀번호 예시
- 최소 12자 이상
- 대소문자, 숫자, 특수문자 조합
- 예: MySecureKBO_2024!@#
```

### 2. 네트워크 보안
```bash
# EC2 보안그룹 설정
- Port 22: SSH (특정 IP만)
- Port 80: HTTP (전체 접속)
- Port 443: HTTPS (전체 접속)
- 기타 포트: 내부 네트워크만
```

### 3. 정기 보안 점검
```bash
# 월 1회 권장 작업
- Docker 이미지 업데이트
- OS 보안 패치 적용
- 접속 로그 점검
- 비밀번호 변경 (분기별)
```

## 🎯 결론 및 권장사항

### 🟢 Public Repository 업로드: 안전함

**조건:**
1. `docker-compose.secure.yml` 파일만 업로드
2. `.env.example` 파일 포함 (실제 .env는 제외)
3. 보안 가이드 문서 포함

### 🔄 배포 워크플로우

```bash
# 1. Repository에서 파일 다운로드
git clone https://github.com/user/kbo-elo-deployment.git
cd kbo-elo-deployment

# 2. 환경변수 설정
cp .env.example .env
vi .env  # 실제 비밀번호 입력

# 3. 보안 배포 실행
docker-compose -f docker-compose.secure.yml up -d

# 4. 배포 후 .env 파일 삭제 (선택사항)
rm .env  # 보안을 위해 삭제
```

### ⚡ 즉시 실행 가능한 명령어

```bash
# EC2에서 한번에 실행 (비밀번호만 입력)
curl -sSL https://raw.githubusercontent.com/user/repo/main/deploy-secure.sh | \
POSTGRES_PASSWORD="YourSecurePassword123!" bash
```

---

**이제 Public Repository에 안전하게 업로드할 수 있습니다!** 🎉