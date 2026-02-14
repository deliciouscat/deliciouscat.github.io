---
title: "Pydantic-AI 01-2: Agent의 출력을 검증하기 (Structured Result)"
date: 2026-02-14T10:10:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 01. Agent의 기본 구조 — 2/3

## 개요

Pydantic-AI의 핵심 강점은 Agent 응답을 Pydantic `BaseModel`로 타입 안전하게 검증할 수 있다는 점이다.

---

## 세부 목차

### 1. 왜 구조화된 결과가 필요한가?

**자유 텍스트 응답의 한계**

LLM이 자유 텍스트로만 응답하면 파싱과 검증이 어렵다:

```python
# 자유 텍스트 응답 예시
response = "사용자 정보: 이름은 홍길동이고, 나이는 30세, 이메일은 hong@example.com입니다."

# 파싱 필요
import re
name = re.search(r'이름은 (.+?)이고', response).group(1)  # 불안정
age = int(re.search(r'나이는 (\d+)세', response).group(1))
email = re.search(r'이메일은 (.+?)입니다', response).group(1)
```

문제점:
- **파싱 오류**: 응답 형식이 조금만 달라져도 실패
- **타입 불안정**: `age`가 숫자인지 보장 불가
- **검증 불가**: 이메일 형식이 올바른지 확인 어려움

**타입 안전성이 프로덕션 코드에 주는 이점**

구조화된 결과를 사용하면:

```python
from pydantic import BaseModel, EmailStr, Field

class UserInfo(BaseModel):
    name: str = Field(min_length=1)
    age: int = Field(ge=0, le=150)
    email: EmailStr  # 이메일 형식 자동 검증

agent = Agent('openai:gpt-4', result_type=UserInfo)
result = await agent.run("홍길동의 정보 조회")

# 타입 안전한 접근
print(result.data.name)  # str 타입 보장
print(result.data.age + 10)  # int 연산 가능
print(result.data.email)  # 유효한 이메일 보장
```

이점:
- **IDE 자동완성**: `result.data.` 입력 시 필드 목록 표시
- **타입 체크**: mypy, pyright로 정적 타입 검증
- **런타임 검증**: Pydantic이 자동으로 형식 확인
- **리팩토링 안전**: 필드명 변경 시 IDE가 모든 사용처 추적

---

### 2. `result_type` 파라미터

**`Agent(result_type=MyModel)`로 응답 스키마 지정**

Agent 생성 시 `result_type`을 지정하면 LLM 응답이 해당 타입으로 파싱된다:

```python
from pydantic import BaseModel
from pydantic_ai import Agent

class WeatherReport(BaseModel):
    city: str
    temperature: float
    condition: str

agent = Agent(
    'openai:gpt-4',
    result_type=WeatherReport,  # 응답 스키마 지정
)

result = await agent.run("서울 날씨 알려줘")
print(result.data.temperature)  # float 타입
```

**Pydantic `BaseModel`을 활용한 응답 구조 정의**

Pydantic의 모든 기능을 활용할 수 있다:

```python
from pydantic import BaseModel, Field, validator
from typing import Literal

class BookRecommendation(BaseModel):
    title: str = Field(description="책 제목")
    author: str = Field(description="저자명")
    genre: Literal["소설", "에세이", "자기계발", "과학"]
    rating: float = Field(ge=1.0, le=5.0, description="평점 (1-5)")
    summary: str = Field(max_length=200, description="200자 이내 요약")
    
    @validator('title')
    def title_not_empty(cls, v):
        if not v.strip():
            raise ValueError('제목은 비어있을 수 없습니다')
        return v.strip()

agent = Agent('openai:gpt-4', result_type=BookRecommendation)
```

---

### 3. 기본 타입 결과

**`str`, `int`, `bool` 등 기본 타입을 `result_type`으로 사용**

복잡한 모델이 필요 없으면 기본 타입 사용 가능:

```python
# 문자열 결과
agent_str = Agent('openai:gpt-4', result_type=str)
result = await agent_str.run("파이썬을 한 문장으로 설명해줘")
print(result.data)  # str: "파이썬은 읽기 쉽고 강력한 프로그래밍 언어입니다."

# 정수 결과
agent_int = Agent('openai:gpt-4', result_type=int)
result = await agent_int.run("2024년에서 2000년을 빼면?")
print(result.data + 100)  # int: 124

# 불리언 결과
agent_bool = Agent('openai:gpt-4', result_type=bool)
result = await agent_bool.run("파이썬은 인터프리터 언어인가?")
print(result.data)  # bool: True
```

