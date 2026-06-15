---
title: "Vibe Coding을 위한 디자인 패턴 - 반복자(Iterator)"
date: 2026-06-15T15:00:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "반복자", "Iterator"]
---
# Iterator Pattern (반복자 패턴)

Iterator Pattern은 **컬렉션(집합 객체)의 내부 표현 방식을 노출하지 않고, 그 요소들에 순차적으로 접근할 수 있게** 해주는 행동 디자인 패턴이다.
클라이언트는 컬렉션이 배열인지, 트리인지, 해시맵인지 알 필요 없이 **동일한 인터페이스(`next()`, `has_next()`)로 순회**할 수 있다.

예를 들어 도서 목록을 순회한다고 해보자.

- 리스트로 저장된 컬렉션은 인덱스로 접근한다.
- 트리로 저장된 컬렉션은 전위/중위/후위 순회가 필요하다.
- 해시맵으로 저장된 컬렉션은 키를 돌면서 값을 꺼낸다.

이렇게 저장 방식이 제각각이지만, 클라이언트는 매번 **"다음 요소가 있나? 있으면 하나 줘"** 만 묻고 싶을 뿐이다.

이때 순회 로직이 컬렉션마다 클라이언트 코드에 흩어지면, 자료구조가 바뀔 때마다 클라이언트도 함께 고쳐야 한다. Iterator는 순회 책임을 별도 객체로 떼어내, 어떤 컬렉션이든 같은 방식으로 다루게 해준다.

예를 들어:
```python
class Iterator:
    def has_next(self): pass   # 다음 요소가 있는지 확인
    def next(self): pass        # 다음 요소를 반환하고 커서를 전진

class Aggregate:
    def create_iterator(self): pass  # 자신을 순회할 반복자를 생성

class BookCollection(Aggregate):
    def __init__(self):
        self.books = []
    def add(self, book): self.books.append(book)
    def create_iterator(self):
        return BookIterator(self)  # 내부 구조를 아는 반복자를 만들어 반환

class BookIterator(Iterator):
    def __init__(self, collection):
        self.collection = collection
        self.index = 0           # 순회 상태(커서)를 반복자가 보관
    def has_next(self):
        return self.index < len(self.collection.books)
    def next(self):
        book = self.collection.books[self.index]
        self.index += 1
        return book

# 클라이언트는 내부가 리스트인지 모른 채 동일한 방식으로 순회
collection = BookCollection()
collection.add("클린 코드")
collection.add("리팩터링")

it = collection.create_iterator()
while it.has_next():        # 다음 요소 존재 여부만 묻고
    print(it.next())        # 다음 요소만 꺼낸다
# 클린 코드
# 리팩터링
```
→ `BookCollection`은 순회 책임을 `BookIterator`에게 위임하고, 클라이언트는 컬렉션의 내부 표현(리스트)을 전혀 몰라도 된다.

## 순회 책임의 분리 (Separation of Traversal)

Iterator Pattern의 핵심은 **순회 로직을 컬렉션 자체에서 분리**하는 것이다. 분리되지 않은 예시를 먼저 보자.

**잘못된 예:**
```python
class UserGroup:
    def __init__(self):
        self.users = []
        self.cursor = 0          # 순회 상태가 컬렉션 안에 섞여 있음

    def add(self, user): self.users.append(user)

    def first(self): self.cursor = 0
    def has_next(self): return self.cursor < len(self.users)
    def next(self):
        user = self.users[self.cursor]
        self.cursor += 1
        return user
    # 문제 1: 컬렉션이 "데이터 저장"과 "순회 상태 관리"를 동시에 책임진다 (SRP 위반)
    # 문제 2: 커서가 하나뿐이라 동시에 두 번 순회할 수 없다
```
→ 순회 상태(`cursor`)가 컬렉션 내부에 있어, 같은 컬렉션을 **중첩 순회**하거나 **여러 곳에서 동시에 순회**하면 커서가 충돌한다.

