---
title: "Vibe Coding을 위한 디자인 패턴 - 싱글톤(Singleton)"
date: 2026-05-14T15:41:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "싱글톤", "Singleton"]
---

Singleton Pattern은 **클래스의 인스턴스가 오직 하나만 생성되도록 보장하고, 그 인스턴스에 대한 전역 접근점을 제공하는** 생성 디자인 패턴이다.

여기서 **인스턴스(instance)**는 클래스라는 설계도를 바탕으로 메모리에 실제로 만들어진 객체 하나를 가리킨다. 예를 들어 `Config()`를 호출하면 그때 생성되는 것이 `Config`의 인스턴스다. 같은 클래스라도 호출할 때마다 새로 만들면 서로 다른 인스턴스가 생기고, 싱글톤은 그중에서 살아 있는 인스턴스를 하나로 고정하는 패턴이다.

쉽게 말하면, 어떤 클래스를 아무리 많이 `new` 해도 항상 동일한 객체 하나를 반환하도록 만드는 패턴이다.

예를 들어 애플리케이션 설정(Config), 로거(Logger), 데이터베이스 연결 풀(Connection Pool) 같은 것들은 여러 개 만들 이유가 없다. 오히려 여러 개가 생기면 문제가 발생한다. 이런 상황에서 싱글톤이 등장한다.

## 문제가 있는 예시

먼저 싱글톤 없이 코드를 작성하면 어떤 문제가 생기는지 보자.

```python
class Config:
    def __init__(self):
        self.debug = False
        self.db_url = "localhost:5432"

config1 = Config()
config2 = Config()

config1.debug = True

print(config1.debug)  # True
print(config2.debug)  # False ← 다른 인스턴스라서 값이 다르다
```

`Config`가 여러 개 생성되면 인스턴스마다 상태가 달라진다. 어떤 곳에서는 `debug=True`, 어떤 곳에서는 `debug=False`인 상황이 생긴다.

의도는 "전체 앱에서 공유되는 설정"이었는데, 실제로는 인스턴스마다 따로 상태를 가져서 동기화 문제가 발생한다.

## 싱글톤 적용

싱글톤 패턴의 핵심은 두 가지다.

1. 생성자를 외부에서 직접 호출하지 못하게 막는다.
2. 인스턴스를 반환하는 정적 메서드를 하나 만들고, 이미 인스턴스가 있으면 그걸 반환, 없으면 새로 만든다.

```python
class Config:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance.debug = False
            cls._instance.db_url = "localhost:5432"
        return cls._instance

config1 = Config()
config2 = Config()

config1.debug = True

print(config1.debug)  # True
print(config2.debug)  # True ← 같은 인스턴스다
print(config1 is config2)  # True
```

이제 `Config()`를 몇 번 호출해도 항상 같은 객체를 반환한다.

**헷갈릴 수 있는 부분:**  
`__new__`라는 이름은 "새 인스턴스를 만들어라"는 원래 역할에서 온 것이다. 싱글톤에서는 그 메서드를 가로채서, 원래 동작(새로 만들기) 대신 기존 것을 반환하도록 바꿔치기한다. 이름이 `__new__`인 건 "항상 새로 만든다"는 의미가 아니라 "객체 생성 시점에 호출되는 훅"이기 때문이다.

## 고전적인 구현 (클래스 메서드 방식)

Python에서 가장 전통적으로 많이 쓰는 방식이다.

```python
class Singleton:
    _instance = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self):
        self.value = 0

s1 = Singleton.get_instance()
s2 = Singleton.get_instance()

print(s1 is s2)  # True
```

`get_instance()`를 통해서만 인스턴스를 가져오도록 유도한다.

단, Python에서는 `Singleton()`을 직접 호출하는 것을 막기가 언어 차원에서 쉽지 않다. 이 방식에는 구멍이 두 가지 있다.

```python
s1 = Singleton.get_instance()  # 의도된 방법

s2 = Singleton()               # 구멍 1: 생성자를 직접 호출하면 새 인스턴스가 생긴다
s3 = Singleton._instance       # 구멍 2: 내부 변수에 직접 접근해도 get_instance()를 우회한다
```

`_instance` 앞의 언더스코어(`_`)는 "내부 변수니까 건드리지 마세요"라는 **관례적 경고**일 뿐, 언어가 강제로 막아주지는 않는다. Java처럼 생성자를 `private`으로 선언하면 컴파일러가 막아주지만, Python에는 그런 장치가 없다. 싱글톤의 무결성은 결국 코드를 쓰는 사람의 규율에 의존하게 된다.

엄격하게 제한하고 싶다면 `__init__`에서 이미 인스턴스가 있으면 예외를 던지거나, `__new__` 방식을 사용하는 것이 낫다.

## 스레드 안전 싱글톤

멀티스레드 환경에서는 두 스레드가 동시에 `_instance is None`을 확인하고 둘 다 인스턴스를 만들 수 있다. 이를 **Race Condition**이라 한다.

```python
import threading

class Config:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                # 락을 얻은 뒤에도 다시 확인한다 (Double-Checked Locking)
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance.debug = False
        return cls._instance
```

