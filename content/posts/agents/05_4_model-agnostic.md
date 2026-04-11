---
title: "Pydantic-AI 05-4: 모델 교체 전략 (Model-Agnostic Design)"
date: 2026-02-13T13:30:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 05. Agent 실행 흐름 설계 — 4/4

## 개요

Pydantic-AI는 모델에 종속되지 않는 설계를 지향한다. OpenAI, Anthropic, Google Gemini 등 다양한 모델 간 전환 방법과 전략을 다룬다.

---

## 세부 목차

### 1. Model-Agnostic 설계 철학
- Pydantic-AI가 모델 추상화를 제공하는 이유
- 모델 독립적 코드의 이점: 비용 최적화, 벤더 종속 방지

### 2. 지원 모델과 설정
- OpenAI (`"openai:gpt-4o"`, `"openai:gpt-4o-mini"`)
- Anthropic (`"anthropic:claude-sonnet"`)
- Google Gemini (`"google/gemini-2.5-flash"`)
- Groq (`"groq:llama-3.3-70b-versatile"`)
- 기타 OpenAI 호환 모델 연동

### 3. 모델 전환 방법
- 생성 시 모델 지정: `Agent(model="...")`
- 실행 시 모델 오버라이드: `agent.run(prompt, model="...")`
- 환경변수 기반 동적 전환

### 4. 모델별 차이점과 대응
- 도구 호출 지원 수준 차이
- 구조화된 출력 지원 여부
- 토큰 제한, 비용, 속도 비교표

### 5. 모델 Fallback 패턴
- 1차 모델 실패 시 대체 모델로 전환
- 비용 최적화: 간단한 작업은 저렴한 모델, 복잡한 작업은 고성능 모델
- A/B 테스트를 위한 모델 라우팅

### 6. 테스트용 모델
- `TestModel` — 결정적 응답을 반환하는 테스트 전용 모델
- `FunctionModel` — 커스텀 로직으로 응답을 생성하는 모델
- CI/CD에서 실제 API 호출 없이 테스트하기
