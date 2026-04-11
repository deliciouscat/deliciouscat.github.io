---
title: "Pydantic-AI 06-2: 의존성 공유를 통한 협업 (Shared Dependencies)"
date: 2026-02-13T14:10:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "Multi-Agent"]
---

> **시리즈**: 06. Multi-Agent — 다중 에이전트 협업 — 2/4

## 개요

여러 Agent가 공통 `DepsType`을 통해 상태를 공유하고 협업하는 패턴을 다룬다. 데이터베이스 연결, 공유 상태 객체 등을 여러 Agent에 걸쳐 사용하는 방법이다.

---

## 세부 목차

### 1. 왜 의존성을 공유하는가?
- 여러 Agent가 동일한 데이터 소스에 접근해야 하는 경우
- 상태 공유를 통한 Agent 간 커뮤니케이션
- 공유 vs 격리의 트레이드오프

### 2. 공통 DepsType 설계
- 여러 Agent가 사용할 수 있는 의존성 타입 정의
- `dataclass` 기반 공유 상태 객체
- 불변(Immutable) vs 가변(Mutable) 의존성

### 3. 공유 패턴 구현
- 동일한 `DepsType`을 사용하는 여러 Agent 정의
- 실행 시 동일한 `deps` 객체 전달
- Agent 간 상태 변경의 가시성

### 4. 공유 상태를 통한 협업
- Agent A가 상태를 변경 → Agent B가 변경된 상태를 읽음
- 리스트/딕셔너리를 통한 결과 축적
- 락(Lock) 없는 비동기 환경에서의 주의사항

### 5. 의존성 범위 관리
- 글로벌 의존성 vs 세션 스코프 의존성
- 의존성 생명주기(Lifecycle) 관리
- 자원 정리(cleanup): `async with` 패턴

### 6. 실전 예제
- 공유 DB 세션으로 여러 Agent가 동일 트랜잭션에서 작업
- 공유 메모리 객체를 통한 Agent 간 메모 전달