락을 얻기 전에 한 번, 락을 얻은 후에 한 번 더 체크한다. 이를 **Double-Checked Locking** 패턴이라 한다.

이미 인스턴스가 있는 경우에는 락 없이 바로 반환되므로 성능 부담도 줄어든다.

## Python에서 가장 간단한 방법: 모듈

Python에서는 모듈 자체가 싱글톤처럼 동작한다.

```python
# config.py
debug = False
db_url = "localhost:5432"
```

```python
# app.py
import config

config.debug = True
```

```python
# other.py
import config

print(config.debug)  # True ← 같은 모듈 객체다
```

Python은 모듈을 처음 임포트할 때만 실행하고, 이후에는 캐싱된 모듈 객체를 그대로 반환한다. 따라서 모듈 레벨 변수는 자연스럽게 전역 상태를 공유한다.

간단한 경우라면 클래스로 싱글톤을 구현하는 것보다 모듈을 활용하는 것이 훨씬 간결하다.

## 실제 사용 예시: 로거

```python
import threading

class Logger:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._logs = []
        return cls._instance

    def log(self, message: str):
        self._logs.append(message)
        print(f"[LOG] {message}")

    def get_logs(self):
        return self._logs

# 어디서 호출해도 같은 로거다
logger1 = Logger()
logger2 = Logger()

logger1.log("서버 시작")
logger2.log("요청 수신")

print(logger1.get_logs())
# ['서버 시작', '요청 수신']

print(logger1 is logger2)  # True
```

로거가 하나의 인스턴스로 유지되므로 로그가 한 곳에 모인다.

## 실제 사용 예시: 데이터베이스 연결 풀

데이터베이스 연결은 비용이 크기 때문에 연결 객체를 하나만 만들어 재사용하는 것이 일반적이다.

```python
import threading

class DatabaseConnection:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._connection = cls._instance._connect()
        return cls._instance

    def _connect(self):
        print("DB 연결 생성")
        return {"host": "localhost", "port": 5432}

    def query(self, sql: str):
        return f"Execute: {sql} on {self._connection}"

# 여러 곳에서 호출해도 연결은 한 번만 생성된다
db1 = DatabaseConnection()
db2 = DatabaseConnection()

print(db1.query("SELECT * FROM users"))
print(db1 is db2)  # True
```

## 장점

1. **인스턴스가 하나임을 보장**
   - 전역 상태를 일관되게 유지할 수 있다.

2. **전역 접근점 제공**
   - 어디서든 같은 인스턴스에 접근할 수 있다.

3. **최초 사용 시점에만 초기화 (Lazy Initialization)**
   - 무거운 자원(DB 연결, 설정 파일 로드 등)을 실제로 필요한 시점까지 초기화를 미룰 수 있다.

## 단점

1. **단일 책임 원칙(SRP) 위반 가능성**
   - 하나의 클래스가 "자기 역할"과 "인스턴스 수 관리"라는 두 가지 책임을 갖는다.

2. **전역 상태로 인한 숨겨진 의존성**
   - 싱글톤은 전역 변수처럼 동작하기 때문에 어디서든 상태를 변경할 수 있다. 코드 흐름을 추적하기 어려워지고 버그 원인을 찾기 힘들어진다.

3. **테스트가 어렵다**
   - 단위 테스트에서 싱글톤의 상태가 테스트 간에 공유된다. 한 테스트에서 상태를 바꾸면 다른 테스트에 영향을 미친다. 테스트 격리를 위해 인스턴스를 초기화하는 별도 메서드가 필요해진다.

4. **멀티스레드 환경에서 주의 필요**
   - 구현이 잘못되면 Race Condition으로 인스턴스가 여러 개 생성될 수 있다.

5. **의존성 주입(DI)과 충돌**
   - 싱글톤은 내부에서 직접 인스턴스를 가져오는 구조라서 외부에서 주입하기 어렵다. DI 컨테이너를 사용하는 환경에서는 싱글톤을 직접 구현하기보다 DI 프레임워크에 싱글톤 스코프를 맡기는 것이 낫다.

## 언제 사용해야 할까?

1. **전체 앱에서 단 하나의 인스턴스만 있어야 할 때**
   - 로거, 설정 관리자, 이벤트 버스 등

2. **공유 자원을 하나의 진입점으로 통제해야 할 때**
   - 데이터베이스 연결 풀, 스레드 풀, 캐시 등

3. **객체 생성 비용이 크고 한 번만 초기화해도 될 때**
   - 무거운 설정 파일 파싱, 외부 API 클라이언트 초기화 등

## 언제 피해야 할까?

1. **테스트 격리가 중요한 경우**
   - 특히 단위 테스트가 많은 코드베이스에서는 전역 상태가 부담이 된다.

2. **의존성이 명확하게 드러나야 할 때**
   - 싱글톤은 의존성을 숨긴다. 어떤 함수가 어떤 싱글톤에 의존하는지 코드만 봐서는 파악하기 힘들 수 있다.

