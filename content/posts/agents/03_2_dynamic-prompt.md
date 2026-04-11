---
title: "Pydantic-AI 03-2: Agent 행동 제어하기 (Dynamic System Prompt)"
date: 2026-02-13T11:10:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 03. Agent와의 상호작용 — 2/5

## 개요

`@agent.system_prompt` 데코레이터를 사용하면 실행 시점의 컨텍스트에 따라 system prompt를 동적으로 생성할 수 있다. LangChain의 미들웨어 대신 Pydantic-AI는 이 패턴으로 Agent 행동을 제어한다.

---

## 세부 목차

### 1. 정적 vs 동적 System Prompt
- `instructions` 파라미터로 전달하는 정적 프롬프트
- `@agent.system_prompt`로 만드는 동적 프롬프트
- 두 방식의 결합: 정적 + 동적 프롬프트 체이닝

### 2. `@agent.system_prompt` 데코레이터
- 데코레이터 함수의 시그니처
- 반환값이 system prompt에 추가되는 방식
- 여러 개의 system prompt 함수 등록하기

### 3. 의존성 기반 동적 프롬프트
- `RunContext[DepsType]`를 활용한 컨텍스트 인식 프롬프트
- 사용자 정보, 시간대, 권한 등에 따른 프롬프트 분기
- 비동기 system prompt 함수

### 4. 프롬프트 설계 패턴
- 역할(Role) 기반 프롬프트
- 제약 조건(Constraints) 명시
- 출력 형식(Format) 가이드

### 5. 실전 예제
- 사용자 권한에 따라 다르게 동작하는 Agent
- 시간대별 인사말이 바뀌는 Agent
- A/B 테스트를 위한 프롬프트 분기
