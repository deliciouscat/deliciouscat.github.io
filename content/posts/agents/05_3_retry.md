---
title: "Pydantic-AI 05-3: Agent 오류 처리 프로세스 (Result Validator & Retry)"
date: 2026-02-14T13:20:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 05. Agent 실행 흐름 설계 — 3/4

## 개요

검증 실패 시 자동 재시도 메커니즘은 Pydantic-AI의 핵심 오류 처리 전략이다. 도구 레벨과 결과 레벨의 재시도를 통합적으로 이해한다.

---

## 세부 목차

### 1. 오류 처리의 두 계층

Pydantic-AI는 오류를 처리하는 두 가지 계층을 제공한다.

**도구 레벨 재시도**: 도구 함수 내에서 `ModelRetry` 발생

도구 실행 중 문제가 발생하면 도구 함수 안에서 `ModelRetry`를 발생시킬 수 있다:

```python
from pydantic_ai import Agent, RunContext, ModelRetry
import httpx

agent = Agent('openai:gpt-4')

@agent.tool
async def fetch_url(ctx: RunContext, url: str) -> str:
    """웹 페이지 내용 가져오기"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=5)
            if response.status_code == 404:
                raise ModelRetry(
                    f"URL {url}을 찾을 수 없습니다 (404). "
                    f"다른 URL을 시도하세요."
                )
            return response.text
    except httpx.TimeoutException:
        raise ModelRetry(
            f"{url} 응답이 너무 느립니다. "
            f"다른 URL을 시도하거나 나중에 다시 시도하세요."
        )

# 실행 시:
# LLM이 잘못된 URL 제공 → 404 오류
# → ModelRetry 발생
# → LLM에게 피드백 전달
# → LLM이 다른 URL로 재시도
```

**결과 레벨 재시도**: `@agent.result_validator`에서 `ModelRetry` 발생

최종 결과 검증 시점에서도 재시도를 요청할 수 있다:

```python
from pydantic import BaseModel, Field

class BookingRequest(BaseModel):
    hotel_name: str
    check_in: str
    check_out: str
    guests: int = Field(ge=1)

agent = Agent('openai:gpt-4', result_type=BookingRequest)

@agent.result_validator
async def validate_booking(ctx: RunContext, result: BookingRequest) -> BookingRequest:
    """예약 정보 검증"""
    from datetime import datetime
    
    check_in = datetime.fromisoformat(result.check_in)
    check_out = datetime.fromisoformat(result.check_out)
    
    if check_in >= check_out:
        raise ModelRetry(
            "체크인 날짜가 체크아웃 날짜와 같거나 늦습니다. "
            "check_in < check_out 조건을 만족하도록 수정하세요."
        )
    
    if (check_out - check_in).days > 30:
        raise ModelRetry(
            "숙박 기간이 30일을 초과합니다. "
            "더 짧은 기간으로 조정하세요."
        )
    
    return result
```

**각 계층의 역할과 차이점**

| 계층 | 발생 시점 | 목적 | 예시 |
|-----|---------|-----|-----|
| **도구 레벨** | 도구 함수 실행 중 | 도구 입력값이 잘못되었거나 외부 API 오류 | 존재하지 않는 URL, API 타임아웃 |
| **결과 레벨** | 최종 결과 생성 후 | 비즈니스 로직 검증 실패 | 날짜 범위 오류, 할당량 초과 |

---

### 2. 도구 실행 중 재시도

**도구 함수에서 `raise ModelRetry("수정 요청 메시지")`**

