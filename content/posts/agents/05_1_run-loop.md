---
title: "Pydantic-AI 05-1: 실행 단계 이해하기 (Run → Retry → Result)"
date: 2026-02-14T13:00:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 05. Agent 실행 흐름 설계 — 1/4

## 개요

Pydantic-AI Agent의 내부 실행 루프 구조를 이해한다. Graph 기반이 아닌 `run → tool call → retry → result`의 선형 루프로 동작하는 방식을 깊이 있게 다룬다.

---

## 세부 목차

### 1. Agent 실행 루프 전체 구조

**`agent.run()` 호출 시 내부에서 일어나는 일**

Pydantic-AI Agent의 실행은 단일 진입점 `agent.run()`으로 시작된다:

```python
result = await agent.run(
    "사용자 질문",
    deps=my_dependencies,
    message_history=previous_messages,
)
```

내부적으로는 다음과 같은 순서로 진행된다:

```
1. 프롬프트 조합
   ↓
2. 모델 요청
   ↓
3. 응답 처리
   ├─ 텍스트 응답 → (5단계로)
   └─ 도구 호출 → (4단계로)
   ↓
4. 도구 실행 (있는 경우)
   ↓ (결과를 모델에 다시 전달)
   ↓ (2단계로 돌아감)
   ↓
5. 결과 검증
   ├─ Pydantic 검증
   └─ Result Validator 검증
   ↓
6. 최종 결과 반환 / 재시도 / 예외
```

**System Prompt 조합 → 모델 요청 → 응답 처리 → 결과 반환**

단순한 예시:

```python
from pydantic_ai import Agent

agent = Agent(
    'openai:gpt-4',
    system_prompt="당신은 친절한 어시스턴트입니다.",
)

# 실행
result = await agent.run("안녕하세요!")

# 내부 과정:
# 1. 시스템 프롬프트 + 사용자 메시지 조합
#    → "당신은 친절한 어시스턴트입니다." + "안녕하세요!"
# 2. OpenAI API 호출
# 3. 모델 응답 수신: "안녕하세요! 무엇을 도와드릴까요?"
# 4. 결과 반환

print(result.data)  # "안녕하세요! 무엇을 도와드릴까요?"
```

**도구 호출이 포함된 경우의 루프 확장**

도구가 있으면 루프가 여러 번 반복될 수 있다:

```python
agent = Agent('openai:gpt-4')

@agent.tool
async def get_weather(city: str) -> str:
    """날씨 조회"""
    return f"{city}의 날씨는 맑음"

@agent.tool
async def get_time(city: str) -> str:
    """현재 시각 조회"""
    return f"{city}의 현재 시각은 14:30"

result = await agent.run("서울 날씨와 시각 알려줘")

# 내부 루프:
# [1회차]
# 요청 → 모델 응답: "get_weather('서울') 호출"
# → 도구 실행: "서울의 날씨는 맑음"
# → 결과를 모델에 전달

# [2회차]
# 요청 → 모델 응답: "get_time('서울') 호출"
# → 도구 실행: "서울의 현재 시각은 14:30"
# → 결과를 모델에 전달

# [3회차]
# 요청 → 모델 응답: "서울은 맑은 날씨이고, 현재 시각은 14:30입니다."
# → 텍스트 응답 → 최종 결과 반환
```

---

### 2. 1단계: 프롬프트 조합

**정적 `instructions` + 동적 `@agent.system_prompt` 결합**

Agent는 두 가지 방식으로 시스템 프롬프트를 구성할 수 있다:

```python
from pydantic_ai import Agent, RunContext

# 방법 1: 정적 시스템 프롬프트
agent = Agent(
    'openai:gpt-4',
    system_prompt="당신은 Python 전문가입니다.",
)

# 방법 2: 동적 시스템 프롬프트
@agent.system_prompt
async def dynamic_prompt(ctx: RunContext) -> str:
    return f"현재 시각: {datetime.now()}\n당신은 Python 전문가입니다."

# 두 방법을 결합하면:
# 최종 시스템 프롬프트 = 정적 + 동적
```

**`message_history`가 있는 경우의 조합 방식**

이전 대화 기록을 포함하여 실행할 수 있다:

```python
from pydantic_ai.messages import ModelMessage, ModelRequest, ModelResponse

# 1차 대화
result1 = await agent.run("내 이름은 홍길동이야")
history = result1.new_messages()  # 대화 기록 저장

# 2차 대화 (이전 대화 포함)
result2 = await agent.run(
    "내 이름이 뭐였지?",
    message_history=history,
)

# 내부 메시지 구조:
# [시스템 프롬프트]
# "당신은 Python 전문가입니다."
#
# [이전 대화 - 메시지 히스토리]
# User: "내 이름은 홍길동이야"
# Assistant: "알겠습니다, 홍길동님!"
#
# [현재 요청]
# User: "내 이름이 뭐였지?"
```

