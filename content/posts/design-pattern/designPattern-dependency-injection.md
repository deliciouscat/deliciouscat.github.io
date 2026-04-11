---
title: "Vibe Coding을 위한 디자인 패턴 - 의존성 주입(Dependency Injection)"
date: 2026-04-08T19:00:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "의존성주입", "DI", "Dependency Injection"]
---

# Dependency Injection Pattern (의존성 주입 패턴)

Dependency Injection(의존성 주입, DI)은 **객체가 자신이 필요한 의존성을 직접 생성하지 않고, 외부에서 주입(inject)받는** 디자인 패턴이다.
"의존성을 스스로 만들지 말고, 누군가가 가져다줄 때까지 기다려라."

예를 들어:
```python
# DI 없이: 의존성을 스스로 만든다
class OrderService:
    def __init__(self):
        self.db = MySQLDatabase()   # 직접 생성 ← 문제

# DI 적용: 의존성을 주입받는다
class OrderService:
    def __init__(self, db):         # 외부에서 받는다 ← 해결
        self.db = db

# 호출 측에서 의존성을 결정하고 주입
db = MySQLDatabase()
service = OrderService(db)
```
→ `OrderService`는 `MySQLDatabase`가 뭔지 알 필요가 없다. **인터페이스만 알면 된다.**

## 문제: 의존성을 직접 만드는 코드

의존성을 클래스 내부에서 직접 생성하면 코드가 강하게 결합(tightly coupled)된다.

**잘못된 예:**
```python
class UserService:
    def __init__(self):
        self.db = PostgreSQLDatabase(    # 구체 클래스에 직접 의존
            host="localhost",
            port=5432,
            password="secret"           # 설정 값까지 내부에 박혀 있음
        )
        self.mailer = SMTPMailer(
            host="smtp.gmail.com",
            port=587
        )
        self.logger = FileLogger("/var/log/app.log")

    def create_user(self, email, password):
        user = self.db.insert("users", {"email": email, "password": password})
        self.mailer.send(email, "환영합니다!")
        self.logger.log(f"유저 생성: {email}")
        return user
```

위 코드의 문제점:
1. `UserService`가 `PostgreSQLDatabase`, `SMTPMailer`, `FileLogger`의 생성 방법까지 알아야 한다.
2. DB를 `MySQL`로 바꾸려면 `UserService`를 직접 수정해야 한다.
3. 테스트 시 실제 DB/메일 서버가 없으면 테스트 자체가 불가능하다.
4. 설정값(호스트, 비밀번호 등)이 비즈니스 로직 안에 섞여 있다.

**DI를 적용한 예:**
```python
class UserService:
    def __init__(self, db, mailer, logger):   # 의존성을 모두 주입받는다
        self.db = db
        self.mailer = mailer
        self.logger = logger

    def create_user(self, email, password):
        user = self.db.insert("users", {"email": email, "password": password})
        self.mailer.send(email, "환영합니다!")
        self.logger.log(f"유저 생성: {email}")
        return user

# 호출 측에서 조립
db = PostgreSQLDatabase(host="localhost", port=5432, password="secret")
mailer = SMTPMailer(host="smtp.gmail.com", port=587)
logger = FileLogger("/var/log/app.log")

service = UserService(db, mailer, logger)
```

`UserService`는 이제 인터페이스만 알면 된다. DB가 바뀌어도, 메일러가 바뀌어도 `UserService` 코드는 손댈 필요가 없다.

## 의존성 역전 원칙 (DIP)과의 관계

DI는 **의존성 역전 원칙(Dependency Inversion Principle; DIP)을 실현하는 수단**이다.

- DIP: "고수준 모듈은 저수준 모듈에 의존하면 안 된다. 둘 다 추상화에 의존해야 한다." (원칙)
- DI: "의존성을 외부에서 주입해라." (구현 기법)

**DIP만 선언하고 DI 없이 구현한 예 (반쪽짜리):**
```python
class Database:         # 추상화를 만들었지만
    def insert(self, table, data): pass

class UserService:
    def __init__(self):
        self.db = PostgreSQLDatabase()  # 여전히 스스로 생성 ← DIP 위반
```

**DIP + DI를 함께 적용한 예 (완성형):**
```python
from abc import ABC, abstractmethod

class Database(ABC):            # 추상화 (인터페이스)
    @abstractmethod
    def insert(self, table, data): pass

class PostgreSQLDatabase(Database):     # 저수준 모듈
    def insert(self, table, data):
        return f"PostgreSQL: {table} ← {data}"

class MySQLDatabase(Database):          # 저수준 모듈
    def insert(self, table, data):
        return f"MySQL: {table} ← {data}"

class UserService:                      # 고수준 모듈
    def __init__(self, db: Database):   # 추상화에만 의존 + 외부에서 주입
        self.db = db

    def create_user(self, email):
        return self.db.insert("users", {"email": email})

# 주입 시점에서 구체 클래스 결정
service = UserService(PostgreSQLDatabase())
service2 = UserService(MySQLDatabase())
```

