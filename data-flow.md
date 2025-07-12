# 데이터 플로우 다이어그램

## 전체 데이터 흐름

```mermaid
flowchart TB
    subgraph "Data Sources"
        A[Naver Sports API]
    end
    
    subgraph "Data Collection"
        B[Game Schedule API<br/>게임 목록 수집]
        C[Game Detail API<br/>게임 상세 데이터]
    end
    
    subgraph "Data Processing"
        D[Raw Game Data<br/>원시 게임 데이터]
        E[Game Analysis<br/>게임 분석]
        F[Data Fixes<br/>데이터 수정]
    end
    
    subgraph "Data Transformation"
        G[Base State Tracking<br/>베이스 상태 추적]
        H[Field Mapping<br/>필드 매핑]
        I[Dual Column Sync<br/>이중 컬럼 동기화]
        J[Pcode Guarantee<br/>Pcode 보장]
    end
    
    subgraph "Database Operations"
        K[Transaction Start<br/>트랜잭션 시작]
        L[Data Validation<br/>데이터 검증]
        M[Batch Insert<br/>배치 삽입]
        N[Transaction Commit<br/>트랜잭션 커밋]
    end
    
    subgraph "Database Tables"
        O[(games)]
        P[(players)]
        Q[(plate_appearances)]
        R[(pitches)]
        S[(pts_data)]
    end
    
    A --> B
    A --> C
    B --> D
    C --> D
    D --> E
    E --> F
    F --> G
    F --> H
    F --> I
    F --> J
    G --> K
    H --> K
    I --> K
    J --> K
    K --> L
    L --> M
    M --> N
    N --> O
    N --> P
    N --> Q
    N --> R
    N --> S
```

## 게임 데이터 수집 플로우

```mermaid
sequenceDiagram
    participant M as migrate_safe.py
    participant API as Naver API
    participant DB as Database
    
    M->>API: GET /schedule/games
    Note over API: 날짜별 게임 목록
    API-->>M: 게임 ID 리스트
    
    loop 각 게임 ID
        M->>DB: SELECT game_id
        DB-->>M: 존재 여부
        
        alt 게임이 없거나 force=True
            M->>API: GET /game/{gameId}
            API-->>M: 상세 게임 데이터
            M->>M: 데이터 처리
            M->>DB: INSERT 트랜잭션
        else 게임 존재
            M->>M: 건너뛰기
        end
    end
```

## 베이스 상태 데이터 플로우

```mermaid
flowchart LR
    subgraph "API Data"
        A[currentGameState<br/>base1: 2<br/>base2: 0<br/>base3: 5]
    end
    
    subgraph "Analysis Phase"
        B[base1_batting_order: 2<br/>base2_batting_order: 0<br/>base3_batting_order: 5]
    end
    
    subgraph "Field Mismatch Fix"
        C[pre_base1_batting_order: 2<br/>pre_base2_batting_order: 0<br/>pre_base3_batting_order: 5]
    end
    
    subgraph "Dual Column Fix"
        D[pre_base1_batting_order: 2<br/>pre_base1_pcode: "2"<br/>pre_base2_batting_order: 0<br/>pre_base2_pcode: null]
    end
    
    subgraph "Database"
        E[(pitches table)]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
```

## 트랜잭션 처리 플로우

```mermaid
stateDiagram-v2
    [*] --> 트랜잭션시작
    트랜잭션시작 --> 게임데이터삽입
    
    게임데이터삽입 --> 선수데이터삽입
    선수데이터삽입 --> 라인업데이터삽입
    라인업데이터삽입 --> 타석데이터삽입
    타석데이터삽입 --> 투구데이터삽입
    투구데이터삽입 --> PTS데이터삽입
    
    PTS데이터삽입 --> 검증
    검증 --> 커밋: 성공
    검증 --> 롤백: 실패
    
    커밋 --> [*]
    롤백 --> [*]
```

## 병렬 처리 데이터 플로우

```mermaid
flowchart TD
    A[게임 리스트<br/>100개 게임] --> B{워커 수?}
    
    B -->|workers=5| C[ThreadPoolExecutor<br/>5개 워커]
    
    C --> D1[Worker 1<br/>게임 1-20]
    C --> D2[Worker 2<br/>게임 21-40]
    C --> D3[Worker 3<br/>게임 41-60]
    C --> D4[Worker 4<br/>게임 61-80]
    C --> D5[Worker 5<br/>게임 81-100]
    
    D1 --> E[결과 수집]
    D2 --> E
    D3 --> E
    D4 --> E
    D5 --> E
    
    E --> F[통계 업데이트]
```

## 오류 처리 플로우

```mermaid
flowchart TD
    A[게임 처리 시작] --> B{API 호출}
    
    B -->|성공| C[데이터 분석]
    B -->|실패| D[재시도<br/>3회]
    
    D -->|성공| C
    D -->|실패| E[게임 건너뛰기]
    
    C --> F{DB 트랜잭션}
    
    F -->|성공| G[커밋]
    F -->|실패| H[롤백]
    
    H --> I[오류 로깅]
    E --> I
    
    G --> J[성공 카운트 증가]
    I --> K[실패 카운트 증가]
```

## 데이터 변환 상세

### 1. 베이스 상태 변환

```python
# API 데이터
currentGameState = {
    "base1": 2,  # 2번 타자
    "base2": 0,  # 비어있음
    "base3": 5   # 5번 타자
}

# 변환 후
pre_base1_batting_order = 2
pre_base1_pcode = "2"
pre_base2_batting_order = 0
pre_base2_pcode = None
pre_base3_batting_order = 5
pre_base3_pcode = "5"
```

### 2. 필드 매핑

| 원본 필드 | 변환 필드 |
|-----------|-----------|
| base1_batting_order | pre_base1_batting_order |
| base2_batting_order | pre_base2_batting_order |
| base3_batting_order | pre_base3_batting_order |
| - | post_base1_batting_order |
| - | post_base2_batting_order |
| - | post_base3_batting_order |

### 3. 이중 컬럼 동기화

```mermaid
graph LR
    A[batting_order = 5] --> B[pcode = "5"]
    C[batting_order = 0] --> D[pcode = NULL]
```

## 데이터 무결성 보장

```mermaid
flowchart TD
    A[데이터 입력] --> B{외래키 검증}
    
    B -->|통과| C[삽입 진행]
    B -->|실패| D[오류 발생]
    
    C --> E{제약조건 검증}
    
    E -->|통과| F[커밋]
    E -->|실패| G[롤백]
    
    D --> G
    G --> H[오류 보고]
```