**최종적으로 모델에 전달되는 메시지 구조**

OpenAI API 형식으로 변환되면:

```json
[
  {
    "role": "system",
    "content": "당신은 Python 전문가입니다."
  },
  {
    "role": "user",
    "content": "내 이름은 홍길동이야"
  },
  {
    "role": "assistant",
    "content": "알겠습니다, 홍길동님!"
  },
  {
    "role": "user",
    "content": "내 이름이 뭐였지?"
  }
]
```

---

### 3. 2단계: 모델 요청과 응답

**LLM API 호출 과정**

```python
# Agent 내부 코드 (단순화)
async def _make_request(messages: list[Message]) -> ModelResponse:
    # 1. 메시지를 모델 API 형식으로 변환
    api_messages = convert_to_api_format(messages)
    
    # 2. API 호출
    response = await openai.chat.completions.create(
        model="gpt-4",
        messages=api_messages,
        tools=get_tool_schemas(),  # 도구 정의 포함
    )
    
    # 3. 응답 파싱
    return parse_response(response)
```

**텍스트 응답 vs 도구 호출 응답 분기**

모델 응답은 두 가지 형태 중 하나:

```python
# 케이스 1: 텍스트 응답
{
    "role": "assistant",
    "content": "안녕하세요!"
}

# 케이스 2: 도구 호출 응답
{
    "role": "assistant",
    "tool_calls": [
        {
            "id": "call_abc123",
            "function": {
                "name": "get_weather",
                "arguments": '{"city": "서울"}'
            }
        }
    ]
}
```

**모델 응답 파싱**

```python
# Agent 내부 분기 로직
if response.tool_calls:
    # 도구 호출 처리
    for tool_call in response.tool_calls:
        result = await execute_tool(tool_call)
        messages.append(result)
    # 루프 재진입 (모델에 다시 요청)
    return await _make_request(messages)
else:
    # 텍스트 응답 처리
    return response.content
```

---

### 4. 3단계: 도구 호출 처리

**도구 선택 → 인자 파싱 → 실행 → 결과 반환**

```python
agent = Agent('openai:gpt-4')

@agent.tool
async def calculate(expression: str) -> float:
    """수식 계산"""
    return eval(expression)  # 실전에서는 안전한 파서 사용

result = await agent.run("23 곱하기 45는?")

# 내부 과정:
# 1. 모델이 도구 선택: calculate
# 2. 인자 파싱: expression = "23 * 45"
# 3. 도구 실행: eval("23 * 45") → 1035.0
# 4. 결과를 모델에 전달: "계산 결과: 1035.0"
```

**도구 결과가 다시 모델에 전달되는 과정**

```python
# 메시지 히스토리에 추가되는 내용:

# [사용자 요청]
User: "23 곱하기 45는?"

# [모델 응답 - 도구 호출]
Assistant: [tool_call: calculate(expression="23 * 45")]

# [도구 실행 결과]
Tool (calculate): 1035.0

# [모델 응답 - 최종]
Assistant: "23 곱하기 45는 1035입니다."
```

**여러 도구가 순차적으로 호출되는 경우**

```python
@agent.tool
async def get_exchange_rate(from_currency: str, to_currency: str) -> float:
    """환율 조회"""
    return 1300.0  # 예시: USD → KRW

@agent.tool
async def multiply(a: float, b: float) -> float:
    """곱셈"""
    return a * b

result = await agent.run("100달러는 한국 돈으로 얼마?")

# 실행 흐름:
# [1회차]
# 모델: get_exchange_rate("USD", "KRW") 호출
# 결과: 1300.0

# [2회차]
# 모델: multiply(100, 1300.0) 호출
# 결과: 130000.0

# [3회차]
# 모델: "100달러는 한국 돈으로 130,000원입니다."
```

일부 모델(GPT-4 등)은 병렬 도구 호출도 지원:

```python
# 병렬 호출 예시 (모델이 한 번에 여러 도구 호출 요청)
result = await agent.run("서울과 부산의 날씨를 알려줘")

# 모델 응답:
# [
#   tool_call: get_weather("서울"),
#   tool_call: get_weather("부산")
# ]
# → 두 도구를 병렬로 실행
# → 결과를 모두 모델에 전달
# → 최종 응답 생성
```

---

### 5. 4단계: 결과 검증과 재시도

**Pydantic 모델 검증 (1차)**