## 주입 방식 세 가지

### 1. 생성자 주입 (Constructor Injection) — 가장 권장

```python
class ReportService:
    def __init__(self, fetcher, formatter, exporter):
        self.fetcher = fetcher
        self.formatter = formatter
        self.exporter = exporter

    def generate(self, report_id):
        data = self.fetcher.fetch(report_id)
        formatted = self.formatter.format(data)
        return self.exporter.export(formatted)

service = ReportService(
    fetcher=ApiDataFetcher(),
    formatter=PdfFormatter(),
    exporter=S3Exporter()
)
```
→ 객체 생성 시점에 모든 의존성이 확정된다. 불변 객체를 만들 수 있고, 의존성 누락이 컴파일/생성 시점에 드러난다.

### 2. 세터 주입 (Setter Injection) — 선택적 의존성에 사용

```python
class EmailService:
    def __init__(self, smtp):
        self.smtp = smtp
        self.logger = None          # 선택적 의존성

    def set_logger(self, logger):   # 필요할 때만 주입
        self.logger = logger

    def send(self, to, body):
        if self.logger:
            self.logger.log(f"Sending to {to}")
        return self.smtp.send(to, body)

service = EmailService(SMTPClient())
service.set_logger(FileLogger())    # 로거는 선택 사항
```
→ 필수가 아닌 의존성에 사용한다. 단, 주입 전에 메서드를 호출하면 `None` 에러가 날 수 있으므로 주의.

### 3. 인터페이스 주입 (Interface Injection) — Python에선 드물게 사용

```python
class Injectable(ABC):
    @abstractmethod
    def inject_logger(self, logger): pass

class PaymentService(Injectable):
    def inject_logger(self, logger):
        self.logger = logger

    def pay(self, amount):
        self.logger.log(f"Payment: {amount}")
        return f"Paid {amount}"

# 프레임워크가 inject_logger를 자동 호출하는 구조
service = PaymentService()
service.inject_logger(ConsoleLogger())
```
→ Python에선 덕 타이핑이 가능해서 이 방식은 잘 쓰지 않는다. Java 같은 언어에서 주로 활용된다.

## DI 컨테이너 (IoC Container)

객체가 많아지면 주입 코드가 반복된다. **DI 컨테이너**는 이 조립 과정을 자동화한다.

**컨테이너 없이 직접 조립하면:**
```python
# 의존성 트리를 손으로 다 조립해야 한다
db = PostgreSQLDatabase(host="localhost")
cache = RedisCache(host="redis-server")
repo = UserRepository(db, cache)
mailer = SMTPMailer(host="smtp.gmail.com")
logger = FileLogger("/var/log/app.log")
service = UserService(repo, mailer, logger)   # 점점 길어진다...
```

**간단한 DI 컨테이너 직접 구현:**
```python
class Container:
    def __init__(self):
        self._bindings = {}
        self._singletons = {}

    def bind(self, abstract, factory):
        """매 요청마다 새 인스턴스"""
        self._bindings[abstract] = factory

    def singleton(self, abstract, factory):
        """처음 한 번만 생성하고 이후엔 재사용"""
        self._bindings[abstract] = factory
        self._singletons[abstract] = None

    def make(self, abstract):
        if abstract in self._singletons:
            if self._singletons[abstract] is None:
                self._singletons[abstract] = self._bindings[abstract](self)
            return self._singletons[abstract]
        return self._bindings[abstract](self)


# 등록
container = Container()
container.singleton("db", lambda c: PostgreSQLDatabase(host="localhost"))
container.singleton("cache", lambda c: RedisCache(host="redis-server"))
container.bind("user_repo", lambda c: UserRepository(c.make("db"), c.make("cache")))
container.bind("user_service", lambda c: UserService(c.make("user_repo")))

# 사용: 조립을 컨테이너가 알아서 처리
service = container.make("user_service")
```

→ 컨테이너를 한 번 설정해두면, `make("user_service")` 한 줄로 복잡한 의존성 트리가 자동으로 조립된다.

## 테스트에서의 위력

DI의 진가는 **테스트**에서 드러난다. 실제 DB나 외부 API 없이 비즈니스 로직만 검증할 수 있다.

