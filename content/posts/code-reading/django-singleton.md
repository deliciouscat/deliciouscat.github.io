---
title: "Singleton은 실전에서 이렇게 쓰인다 — Django App Registry"
date: 2026-05-19T17:42:00+09:00
draft: false
categories: ["Code Reading"]
tags: ["Django", "Singleton", "디자인패턴"]
---

> 이전 글 [Vibe Coding을 위한 디자인 패턴 - 싱글톤](/posts/design-pattern/designpattern-singleton/)을 읽었다는 가정 하에 쓴다.

## Django가 뭔지 3줄

Django는 Python으로 서버를 만들 때 쓰는 웹 프레임워크다.  
Supabase가 "DB + 인증 + API를 클라우드에서 제공"하는 서비스라면, Django는 그 서버 코드를 직접 짜는 도구다.  
"앱(app)을 조립해서 하나의 프로젝트를 만든다"는 구조가 특징이고, 이 조립 정보를 관리하는 게 오늘의 주제다.

---

## 문제: 서버가 켜질 때 "뭐가 설치돼 있지?" 를 어떻게 알지?

Supabase를 쓸 때는 어떤 테이블이 있는지 Supabase 대시보드가 관리한다. Django는 그걸 직접 코드로 관리한다. 서버가 켜지는 순간부터 이런 질문에 답해야 한다.

- 이 프로젝트에 어떤 앱들이 설치돼 있지?
- `User` 테이블은 어떤 클래스가 대표하지?
- `auth` 앱은 준비됐나?

이 질문들은 **서버가 켜진 동안 내내 일관된 답을 줘야 한다.** 요청이 올 때마다 다른 답을 주면 안 된다.

그래서 Django는 이걸 **하나의 전역 객체**에 모아둔다.

---

## 해법: `apps` — 프로세스 안의 유일한 지도

```python
# django/apps/registry.py 맨 마지막 줄
apps = Apps(installed_apps=None)
```

이 한 줄이 전부다. `registry.py` 파일이 처음 import될 때 딱 한 번 실행되고, 이후 어디서 `from django.apps import apps`를 쓰든 **같은 객체**가 돌아온다.

`designPattern-singleton.md`에서 봤던 "Python에서 가장 간단한 방법: 모듈" 그대로다.

```python
# Python 모듈은 처음 import할 때만 실행된다
# 이후 같은 import는 캐시된 객체를 반환한다
from django.apps import apps

User = apps.get_model("auth", "User")    # 항상 같은 Apps 인스턴스
config = apps.get_app_config("admin")   # 항상 같은 Apps 인스턴스
```

`__new__`를 막거나 `_instance` 변수를 쓰지 않는다. **모듈 레벨 객체**가 자연스럽게 싱글톤 역할을 한다.

---

## `apps` 안에 뭐가 들어 있나

`apps`는 두 가지를 저장하는 컨테이너다.

```
apps (Apps 인스턴스, 전역 유일)
 ├── app_configs  →  설치된 앱마다 AppConfig 하나
 │    ├── "auth"   →  <AuthConfig>
 │    ├── "admin"  →  <AdminConfig>
 │    └── "myapp"  →  <MyAppConfig>
 │
 └── all_models   →  import된 모델 클래스마다 하나
      ├── "auth" → { "user": User, "group": Group, ... }
      └── "myapp" → { "post": Post, ... }
```

**`AppConfig`** 는 앱의 신분증이다. 이름, 경로, 라벨, 그리고 `ready()` 훅을 담는다.  
**모델 클래스** 는 `User`, `Post` 같은 테이블 대표 클래스 자체다.

---

## 서버가 켜지는 순서 — Singleton이 채워지는 과정

`apps` 객체는 **모듈 import 시점에 생성**되지만 처음엔 비어 있다. 실제로 채워지는 건 `django.setup()` 이후다.

```
서버 실행
  └─ django.setup()
       └─ apps.populate(settings.INSTALLED_APPS)
            │
            ├─ Phase 1: 각 앱의 AppConfig 생성 → app_configs에 등록
            │           (apps_ready = True)
            │
            ├─ Phase 2: 각 앱의 models.py import
            │           → 모델 클래스 정의 시 자동으로 register_model() 호출
            │           (models_ready = True)
            │
            └─ Phase 3: 각 AppConfig.ready() 호출
                        → 시그널 연결 같은 앱 초기화 작업
                        (ready = True)
```

단계가 3개인 이유는 섞이면 문제가 생기기 때문이다. 앱 설정이 안 끝난 상태에서 모델을 로드하거나, 모델이 안 준비된 상태에서 시그널을 연결하면 순환 import나 미완성 객체 참조가 발생한다.

---

## 이건 어느 레벨의 Singleton인가

싱글톤 포스트 끝부분에 나온 것처럼, **멀티프로세스 환경에서 "싱글톤이 정말 하나인가?"는 의미가 없어진다.**