3. **객체가 여러 개여도 문제없는 경우**
   - 반드시 하나일 필요가 없는 객체에 싱글톤을 쓰면 불필요하게 결합도만 높인다.

## 안티패턴으로 불리는 이유

싱글톤은 디자인 패턴 중에서도 **안티패턴**으로 분류되는 경우가 많다.

이유는 전역 상태를 만들기 때문이다. 전역 상태는:

- 코드 어디서든 변경할 수 있어 예측이 어렵다.
- 테스트할 때 상태 격리가 힘들다.
- 의존성이 코드에서 명시적으로 보이지 않는다.

특히 멀티스레드나 분산 환경에서는 "싱글톤이 정말 하나인가?"라는 질문도 의미가 없어진다. 프로세스가 여러 개라면 각 프로세스마다 각자의 싱글톤 인스턴스를 갖기 때문이다.

그렇다고 싱글톤 자체가 나쁜 것은 아니다. **로거, 설정 관리, 연결 풀처럼 본질적으로 하나여야 하는 것**에는 여전히 유효하다. 중요한 것은 필요에 의해 쓰는 것과, 습관적으로 전역 변수 대신 쓰는 것을 구분하는 것이다.

## Registry, DI와의 관계

싱글톤의 단점을 해결하는 현실적인 대안이 **Registry 패턴**과 **의존성 주입(DI)**이다.

### Registry 패턴: 레지스트리 객체가 싱글톤임. 인스턴스도 싱글턴처럼 동작함.

Registry는 객체를 이름(키)으로 등록해두고 꺼내 쓰는 중앙 저장소 패턴이다. 인스턴스를 등록해두면 어디서 꺼내도 같은 객체가 반환되므로, 싱글톤과 동일한 효과를 낼 수 있다.

```python
class ServiceRegistry:
    _store = {}

    @classmethod
    def register(cls, name, instance):
        cls._store[name] = instance

    @classmethod
    def get(cls, name):
        return cls._store[name]

# 딱 한 번 등록
ServiceRegistry.register("logger", Logger())

# 어디서든 같은 인스턴스
logger = ServiceRegistry.get("logger")
```

싱글톤과의 차이는 **관리 주체**다. 싱글톤은 클래스 스스로 "나는 하나만 존재한다"고 강제하지만, Registry는 외부에서 인스턴스를 맡겨두는 방식이다. 덕분에 테스트할 때 Mock 객체로 교체하기가 훨씬 쉽다.

```python
# 테스트에서 실제 Logger 대신 Mock으로 교체
ServiceRegistry.register("logger", MockLogger())
```

단, Registry 자체는 앱 전체에서 하나여야 하므로 결국 싱글톤으로 구현된다.

### 의존성 주입(DI): IoC 컨테이너가 싱글톤임. 컨테이너가 싱글톤 스코프인지 개별 스코프인지 인스턴스를 관리함.

DI는 싱글톤의 가장 큰 단점인 "숨겨진 의존성" 문제를 해결한다. 필요한 객체를 내부에서 직접 꺼내는 대신, 외부에서 주입받는다.

```python
# 싱글톤 방식: 의존성이 코드 안에 숨어 있다
class OrderService:
    def process(self, order):
        logger = Logger()          # 숨겨진 의존성
        db = DatabaseConnection()  # 숨겨진 의존성
        ...

# DI 방식: 의존성이 생성자에 명시적으로 드러난다
class OrderService:
    def __init__(self, logger, db):
        self.logger = logger
        self.db = db
```

DI 프레임워크(Spring, FastAPI의 Depends 등)는 내부적으로 Registry를 자료구조로 사용하며, 객체의 생명주기를 `singleton`(한 번 만들어 재사용)과 `transient`(요청마다 새로 생성) 중에서 선택할 수 있게 해준다. 즉, DI 컨테이너는 Registry 위에서 싱글톤을 더 유연하게 구현하는 구조다.

실무에서는 싱글톤을 클래스에 직접 구현하기보다, DI 컨테이너에 싱글톤 스코프를 맡기는 방식이 권장된다. 의존성이 명시적으로 드러나고, 테스트 격리도 쉬워지기 때문이다.

## 용어 정리

- **Singleton (싱글톤)**: 인스턴스가 하나임을 보장하는 클래스
- **Lazy Initialization (지연 초기화)**: 처음 접근하는 시점에 인스턴스를 생성하는 방식
- **Eager Initialization (즉시 초기화)**: 클래스 로드 시점에 인스턴스를 미리 만드는 방식
- **Double-Checked Locking**: 멀티스레드 환경에서 락을 최소화하면서 인스턴스를 안전하게 초기화하는 기법
- **Race Condition**: 두 스레드가 동시에 같은 코드를 실행해 의도치 않은 결과가 발생하는 상황

## 한 줄 요약

싱글톤은 **인스턴스를 딱 하나로 제한하고 전역에서 접근할 수 있게 만드는 패턴**이다. 전역 상태의 편리함과 그로 인한 복잡도 상승을 함께 가져오므로, 정말 하나여야 하는 이유가 있을 때만 쓰는 것이 좋다.
