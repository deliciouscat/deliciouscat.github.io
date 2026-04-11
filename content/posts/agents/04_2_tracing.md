---
title: "Pydantic-AI 04-2: Agent 실행 흐름 시각화 (Tracing)"
date: 2026-02-13T12:10:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "Logfire"]
---

> **시리즈**: 04. 관측성(Observability) — Logfire 연동 — 2/3

## 개요

Logfire Tracing을 활용하면 Agent의 실행 흐름 — 도구 호출, 재시도, 모델 요청 등 — 을 시각적으로 추적할 수 있다.

---

## 세부 목차

### 1. 추적(Tracing)의 기본 개념
- Span, Trace, Attribute의 정의
- OpenTelemetry 표준과 Logfire의 관계
- 분산 추적(Distributed Tracing)의 원리

### 2. Agent 실행 추적 구조
- 최상위 Span: `agent.run()` 실행
- 하위 Span: 모델 요청, 도구 호출, 검증
- Span 간 부모-자식 관계

### 3. 도구 호출 추적
- 도구 이름, 인자, 반환값 기록
- 도구 실행 시간 측정
- 도구 내부에서 추가 Span 생성하기

### 4. 재시도 추적
- 검증 실패 → 재시도 흐름 시각화
- `ModelRetry` 발생 시 기록되는 정보
- 재시도 횟수와 성공까지의 시간 분석

### 5. 커스텀 Span 추가하기
- `logfire.span()` 컨텍스트 매니저
- 도구 함수 내부의 세부 작업 추적
- 사용자 정의 속성(attribute) 추가

### 6. 추적 데이터 분석
- 병목 구간 식별 (느린 도구, 과도한 재시도)
- 모델별 응답 시간 비교
- 실행 패턴 분석과 최적화 방향 도출
