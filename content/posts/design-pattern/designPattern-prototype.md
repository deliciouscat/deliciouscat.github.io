---
title: "Vibe Coding을 위한 디자인 패턴 - 프로토타입(Prototype)"
date: 2026-05-23T15:30:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "프로토타입", "Prototype"]
---

Prototype Pattern은 **기존 객체를 복제(clone)하여 새로운 객체를 생성하는** 생성 디자인 패턴이다.

`new`로 처음부터 만드는 대신, 이미 존재하는 객체를 복사해서 새 객체를 만든다. 복제 대상이 되는 원본 객체를 프로토타입(Prototype)이라고 부른다.

## 왜 복제가 필요한가?

객체를 만들 때 다음과 같은 상황이 있다.

1. **생성 비용이 크다** — DB에서 데이터를 조회하거나, 복잡한 계산을 거쳐야 객체가 완성되는 경우
2. **비슷한 객체를 여러 개 만들어야 한다** — 기본 설정이 같고 일부만 다른 객체를 반복 생성하는 경우
3. **클라이언트가 구체 클래스를 몰라야 한다** — 인터페이스만 알고 있는 상태에서 같은 타입의 객체를 만들어야 하는 경우

이런 상황에서 매번 `new`를 호출하고, 생성자에 파라미터를 하나하나 넘기고, 초기화 로직을 반복하는 건 비효율적이다. 프로토타입 패턴은 "이미 만들어진 객체를 복사하면 된다"는 발상으로 이 문제를 해결한다.

## 문제가 있는 예시

게임에서 몬스터를 생성하는 상황을 생각해보자.

```python
class Monster:
    def __init__(self, name, hp, attack, defense, skills, sprite_data):
        self.name = name
        self.hp = hp
        self.attack = attack
        self.defense = defense
        self.skills = skills
        self.sprite_data = sprite_data  # 로딩에 비용이 큰 데이터

def spawn_goblin_squad():
    goblins = []
    for i in range(50):
        goblin = Monster(
            name=f"Goblin_{i}",
            hp=100,
            attack=15,
            defense=5,
            skills=["slash", "dodge"],
            sprite_data=load_sprite("goblin.png")  # 매번 디스크에서 로드
        )
        goblins.append(goblin)
    return goblins
```

위 코드의 문제점:

1. 50마리의 고블린을 만들 때마다 `load_sprite()`가 50번 호출된다.
2. 모든 고블린이 같은 기본 스탯을 가지는데, 매번 파라미터를 나열해야 한다.
3. 나중에 고블린의 기본 스펙이 바뀌면 `spawn_goblin_squad()` 전체를 수정해야 한다.

## Prototype 적용

프로토타입 패턴을 적용하면 원본 고블린을 하나 만들고, 나머지는 복제한다.

```python
from abc import ABC, abstractmethod
import copy

class Monster(ABC):
    @abstractmethod
    def clone(self):
        pass

    @abstractmethod
    def describe(self):
        pass

class Goblin(Monster):
    def __init__(self, name, hp, attack, defense, skills, sprite_data):
        self.name = name
        self.hp = hp
        self.attack = attack
        self.defense = defense
        self.skills = list(skills)
        self.sprite_data = sprite_data

    def clone(self):
        cloned = copy.copy(self)
        cloned.skills = list(self.skills)  # 리스트는 별도로 깊은 복사
        return cloned

    def describe(self):
        return f"{self.name} (HP:{self.hp}, ATK:{self.attack}, DEF:{self.defense})"
```

이제 원본 하나를 만들고 복제해서 쓴다.

```python
def spawn_goblin_squad():
    prototype = Goblin(
        name="Goblin",
        hp=100,
        attack=15,
        defense=5,
        skills=["slash", "dodge"],
        sprite_data=load_sprite("goblin.png")  # 한 번만 로드
    )

    goblins = []
    for i in range(50):
        goblin = prototype.clone()
        goblin.name = f"Goblin_{i}"
        goblins.append(goblin)
    return goblins
```

`load_sprite()`는 한 번만 호출된다. 50마리 모두 같은 `sprite_data`를 공유하고, 개별적으로 달라야 하는 부분(이름 등)만 복제 후에 바꾼다.

## 얕은 복사 vs 깊은 복사

프로토타입 패턴에서 가장 주의해야 할 부분이다.

### 얕은 복사 (Shallow Copy)

객체의 최상위 필드만 복사한다. 내부에 리스트, 딕셔너리, 다른 객체가 있으면 **참조만 복사**되므로 원본과 복제본이 같은 내부 객체를 공유한다.