```python
from pydantic import BaseModel, Field

class UserData(BaseModel):
    name: str
    age: int = Field(ge=0, le=150)

agent = Agent('openai:gpt-4', result_type=UserData)
result = await agent.run("사용자 정보 생성")

# 내부 검증 과정:
# 1. 모델 응답: {"name": "홍길동", "age": 30}
# 2. Pydantic 검증:
#    - name이 str인가? ✓
#    - age가 int인가? ✓
#    - 0 <= age <= 150인가? ✓
# 3. 검증 통과 → 결과 반환
```

검증 실패 시:

```python
# 모델이 잘못된 응답 반환: {"name": "홍길동", "age": -5}
# Pydantic 검증: age가 0 미만 ✗
# → 오류 메시지를 모델에 전달
# → 모델이 재시도: {"name": "홍길동", "age": 30}
```

**`@agent.result_validator` 검증 (2차)**

```python
from pydantic_ai import ModelRetry

@agent.result_validator
async def validate_user(ctx: RunContext, result: UserData) -> UserData:
    """비즈니스 로직 검증"""
    if result.age < 18:
        raise ModelRetry("성인(18세 이상)만 등록 가능합니다.")
    
    if "홍" not in result.name:
        raise ModelRetry("성이 '홍'씨인 사용자만 등록 가능합니다.")
    
    return result

# 실행 시:
# 1. Pydantic 검증 통과
# 2. Result Validator 검증
#    - age >= 18? ✓
#    - "홍" in name? ✓
# 3. 최종 결과 반환
```

**검증 실패 → `ModelRetry` → 루프 재진입**

```python
# 시나리오:
result = await agent.run("20세 김철수 정보 생성")

# [1차 시도]
# 모델: {"name": "김철수", "age": 20}
# Pydantic: ✓
# Result Validator: "홍" not in "김철수" ✗
# → ModelRetry("성이 '홍'씨인 사용자만...")

# [2차 시도]
# 모델이 피드백 받고 재생성
# 모델: {"name": "홍철수", "age": 20}
# Pydantic: ✓
# Result Validator: ✓
# → 최종 결과 반환
```

---

### 6. 루프 종료 조건

**최종 텍스트/구조화된 결과 생성 시**

정상 종료:

```python
result = await agent.run("안녕하세요")
# 모델이 최종 응답 반환 → 검증 통과 → 루프 종료
print(result.data)  # "안녕하세요! 무엇을 도와드릴까요?"
```

**`UsageLimits` 초과 시**

```python
from pydantic_ai import UsageLimits

result = await agent.run(
    "복잡한 작업 수행",
    usage_limits=UsageLimits(
        request_tokens=1000,  # 최대 1000 토큰
    )
)

# 토큰 한도 초과 시:
# → UnexpectedModelBehavior 예외 발생
```

**최대 재시도 횟수 초과 시**

```python
agent = Agent(
    'openai:gpt-4',
    result_type=StrictModel,
    result_retries=3,  # 최대 3회
)

try:
    result = await agent.run("작업 수행")
except UnexpectedModelBehavior:
    # 3회 재시도 후에도 검증 실패
    print("검증 실패")
```

**각 종료 시나리오별 반환값과 예외**

| 종료 조건 | 반환값/예외 | 상황 |
|---------|----------|-----|
| 정상 완료 | `RunResult` 객체 | 검증 통과한 최종 결과 |
| 검증 재시도 한도 초과 | `UnexpectedModelBehavior` | `result_retries` 초과 |
| 도구 재시도 한도 초과 | `UnexpectedModelBehavior` | `retries` 초과 |
| UsageLimits 초과 | `UsageLimitExceeded` | 토큰/요청 한도 초과 |
| 네트워크 오류 | `ModelError` | API 호출 실패 |

```python
from pydantic_ai.exceptions import (
    UnexpectedModelBehavior,
    UsageLimitExceeded,
    ModelError,
)

try:
    result = await agent.run("작업")
    print(result.data)
except UnexpectedModelBehavior as e:
    print(f"검증 실패: {e}")
except UsageLimitExceeded as e:
    print(f"한도 초과: {e}")
except ModelError as e:
    print(f"API 오류: {e}")
```

---

## 마무리

Pydantic-AI의 실행 루프는:

1. **프롬프트 조합** → 시스템 프롬프트 + 메시지 히스토리 + 현재 요청
2. **모델 요청** → LLM API 호출
3. **응답 처리** → 텍스트 또는 도구 호출
4. **도구 실행** → 결과를 모델에 피드백 (루프 재진입)
5. **결과 검증** → Pydantic + Result Validator
6. **종료** → 정상 완료 / 재시도 초과 / 한도 초과

이 선형 루프 구조 덕분에 복잡한 다단계 작업도 단일 `agent.run()` 호출로 처리할 수 있다.
