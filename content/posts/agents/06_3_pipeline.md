---
title: "Pydantic-AI 06-3: 단계별 Agent 파이프라인 구성 (Pipeline Composition)"
date: 2026-02-13T14:20:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "Multi-Agent"]
---

> **시리즈**: 06. Multi-Agent — 다중 에이전트 협업 — 3/4

## 개요

한 Agent의 결과를 다음 Agent의 입력으로 연결하는 파이프라인 패턴을 다룬다. 복잡한 작업을 단계별로 분해하여 순차적으로 처리하는 구조이다.

---

## 세부 목차

### 1. 파이프라인 패턴이란?
- Agent A의 출력 → Agent B의 입력 → Agent C의 입력
- Unix 파이프(`|`)와의 유사성
- Graph 기반 워크플로우와의 차이점

### 2. 기본 파이프라인 구현
- 순차적 `agent.run()` 호출 체이닝
- 이전 Agent의 `result.data`를 다음 Agent의 프롬프트에 포함
- 구조화된 결과(`BaseModel`)를 다음 Agent에 전달하기

### 3. 타입 안전한 파이프라인
- Agent별 `result_type` 정의로 단계 간 인터페이스 명확화
- Agent A: `result_type=AnalysisResult` → Agent B: 프롬프트에 `AnalysisResult` 포함
- Pydantic 모델 간 변환과 검증

### 4. 조건부 파이프라인
- 이전 단계의 결과에 따라 다음 단계 분기
- 파이프라인 중간에 사람의 개입(Human-in-the-loop) 삽입
- 실패 시 조기 종료 vs 대체 경로

### 5. 파이프라인 에러 처리
- 중간 단계 실패 시 전체 파이프라인 처리
- 부분 결과 보존과 재시도
- 보상 트랜잭션(Compensating Transaction) 패턴

### 6. 실전 예제
- 문서 분석 파이프라인: 추출 Agent → 분류 Agent → 요약 Agent
- 코드 리뷰 파이프라인: 분석 Agent → 제안 Agent → 포매팅 Agent
