---
title: "Pydantic-AI 03-3: Agent 응답 가로채기 (Result Validator)"
date: 2026-02-14T11:20:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 03. Agent와의 상호작용 — 3/5

## 개요

`@agent.result_validator`를 사용하면 Agent가 반환한 결과를 가로채서 추가 검증을 수행하고, 기준에 미달하면 재시도를 요청할 수 있다. Pydantic-AI의 품질 보증 메커니즘이다.

---

## 세부 목차

### 1. Result Validator란?

Pydantic-AI의 `result_validator`는 Agent가 반환한 결과를 검증하는 2차 방어선이다.

**Pydantic 모델 검증 vs Result Validator**

```python
from pydantic import BaseModel, Field
from pydantic_ai import Agent, ModelRetry, RunContext

class BookingRequest(BaseModel):
    hotel_name: str
    check_in: str  # 1차: Pydantic이 str 타입 검증
    check_out: str
    guests: int = Field(ge=1)  # 1차: 1명 이상 검증
```

Pydantic 스키마 검증만으로는 다음과 같은 비즈니스 로직을 검증할 수 없다:
- 체크인 날짜가 체크아웃보다 앞서는가?
- 예약 날짜가 과거인가?
- 해당 호텔이 실제 존재하는가?

이런 "의미적 정합성"을 검증하는 것이 Result Validator의 역할이다.

**LangChain의 OutputParser / Guardrails와의 비교**

| 프레임워크 | 검증 위치 | 재시도 방식 |
|---------|--------|---------|
| LangChain OutputParser | 응답 파싱 후 | 수동으로 재호출 |
| Guardrails | 별도 레일 체인 | Guard 실패 시 재생성 |
| Pydantic-AI | Agent 내부 통합 | `ModelRetry` 자동 재시도 |

Pydantic-AI는 검증이 Agent 실행 루프에 **네이티브로 통합**되어 있다.

---

### 2. `@agent.result_validator` 데코레이터

Result Validator는 데코레이터로 정의하며, Agent가 최종 결과를 반환하기 직전에 실행된다.

**데코레이터 함수 시그니처**

```python
from pydantic_ai import Agent, RunContext, ModelRetry
from datetime import datetime

agent = Agent(
    'openai:gpt-4',
    result_type=BookingRequest,
)

@agent.result_validator
async def validate_booking(
    ctx: RunContext[None],  # 의존성 전달 가능
    result: BookingRequest,  # Agent가 생성한 결과
) -> BookingRequest:  # 검증 통과 시 그대로 반환
    """결과 검증 로직"""
    check_in = datetime.fromisoformat(result.check_in)
    check_out = datetime.fromisoformat(result.check_out)
    
    if check_in >= check_out:
        raise ModelRetry(
            "체크인 날짜가 체크아웃 날짜보다 늦습니다. "
            "check_in < check_out 조건을 만족하도록 수정하세요."
        )
    
    if check_in < datetime.now():
        raise ModelRetry("과거 날짜로 예약할 수 없습니다.")
    
    return result  # 검증 통과
```

**검증 통과 시**: 결과를 그대로 반환하면 Agent는 해당 결과를 최종 응답으로 사용한다.

**검증 실패 시**: `ModelRetry` 예외를 발생시키면 LLM에게 피드백 메시지와 함께 재시도를 요청한다.

---

### 3. `ModelRetry` 예외

`ModelRetry`는 Pydantic-AI의 특수 예외로, **LLM에게 수정을 요청하는 메시지**를 전달한다.

**`raise ModelRetry("이유 설명")`로 재시도 요청**

```python
@agent.result_validator
async def validate_url(ctx: RunContext, result: UrlResponse) -> UrlResponse:
    import httpx
    
    try:
        response = await httpx.AsyncClient().head(result.url, timeout=5)
        if response.status_code >= 400:
            raise ModelRetry(
                f"URL {result.url}이 존재하지 않습니다 (HTTP {response.status_code}). "
                f"유효한 URL을 제공하세요."
            )
    except httpx.RequestError:
        raise ModelRetry(f"{result.url}에 접근할 수 없습니다.")
    
    return result
```

**LLM에게 전달되는 피드백 메시지**

`ModelRetry`의 메시지는 LLM의 대화 기록에 다음과 같이 추가된다:

```
[이전 시도]
Assistant: {"url": "https://example.com/broken-link"}

[시스템 피드백]
URL https://example.com/broken-link이 존재하지 않습니다 (HTTP 404). 
유효한 URL을 제공하세요.

[재시도 요청]
(LLM이 이 피드백을 읽고 다시 응답 생성)
```

**재시도 시 LLM이 이전 실패를 인식하는 방식**

메시지 히스토리에 실패 기록이 남아 있어, LLM은:
1. 이전에 시도한 값이 무엇인지
2. 왜 실패했는지
3. 어떻게 수정해야 하는지

를 맥락으로 이해하고 개선된 응답을 생성한다.

---

### 4. 재시도 횟수 제어

무한 재시도를 방지하기 위해 `result_retries` 파라미터로 최대 횟수를 제한한다.