```python
# 테스트용 Mock 객체
class FakeDatabase:
    def __init__(self):
        self.data = {}
    def insert(self, table, row):
        self.data.setdefault(table, []).append(row)
        return row
    def find(self, table, id):
        return next((r for r in self.data.get(table, []) if r["id"] == id), None)

class FakeMailer:
    def __init__(self):
        self.sent = []
    def send(self, to, body):
        self.sent.append({"to": to, "body": body})

# 테스트: 실제 DB/메일 서버 없이 완전한 격리 가능
def test_create_user_sends_welcome_email():
    db = FakeDatabase()
    mailer = FakeMailer()
    service = UserService(db=db, mailer=mailer, logger=FakeLogger())

    service.create_user("alice@example.com", "password123")

    assert len(mailer.sent) == 1
    assert mailer.sent[0]["to"] == "alice@example.com"
    assert "환영" in mailer.sent[0]["body"]
```

DI 없이 `UserService` 내부에서 `SMTPMailer()`를 직접 생성한다면, 이 테스트는 SMTP 서버 없이 실행조차 안 된다.

## Registry Pattern과의 차이

[레지스트리 패턴](../designpattern-registry/)도 의존성 문제를 다루지만, 방식이 다르다.

| | Dependency Injection | Registry Pattern |
|---|---|---|
| **의존성 취득 방법** | 외부에서 주입받는다 (수동적) | 레지스트리에 물어본다 (능동적) |
| **클라이언트 코드** | 의존성이 누군지 모른다 | 레지스트리에 키를 넣고 꺼낸다 |
| **결합도** | 매우 낮음 | 레지스트리에는 의존 |
| **테스트 격리** | 주입만 바꾸면 됨 | 레지스트리 상태를 초기화해야 함 |
| **주요 사용처** | 서비스 계층, 비즈니스 로직 | 플러그인, 핸들러 동적 등록 |

```python
# Registry 방식: 클라이언트가 직접 조회
class OrderService:
    def process(self, order):
        handler = HandlerRegistry.get(order.type)  # 능동적으로 꺼냄
        return handler.handle(order)

# DI 방식: 클라이언트는 그냥 받아서 씀
class OrderService:
    def __init__(self, handler):    # 수동적으로 주입받음
        self.handler = handler

    def process(self, order):
        return self.handler.handle(order)
```

두 패턴은 **함께 쓰이기도** 한다. DI 컨테이너 내부에서 Registry를 활용해 동적 조회를 수행하고, 그 결과를 외부 객체에 주입하는 방식이다.

## Dependency Injection은 다음과 같은 상황에서 유용하다:

1. **구현체를 교체해야 할 가능성이 있을 때**
   - 개발 환경 DB ↔ 프로덕션 DB
   - 실제 결제 모듈 ↔ 테스트용 결제 모듈

2. **단위 테스트를 제대로 작성하고 싶을 때**
   - 외부 시스템(DB, API, 메일) 없이 비즈니스 로직만 검증

3. **코드가 복잡해지고 클래스 간 결합도를 낮추고 싶을 때**
   - 클래스가 10개를 넘어가기 시작하면 DI 컨테이너 도입을 고려

4. **프레임워크를 사용할 때 (대부분 이미 DI를 지원함)**
   - FastAPI: `Depends()`
   - Spring: `@Autowired`
   - Angular: 생성자 주입 자동화

## 장단점

### 장점

✅ **테스트 용이성**: 실제 의존성을 Mock으로 교체해서 완전한 단위 테스트 가능

✅ **느슨한 결합**: 클래스가 구체 구현이 아닌 추상화에만 의존

✅ **유연한 교체**: 설정 파일이나 환경 변수만 바꿔서 구현체 교체 가능

✅ **단일 책임 원칙 준수**: 객체 생성 책임이 비즈니스 로직과 분리됨

### 단점

❌ **초기 설정 복잡도**: 작은 프로젝트에선 오히려 코드가 늘어나는 느낌

❌ **런타임 에러 가능성**: 주입이 누락되면 컴파일 타임이 아닌 런타임에 오류 발생

❌ **추적 어려움**: IDE에서 "이 인터페이스의 실제 구현체가 뭐야?"를 찾기 번거로울 수 있음

## 용어 정리

**Dependency (의존성)**: 어떤 클래스가 동작하기 위해 필요한 다른 객체  
**Injection (주입)**: 의존성을 외부에서 전달하는 행위  
**Consumer (소비자)**: 의존성을 주입받아 사용하는 클래스  
**Provider (제공자)**: 의존성을 생성하고 공급하는 쪽 (컨테이너, 테스트 코드, 메인 함수 등)  
**IoC Container (IoC 컨테이너)**: 의존성 등록과 조립을 자동화하는 객체

1. 유저 서비스 예시:
   - Consumer → `UserService`
   - Dependency → `Database`, `Mailer`, `Logger`
   - Provider → `container.make("user_service")`

2. 테스트 예시:
   - Consumer → `UserService`
   - Dependency → `FakeDatabase`, `FakeMailer`
   - Provider → 테스트 함수 (`test_create_user_sends_welcome_email`)
