---
title: "Pydantic-AI 03-1: Agent의 사고 과정 듣기 (Streaming)"
date: 2026-02-13T11:00:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 03. Agent와의 상호작용 — 1/5

## 개요

`agent.run_stream()`을 사용하면 Agent의 응답을 실시간으로 스트리밍할 수 있다. 사용자 경험 개선과 긴 응답 처리에 필수적인 패턴을 다룬다.

---

## 세부 목차

### 1. 스트리밍이 필요한 이유
- 사용자 대기 시간 체감 감소
- 긴 응답의 점진적 렌더링
- 토큰 단위 출력의 원리

### 2. `agent.run_stream()` 기본 사용법
- `async with agent.run_stream(prompt) as result:` 패턴
- `StreamedRunResult` 객체의 구조

### 3. 텍스트 스트리밍
- `result.stream_text()` — 텍스트 청크 순회
- `delta=True` 옵션으로 증분 텍스트만 수신
- `result.stream()` — 전체 응답 메시지 스트리밍

### 4. 구조화된 결과 스트리밍
- `result_type`이 지정된 경우의 스트리밍 동작
- 부분 검증(partial validation)의 한계와 대응

### 5. 스트리밍 중 도구 호출 처리
- 스트리밍 도중 도구가 호출되는 흐름
- 도구 실행 후 스트리밍이 재개되는 과정

### 6. 실전 통합 예제
- FastAPI/Starlette SSE 엔드포인트와 연동
- 터미널에서 실시간 출력 구현