**잘된 예:**
```python
class Iterator:
    def has_next(self): pass
    def next(self): pass

class UserGroup:
    def __init__(self):
        self.users = []
    def add(self, user): self.users.append(user)
    def create_iterator(self):
        return UserIterator(self.users)  # 호출할 때마다 독립적인 반복자 생성

class UserIterator(Iterator):
    def __init__(self, users):
        self.users = users
        self.index = 0           # 순회 상태는 각 반복자가 따로 보관
    def has_next(self):
        return self.index < len(self.users)
    def next(self):
        user = self.users[self.index]
        self.index += 1
        return user

group = UserGroup()
group.add("Alice"); group.add("Bob")

# 두 반복자가 서로의 커서에 영향을 주지 않음 → 중첩 순회 가능
it1 = group.create_iterator()
it2 = group.create_iterator()
```
→ 순회 상태를 반복자 객체로 옮겼기 때문에, 같은 컬렉션을 여러 반복자가 **독립적으로 동시에** 순회할 수 있다.

## 내부 표현의 은닉 (Hiding Internal Representation)

서로 다른 자료구조라도 같은 `Iterator` 인터페이스를 제공하면, 클라이언트 코드는 **컬렉션 종류와 무관하게 재사용**된다.

```python
class Iterator:
    def has_next(self): pass
    def next(self): pass

# 내부가 리스트인 컬렉션
class ListCollection:
    def __init__(self, items): self.items = items
    def create_iterator(self):
        return ListIterator(self.items)

class ListIterator(Iterator):
    def __init__(self, items):
        self.items, self.index = items, 0
    def has_next(self): return self.index < len(self.items)
    def next(self):
        item = self.items[self.index]; self.index += 1
        return item

# 내부가 트리인 컬렉션 (중위 순회를 반복자 뒤에 숨김)
class TreeCollection:
    def __init__(self, root): self.root = root
    def create_iterator(self):
        return TreeIterator(self.root)

class TreeIterator(Iterator):
    def __init__(self, root):
        self.stack = []
        self._push_left(root)    # 복잡한 순회 로직은 반복자 내부에 캡슐화
    def _push_left(self, node):
        while node:
            self.stack.append(node)
            node = node.left
    def has_next(self): return len(self.stack) > 0
    def next(self):
        node = self.stack.pop()
        self._push_left(node.right)
        return node.value

# 클라이언트 코드는 컬렉션 종류와 무관하게 동일하다
def print_all(collection):
    it = collection.create_iterator()
    while it.has_next():
        print(it.next())

print_all(ListCollection([1, 2, 3]))   # 리스트든
print_all(TreeCollection(some_tree))   # 트리든 같은 코드로 순회
```
→ 순회의 복잡함(트리의 중위 순회 등)은 반복자 내부에 숨겨지고, 클라이언트는 `has_next()`/`next()`만 안다.

## 파이썬의 내장 반복자 프로토콜

파이썬은 Iterator Pattern을 언어 차원에서 지원한다. `__iter__`와 `__next__`만 구현하면 `for` 문이 자동으로 반복자를 사용한다.

```python
class Fibonacci:
    def __init__(self, limit):
        self.limit = limit

    def __iter__(self):              # create_iterator() 역할
        self.a, self.b = 0, 1
        self.count = 0
        return self

    def __next__(self):              # next() 역할
        if self.count >= self.limit:
            raise StopIteration      # has_next()가 False인 상황을 예외로 표현
        value = self.a
        self.a, self.b = self.b, self.a + self.b
        self.count += 1
        return value

# for 문이 내부적으로 __iter__()와 __next__()를 호출
for n in Fibonacci(5):
    print(n)  # 0 1 1 2 3
```
→ `for ... in`은 사실 Iterator Pattern의 문법적 설탕(syntactic sugar)이다. `StopIteration` 예외가 `has_next()`의 종료 신호 역할을 한다.

제너레이터를 쓰면 반복자를 더 간결하게 만들 수 있다.
```python
def fibonacci(limit):
    a, b = 0, 1
    for _ in range(limit):
        yield a              # yield가 자동으로 순회 상태를 보관
        a, b = b, a + b

for n in fibonacci(5):
    print(n)  # 0 1 1 2 3
```

## 장점

1. **내부 표현의 은닉**
   - 클라이언트가 컬렉션이 리스트인지 트리인지 몰라도 순회할 수 있다.

2. **여러 순회의 독립성**
   - 같은 컬렉션을 여러 반복자가 각자의 커서로 동시에 순회할 수 있다.