**`Union` 타입을 통한 다중 결과 타입**

상황에 따라 다른 타입을 반환해야 하면 `Union` 사용:

```python
from typing import Union
from pydantic import BaseModel

class SuccessResult(BaseModel):
    status: Literal["success"]
    data: dict

class ErrorResult(BaseModel):
    status: Literal["error"]
    message: str
    code: int

agent = Agent(
    'openai:gpt-4',
    result_type=Union[SuccessResult, ErrorResult],
)

result = await agent.run("데이터 조회")

# 타입 가드로 분기
if isinstance(result.data, SuccessResult):
    print(f"성공: {result.data.data}")
elif isinstance(result.data, ErrorResult):
    print(f"오류 {result.data.code}: {result.data.message}")
```

---

### 4. 복합 모델 결과

**중첩된 BaseModel 구조**

복잡한 데이터는 중첩 모델로 표현:

```python
from pydantic import BaseModel
from typing import List

class Address(BaseModel):
    street: str
    city: str
    zipcode: str

class ContactInfo(BaseModel):
    email: EmailStr
    phone: str

class Person(BaseModel):
    name: str
    age: int
    address: Address  # 중첩 모델
    contacts: ContactInfo
    tags: List[str]

agent = Agent('openai:gpt-4', result_type=Person)
result = await agent.run("홍길동 정보 생성")

# 중첩 접근
print(result.data.address.city)  # "서울"
print(result.data.contacts.email)  # "hong@example.com"
```

**`Field(description=...)`로 LLM에게 필드 의미 전달**

`description`은 LLM에게 필드의 의미를 설명하는 힌트가 된다:

```python
from pydantic import Field

class ProductReview(BaseModel):
    product_name: str = Field(description="리뷰 대상 제품명")
    rating: int = Field(
        ge=1,
        le=5,
        description="1(최악)부터 5(최고)까지의 평점"
    )
    pros: List[str] = Field(
        description="제품의 장점 목록 (최소 2개 이상)"
    )
    cons: List[str] = Field(
        description="제품의 단점 목록 (최소 1개 이상)"
    )
    would_recommend: bool = Field(
        description="다른 사람에게 추천할 의향이 있는지 여부"
    )
    summary: str = Field(
        max_length=100,
        description="리뷰 핵심 내용을 100자 이내로 요약"
    )

agent = Agent('openai:gpt-4', result_type=ProductReview)
```

LLM은 이 `description`을 보고 각 필드에 적절한 값을 생성한다.

**`Optional` 필드와 기본값 처리**

필수가 아닌 필드는 `Optional`로 표시:

```python
from typing import Optional

class ArticleSummary(BaseModel):
    title: str
    author: str
    published_date: Optional[str] = None  # 선택 필드
    summary: str
    tags: List[str] = []  # 기본값: 빈 리스트
    reading_time_minutes: Optional[int] = Field(
        default=None,
        description="예상 읽기 시간 (분), 알 수 없으면 비워두기"
    )

agent = Agent('openai:gpt-4', result_type=ArticleSummary)
result = await agent.run("기사 요약 생성")

# Optional 필드 안전하게 접근
if result.data.published_date:
    print(f"발행일: {result.data.published_date}")
else:
    print("발행일 정보 없음")
```

---

### 5. 결과 검증 흐름

**Pydantic 검증 실패 시 자동 재시도 메커니즘**

LLM이 잘못된 형식으로 응답하면 Pydantic 검증이 실패하고, Pydantic-AI는 자동으로 재시도를 요청한다:

```python
class StrictData(BaseModel):
    age: int = Field(ge=0, le=150)  # 0~150 범위
    email: EmailStr  # 이메일 형식

agent = Agent('openai:gpt-4', result_type=StrictData)

# 실행 시나리오:
# 1차 시도: LLM이 {"age": -5, "email": "invalid"} 반환
#   → Pydantic 검증 실패 (age < 0, email 형식 오류)
#   → Pydantic-AI가 LLM에게 오류 메시지 전달
# 2차 시도: LLM이 {"age": 25, "email": "user@example.com"} 반환
#   → 검증 통과 → 최종 결과 반환

result = await agent.run("사용자 데이터 생성")
```

내부 프로세스:

```
[1차 시도]
LLM → {"age": -5, "email": "invalid"}

[Pydantic 검증]
❌ age: -5는 0 이상이어야 함
❌ email: 유효한 이메일 형식이 아님

[시스템 피드백]
"검증 오류:
- age: ensure this value is greater than or equal to 0
- email: value is not a valid email address"

[2차 시도]
LLM → {"age": 25, "email": "user@example.com"}

[Pydantic 검증]
✅ 통과 → 결과 반환
```

