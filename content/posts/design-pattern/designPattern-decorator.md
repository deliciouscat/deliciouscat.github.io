---
title: "Vibe Coding을 위한 디자인 패턴 - 장식자(Decorator)"
date: 2025-11-06T17:45:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "데코레이터", "Decorator"]
---

# Decorator Pattern (장식자 패턴)

Decorator Pattern(장식자 패턴)은 객체에 **동적으로 새로운 책임(기능)을 추가**할 수 있게 해주는 구조 디자인 패턴이다.
클라이언트가 **기본 객체**와 **장식된 객체**를 동일한 방식으로 다룰 수 있다.

예를 들어:
```python
class Component:
    def operation(self): pass

class ConcreteComponent(Component):
    def operation(self): return "기본 기능"

class Decorator(Component):
    def __init__(self, component):
        self.component = component
    def operation(self):
        return self.component.operation()

class ConcreteDecorator(Decorator):
    def operation(self):
        return f"{self.component.operation()} + 추가 기능"

# 클라이언트는 기본 객체와 장식된 객체를 구분하지 않음
basic = ConcreteComponent()
decorated = ConcreteDecorator(basic)
double_decorated = ConcreteDecorator(decorated)

print(basic.operation())           # 기본 기능
print(decorated.operation())        # 기본 기능 + 추가 기능  
print(double_decorated.operation()) # 기본 기능 + 추가 기능 + 추가 기능
```
→ `ConcreteComponent`와 `Decorator` 모두 `Component` 인터페이스를 구현해서 `operation` 메서드를 호출할 수 있고, **런타임에 기능을 조합**할 수 있다.

## 단일 책임 원칙 / 개방-폐쇄 원칙

Decorator Pattern을 사용할 땐 이 원칙을 준수해야 하는데, 먼저 단일 책임 원칙(Single Responsibility Principle; SRP)이 지켜지지 않은 예시를 보자.

**잘못된 예:**
```python
class Coffee:
    def __init__(self):
        self.cost = 10
        self.description = "커피"
        self.has_milk = False
        self.has_sugar = False
        self.has_whip = False
        self.shot_count = 1
        
    def add_milk(self):
        self.has_milk = True
        self.cost += 2
        self.description += ", 우유"
        
    def add_sugar(self):
        self.has_sugar = True
        self.cost += 1
        self.description += ", 설탕"
        
    def add_whip(self):
        self.has_whip = True
        self.cost += 3
        self.description += ", 휘핑"
        
    def add_shot(self):
        self.shot_count += 1
        self.cost += 5
        self.description += ", 샷 추가"
        
    def get_cost(self):  # 모든 옵션 계산 로직까지 담당
        return self.cost
    
    def make_coffee(self):  # 제조 책임까지 가짐
        return f"제조 중: {self.description}"
```
위의 코드를 보면 `Coffee` 클래스가 기본 커피 + 모든 옵션 관리 + 가격 계산 + 제조까지 담당하고 있다. (`has_milk`, `has_sugar` 등이 쓸데없는 책임을 지고 있음!) 새로운 옵션(시럽, 디카페인 등)이 추가될 때마다 클래스를 수정해야 한다. 이 코드를 SRP를 준수하도록 수정하자.

**잘된 예:**
```python
class Beverage:
    def get_description(self): pass
    def cost(self): pass

class Espresso(Beverage):
    def get_description(self): return "에스프레소"
    def cost(self): return 10

class CondimentDecorator(Beverage):
    def __init__(self, beverage):
        self.beverage = beverage

class Milk(CondimentDecorator):  # 우유 추가에만 집중
    def get_description(self):
        return f"{self.beverage.get_description()}, 우유"
    def cost(self): 
        return self.beverage.cost() + 2

class Sugar(CondimentDecorator):  # 설탕 추가에만 집중
    def get_description(self):
        return f"{self.beverage.get_description()}, 설탕"
    def cost(self): 
        return self.beverage.cost() + 1

class Whip(CondimentDecorator):  # 휘핑 추가에만 집중
    def get_description(self):
        return f"{self.beverage.get_description()}, 휘핑"
    def cost(self): 
        return self.beverage.cost() + 3
```
이렇게 하면 기본 음료는 음료대로, 각 토핑은 토핑대로 각 클래스가 필요한 역할만 담당하게 된다. **단일 책임 원칙**을 준수하면 다양한 행동들의 여러 변형들을 구현하는 모놀리식 클래스를 여러 개의 작은 클래스들로 나눌 수 있다.