```python
@agent.tool
async def calculate_discount(
    ctx: RunContext,
    original_price: float,
    discount_percent: float
) -> float:
    """할인가 계산"""
    if discount_percent < 0 or discount_percent > 100:
        raise ModelRetry(
            f"할인율은 0~100 사이여야 합니다. "
            f"현재 값: {discount_percent}"
        )
    
    if original_price <= 0:
        raise ModelRetry(
            f"원가는 0보다 커야 합니다. "
            f"현재 값: {original_price}"
        )
    
    return original_price * (1 - discount_percent / 100)

# 실행 예시:
result = await agent.run("10,000원 상품에 150% 할인 적용")

# [1차 시도]
# LLM: calculate_discount(10000, 150)
# → ModelRetry("할인율은 0~100 사이여야 합니다. 현재 값: 150")

# [2차 시도]
# LLM이 피드백 받고 수정
# LLM: calculate_discount(10000, 15)
# → 성공: 8500.0
```

**LLM에게 전달되는 오류 피드백**

`ModelRetry`의 메시지는 대화 기록에 추가되어 LLM이 볼 수 있다:

```
[대화 기록]

User: "10,000원 상품에 150% 할인 적용"
Assistant (tool call): calculate_discount(10000, 150)

Tool Error: "할인율은 0~100 사이여야 합니다. 현재 값: 150"

Assistant (tool call): calculate_discount(10000, 15)

Tool Success: 8500.0
Assistant (final): "10,000원 상품에 15% 할인을 적용하면 8,500원입니다."
```

**`retries` 파라미터로 도구별 재시도 횟수 제한**

각 도구마다 재시도 횟수를 제한할 수 있다:

```python
from pydantic_ai import Tool

@agent.tool(retries=3)  # 이 도구는 최대 3번까지 재시도
async def risky_api_call(ctx: RunContext, endpoint: str) -> str:
    """불안정한 API 호출"""
    try:
        response = await api_client.get(endpoint)
        return response.text
    except APIError as e:
        if ctx.retry < 2:
            raise ModelRetry(f"API 오류 발생. 재시도 중... ({ctx.retry + 1}/3)")
        else:
            # 최대 재시도 횟수에 도달하면 다른 전략 제안
            raise ModelRetry(
                "API가 계속 실패합니다. "
                "다른 엔드포인트를 시도하거나 나중에 다시 시도하세요."
            )
```

전역 재시도 설정:

```python
agent = Agent(
    'openai:gpt-4',
    retries=5,  # 모든 도구의 기본 재시도 횟수
)

# 특정 도구만 재시도 횟수 오버라이드
@agent.tool(retries=10)  # 이 도구는 10번까지
async def critical_tool(ctx: RunContext) -> str:
    """중요한 작업 - 더 많은 재시도 허용"""
    pass
```

---

### 3. 결과 검증 실패와 재시도

**`@agent.result_validator`에서의 검증 로직**

```python
from datetime import datetime, timedelta

class EventPlan(BaseModel):
    event_name: str
    start_date: str
    end_date: str
    location: str
    max_attendees: int = Field(gt=0)

agent = Agent('openai:gpt-4', result_type=EventPlan)

@agent.result_validator
async def validate_event(ctx: RunContext, result: EventPlan) -> EventPlan:
    """이벤트 계획 검증"""
    start = datetime.fromisoformat(result.start_date)
    end = datetime.fromisoformat(result.end_date)
    now = datetime.now()
    
    # 과거 날짜 검증
    if start < now:
        raise ModelRetry(
            f"이벤트 시작일이 과거입니다 (시작: {result.start_date}). "
            f"오늘({now.date()}) 이후의 날짜로 설정하세요."
        )
    
    # 기간 검증
    duration = (end - start).days
    if duration < 1:
        raise ModelRetry(
            "이벤트 종료일이 시작일보다 앞서거나 같습니다. "
            "최소 1일 이상의 기간을 설정하세요."
        )
    
    if duration > 14:
        raise ModelRetry(
            f"이벤트 기간이 {duration}일로 너무 깁니다. "
            f"최대 14일 이내로 조정하세요."
        )
    
    # 참석자 수 검증
    if result.max_attendees > 1000:
        raise ModelRetry(
            f"최대 참석자 수({result.max_attendees}명)가 너무 많습니다. "
            f"1000명 이하로 설정하세요."
        )
    
    return result
```

