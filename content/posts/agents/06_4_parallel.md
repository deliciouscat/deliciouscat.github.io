---
title: "Pydantic-AI 06-4: 병렬 Agent 실행 (Parallel Execution)"
date: 2026-02-13T14:30:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "Multi-Agent"]
---

> **시리즈**: 06. Multi-Agent — 다중 에이전트 협업 — 4/4

## 개요

`asyncio`를 활용하여 여러 Agent를 동시에 실행하는 패턴을 다룬다. 독립적인 작업을 병렬로 처리하여 전체 실행 시간을 단축하는 방법이다.

---

## 세부 목차

### 1. 병렬 실행이 유효한 경우
- 독립적인 작업의 동시 처리
- 여러 소스에서 정보를 동시에 수집
- 병렬 처리의 이점과 비용 고려

### 2. `asyncio.gather()` 기반 병렬 실행
- 여러 `agent.run()` 코루틴을 동시에 실행
- `asyncio.gather(*tasks)` 패턴
- 결과 수집과 병합

### 3. `asyncio.TaskGroup` 활용
- Python 3.11+ `TaskGroup`을 활용한 구조화된 동시성
- 예외 처리와 취소 전파
- `TaskGroup` vs `gather`의 차이점

### 4. 병렬 결과 통합
- 여러 Agent의 결과를 하나의 최종 답변으로 종합
- 통합 Agent 패턴: 병렬 결과 → 종합 Agent
- 결과 충돌 시 해결 전략 (투표, 우선순위 등)

### 5. 동시성 제어
- 세마포어(Semaphore)를 통한 동시 실행 수 제한
- API Rate Limit 고려한 병렬도 조절
- 공유 자원 접근 시 주의사항

### 6. 실전 예제
- 다국어 번역: 각 언어별 Agent 병렬 실행
- 다관점 분석: 긍정/부정/중립 분석 Agent 동시 실행
- 데이터 파이프라인: 여러 데이터 소스 동시 수집
