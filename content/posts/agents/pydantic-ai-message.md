---
title: "Pydantic-AI로 에이전트 구축하기: Message Type 사용하기"
date: 2026-02-13T16:45:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

Pydantic-AI에서는 모델에서 처리되었는가/외부에서 입력받았는가를 기준으로 `Request`와 `Response`로 구분한다.

**ModelRequest**: 모델에 보내는 것 (system, user, tool return)
**ModelResponse**: 모델이 보낸 것 (텍스트, tool call)

```py
from pydantic_ai import (
    ModelRequest,
    ModelResponse,
    SystemPromptPart,
    UserPromptPart,
    ToolReturnPart,
    TextPart,
    ToolCallPart,
)

# 에이전트의 대화 기억(Memory)
messages = [
    ModelRequest(
        parts=[
            SystemPromptPart(content="너는 사실에 의거하여 응답하는 비서 에이전트야."),
            UserPromptPart(content="내일 비와?"),
        ]
    ),
    # 에이전트의 반응
    ModelResponse(
        parts=[
            TextPart(content="기상청에서 예보를 알아보겠습니다."),      # 모델의 생각
            ToolCallPart(                                       # 모델의 행동
                tool_name="search_weather",
                args={"date"="tomorrow"},
                tool_call_id="search_weather_318",  # ToolReturnPart와 매칭용 ID
            ),
        ]
    ),
    # 3. 외부 도구 실행 결과
    ModelRequest(
        parts=[
            ToolReturnPart(
                tool_name="search_weather",
                content="temparature: 8°C, foggy (Seoul, 12:00)",
                tool_call_id="search_wearher_318",  # ToolResponsePart와 매칭용 ID
            ),
        ]
    ),
    # 4. 최종 답변
    ModelResponse(
        parts=[
            TextPart(content="서울 정오 기준, 섭씨 8도로 비교적 따듯하지만 안개로 인해 운전 시 각별한 주의가 필요합니다."),
        ]
    ),
]
```

이렇게 만들어진 가상의 과거 대화 이력을 반영하여, 후속 질문을 처리하는 에이전트에게 명령할 수 있다.
```py
from pydantic_ai import Agent

agent = Agent("openai:gpt-4", tools=[search_rate_tool])

result = agent.run_sync(
    "나 지금 치앙마이로 여행 왔는데?",
    message_history=messages,
)
```