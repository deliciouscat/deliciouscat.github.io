---
title: "Pydantic-AI 02-3: Agent의 센서 읽기 (RunContext & Dependencies)"
date: 2026-02-14T10:40:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 02. Agent에게 도구 쥐어주기 — 3/4

## 개요

`RunContext[DepsType]`는 Pydantic-AI의 의존성 주입(DI) 시스템의 핵심이다. 도구 함수에 데이터베이스 연결, API 클라이언트 등 외부 의존성을 안전하게 전달하는 방법을 다룬다.

---

## 세부 목차

### 1. 의존성 주입이란?

**전통적인 DI 패턴과 Pydantic-AI의 접근법 비교**

전통적인 의존성 주입 프레임워크(Spring, FastAPI Depends 등)는 생성자나 함수 파라미터를 통해 의존성을 주입한다.

```python
# 전통적 DI (FastAPI 스타일)
from fastapi import Depends

def get_db_session():
    return DatabaseSession()

@app.get("/users")
async def list_users(db: DatabaseSession = Depends(get_db_session)):
    return db.query(User).all()
```

Pydantic-AI는 이와 유사하지만, **Agent 실행 시점**에 의존성을 전달하는 방식을 사용한다:

```python
from pydantic_ai import Agent, RunContext

agent = Agent('openai:gpt-4')

@agent.tool
async def query_database(ctx: RunContext[DatabaseSession], query: str) -> str:
    """데이터베이스 쿼리 실행"""
    db = ctx.deps  # 실행 시 전달된 의존성
    result = await db.execute(query)
    return str(result)

# 실행 시 의존성 주입
db_session = DatabaseSession()
result = await agent.run("사용자 목록 조회", deps=db_session)
```

**왜 글로벌 변수 대신 DI를 사용해야 하는가**

❌ **글로벌 변수 사용 (안티패턴)**

```python
# 전역 DB 클라이언트
DB_CLIENT = DatabaseClient()

@agent.tool
async def get_user(user_id: int) -> str:
    # 전역 변수 직접 참조
    user = await DB_CLIENT.fetch_user(user_id)
    return user.name
```

문제점:
- **테스트 불가능**: Mock 주입이 어려움
- **동시성 문제**: 여러 요청이 동일 전역 객체 공유
- **상태 관리 어려움**: 연결 풀 관리, 트랜잭션 경계 설정 불가

✅ **의존성 주입 사용**

```python
from dataclasses import dataclass

@dataclass
class AppDeps:
    db: DatabaseClient
    user_id: str  # 현재 요청 사용자 ID

agent = Agent[AppDeps, str]('openai:gpt-4')

@agent.tool
async def get_user(ctx: RunContext[AppDeps]) -> str:
    user = await ctx.deps.db.fetch_user(ctx.deps.user_id)
    return user.name

# 요청마다 독립적인 의존성 주입
async def handle_request(user_id: str):
    deps = AppDeps(db=DatabaseClient(), user_id=user_id)
    return await agent.run("내 정보 조회", deps=deps)
```

장점:
- **테스트 가능**: Mock 객체 주입 가능
- **요청별 격리**: 각 실행이 독립적인 의존성 사용
- **명시적 의존성**: 함수 시그니처에서 의존성 확인 가능

---

### 2. `DepsType` 정의하기

**`Agent[DepsType, ResultType]` 제네릭 파라미터**

Agent는 두 개의 타입 파라미터를 받는다:

```python
from pydantic_ai import Agent

# DepsType: 의존성 타입
# ResultType: 반환 결과 타입
agent = Agent[MyDepsType, MyResultType](
    'openai:gpt-4',
    result_type=MyResultType,
)
```

**`dataclass` / `BaseModel` / `NamedTuple`로 의존성 타입 정의**

세 가지 방식 모두 지원된다:

```python
# 방법 1: dataclass (추천)
from dataclasses import dataclass
import httpx

@dataclass
class HttpDeps:
    client: httpx.AsyncClient
    api_key: str

# 방법 2: Pydantic BaseModel
from pydantic import BaseModel

class ConfigDeps(BaseModel):
    api_key: str
    timeout: int = 30

# 방법 3: NamedTuple
from typing import NamedTuple

class SimpleDeps(NamedTuple):
    api_key: str
```

**단일 의존성 vs 복합 의존성 구조**

단일 의존성 (간단한 경우):

```python
# 의존성이 하나면 타입 자체를 사용
agent = Agent[httpx.AsyncClient, str]('openai:gpt-4')

@agent.tool
async def fetch_data(ctx: RunContext[httpx.AsyncClient], url: str) -> str:
    response = await ctx.deps.get(url)  # deps가 곧 클라이언트
    return response.text

# 실행
async with httpx.AsyncClient() as client:
    result = await agent.run("데이터 가져오기", deps=client)
```