다음으로 개방-폐쇄 원칙(Open-Closed Principle; OCP)를 살펴보자. 'Entity는 확장에는 열려있고, 수정에는 닫혀있어야 한다'는 원칙인데,

**잘못된 예:**
```python
class TextProcessor:
    def process(self, text, options):
        result = text
        if "bold" in options:
            result = f"<b>{result}</b>"
        if "italic" in options:
            result = f"<i>{result}</i>"
        if "underline" in options:
            result = f"<u>{result}</u>"
        if "strikethrough" in options:
            result = f"<s>{result}</s>"
        return result
```
→ 이렇게 하면 새로운 텍스트 스타일(하이라이트, 색상 등)을 추가할 때마다 `TextProcessor`를 수정해야 하는 구조이다. (확장에 대해 개방성이 없다)

**잘된 예:**
```python
class TextComponent:
    def render(self): pass

class PlainText(TextComponent):
    def __init__(self, text):
        self.text = text
    def render(self): return self.text

class TextDecorator(TextComponent):
    def __init__(self, component):
        self.component = component

class BoldDecorator(TextDecorator):
    def render(self):
        return f"<b>{self.component.render()}</b>"

class ItalicDecorator(TextDecorator):
    def render(self):
        return f"<i>{self.component.render()}</i>"

class ColorDecorator(TextDecorator):  # 새 스타일 추가해도 기존 코드 수정 불필요
    def __init__(self, component, color):
        super().__init__(component)
        self.color = color
    def render(self):
        return f'<span style="color:{self.color}">{self.component.render()}</span>'
```
이제, 새로운 스타일을 추가하고자 할 때엔 `TextDecorator` 클래스를 상속하여 쉽게 기존 기능들을 확장할 수 있으며(확장에는 개방), 기존 클래스들에 별도의 코드를 추가할 필요가 없다. (수정에는 닫혀있다.)

**각 클래스가 명확한 단일 책임, 각 컴포넌트들이 인터페이스(`Beverage`, `TextComponent` 등)를 통해서만 상호작용!**

Decorator Pattern의 가장 큰 특징은 **래핑(Wrapping) 구조**이다. 각 데코레이터는 컴포넌트를 감싸서 기능을 추가하며, 이러한 래핑이 중첩될 수 있다.
- 런타임에 동적으로 기능 조합 가능
- 상속 대신 조합(composition)을 사용
- 데코레이터 체인을 통한 기능 누적

## 실제 사용 예시: 파일 스트림
```python
class Stream:
    def read(self): pass
    def write(self, data): pass

class FileStream(Stream):
    def __init__(self, filename):
        self.filename = filename
    def read(self): return f"파일 {self.filename} 읽기"
    def write(self, data): return f"파일 {self.filename}에 쓰기: {data}"

class StreamDecorator(Stream):
    def __init__(self, stream):
        self.stream = stream

class BufferedStream(StreamDecorator):
    def read(self):
        return f"버퍼링된 {self.stream.read()}"
    def write(self, data):
        return f"버퍼링된 {self.stream.write(data)}"

class EncryptedStream(StreamDecorator):
    def read(self):
        return f"복호화된 {self.stream.read()}"
    def write(self, data):
        return f"암호화된 {self.stream.write(data)}"

# 기능 조합: 버퍼링 + 암호화
file = FileStream("data.txt")
buffered = BufferedStream(file)
encrypted = EncryptedStream(buffered)

print(encrypted.read())   # 복호화된 버퍼링된 파일 data.txt 읽기
print(encrypted.write("Hello"))  # 암호화된 버퍼링된 파일 data.txt에 쓰기: Hello
```

## 언제 Decorator Pattern을 사용해야 하는가?

Decorator Pattern은 다음과 같은 상황에서 유용하다:

### 1. 런타임에 객체의 책임을 추가해야 할 때

객체를 사용하는 코드를 훼손하지 않으면서 런타임에 추가 행동들을 할당할 수 있어야 할 때 사용한다. 데코레이터는 비즈니스 로직을 계층으로 구성하고, 각 계층에 데코레이터를 생성하여 런타임에 이 로직의 다양한 조합들로 객체들을 구성할 수 있도록 한다.

예시:
- 커피숍 주문 시스템 (기본 커피 + 다양한 토핑 조합)
- 텍스트 에디터 (기본 텍스트 + 다양한 스타일 적용)
- 웹 요청 처리 (기본 요청 + 인증/로깅/캐싱 등)

### 2. 상속으로는 기능 확장이 비현실적일 때

