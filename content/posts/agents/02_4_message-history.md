---
title: "Pydantic-AI 02-4: Agent에게 대화 기억시키기 (Message History)"
date: 2026-02-13T10:50:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 02. Agent에게 도구 쥐어주기 — 4/4

## 개요

Pydantic-AI는 별도의 체크포인트 시스템 없이, `message_history` 파라미터를 통해 대화 맥락을 유지한다. 이전 대화를 기반으로 연속적인 상호작용을 구현하는 방법을 다룬다.

---

## 세부 목차

### 1. 대화 맥락의 필요성
- 단일 실행(stateless) Agent의 한계
- 멀티턴 대화의 기본 구조

### 2. `message_history` 파라미터
- `agent.run(prompt, message_history=messages)` 사용법
- `RunResult.all_messages()`로 대화 이력 추출
- 이전 실행 결과를 다음 실행에 전달하기

### 3. 메시지 타입 복습
- `ModelRequest` / `ModelResponse` 구조 (01-3 참조)
- 도구 호출 이력이 포함된 메시지 체인

### 4. 대화 이력 관리 전략
- 토큰 제한을 고려한 이력 트리밍
- 요약 기반 압축 패턴
- 최근 N턴만 유지하는 슬라이딩 윈도우

### 5. 대화 이력 직렬화
- 메시지 객체의 JSON 직렬화/역직렬화
- 데이터베이스에 대화 이력 저장하기
- `model_dump()` / `model_validate()` 활용

### 6. 실전 예제
- 멀티턴 챗봇 구현
- 이전 대화 맥락을 활용한 후속 질문 처리