복합 의존성 (실전에서 일반적):

```python
@dataclass
class AppDeps:
    http_client: httpx.AsyncClient
    db_session: AsyncSession
    redis_client: Redis
    config: AppConfig
    current_user_id: str

agent = Agent[AppDeps, QueryResult]('openai:gpt-4')

@agent.tool
async def complex_query(ctx: RunContext[AppDeps], query: str) -> str:
    # 여러 의존성 동시 활용
    cache_key = f"query:{query}"
    
    # Redis 캐시 확인
    cached = await ctx.deps.redis_client.get(cache_key)
    if cached:
        return cached
    
    # DB 조회
    result = await ctx.deps.db_session.execute(query)
    
    # 외부 API 호출
    enriched = await ctx.deps.http_client.post(
        ctx.deps.config.api_url,
        json={"data": result}
    )
    
    # 캐시 저장
    await ctx.deps.redis_client.set(cache_key, enriched.text)
    
    return enriched.text
```

---

### 3. `RunContext` 활용하기

**`@agent.tool` 데코레이터와 `RunContext` 첫 번째 인자**

도구 함수의 첫 번째 파라미터로 `RunContext`를 받으면 의존성에 접근할 수 있다:

```python
from pydantic_ai import Agent, RunContext

agent = Agent[DatabaseClient, str]('openai:gpt-4')

@agent.tool
async def search_users(
    ctx: RunContext[DatabaseClient],  # 첫 번째 인자
    name: str,  # LLM이 제공하는 파라미터
    limit: int = 10
) -> list[str]:
    """사용자 이름으로 검색"""
    db = ctx.deps
    results = await db.query(f"SELECT * FROM users WHERE name LIKE '%{name}%' LIMIT {limit}")
    return [r['name'] for r in results]
```

**`ctx.deps`로 의존성 객체 접근**

```python
@agent.tool
async def get_config(ctx: RunContext[AppDeps]) -> str:
    """현재 설정 조회"""
    return f"API URL: {ctx.deps.config.api_url}, Timeout: {ctx.deps.config.timeout}s"
```

**`ctx.retry` — 현재 재시도 횟수 확인**

도구 실행 중 재시도가 발생하면 `ctx.retry` 값이 증가한다. 이를 활용해 재시도 시 다른 전략을 사용할 수 있다:

```python
from pydantic_ai import ModelRetry

@agent.tool
async def fetch_with_retry(ctx: RunContext[httpx.AsyncClient], url: str) -> str:
    """재시도 시 타임아웃 증가"""
    timeout = 5 + (ctx.retry * 5)  # 1차: 5초, 2차: 10초, 3차: 15초
    
    try:
        response = await ctx.deps.get(url, timeout=timeout)
        return response.text
    except httpx.TimeoutException:
        if ctx.retry < 2:
            raise ModelRetry(f"타임아웃 발생. 재시도 중... ({ctx.retry + 1}/3)")
        else:
            raise ModelRetry("최대 재시도 횟수 초과. 다른 URL을 시도하세요.")
```

---

### 4. 의존성 전달 방법

**`agent.run(prompt, deps=my_deps)`로 실행 시 의존성 전달**

```python
from dataclasses import dataclass
import httpx

@dataclass
class MyDeps:
    client: httpx.AsyncClient
    api_key: str

agent = Agent[MyDeps, str]('openai:gpt-4')

# 실행 시 의존성 생성 및 전달
async def main():
    async with httpx.AsyncClient() as client:
        deps = MyDeps(client=client, api_key="sk-...")
        result = await agent.run(
            "외부 API에서 데이터 가져오기",
            deps=deps  # 의존성 주입
        )
    return result
```

**비동기 의존성 처리 (async DB 클라이언트 등)**

비동기 컨텍스트 매니저를 사용하는 의존성은 `async with`로 관리:

```python
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

@dataclass
class DbDeps:
    session: AsyncSession

agent = Agent[DbDeps, list[str]]('openai:gpt-4')

@agent.tool
async def query_users(ctx: RunContext[DbDeps]) -> list[str]:
    result = await ctx.deps.session.execute("SELECT name FROM users")
    return [row[0] for row in result]

# 실행
async def main():
    engine = create_async_engine("postgresql+asyncpg://...")
    async with AsyncSession(engine) as session:
        deps = DbDeps(session=session)
        result = await agent.run("사용자 목록 조회", deps=deps)
    return result
```

---

### 5. 실전 패턴

**HTTP 클라이언트 주입: `httpx.AsyncClient`**

