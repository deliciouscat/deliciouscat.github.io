---
title: "Pydantic-AI 01-1: Agent 정의와 생성"
date: 2026-02-13T10:00:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 01. Agent의 기본 구조 — 1/3

## 개요

`Agent` 클래스는 Pydantic-AI의 핵심 진입점이다. 이 글에서는 Agent를 정의하고 생성하는 방법을 다룬다.

---

## 세부 목차

### 1. Agent 클래스란?
- Pydantic-AI에서 Agent의 역할과 위치
- LangChain의 AgentExecutor와의 차이점

### 2. Agent 생성 기본
- `Agent()` 생성자의 주요 매개변수
- `model` 설정: 문자열 기반 모델 지정 (`"openai:gpt-4"`, `"google/gemini-2.5-flash"` 등)
- `instructions` (system prompt) 작성법

### 3. System Prompt 설계
- 정적 system prompt: 문자열 직접 전달
- 동적 system prompt: `@agent.system_prompt` 데코레이터 (미리보기)
- 효과적인 system prompt 작성 가이드라인

### 4. 모델 설정과 교체
- 지원 모델 목록 (OpenAI, Anthropic, Google, Groq 등)
- `model` 파라미터의 문자열 형식 이해
- 환경변수 기반 API 키 관리

### 5. Agent 실행 방법
- `agent.run()` — 비동기 실행
- `agent.run_sync()` — 동기 실행
- `RunResult` 객체의 구조

### 6. 첫 번째 Agent 만들기
- 최소 코드로 Agent 생성 및 실행
- 응답 확인과 기본 동작 이해