**검증 실패 메시지가 LLM에게 전달되는 방식**

```python
# 실행 예시
result = await agent.run("내일부터 20일간 2000명 참석 가능한 컨퍼런스 계획")

# [1차 시도]
# LLM 응답: {
#   "event_name": "Tech Conference",
#   "start_date": "2026-02-15",
#   "end_date": "2026-03-07",  # 20일 기간
#   "location": "Seoul",
#   "max_attendees": 2000
# }
# 
# Result Validator:
# → duration = 20일 > 14일 ✗
# → max_attendees = 2000 > 1000 ✗
# → ModelRetry("이벤트 기간이 20일로 너무 깁니다...")

# [2차 시도]
# LLM이 피드백 받고 수정:
# {
#   "event_name": "Tech Conference",
#   "start_date": "2026-02-15",
#   "end_date": "2026-02-25",  # 10일로 조정
#   "location": "Seoul",
#   "max_attendees": 800  # 1000명 이하로 조정
# }
# → 검증 통과 ✓
```

**`result_retries`로 결과 검증 재시도 횟수 제한**

```python
agent = Agent(
    'openai:gpt-4',
    result_type=EventPlan,
    result_retries=5,  # 결과 검증 재시도 최대 5회
)

# 실행 시 오버라이드
result = await agent.run(
    "이벤트 계획 생성",
    result_retries=3,  # 이번 실행만 3회로 제한
)
```

---

### 4. 재시도 전략 설계

**명확한 피드백 메시지 작성법**

❌ **나쁜 예**: 모호한 메시지

```python
raise ModelRetry("날짜가 잘못되었습니다.")
```

✅ **좋은 예**: 구체적인 지시

```python
raise ModelRetry(
    f"체크인 날짜({result.check_in})가 체크아웃 날짜({result.check_out})보다 늦습니다. "
    f"체크인을 체크아웃보다 앞선 날짜로 변경하거나, "
    f"체크아웃을 체크인보다 뒤의 날짜로 변경하세요."
)
```

**점진적 힌트 제공 (1차 실패: 일반적 → 2차 실패: 구체적)**

```python
@agent.result_validator
async def validate_with_hints(ctx: RunContext, result: QueryResult) -> QueryResult:
    """재시도 횟수에 따라 힌트 강도 증가"""
    
    if not result.query_valid:
        if ctx.retry == 0:
            # 1차 실패: 일반적인 힌트
            raise ModelRetry(
                "쿼리 형식이 올바르지 않습니다. "
                "SQL 문법을 확인하세요."
            )
        elif ctx.retry == 1:
            # 2차 실패: 더 구체적인 힌트
            raise ModelRetry(
                "SELECT, FROM, WHERE 절의 순서와 문법을 확인하세요. "
                "예시: SELECT * FROM users WHERE age > 18"
            )
        else:
            # 3차 이상 실패: 매우 구체적인 예시
            raise ModelRetry(
                "다음 형식을 따르세요:\n"
                "SELECT [컬럼명] FROM [테이블명] WHERE [조건]\n\n"
                "현재 쿼리: {result.query}\n"
                "오류 부분: WHERE 절의 비교 연산자를 확인하세요."
            )
    
    return result
```

**`ctx.retry` 값을 활용한 단계별 대응**

```python
@agent.tool
async def fetch_data_with_fallback(ctx: RunContext, source: str) -> str:
    """재시도 횟수에 따라 전략 변경"""
    
    if ctx.retry == 0:
        # 1차 시도: 빠른 API
        try:
            return await fast_api.get(source)
        except APIError:
            raise ModelRetry(
                "빠른 API가 실패했습니다. 재시도 중..."
            )
    
    elif ctx.retry == 1:
        # 2차 시도: 느리지만 안정적인 API
        try:
            return await stable_api.get(source)
        except APIError:
            raise ModelRetry(
                "메인 API가 모두 실패했습니다. "
                "캐시된 데이터를 사용합니다..."
            )
    
    else:
        # 3차 이상: 캐시 사용
        cached = await cache.get(source)
        if cached:
            return f"[캐시됨] {cached}"
        else:
            raise ModelRetry(
                "모든 데이터 소스가 실패했습니다. "
                "다른 source 값을 시도하거나 나중에 다시 시도하세요."
            )
```