상속을 사용하여 객체의 행동을 확장하는 것이 어색하거나 불가능할 때 사용한다. 많은 프로그래밍 언어에는 클래스의 추가 확장을 방지하는 데 사용할 수 있는 `final` 키워드가 있다. Final 클래스의 경우 기존 행동들을 재사용할 수 있는 유일한 방법은 데코레이터 패턴을 사용하여 클래스를 자체 래퍼로 래핑하는 것이다.

예시:
- GUI 컴포넌트 (스크롤바, 테두리, 그림자 등의 조합)
- 스트림 처리 (버퍼링, 암호화, 압축 등의 조합)

## 구현 방법

1. 비즈니스 도메인이 여러 선택적 계층으로 감싸진 기본 컴포넌트로 표시될 수 있는지 확인.

2. 기본 컴포넌트와 선택적 계층들 양쪽에 공통적인 메서드들이 무엇인지 파악. 그곳에 컴포넌트 인터페이스를 만들고 해당 메서드들을 선언.

3. Concrete(구상) 컴포넌트 클래스를 만든 후 그 안에 기초 행동들을 정의.

4. 기초 데코레이터 클래스를 만든다.
- 이 클래스에는 래핑된 객체에 대한 참조를 저장하기 위한 필드가 있어야 함
- 이 필드는 데코레이터들 및 구상 컴포넌트들과의 연결을 허용하기 위하여 컴포넌트 인터페이스 유형으로 선언해야 함
- 기초 데코레이터는 모든 작업을 래핑된 객체에 위임

5. 모든 클래스들이 컴포넌트 인터페이스를 구현하도록 한다.

6. 기초 데코레이터를 확장하여 구상 데코레이터들을 생성
- 구상 데코레이터는 항상 부모 메서드 호출 전 또는 후에 행동들을 실행해야 함 (부모 메서드는 항상 래핑된 객체에 작업을 위임)

7. 데코레이터들을 만들고 이러한 데코레이터들을 클라이언트가 필요로 하는 방식으로 구성하는 일은 반드시 클라이언트 코드가 맡아야 함

## 장단점

### 장점

✅ **새 자식 클래스를 만들지 않고도 객체의 행동을 확장할 수 있음**
- 상속 대신 조합을 사용하여 유연한 기능 확장이 가능

✅ **런타임에 객체들에서 책임들을 추가하거나 제거할 수 있음**
- 동적으로 기능을 조합하거나 제거할 수 있어 유연성이 뛰어남

✅ **객체를 여러 데코레이터로 래핑하여 여러 행동들을 합성할 수 있음**
- 데코레이터 체인을 통해 복잡한 기능 조합이 가능

✅ **단일 책임 원칙 준수**
- 다양한 행동들의 여러 변형들을 구현하는 모놀리식 클래스를 여러 개의 작은 클래스들로 나눌 수 있다.

### 단점

❌ **래퍼들의 스택에서 특정 래퍼를 제거하기가 어려움**
- 데코레이터가 중첩되면 중간에 있는 특정 데코레이터만 제거하기 복잡함

❌ **데코레이터의 행동이 데코레이터 스택 내의 순서에 의존하지 않는 방식으로 구현하기가 어렵다**
- 데코레이터의 적용 순서에 따라 결과가 달라질 수 있어 주의가 필요하다.

❌ **계층들의 초기 설정 코드가 보기 흉할 수 있다**
- 여러 데코레이터를 중첩할 때 초기화 코드가 복잡해질 수 있음.

## 용어 정리

**Component (컴포넌트)**: ConcreteComponent와 Decorator가 구현하는 공통 인터페이스  
**ConcreteComponent (구체적 컴포넌트)**: 기본 기능을 제공하는 핵심 객체  
**Decorator (장식자)**: Component를 구현하고 다른 Component를 감싸는 추상 클래스  
**ConcreteDecorator (구체적 장식자)**: 실제 추가 기능을 구현하는 데코레이터

1. 커피숍 시스템 예시:
- Component (컴포넌트) → Beverage
- ConcreteComponent (구체적 컴포넌트) → Espresso, Latte
- Decorator (장식자) → CondimentDecorator  
- ConcreteDecorator (구체적 장식자) → Milk, Sugar, Whip

2. 파일 스트림 예시:
- Component (컴포넌트) → Stream
- ConcreteComponent (구체적 컴포넌트) → FileStream
- Decorator (장식자) → StreamDecorator
- ConcreteDecorator (구체적 장식자) → BufferedStream, EncryptedStream
