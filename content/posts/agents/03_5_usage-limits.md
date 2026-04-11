---
title: "Pydantic-AI 03-5: 사용량 추적과 제한 (Usage & Limits)"
date: 2026-02-13T11:40:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI"]
---

> **시리즈**: 03. Agent와의 상호작용 — 5/5

## 개요

프로덕션 환경에서 Agent의 비용과 호출 횟수를 제어하는 것은 필수이다. `Usage`와 `UsageLimits`를 통한 사용량 추적 및 제한 방법을 다룬다.

---

## 세부 목차

### 1. 왜 사용량 제한이 필요한가?
- 무한 루프 도구 호출의 위험
- API 비용 폭증 시나리오
- 프로덕션 안전장치의 필요성

### 2. `Usage` 객체 이해하기
- `RunResult.usage()` — 실행 후 사용량 확인
- 요청 토큰(request_tokens), 응답 토큰(response_tokens)
- 총 토큰과 요청 횟수 추적

### 3. `UsageLimits` 설정하기
- `agent.run(prompt, usage_limits=UsageLimits(...))`
- `request_limit` — 최대 모델 요청 횟수
- `request_tokens_limit` — 최대 요청 토큰 수
- `response_tokens_limit` — 최대 응답 토큰 수
- `total_tokens_limit` — 총 토큰 제한

### 4. 제한 초과 시 동작
- `UsageLimitExceeded` 예외 처리
- 제한 초과 전 마지막 유효 결과 활용

### 5. 사용량 모니터링 패턴
- 여러 실행에 걸친 누적 사용량 추적
- 사용자별 / 세션별 사용량 관리
- 대시보드 연동을 위한 로깅

### 6. 비용 최적화 전략
- 모델별 토큰 비용 비교
- 적절한 제한값 설정 가이드라인
- 캐싱을 통한 중복 호출 방지