```python
import copy

original = Goblin("Goblin", 100, 15, 5, ["slash", "dodge"], None)
shallow = copy.copy(original)

shallow.skills.append("fireball")

print(original.skills)  # ["slash", "dodge", "fireball"] — 원본도 변경됨!
```

### 깊은 복사 (Deep Copy)

객체 내부의 모든 중첩 객체까지 재귀적으로 복사한다. 원본과 복제본이 완전히 독립된다.

```python
original = Goblin("Goblin", 100, 15, 5, ["slash", "dodge"], None)
deep = copy.deepcopy(original)

deep.skills.append("fireball")

print(original.skills)  # ["slash", "dodge"] — 원본은 영향 없음
```

### 선택 기준

- **불변(immutable) 필드만 있다면**: 얕은 복사로 충분하다.
- **가변(mutable) 필드가 있다면**: 깊은 복사를 쓰거나, `clone()` 안에서 해당 필드만 수동으로 깊은 복사한다.
- **성능이 중요하다면**: `deepcopy`는 느릴 수 있으므로, 꼭 필요한 필드만 선택적으로 복사하는 게 낫다.

앞선 `Goblin.clone()`에서 `copy.copy()`로 얕은 복사를 하되, `skills` 리스트만 별도로 복사한 이유가 이것이다.

## Prototype Registry

프로토타입을 미리 등록해두고 키로 꺼내 쓰는 패턴도 자주 사용된다.

```python
class MonsterRegistry:
    def __init__(self):
        self._prototypes = {}

    def register(self, key, prototype):
        self._prototypes[key] = prototype

    def create(self, key, **overrides):
        if key not in self._prototypes:
            raise ValueError(f"Unknown monster type: {key}")
        clone = self._prototypes[key].clone()
        for attr, value in overrides.items():
            setattr(clone, attr, value)
        return clone
```

등록하고 사용하는 코드:

```python
registry = MonsterRegistry()

registry.register("goblin", Goblin(
    name="Goblin", hp=100, attack=15, defense=5,
    skills=["slash", "dodge"],
    sprite_data=load_sprite("goblin.png")
))

registry.register("orc", Orc(
    name="Orc", hp=300, attack=40, defense=20,
    skills=["smash", "roar"],
    sprite_data=load_sprite("orc.png")
))

# 사용
goblin = registry.create("goblin", name="Goblin_Elite", attack=25)
orc = registry.create("orc", name="Orc_Chief", hp=500)
```

클라이언트는 `Goblin`, `Orc` 같은 구체 클래스를 직접 알 필요 없다. 레지스트리에 키만 넘기면 복제된 객체를 받는다.

## 설정 객체 예시

게임 예시가 너무 도메인 특화되어 있으니, 더 일반적인 예시도 보자.

서버 설정 객체를 환경별로 만드는 상황이다.

```python
import copy

class ServerConfig:
    def __init__(self, host, port, db_url, cache_size, log_level, 
                 ssl_cert, timeout, max_connections):
        self.host = host
        self.port = port
        self.db_url = db_url
        self.cache_size = cache_size
        self.log_level = log_level
        self.ssl_cert = ssl_cert
        self.timeout = timeout
        self.max_connections = max_connections
        self.middleware = []

    def clone(self):
        cloned = copy.copy(self)
        cloned.middleware = list(self.middleware)
        return cloned

    def __repr__(self):
        return f"ServerConfig({self.host}:{self.port}, log={self.log_level})"
```

기본 설정을 프로토타입으로 만들고, 환경별로 일부만 오버라이드한다.

```python
base_config = ServerConfig(
    host="0.0.0.0",
    port=8080,
    db_url="postgresql://localhost:5432/app",
    cache_size=256,
    log_level="INFO",
    ssl_cert="/etc/ssl/cert.pem",
    timeout=30,
    max_connections=100
)
base_config.middleware = ["auth", "cors", "logging"]

# 개발 환경: 기본 설정을 복제하고 일부만 변경
dev_config = base_config.clone()
dev_config.log_level = "DEBUG"
dev_config.db_url = "postgresql://localhost:5432/app_dev"
dev_config.ssl_cert = None

# 스테이징 환경
staging_config = base_config.clone()
staging_config.host = "staging.example.com"
staging_config.db_url = "postgresql://staging-db:5432/app"

# 프로덕션 환경
prod_config = base_config.clone()
prod_config.host = "api.example.com"
prod_config.max_connections = 1000
prod_config.cache_size = 1024
```