```python
import httpx
from pydantic_ai import Agent, RunContext

agent = Agent[httpx.AsyncClient, str]('openai:gpt-4')

@agent.tool
async def fetch_weather(ctx: RunContext[httpx.AsyncClient], city: str) -> str:
    """날씨 API 호출"""
    response = await ctx.deps.get(
        f"https://api.weather.com/v1/current",
        params={"city": city}
    )
    return response.json()["temperature"]

# 사용
async with httpx.AsyncClient(timeout=10) as client:
    result = await agent.run("서울 날씨 알려줘", deps=client)
```

**데이터베이스 세션 주입**

```python
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

@dataclass
class DbDeps:
    session: AsyncSession

agent = Agent[DbDeps, str]('openai:gpt-4')

@agent.tool
async def get_user_count(ctx: RunContext[DbDeps]) -> int:
    """사용자 수 조회"""
    result = await ctx.deps.session.scalar(
        select(func.count()).select_from(User)
    )
    return result

@agent.tool
async def create_user(ctx: RunContext[DbDeps], name: str, email: str) -> str:
    """사용자 생성"""
    user = User(name=name, email=email)
    ctx.deps.session.add(user)
    await ctx.deps.session.commit()
    return f"사용자 {name} 생성 완료"
```

**설정(Config) 객체 주입**

```python
from pydantic import BaseModel

class AppConfig(BaseModel):
    api_key: str
    api_url: str
    max_retries: int = 3
    timeout: int = 30

@dataclass
class ConfigDeps:
    config: AppConfig
    http_client: httpx.AsyncClient

agent = Agent[ConfigDeps, str]('openai:gpt-4')

@agent.tool
async def call_api(ctx: RunContext[ConfigDeps], endpoint: str) -> str:
    """설정 기반 API 호출"""
    config = ctx.deps.config
    response = await ctx.deps.http_client.get(
        f"{config.api_url}/{endpoint}",
        headers={"Authorization": f"Bearer {config.api_key}"},
        timeout=config.timeout
    )
    return response.text

# 실행
config = AppConfig(api_key="sk-...", api_url="https://api.example.com")
async with httpx.AsyncClient() as client:
    deps = ConfigDeps(config=config, http_client=client)
    result = await agent.run("데이터 가져오기", deps=deps)
```

---

### 6. 테스트에서의 의존성 교체

**테스트 시 Mock 의존성 주입**

```python
import pytest
from unittest.mock import AsyncMock

@dataclass
class ApiDeps:
    client: httpx.AsyncClient

agent = Agent[ApiDeps, str]('openai:gpt-4')

@agent.tool
async def fetch_data(ctx: RunContext[ApiDeps], url: str) -> str:
    response = await ctx.deps.client.get(url)
    return response.text

# 프로덕션 코드
async def production_run():
    async with httpx.AsyncClient() as client:
        deps = ApiDeps(client=client)
        return await agent.run("데이터 가져오기", deps=deps)

# 테스트 코드
@pytest.mark.asyncio
async def test_agent_with_mock():
    # Mock HTTP 클라이언트
    mock_client = AsyncMock(spec=httpx.AsyncClient)
    mock_response = AsyncMock()
    mock_response.text = "mocked data"
    mock_client.get.return_value = mock_response
    
    # Mock 의존성 주입
    test_deps = ApiDeps(client=mock_client)
    result = await agent.run("테스트 데이터 가져오기", deps=test_deps)
    
    # 검증
    mock_client.get.assert_called_once()
    assert "mocked" in result.data
```

**환경별 의존성 전환 전략**

```python
from enum import Enum

class Environment(Enum):
    DEVELOPMENT = "dev"
    STAGING = "staging"
    PRODUCTION = "prod"

@dataclass
class EnvDeps:
    db_url: str
    api_key: str
    debug: bool

def create_deps(env: Environment) -> EnvDeps:
    """환경별 의존성 생성 팩토리"""
    if env == Environment.DEVELOPMENT:
        return EnvDeps(
            db_url="sqlite:///dev.db",
            api_key="test-key",
            debug=True
        )
    elif env == Environment.STAGING:
        return EnvDeps(
            db_url="postgresql://staging-db",
            api_key=os.getenv("STAGING_API_KEY"),
            debug=True
        )
    else:  # PRODUCTION
        return EnvDeps(
            db_url="postgresql://prod-db",
            api_key=os.getenv("PROD_API_KEY"),
            debug=False
        )

# 실행
env = Environment.PRODUCTION
deps = create_deps(env)
result = await agent.run("프로덕션 쿼리", deps=deps)
```

---

## 마무리

`RunContext`와 의존성 주입은 Pydantic-AI의 핵심 설계 패턴이다:

1. **의존성 명시화**: 도구가 필요한 외부 리소스를 타입으로 선언
2. **테스트 가능성**: Mock 주입으로 단위 테스트 작성 가능
3. **요청별 격리**: 각 Agent 실행이 독립적인 의존성 사용
