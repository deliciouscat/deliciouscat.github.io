---
title: "Pydantic-AI 06-1: Agent 간 위임하기 (Agent Delegation)"
date: 2026-02-13T14:00:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "Multi-Agent"]
---

> **시리즈**: 06. Multi-Agent — 다중 에이전트 협업 — 1/4

## 개요

Pydantic-AI에서 다중 Agent 협업의 가장 기본적인 패턴은 도구 함수 내에서 다른 Agent를 호출하는 "위임(Delegation)"이다.

---

## 세부 목차

### 1. Agent 위임이란?
- 하나의 Agent가 특정 작업을 다른 Agent에게 넘기는 패턴
- LangGraph의 Agent 전환과의 비교
- 위임의 장점: 관심사 분리, 전문화

### 2. 도구 내에서 Agent 호출하기
- `@agent.tool` 함수 안에서 `other_agent.run()` 호출
- 부모 Agent ↔ 자식 Agent 간 데이터 전달
- 자식 Agent의 결과를 도구 반환값으로 변환

### 3. 위임 구조 설계
- 오케스트레이터 Agent + 전문 Agent 패턴
- 분류(Router) Agent → 처리(Worker) Agent 패턴
- 계층적 위임 (Manager → Team Lead → Worker)

### 4. 컨텍스트 전파
- 부모의 `RunContext`를 자식 Agent에 전달하는 방법
- 공통 의존성 공유 vs 격리
- 자식 Agent의 메시지 이력 관리

### 5. 에러 전파와 재시도
- 자식 Agent 실행 실패 시 부모 Agent의 대응
- 위임 실패에 대한 Fallback 전략
- 재시도 예산의 분배

### 6. 실전 예제
- 고객 서비스: 분류 Agent → (환불 Agent / 기술지원 Agent / 일반문의 Agent)
- 문서 처리: 파싱 Agent → 분석 Agent → 보고서 Agent
