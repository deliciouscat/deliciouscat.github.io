---
title: "Pydantic-AI 07-4: 근거 기반 응답 설계 (Grounding & Citation)"
date: 2026-02-13T15:30:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "RAG"]
---

> **시리즈**: 07. 지식 베이스 — Agent 지식 공유 — 4/4

## 개요

검색 결과를 구조화된 응답에 반영하여, Agent가 근거 있는 답변을 생성하도록 설계하는 방법을 다룬다. 환각(Hallucination)을 줄이고 신뢰도를 높이는 핵심 기법이다.

---

## 세부 목차

### 1. Grounding이란?
- LLM 환각(Hallucination)의 문제
- 근거 기반 응답의 정의와 중요성
- "출처 없는 주장"을 방지하는 설계 원칙

### 2. 구조화된 응답에 출처 포함하기
- `result_type`에 `source` / `citation` 필드 정의
- Pydantic `BaseModel`로 응답 + 출처 구조 설계
- LLM이 검색 결과를 인용하도록 유도하는 프롬프트

### 3. Citation 패턴
- 인라인 인용: 문장별 출처 태깅
- 참조 목록: 응답 하단에 출처 모음
- 신뢰도 점수: 각 주장에 대한 근거 강도 표시

### 4. Result Validator로 근거 검증
- 응답에 출처가 포함되어 있는지 검증
- 인용된 출처가 실제 검색 결과에 있는지 확인
- 근거 없는 주장이 포함된 경우 `ModelRetry`로 재생성 요청

### 5. 환각 방지 전략
- System Prompt에서 "모르면 모른다고 답하라" 지시
- 검색 결과에 없는 정보는 생성하지 않도록 제약
- 검색 결과 없을 때의 Fallback 응답 설계

### 6. 실전 예제
- 법률 자문 Agent: 판례/법조항 인용 포함 응답
- 학술 Q&A Agent: 논문/문서 출처 태깅
- 의료 정보 Agent: 가이드라인 기반 근거 제시