---

### 5. 재시도 한계 초과 시 처리

**`UnexpectedModelBehavior` 예외**

재시도 횟수를 초과하면 `UnexpectedModelBehavior` 예외가 발생한다:

```python
from pydantic_ai.exceptions import UnexpectedModelBehavior

agent = Agent(
    'openai:gpt-4',
    result_type=StrictModel,
    result_retries=3,
)

try:
    result = await agent.run("작업 수행")
except UnexpectedModelBehavior as e:
    print(f"검증 실패 (3회 재시도 후): {e}")
    print(f"마지막 시도 메시지: {e.message}")
```

**Fallback 전략 설계**

```python
async def run_with_fallback(prompt: str) -> dict:
    """재시도 실패 시 안전한 기본값 반환"""
    try:
        result = await agent.run(prompt, result_retries=3)
        return result.data.dict()
    
    except UnexpectedModelBehavior:
        # Fallback 1: 더 간단한 모델로 재시도
        simple_agent = Agent('openai:gpt-3.5-turbo', result_type=SimpleModel)
        try:
            result = await simple_agent.run(prompt)
            return result.data.dict()
        except UnexpectedModelBehavior:
            # Fallback 2: 기본값 반환
            return {
                "status": "failed",
                "message": "AI 처리 실패, 기본값 사용",
                "data": DEFAULT_VALUE
            }
```

**부분 결과 활용 패턴**

```python
class PartialResult(BaseModel):
    name: str
    age: Optional[int] = None
    email: Optional[str] = None
    processed: bool = False

agent = Agent('openai:gpt-4', result_type=PartialResult)

@agent.result_validator
async def validate_partial(ctx: RunContext, result: PartialResult) -> PartialResult:
    """필수 필드만 검증, 선택 필드는 허용"""
    if not result.name:
        raise ModelRetry("name 필드는 필수입니다.")
    
    # email이 있으면 검증, 없으면 무시
    if result.email and "@" not in result.email:
        raise ModelRetry("email 형식이 올바르지 않습니다.")
    
    result.processed = True
    return result

# 실행: 부분 정보만 있어도 통과
result = await agent.run("홍길동의 기본 정보")
# {"name": "홍길동", "age": null, "email": null, "processed": true}
```

---

### 6. 에러 처리 모범 사례

**예측 가능한 실패에 대한 사전 방어**

```python
@agent.tool
async def divide_numbers(ctx: RunContext, a: float, b: float) -> float:
    """나눗셈 (0으로 나누기 방어)"""
    if b == 0:
        raise ModelRetry(
            "0으로 나눌 수 없습니다. "
            "b 값을 0이 아닌 숫자로 변경하세요."
        )
    return a / b

@agent.tool
async def fetch_user(ctx: RunContext, user_id: int) -> dict:
    """사용자 조회 (범위 검증)"""
    if user_id < 1 or user_id > 999999:
        raise ModelRetry(
            f"user_id ({user_id})가 유효 범위(1~999999)를 벗어났습니다."
        )
    
    user = await db.get_user(user_id)
    if user is None:
        raise ModelRetry(
            f"user_id {user_id}를 찾을 수 없습니다. "
            f"다른 user_id를 시도하거나 'list_users' 도구로 목록을 확인하세요."
        )
    
    return user
```

**도구 내부의 try-except와 `ModelRetry`의 조합**