Django의 경우도 마찬가지다.

```
[서버 인프라]
  워커 프로세스 1 → apps (앱/모델 지도)  ┐
  워커 프로세스 2 → apps (앱/모델 지도)  ├─ 코드는 같지만 메모리는 각자
  워커 프로세스 3 → apps (앱/모델 지도)  ┘

  PostgreSQL (DB) ← 모든 워커가 같은 데이터를 읽고 씀
```

`apps`는 **한 프로세스(워커) 안**에서 하나다. 워커가 3개면 `apps`도 3개지만, 같은 코드·같은 설정으로 만든 복제본이라 결과는 동일하다.

진짜 "프로덕트 전체"의 단일 저장소는 **DB**다. DB는 프로세스 밖에 있는 공유 창고이고, `apps`는 각 프로세스가 가진 **코드/메타데이터 지도**다. 관심사가 다르다.

| | `apps` (registry) | DB |
|---|---|---|
| 저장하는 것 | 앱·모델 **코드** 구조 | 실제 **데이터** |
| 범위 | 프로세스 1개 | 서비스 전체 |
| 바뀌는 시점 | 서버 재시작 | 쿼리 실행 때 |
| 싱글톤 스코프 | 프로세스 내 | 인프라 내 |

---

## Singleton 패턴의 교훈 — "왜 하나여야 하는가"

싱글톤 포스트에서 가장 중요한 말은 이거였다.

> **반드시 하나일 필요가 없는 객체에 싱글톤을 쓰면 불필요하게 결합도만 높인다.**

Django app registry는 이 기준을 통과한다. 하나여야 하는 **도메인 이유**가 있기 때문이다.

- `auth.User`가 무엇인지에 대한 답은 이 프로세스 안에서 하나여야 한다.
- 요청마다, 모듈마다 다른 `User` 클래스를 참조하면 ORM이 망가진다.

반면 단순히 "여러 곳에서 쓰니까 하나로 만들자"는 이유라면 안티패턴이 된다.

---

## Singleton의 단점 — Django는 어떻게 처리했나

싱글톤 포스트에서 단점으로 꼽은 것들이 Django에서 어떻게 나타나는지 확인해보자.

### 테스트가 어렵다 → `set_installed_apps()`로 탈출구 제공

전역 registry는 테스트 간 상태가 공유된다. Django는 이를 알고 있어서, 테스트 환경에서 앱 목록을 임시로 교체하는 API를 따로 만들어뒀다.

```python
# 테스트 내에서만 다른 앱 구성을 사용
with self.settings(INSTALLED_APPS=["myapp"]):
    # 이 블록 안에서는 apps가 다른 상태
    ...
# 나오면 원래대로 복원
```

내부적으로 `set_installed_apps()` / `unset_installed_apps()` / `clear_cache()`가 쓰인다.

### 멀티스레드 Race Condition → `RLock` + Double-Checked Locking

`populate()`는 싱글톤 포스트에서 나온 `Double-Checked Locking` 구조와 같다.

```python
def populate(self, installed_apps=None):
    if self.ready:          # 락 없이 빠르게 확인 (이미 완료된 경우)
        return

    with self._lock:        # 락 획득
        if self.ready:      # 락 안에서 다시 확인 (Race Condition 방지)
            return
        if self.loading:    # Reentrant 호출 방지
            raise RuntimeError("populate() isn't reentrant")
        ...
```

패턴 포스트의 코드와 거의 같은 구조다. 실제 프레임워크에서도 그대로 쓰인다.

---

## module-level Singleton — Python의 실용적 방식

싱글톤 포스트에서 "Python에서 가장 간단한 방법"으로 소개한 모듈 방식이 Django에서 실제로 쓰이는 형태다.

```python
# designPattern-singleton.md 예시
# config.py
debug = False
db_url = "localhost:5432"
```

```python
# Django 방식
# registry.py
class Apps:
    ...

apps = Apps(installed_apps=None)  # 모듈 레벨 객체 하나
```

차이가 있다면 Django는 **단순 변수 대신 클래스 인스턴스**를 쓴다는 것이다. 덕분에:

- 초기화 상태(`apps_ready`, `models_ready`, `ready`)를 추적할 수 있다.
- 메서드(`get_model`, `get_app_config`)로 API를 제공할 수 있다.
- 테스트에서 별도 `Apps([...])` 인스턴스를 만들 여지가 남는다.

모듈이 자연스럽게 캐시해주는 덕분에 `__new__`나 `_instance` 없이도 싱글톤처럼 동작한다.

---

## 한 줄 정리

> Django app registry는 "싱글톤을 어떻게 구현하느냐"보다 **"언제 하나여야 하는가"가 명확할 때, Python에서 가장 자연스러운 방식(module-level object)으로 구현하면 충분하다**는 걸 보여주는 예시다.