**`result_retries` 파라미터로 재시도 횟수 제어**

기본적으로 재시도 횟수 제한이 있으며, 필요 시 조정 가능:

```python
agent = Agent(
    'openai:gpt-4',
    result_type=StrictData,
    result_retries=5,  # 최대 5번까지 재시도
)

# 또는 실행 시 오버라이드
result = await agent.run(
    "데이터 생성",
    result_retries=3,  # 이번 실행만 3번으로 제한
)
```

재시도 초과 시 `UnexpectedModelBehavior` 예외 발생:

```python
from pydantic_ai.exceptions import UnexpectedModelBehavior

try:
    result = await agent.run("생성", result_retries=2)
except UnexpectedModelBehavior as e:
    print(f"검증 실패 (2회 재시도 후): {e}")
    # Fallback 로직 실행
```

---

### 6. 실전 예제

**API 응답을 구조화된 객체로 변환하는 Agent**

```python
from pydantic import BaseModel, HttpUrl
from typing import List, Optional

class ApiResponse(BaseModel):
    status_code: int
    headers: dict[str, str]
    body: dict
    
class ParsedApiData(BaseModel):
    user_id: int
    username: str
    email: EmailStr
    created_at: str
    is_active: bool
    profile_url: Optional[HttpUrl] = None

agent = Agent('openai:gpt-4', result_type=ParsedApiData)

@agent.tool
async def fetch_api_data(user_id: int) -> ApiResponse:
    """외부 API에서 사용자 데이터 가져오기"""
    import httpx
    async with httpx.AsyncClient() as client:
        response = await client.get(f"https://api.example.com/users/{user_id}")
        return ApiResponse(
            status_code=response.status_code,
            headers=dict(response.headers),
            body=response.json()
        )

# Agent가 API 응답을 파싱하여 구조화된 객체로 변환
result = await agent.run(
    "user_id 123의 데이터를 가져와서 ParsedApiData 형식으로 파싱해줘"
)

# 타입 안전한 접근
print(result.data.username)
print(result.data.email)
if result.data.profile_url:
    print(f"프로필: {result.data.profile_url}")
```

**여러 필드를 가진 분석 결과 반환**

```python
from pydantic import BaseModel, Field
from typing import List, Literal

class SentimentAnalysis(BaseModel):
    """텍스트 감성 분석 결과"""
    sentiment: Literal["positive", "negative", "neutral"] = Field(
        description="전체적인 감성 (긍정/부정/중립)"
    )
    confidence: float = Field(
        ge=0.0,
        le=1.0,
        description="분석 신뢰도 (0~1)"
    )
    key_phrases: List[str] = Field(
        description="핵심 감성 표현 문구 (3~5개)"
    )
    emotions: dict[str, float] = Field(
        description="세부 감정 점수 (기쁨, 슬픔, 분노, 놀람 등)"
    )
    summary: str = Field(
        max_length=150,
        description="분석 결과 요약 (150자 이내)"
    )

agent = Agent('openai:gpt-4', result_type=SentimentAnalysis)

text = """
오늘 새로 오픈한 레스토랑에 다녀왔는데, 
음식은 정말 맛있었지만 서비스가 너무 느려서 실망스러웠습니다.
특히 파스타는 훌륭했어요!
"""

result = await agent.run(f"다음 리뷰를 분석해줘: {text}")

# 구조화된 결과 활용
print(f"감성: {result.data.sentiment}")
print(f"신뢰도: {result.data.confidence:.2%}")
print(f"핵심 문구: {', '.join(result.data.key_phrases)}")
print(f"감정 분석:")
for emotion, score in result.data.emotions.items():
    print(f"  {emotion}: {score:.2f}")
print(f"\n요약: {result.data.summary}")
```

출력 예시:

```
감성: neutral
신뢰도: 87.50%
핵심 문구: 정말 맛있었지만, 서비스가 너무 느려서, 훌륭했어요
감정 분석:
  기쁨: 0.65
  실망: 0.45
  만족: 0.70
  불만: 0.40

요약: 음식 품질은 우수하나 서비스 속도 개선 필요. 전체적으로 중립적 평가.
```

---

## 마무리

구조화된 결과는 Pydantic-AI의 핵심 기능이다:

1. **타입 안전성**: Pydantic으로 런타임 검증
2. **자동 재시도**: 검증 실패 시 LLM이 자동으로 수정
3. **IDE 지원**: 자동완성과 타입 체크로 개발 생산성 향상
