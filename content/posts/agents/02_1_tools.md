---
title: "Pydantic-AI로 에이전트 구축하기: Tools 정의하기"
date: 2026-02-13T16:45:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

## 도구(Tools)란 무엇인가?

에이전트에게 **도구(Tools)**는 에이전트가 실제로 작업을 수행할 수 있게 해주는 핵심 요소이다. 

기본적으로 LLM(대규모 언어 모델)은 텍스트를 생성하는 것만 잘한다. 하지만 현실의 문제들은 텍스트 생성 이상의 기능이 필요한 경우가 많다:

- **데이터베이스 조회**: 사용자 정보, 주문 내역 등을 검색해야 함
- **외부 API 호출**: 날씨, 뉴스, 결제 시스템 등과 연동
- **파일 시스템 접근**: 문서 저장, 읽기, 분석
- **계산 및 데이터 처리**: 복잡한 로직 실행
- **상태 변경**: 데이터베이스 업데이트, 주문 생성 등

도구를 정의하면 에이전트는 필요한 순간에 이러한 기능들을 **자율적으로 선택하여 실행**할 수 있다. 이것이 단순한 `챗봇`과 `AI 에이전트`의 차이이다.

## 실제 예제

```py
import os
import random
from typing import Literal, Optional

from pydantic import BaseModel, Field
from pydantic_ai import Agent

# 에이전트 생성
agent = Agent(
    "google/gemini-2.5-flash",
    instructions="너는 티라노사우르스 에이전트야. 울부짖고, 사냥하고, 알을 낳는 행동을 할 수 있어.",
)

@agent.tool_plain
def roar(roar_intensity: Literal["Grrr...", "ROOOAAARRR!!!", "Yee~"] = "Grr...") -> str:
    """티라노사우르스처럼 울부짖습니다. 디렉토리에 roar.txt 파일에 기록을 추가합니다.

    Args:
        roar_intensity: 울부짖는 형태.
    """
    with open("roar.txt", "a") as f:
        f.write(f"{roar_intensity}\n")
    return f"{roar_intensity}으로 울부짖음 성공!"


@agent.tool_plain
def hunt(
    prey: Literal["트리케라톱스", "갈리미무스", "파라사우롤로푸스"] = "갈리미무스",
    hunt_success: bool | None = None,
) -> str:
    """사냥을 시도합니다. 디렉토리에 hunt.txt 파일에 기록을 추가합니다.

    Args:
        prey: 사냥 대상 ("트리케라톱스", "갈리미무스", 또는 "파라사우롤로푸스").
        hunt_success: 사냥 성공 여부. 지정 안 하면 50% 확률로 결정.
    """
    success = hunt_success if hunt_success is not None else random.choice([True, False])
    result = "사냥 성공! 맛있는 저녁식사!" if success else "사냥 실패... 다음 기회를 노리자."
    with open("hunt.txt", "a") as f:
        f.write(f"[{prey}] {result}\n")
    return f"{prey}을(를) 대상으로 {result}"


@agent.tool_plain
def lay_egg(egg_count: int | None = None) -> str:
    """알을 낳습니다. 디렉토리에 eggs.txt 파일에 기록을 추가합니다.

    Args:
        egg_count: 낳을 알의 개수. 지정 안 하면 1~5 랜덤.
    """
    count = egg_count if isinstance(egg_count, int) and egg_count > 0 else random.randint(1, 5)
    with open("eggs.txt", "a") as f:
        f.write("🥚" * count + "\n")
    return f"알 {count}개를 성공적으로 낳았습니다!"
```

## 도구의 주요 특징

### 1. 자동 인식
`@agent.tool_plain` 데코레이터를 붙이면 Pydantic-AI가 자동으로 함수의 시그니처와 docstring을 분석한다. LLM은 이 정보를 기반으로 언제 어떻게 도구를 사용할지 판단한다.

### 2. 명확한 매개변수 정의
```python
Literal["옵션1", "옵션2"]  # 선택지 제한
int | None = None          # 선택적 매개변수
```

매개변수의 타입과 기본값을 명확히 하면, LLM이 올바르게 도구를 호출할 수 있다.

### 3. 설명적인 문서화
일반적인 파이썬 코드와는 다르게, **docstring은 반드시 기입되어야 한다**.
이것을 참고하여 LLM이 도구를 불러오기 때문.

```python
def hunt(prey: Literal["트리케라톱스", "갈리미무스", "파라사우롤로푸스"] = "갈리미무스") -> str:
    """사냥을 시도합니다. 디렉토리에 hunt.txt 파일에 기록을 추가합니다."""
```


## 도구를 설계할 때 고려사항

1. **단일 책임**: 도구는 하나의 명확한 목적만 가져야 함
2. **멱등성(Idempotent)**: 같은 입력에 같은 결과를 반환하도록 (부작용은 제한적으로)
3. **명확한 반환값**: 도구 실행 결과를 문자열로 반환하여 LLM이 이해하기 쉽게 함
4. **오류 처리**: 도구 실행 중 발생할 수 있는 예외를 적절히 처리
