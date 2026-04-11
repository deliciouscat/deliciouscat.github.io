---
title: "Pydantic-AI 02-2: Agent에게 사용설명서 제공하기 (Tool Schema)"
date: 2026-02-13T10:30:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 02. Agent에게 도구 쥐어주기 — 2/4

## 개요

Pydantic-AI는 함수 시그니처와 docstring을 기반으로 도구의 JSON 스키마를 자동 생성한다. 이 스키마가 LLM이 도구를 이해하고 올바르게 호출하는 "사용설명서" 역할을 한다.

---

## 세부 목차

### 1. 스키마 자동 생성 원리
- 함수 시그니처 → JSON Schema 변환 과정
- `Annotated` 타입 힌트의 활용
- Pydantic-AI가 읽는 정보: 파라미터명, 타입, 기본값, docstring

### 2. docstring의 역할
- Google 스타일 docstring 작성법
- `Args:` 섹션이 파라미터 설명으로 변환되는 과정
- 함수 설명(첫 줄)이 도구 설명이 되는 규칙

### 3. 타입 힌트를 통한 스키마 제어
- `Literal` — 선택지 제한
- `Optional` / `Union` — 선택적 파라미터
- `Annotated[int, Field(ge=0, le=100)]` — 값 범위 제약

### 4. `@agent.tool` vs `@agent.tool_plain`
- `tool`: `RunContext`를 첫 번째 인자로 받음
- `tool_plain`: 컨텍스트 없이 순수 함수로 동작
- 언제 어떤 것을 선택해야 하는가

### 5. 커스텀 스키마 오버라이드
- `Tool()` 객체를 직접 생성하여 세밀한 제어
- 파라미터 이름 변경, 설명 커스텀

### 6. 좋은 도구 스키마 설계 원칙
- LLM이 이해하기 쉬운 파라미터 네이밍
- 명확한 반환값 설명의 중요성
- 과도한 파라미터 vs 적절한 추상화