8개의 필드를 가진 설정 객체인데, 환경별로 다른 건 2~3개뿐이다. 매번 8개 파라미터를 나열하는 것보다 프로토타입을 복제하고 차이점만 수정하는 게 훨씬 깔끔하다.

## 다른 생성 패턴과의 비교

### Factory Method / Abstract Factory와의 차이

팩토리 패턴들은 **클래스 기반**이다. "어떤 클래스의 인스턴스를 만들 것인가?"가 핵심이다.

프로토타입은 **인스턴스 기반**이다. "어떤 기존 객체를 복사할 것인가?"가 핵심이다.

```python
# Factory: 클래스를 지정해서 새로 생성
goblin = GoblinFactory.create()

# Prototype: 기존 객체를 복사해서 생성
goblin = goblin_prototype.clone()
```

팩토리는 항상 초기 상태의 객체를 만든다. 프로토타입은 특정 상태의 객체를 그대로 복제할 수 있다.

### Builder와의 차이

Builder는 복잡한 객체를 **단계별로 조립**한다.

프로토타입은 이미 조립된 객체를 **통째로 복사**한다.

```python
# Builder: 단계별 조립
config = ConfigBuilder() \
    .set_host("0.0.0.0") \
    .set_port(8080) \
    .set_db_url("...") \
    .build()

# Prototype: 기존 객체 복사 후 수정
config = base_config.clone()
config.port = 9090
```

이미 완성된 객체가 있고 약간만 바꾸고 싶다면 프로토타입이 더 적합하다.

## 장점

1. **생성 비용 절감**
   - 초기화에 비용이 큰 객체(DB 조회, 파일 로딩 등)를 매번 새로 만들지 않아도 된다.

2. **구체 클래스 의존 제거**
   - `clone()`만 호출하면 되므로, 클라이언트가 구체 클래스를 몰라도 같은 타입의 객체를 만들 수 있다.

3. **유사 객체 대량 생성에 유리**
   - 기본 설정이 같고 일부만 다른 객체를 쉽게 만들 수 있다.

4. **상태가 포함된 객체 복제**
   - 팩토리는 초기 상태의 객체만 만들지만, 프로토타입은 현재 상태 그대로를 복제할 수 있다.

## 단점

1. **깊은 복사의 복잡성**
   - 순환 참조가 있거나 복잡한 중첩 구조를 가진 객체는 올바르게 복제하기 어렵다.

2. **clone() 구현 부담**
   - 모든 프로토타입 클래스에 `clone()`을 구현해야 하고, 필드가 변경될 때마다 `clone()`도 함께 갱신해야 한다.

3. **얕은 복사 버그 위험**
   - 얕은 복사로 인해 원본과 복제본이 내부 객체를 공유하는 문제를 놓치기 쉽다.

## 언제 사용해야 할까?

1. **객체 생성 비용이 클 때**
   - 네트워크 호출, 파일 I/O, 복잡한 계산이 초기화에 필요한 경우

2. **비슷한 객체를 여러 개 만들어야 할 때**
   - 기본값이 같고 일부만 다른 객체를 반복 생성하는 경우

3. **런타임에 객체의 타입이 결정될 때**
   - 설정 파일이나 사용자 입력에 따라 다양한 타입의 객체를 만들어야 하는데, 구체 클래스를 미리 알 수 없는 경우

4. **객체의 현재 상태를 보존한 채 복사하고 싶을 때**
   - 스냅샷, 되돌리기(undo), 시뮬레이션 분기 등

## 용어 정리

- **Prototype (프로토타입)**: 복제의 원본이 되는 객체. `clone()` 메서드를 제공한다.
- **Concrete Prototype (구체 프로토타입)**: Prototype 인터페이스를 구현한 실제 클래스.
- **Clone (복제)**: 프로토타입의 현재 상태를 복사하여 새 객체를 만드는 연산.
- **Shallow Copy (얕은 복사)**: 최상위 필드만 복사. 내부 참조 객체는 공유.
- **Deep Copy (깊은 복사)**: 모든 중첩 객체까지 재귀적으로 복사. 완전 독립.
- **Prototype Registry (프로토타입 레지스트리)**: 프로토타입들을 키-값으로 관리하는 저장소.

## 한 줄 요약

Prototype Pattern은 **기존 객체를 복제하여 새 객체를 생성하는 패턴**이다.

즉:

> "처음부터 만들지 말고, 있는 걸 복사해서 고쳐 쓰자."
