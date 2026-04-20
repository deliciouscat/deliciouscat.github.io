---
title: "Vibe Coding을 위한 디자인 패턴 - 레지스트리(Registry)"
date: 2026-04-08T18:00:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "레지스트리", "Registry"]
---
## 사전지식
- [데코레이터](https://www.youtube.com/watch?v=3t26Z4vk7XE&list=PL6R2CbVlhcYtnLsypcisMzDN344c1Conr)


# Registry Pattern (레지스트리 패턴)

Registry Pattern은 **객체나 서비스를 중앙 저장소에 등록(register)하고, 이름(키)으로 조회(lookup)할 수 있도록** 하는 디자인 패턴이다.
클라이언트는 구체적인 클래스를 직접 `import`하거나 생성하는 대신, **레지스트리에 이름을 물어보면** 원하는 객체를 얻는다.

예를 들어:
```python
class Registry:
    _registry = {}

    @classmethod
    def register(cls, name, obj):
        cls._registry[name] = obj

    @classmethod
    def get(cls, name):
        return cls._registry[name]

# 등록
Registry.register("email", EmailService())
Registry.register("sms", SmsService())

# 조회 (클라이언트는 EmailService를 import하지 않아도 됨)
service = Registry.get("email")
service.send("Hello!")
```
→ 클라이언트는 `EmailService`가 어떤 클래스인지, 어디에 있는지 알 필요가 없다. **이름만 알면 된다.**

## 문제: if-elif 분기의 폭발

레지스트리 없이 여러 구현체를 다루면 흔히 이런 코드가 생긴다.

**잘못된 예:**
```python
class NotificationManager:
    def send(self, channel, message):
        if channel == "email":
            EmailService().send(message)
        elif channel == "sms":
            SmsService().send(message)
        elif channel == "push":
            PushService().send(message)
        elif channel == "slack":
            SlackService().send(message)
        # 새로운 채널 추가 때마다 이 메서드를 수정해야 함!
```

위 코드의 문제점:
1. 채널이 추가될 때마다 `NotificationManager`를 직접 수정해야 한다. (개방-폐쇄 원칙 위반)
2. `NotificationManager`가 모든 서비스 클래스를 알고 있어야 한다. (의존성 역전 원칙 위반)
3. 테스트 시 Mock 서비스를 끼워 넣기 어렵다.

**Registry Pattern을 적용한 예:**
```python
class NotificationRegistry:
    _services = {}

    @classmethod
    def register(cls, name, service):
        cls._services[name] = service

    @classmethod
    def get(cls, name):
        if name not in cls._services:
            raise KeyError(f"'{name}' 채널은 등록되어 있지 않습니다.")
        return cls._services[name]


class NotificationManager:
    def send(self, channel, message):
        service = NotificationRegistry.get(channel)  # if-elif 전부 삭제!
        service.send(message)


# 등록은 애플리케이션 초기화 시 한 번만
NotificationRegistry.register("email", EmailService())
NotificationRegistry.register("sms", SmsService())
NotificationRegistry.register("push", PushService())

# 이제 새 채널 추가 = 한 줄 추가 (기존 코드 수정 없음)
NotificationRegistry.register("slack", SlackService())
```

`NotificationManager`는 더 이상 채널 목록을 알 필요가 없다. 새로운 채널이 추가돼도 `NotificationManager`를 건드리지 않는다.

## 개방-폐쇄 원칙 (Open-Closed Principle; OCP)

Registry Pattern은 OCP를 자연스럽게 실현한다. 새 구현체를 **등록**하는 것이 곧 확장이고, 기존 코드는 수정하지 않는다.

**플러그인 시스템 예시:**
```python
class ParserRegistry:
    _parsers = {}

    @classmethod
    def register(cls, extension, parser_class):
        cls._parsers[extension] = parser_class

    @classmethod
    def parse(cls, filename, content):
        ext = filename.rsplit(".", 1)[-1]
        if ext not in cls._parsers:
            raise ValueError(f".{ext} 파일은 지원하지 않습니다.")
        return cls._parsers[ext]().parse(content)


class JsonParser:
    def parse(self, content): return f"[JSON] {content}"

class CsvParser:
    def parse(self, content): return f"[CSV] {content}"

class YamlParser:
    def parse(self, content): return f"[YAML] {content}"


# 기존 코드를 수정하지 않고 파서를 추가
ParserRegistry.register("json", JsonParser)
ParserRegistry.register("csv", CsvParser)
ParserRegistry.register("yaml", YamlParser)

print(ParserRegistry.parse("data.json", "{}"))   # [JSON] {}
print(ParserRegistry.parse("users.csv", "a,b"))  # [CSV] a,b
```

내일 XML 파서가 필요해지면? `ParserRegistry.register("xml", XmlParser)` 한 줄이면 끝이다.

## 클래스(타입) 레지스트리 vs 인스턴스 레지스트리

레지스트리에는 **클래스(생성자)를 등록**하는 방식과 **인스턴스를 등록**하는 방식 두 가지가 있다.

```python
class ServiceRegistry:
    _classes = {}      # 클래스 등록: 매 요청마다 새 인스턴스
    _singletons = {}   # 인스턴스 등록: 하나의 인스턴스를 공유

    @classmethod
    def register_class(cls, name, klass):
        cls._classes[name] = klass

    @classmethod
    def register_instance(cls, name, instance):
        cls._singletons[name] = instance

    @classmethod
    def get_new(cls, name, *args, **kwargs):
        """호출 때마다 새 인스턴스 생성"""
        return cls._classes[name](*args, **kwargs)

    @classmethod
    def get(cls, name):
        """항상 같은 인스턴스 반환 (싱글턴처럼)"""
        return cls._singletons[name]


# 클래스 등록: 매번 새 Connection 생성
ServiceRegistry.register_class("db_connection", DatabaseConnection)
conn1 = ServiceRegistry.get_new("db_connection", host="localhost")
conn2 = ServiceRegistry.get_new("db_connection", host="localhost")
# conn1 is conn2 → False

# 인스턴스 등록: 공유 캐시
ServiceRegistry.register_instance("cache", RedisCache(host="localhost"))
cache = ServiceRegistry.get("cache")  # 항상 같은 객체
```

**규칙:**
- 상태가 없거나(stateless) 매 요청마다 새로 만들어야 하면 → **클래스 등록**
- DB 커넥션 풀, 캐시처럼 공유해야 하면 → **인스턴스 등록**

## 데코레이터로 등록 자동화하기

Python에서는 `@` 데코레이터 문법으로 등록을 더 깔끔하게 할 수 있다.

```python
class HandlerRegistry:
    _handlers = {}

    @classmethod
    def register(cls, event_type):
        def decorator(handler_class):
            cls._handlers[event_type] = handler_class
            return handler_class
        return decorator

    @classmethod
    def handle(cls, event_type, payload):
        handler = cls._handlers[event_type]()
        return handler.process(payload)


@HandlerRegistry.register("user.created")
class UserCreatedHandler:
    def process(self, payload):
        return f"새 유저 환영 이메일 발송: {payload['email']}"


@HandlerRegistry.register("order.placed")
class OrderPlacedHandler:
    def process(self, payload):
        return f"주문 확인 알림: {payload['order_id']}"


# 클래스를 선언하는 것만으로 자동 등록됨
print(HandlerRegistry.handle("user.created", {"email": "a@b.com"}))
print(HandlerRegistry.handle("order.placed", {"order_id": 42}))
```

파일이 `import`되는 순간 `@register` 데코레이터가 실행되어 레지스트리에 자동 등록된다. 수동 `register()` 호출조차 필요 없다.

## Facade Pattern과의 차이

이 두 패턴은 "복잡한 것을 감춘다"는 점에서 비슷해 보이지만, **목적과 구조가 완전히 다르다.**

### Facade Pattern

Facade는 **복잡한 서브시스템을 단순한 인터페이스로 감싸는** 패턴이다. 내부 구조를 알고 있으며, 여러 컴포넌트를 **직접 조율**한다.

```python
# Facade: 내부가 어떻게 돌아가는지 안다
class VideoConverterFacade:
    def convert(self, filename, format):
        file = VideoFile(filename)
        codec = CodecFactory.extract(file)          # 내부 컴포넌트를 직접 알고
        result = BitrateReader.read(file, codec)    # 순서를 직접 조율하고
        return AudioMixer.fix(result)               # 최종 결과를 조립해 반환
```

### Registry Pattern

Registry는 **무엇이 등록되는지 모른다**. 그냥 키-값을 저장하고 돌려줄 뿐이다.

```python
# Registry: 내부가 어떻게 돌아가는지 모른다
class ConverterRegistry:
    _converters = {}

    @classmethod
    def register(cls, format, converter):
        cls._converters[format] = converter  # 그냥 저장

    @classmethod
    def get(cls, format):
        return cls._converters[format]       # 그냥 반환
```

### 핵심 차이 요약

| | Registry | Facade |
|---|---|---|
| **목적** | 객체 조회 (lookup) | 복잡성 은닉 (simplify) |
| **내부 구조 인지** | 모름 (무지) | 알고 있음 (조율) |
| **관계** | 클라이언트 ↔ 레지스트리 ↔ 구현체 | 클라이언트 ↔ 파사드 → 서브시스템 |
| **변경 방식** | 런타임에 등록/교체 가능 | 파사드 내부 수정 필요 |
| **주요 관심사** | "이 이름에 해당하는 게 뭐야?" | "이 복잡한 일을 대신 처리해줘" |

### 함께 쓰는 경우

두 패턴은 함께 쓰이기도 한다. Facade가 내부적으로 Registry를 활용하면, 서브시스템의 확장성과 단순성을 동시에 얻을 수 있다.

```python
class NotificationFacade:
    """클라이언트는 이것만 알면 된다"""

    def __init__(self):
        # Facade가 Registry를 통해 서비스를 조회
        self._registry = NotificationRegistry

    def notify_user(self, user, event_type, message):
        # 복잡한 조율 로직은 Facade가 담당
        channel = user.preferred_channel
        service = self._registry.get(channel)   # 조회는 Registry가 담당
        log(f"Sending {event_type} to {user.id}")
        return service.send(message)
```

→ `NotificationFacade`가 복잡한 흐름을 조율하되, 실제 서비스 조회는 `NotificationRegistry`에 위임한다.

## Registry Pattern은 다음과 같은 상황에서 유용하다:

1. **런타임에 구현체를 동적으로 교체해야 할 때**
   - A/B 테스트: "이 사용자에겐 v2 알고리즘을 써"
   - 환경별 다른 구현체 (개발/스테이징/프로덕션)

2. **플러그인/확장 포인트를 제공할 때**
   - 파일 포맷 파서 (json, csv, yaml, ...)
   - 이벤트 핸들러, 미들웨어 체인

3. **if-elif 분기를 제거하고 싶을 때**
   - 분기가 늘어날수록 레지스트리의 가치가 커진다

4. **의존성 주입 컨테이너(DI Container)가 필요할 때**
   - 간단한 IoC 컨테이너를 직접 구현할 때 Registry가 핵심 자료구조가 된다

## 장단점

### 장점

✅ **개방-폐쇄 원칙 준수**: 새 구현체 추가 = `register()` 한 줄, 기존 코드 수정 없음

✅ **테스트 용이성**: 테스트 시 Mock 객체를 레지스트리에 등록하면 된다
```python
# 테스트에서 실제 EmailService 대신 Mock으로 교체
NotificationRegistry.register("email", MockEmailService())
```

✅ **느슨한 결합**: 클라이언트는 구체 클래스를 `import`하지 않아도 됨

✅ **중앙 관리**: 어떤 구현체가 사용 가능한지 레지스트리만 보면 파악 가능

### 단점

❌ **전역 상태**: 레지스트리가 싱글턴처럼 동작하면, 테스트 간 격리가 어려울 수 있다. (테스트마다 레지스트리를 초기화해야 함)

❌ **런타임 에러**: 존재하지 않는 키를 조회하면 컴파일 타임이 아닌 런타임에 오류가 발생한다.

❌ **등록 누락**: 사용하기 전에 반드시 등록해야 하는데, 초기화 순서가 잘못되면 찾기 어려운 버그가 생길 수 있다.

## 용어 정리

**Registry (레지스트리)**: 이름(키)과 객체(값)를 관리하는 중앙 저장소  
**Key (키)**: 객체를 식별하는 이름 또는 타입  
**Entry (항목)**: 레지스트리에 등록된 개별 객체 또는 클래스

1. 알림 서비스 예시:
   - Registry → `NotificationRegistry`
   - Key → `"email"`, `"sms"`, `"push"`
   - Entry → `EmailService`, `SmsService`, `PushService`

2. 파일 파서 예시:
   - Registry → `ParserRegistry`
   - Key → `"json"`, `"csv"`, `"yaml"`
   - Entry → `JsonParser`, `CsvParser`, `YamlParser`
