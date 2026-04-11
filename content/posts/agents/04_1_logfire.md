---
title: "Pydantic-AI 04-1: Logfire 실행과 설정"
date: 2026-02-13T12:00:00+09:00
draft: false
categories: ["Agents"]
tags: ["PydanticAI", "Logfire"]
---

> **시리즈**: 04. 관측성(Observability) — Logfire 연동 — 1/3

## 개요

Pydantic Logfire는 Pydantic 생태계의 관측성(Observability) 도구로, Agent의 실행 과정을 추적하고 시각화할 수 있다. LangChain의 LangSmith/Studio에 대응하는 도구이다.

---

## 세부 목차

### 1. Logfire란?
- Pydantic 팀이 만든 관측성 플랫폼
- OpenTelemetry 기반 추적 시스템
- LangSmith / LangFuse와의 비교

### 2. Logfire 설치와 초기 설정
- `pip install logfire` 및 의존성
- `logfire.configure()` 기본 설정
- 프로젝트 토큰 발급 및 환경변수 설정

### 3. Pydantic-AI와 Logfire 연동
- `logfire.instrument_pydantic_ai()` 한 줄 연동
- 자동으로 추적되는 항목: Agent 실행, 도구 호출, 모델 요청
- 추적 범위(span) 구조 이해

### 4. Logfire 대시보드 둘러보기
- 웹 대시보드 접근 및 기본 인터페이스
- 실행 타임라인 읽는 법
- 필터링과 검색

### 5. 로컬 개발 환경에서의 활용
- `logfire.configure(send_to_logfire=False)` — 로컬 전용 모드
- 콘솔 출력으로 추적 정보 확인
- 개발 vs 프로덕션 설정 분리

### 6. 환경별 설정 관리
- 환경변수 기반 설정 전환
- 민감 정보(API 키, 사용자 데이터) 마스킹
- 샘플링 비율 조정을 통한 비용 관리