```python
@agent.tool
async def robust_api_call(ctx: RunContext, endpoint: str) -> str:
    """견고한 API 호출 (여러 예외 처리)"""
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(endpoint)
            response.raise_for_status()
            return response.text
    
    except httpx.TimeoutException:
        raise ModelRetry(
            f"{endpoint}의 응답이 10초를 초과했습니다. "
            f"더 빠른 엔드포인트를 시도하거나 나중에 다시 시도하세요."
        )
    
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise ModelRetry(
                f"{endpoint}를 찾을 수 없습니다 (404). "
                f"URL을 확인하거나 다른 엔드포인트를 시도하세요."
            )
        elif e.response.status_code == 403:
            raise ModelRetry(
                f"{endpoint} 접근이 거부되었습니다 (403). "
                f"인증이 필요한지 확인하거나 공개 엔드포인트를 사용하세요."
            )
        else:
            raise ModelRetry(
                f"API 오류 발생 (HTTP {e.response.status_code}). "
                f"다른 엔드포인트를 시도하세요."
            )
    
    except httpx.NetworkError:
        raise ModelRetry(
            f"{endpoint}에 네트워크 연결을 할 수 없습니다. "
            f"URL이 올바른지 확인하거나 나중에 다시 시도하세요."
        )
    
    except Exception as e:
        # 예상치 못한 오류: 로깅 후 ModelRetry
        logger.error(f"Unexpected error in robust_api_call: {e}")
        raise ModelRetry(
            f"예상치 못한 오류가 발생했습니다: {type(e).__name__}. "
            f"다른 파라미터로 다시 시도하세요."
        )
```

**로깅과 알림을 통한 반복 실패 모니터링**

```python
import logging
from collections import defaultdict

logger = logging.getLogger(__name__)
failure_counts = defaultdict(int)

@agent.tool
async def monitored_tool(ctx: RunContext, task: str) -> str:
    """반복 실패 모니터링"""
    tool_name = "monitored_tool"
    
    try:
        result = await perform_task(task)
        
        # 성공 시 실패 카운트 리셋
        if failure_counts[tool_name] > 0:
            logger.info(f"{tool_name} 복구됨 (이전 실패 {failure_counts[tool_name]}회)")
            failure_counts[tool_name] = 0
        
        return result
    
    except TaskError as e:
        failure_counts[tool_name] += 1
        
        # 로그 기록
        logger.warning(
            f"{tool_name} 실패 #{failure_counts[tool_name]}: {e}",
            extra={"retry": ctx.retry, "task": task}
        )
        
        # 반복 실패 시 알림
        if failure_counts[tool_name] >= 5:
            await send_alert(
                f"경고: {tool_name}이 {failure_counts[tool_name]}회 연속 실패 중"
            )
        
        # LLM에게 피드백
        if ctx.retry < 2:
            raise ModelRetry(
                f"{task} 작업이 실패했습니다. "
                f"다른 방식으로 시도하세요."
            )
        else:
            raise ModelRetry(
                f"{task} 작업이 계속 실패합니다 ({failure_counts[tool_name]}회). "
                f"완전히 다른 접근 방식을 사용하거나 이 작업을 건너뛰세요."
            )

async def send_alert(message: str):
    """모니터링 시스템에 알림 전송"""
    # Slack, PagerDuty, 이메일 등으로 알림
    logger.critical(message)
    # await slack_client.send_message(channel="#alerts", text=message)
```

---

## 마무리

Pydantic-AI의 재시도 메커니즘은:

1. **두 계층 방어**: 도구 레벨 + 결과 레벨
2. **자동 피드백**: `ModelRetry` 메시지를 LLM에게 전달
3. **유연한 전략**: `ctx.retry`로 단계별 대응 가능
4. **안전한 한계**: 재시도 횟수 제한으로 무한 루프 방지

명확한 오류 메시지와 단계적 힌트 제공이 성공적인 재시도의 핵심이다.