**`result_retries` 파라미터**

```python
agent = Agent(
    'openai:gpt-4',
    result_type=BookingRequest,
    result_retries=3,  # 최대 3번까지 재시도
)
```

실행 시에도 오버라이드 가능:

```python
result = await agent.run(
    "2박 3일 호텔 예약해줘",
    result_retries=5,  # 이번 실행만 5번까지 허용
)
```

**최대 재시도 초과 시 동작**

재시도 횟수를 초과하면 `UnexpectedModelBehavior` 예외가 발생한다:

```python
from pydantic_ai.exceptions import UnexpectedModelBehavior

try:
    result = await agent.run("예약 요청", result_retries=2)
except UnexpectedModelBehavior as e:
    print(f"검증 실패 (2회 재시도 후): {e}")
    # Fallback 로직 실행
```

---

### 5. 검증 패턴

Result Validator의 다양한 활용 패턴을 살펴본다.

**비즈니스 로직 기반 검증 (예: 날짜 범위 확인)**

```python
@agent.result_validator
async def validate_date_range(ctx: RunContext, result: EventPlan) -> EventPlan:
    from datetime import datetime, timedelta
    
    start = datetime.fromisoformat(result.start_date)
    end = datetime.fromisoformat(result.end_date)
    
    if (end - start).days > 30:
        raise ModelRetry(
            "이벤트 기간이 30일을 초과합니다. "
            "더 짧은 기간으로 조정하세요."
        )
    
    return result
```

**외부 API를 통한 검증 (예: 존재하는 URL인지 확인)**

```python
@agent.result_validator
async def validate_link(ctx: RunContext, result: ArticleSummary) -> ArticleSummary:
    import httpx
    
    async with httpx.AsyncClient() as client:
        for link in result.references:
            try:
                resp = await client.head(link, timeout=3)
                if resp.status_code >= 400:
                    raise ModelRetry(
                        f"참고 링크 {link}가 유효하지 않습니다. "
                        f"실제 접근 가능한 URL로 교체하세요."
                    )
            except httpx.RequestError:
                raise ModelRetry(f"{link}에 접근할 수 없습니다.")
    
    return result
```

**의존성(`RunContext`)을 활용한 동적 검증**

```python
from dataclasses import dataclass

@dataclass
class AppDeps:
    db_session: AsyncSession
    user_id: str

agent = Agent[AppDeps, BookingRequest](
    'openai:gpt-4',
    result_type=BookingRequest,
)

@agent.result_validator
async def validate_user_quota(
    ctx: RunContext[AppDeps],
    result: BookingRequest
) -> BookingRequest:
    # 의존성에서 DB 세션 가져오기
    session = ctx.deps.db_session
    
    # 사용자의 현재 예약 개수 확인
    count = await session.scalar(
        select(func.count()).where(Booking.user_id == ctx.deps.user_id)
    )
    
    if count >= 5:
        raise ModelRetry(
            "이미 5개의 예약이 있습니다. "
            "기존 예약을 취소하거나 다른 계정을 사용하세요."
        )
    
    return result
```

---

### 6. Pydantic 검증과의 이중 레이어

Pydantic-AI는 두 단계의 검증 레이어를 제공한다.

**1차: Pydantic `BaseModel` 스키마 검증**

```python
class Product(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    price: float = Field(gt=0)  # 양수만 허용
    category: Literal["electronics", "books", "clothing"]
```

- 타입 검증 (`str`, `float`)
- 필드 제약 (`min_length`, `gt`)
- 열거형 제한 (`Literal`)

**2차: `@agent.result_validator` 비즈니스 검증**

```python
@agent.result_validator
async def validate_product(ctx: RunContext, result: Product) -> Product:
    # 1차 검증 통과 후 실행됨 (타입과 기본 제약은 이미 OK)
    
    # 비즈니스 규칙: 전자제품은 100달러 이상이어야 함
    if result.category == "electronics" and result.price < 100:
        raise ModelRetry(
            "전자제품은 최소 $100 이상이어야 합니다. "
            "가격을 올리거나 다른 카테고리로 변경하세요."
        )
    
    return result
```

**두 레이어의 역할 분담**

| 검증 레이어 | 역할 | 예시 |
|---------|-----|-----|
| **Pydantic 스키마** | 구문적 정합성 (타입, 형식, 범위) | `price`가 양수인가? |
| **Result Validator** | 의미적 정합성 (비즈니스 로직) | 전자제품 가격이 $100 이상인가? |

이 이중 레이어 구조 덕분에:
- **타입 안전성**: Pydantic이 보장
- **비즈니스 정합성**: Result Validator가 보장
- **자동 재시도**: 두 검증 모두 실패 시 LLM이 다시 시도

---

## 마무리

Result Validator는 Pydantic-AI의 품질 보증 시스템이다. Pydantic 스키마 검증과 결합하여:

1. **타입 안전성** (Pydantic)
2. **비즈니스 로직 검증** (Result Validator)
3. **자동 재시도** (`ModelRetry`)

세 가지를 한 번에 제공한다.