3. **다양한 순회 방식 제공**
   - 하나의 컬렉션에 전위/중위/역방향 등 여러 반복자를 둘 수 있다.

## 단점

1. **단순한 컬렉션에는 과하다**
   - 그냥 리스트를 `for`로 도는 경우라면 반복자를 따로 만들 필요가 없다.

2. **클래스 수가 늘어난다**
   - 컬렉션마다 대응하는 반복자 클래스가 추가된다.

3. **순회 중 변경에 취약할 수 있다**
   - 순회 도중 컬렉션이 수정되면 커서가 어긋날 수 있다(파이썬도 순회 중 수정 시 `RuntimeError`).

## 언제 사용해야 할까?

1. **컬렉션의 내부 구조를 숨기고 순회만 노출하고 싶을 때**
   - 데이터베이스 결과 집합(ResultSet) 순회
   - 파일/스트림의 한 줄씩 읽기
   - 페이지네이션된 API 응답 순회

2. **하나의 컬렉션을 여러 방식으로 순회해야 할 때**
   - 트리의 전위/중위/후위 순회
   - 정방향/역방향 순회
   - 필터링된 순회 (특정 조건 요소만)

3. **여러 종류의 컬렉션을 동일한 코드로 다루고 싶을 때**
   - 리스트, 트리, 그래프를 같은 인터페이스로 순회
   - 무한 수열(피보나치 등)의 지연 평가(lazy evaluation)

## 용어 정리

**Iterator (반복자)**: `has_next()`, `next()` 등 순회 인터페이스를 정의  
**ConcreteIterator (구체적 반복자)**: 특정 컬렉션의 순회와 현재 위치(커서)를 구현  
**Aggregate (집합 객체)**: 반복자를 생성하는 인터페이스(`create_iterator()`)  
**ConcreteAggregate (구체적 집합 객체)**: 실제 데이터를 보관하고 자신에 맞는 반복자를 반환

1. 도서 컬렉션 예시:
   - Iterator → Iterator
   - ConcreteIterator → BookIterator
   - Aggregate → Aggregate
   - ConcreteAggregate → BookCollection

2. 파이썬 내장 예시:
   - Iterator → `__next__`을 가진 객체
   - Aggregate → `__iter__`을 가진 객체
   - ConcreteIterator/Aggregate → Fibonacci, 제너레이터 등

## 한 줄 요약

Iterator는 **"컬렉션을 어떻게 순회하느냐"는 책임을 컬렉션 밖으로 떼어내는** 패턴이다.

즉:

> 컬렉션은 "무엇을 담을지"에 집중하고, 반복자는 "어떻게 돌지"에 집중한다.


-----

## Strategy 패턴과의 관계

순회 방식(전위/중위/후위)을 교체 가능한 전략으로 본다면 Strategy처럼 보일 수도 있다.
하지만 Iterator는 **"순회"라는 구체적 책임**에 특화되어 있고, 순회 상태(커서)를 보관한다는 점에서 다르다.
실제로는 **하나의 컬렉션에 여러 종류의 반복자**를 제공하는 식으로, Iterator가 Strategy의 성격을 일부 흡수하는 경우가 많다.

```python
class TreeCollection:
    def create_preorder_iterator(self): ...   # 전위 순회 반복자
    def create_inorder_iterator(self): ...    # 중위 순회 반복자
    # 같은 데이터, 다른 순회 "전략"을 각각의 반복자로 제공
```

---

### 요약 비교표

| 패턴 | 푸는 질문 | 핵심 관심사 | 흐름 |
|---|---|---|---|
| Iterator | "이 컬렉션을 어떻게 순회할까?" | 순회 책임의 분리 | 클라이언트가 당겨옴(pull) |
| Observer | "상태가 바뀌면 누구에게 알릴까?" | 상태 변화 알림 | Subject가 밀어줌(push) |
| Strategy | "어떤 알고리즘을 실행할까?" | 행동의 교체 | 호출 측이 전략 선택 |
| Composite | "전체와 부분을 어떻게 같게 다룰까?" | 트리 구조의 일관성 | 재귀적 구성 |

→ Iterator는 종종 다른 패턴과 함께 쓰인다. 예를 들어 **Composite로 만든 트리를 Iterator로 순회**하면, 복잡한 구조를 평탄한 순차 접근으로 다룰 수 있다.
