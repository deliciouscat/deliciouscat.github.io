---
title: "Pydantic-AI 07-2: DB를 의존성으로 주입하기 (Database Dependencies)"
date: 2026-02-13T15:10:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "RAG"]
---

> **시리즈**: 07. 지식 베이스 — Agent 지식 공유 — 2/4

## 개요

`RunContext`를 통해 데이터베이스 클라이언트를 Agent에 주입하고, 도구 함수에서 DB를 조회하는 패턴을 다룬다. Pydantic-AI의 DI 시스템이 가장 빛나는 활용 사례이다.

---

## 세부 목차

### 1. DB 의존성 주입의 이점
- 글로벌 DB 연결 vs 의존성 주입 비교
- 테스트 용이성, 연결 관리, 타입 안전성
- 비동기 DB 클라이언트 활용

### 2. DepsType에 DB 클라이언트 포함하기
- `@dataclass`로 DB 연결을 포함한 의존성 타입 정의
- 여러 DB(관계형 + 벡터)를 하나의 DepsType에 구성
- 연결 풀(Connection Pool) 관리

### 3. 도구 함수에서 DB 접근
- `ctx.deps.db_client`로 DB 클라이언트 접근
- 비동기 쿼리 실행 (`await ctx.deps.db.fetch(...)`)
- 쿼리 결과를 LLM에게 전달하는 포매팅

### 4. SQL DB 연동 예제
- PostgreSQL / SQLite 비동기 클라이언트 주입
- 자연어 → SQL 변환 패턴 (Text-to-SQL)
- 쿼리 결과를 자연어로 해석하는 Agent

### 5. NoSQL / 벡터 DB 연동 예제
- MongoDB, Redis 클라이언트 주입
- Pinecone, Chroma, Qdrant 등 벡터 DB 연동
- 그래프 DB (Neo4j) 연동

### 6. DB 연결 생명주기 관리
- `async with` 기반 연결 관리
- 애플리케이션 시작/종료 시 연결 풀 관리
- 에러 시 연결 복구 전략
