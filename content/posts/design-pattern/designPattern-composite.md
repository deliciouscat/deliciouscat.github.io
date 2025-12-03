---
title: "Vibe Coding을 위한 디자인 패턴 - 복합체(Composite)"
date: 2025-09-20T18:00:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "복합체", "Composite"]
---

Composite Pattern(복합체 패턴)은 객체들을 트리 구조로 구성하여 부분과 전체로 계층을 표현하는 디자인 패턴이다.
클라이언트가 **개별 객체**와 **복합 객체**를 동일한 방식으로 다룰 수 있다.

예를 들어:
```python
class Component:
    def execute(self): pass

class Leaf(Component):
    def execute(self): return 1

class Composite(Component):
    def __init__(self): self.children = []
    def add(self, c): self.children.append(c)
    def execute(self): return sum(c.execute() for c in self.children)

# 클라이언트는 Leaf와 Composite를 구분하지 않음
items = [Leaf(), Composite(), Leaf()]  # 모두 Component
items[1].add(Leaf())    # Composite에 Leaf 추가: children = [leaf1]
items[1].add(Leaf())    # Composite에 Leaf 추가: children = [leaf1, leaf2]
total = sum(item.execute() for item in items)
print(total)  # 1 + 2 + 1 = 4
```
-> `Leaf`와 `Composite`는 둘 다 `Component`(execute 메서드를 가진)를 상속해서 `execute` 메서드를 호출할 수 있고, 위계에 상관없이 메서드를 호출 가능하다.

## 단일 책임 원칙 / 개방-폐쇄 원칙
Composite Pattern을 사용할 땐 이 원칙을 준수해야 하는데, 먼저 단일 책임 원칙 (Single Responsibility Principle; SRP)이 지켜지지 않은 예시를 보자.

**잘못된 예:**
```python
class FileSystemItem:
    def __init__(self, name, is_folder=False):
        self.name = name
        self.is_folder = is_folder
        self.children = [] if is_folder else None
        self.size = 0 if not is_folder else None
        
    def calculate_size(self):
        if self.is_folder:
            return sum(c.calculate_size() for c in self.children)
        return self.size
    
    def render_ui(self):  # UI 렌더링 책임까지 가짐
        return f"<div>{self.name}</div>"
```
위의 코드를 보면 `type()`으로 이것이 폴더인지 파일인지 확인할 수도 없고, 번거롭게 `if is_folder else None`을 반복하고 있다. (`self.children`과 `self.size`가 쓸테없는 책임을 지고 있음!) 게다가 파일 시스템에 렌더링 기능까지... 이 코드를 SRP를 준수하도록 수정하자.

**잘된 예:**
```python
class Component:
    def calculate_size(self): pass

class File(Component):
    def __init__(self, name, size):
        self.name, self.size = name, size
    def calculate_size(self): return self.size

class Folder(Component):
    def __init__(self, name):
        self.name, self.children = name, []
    def add(self, item): self.children.append(item)
    def calculate_size(self): 
        return sum(c.calculate_size() for c in self.children)
```
이렇게 하면 파일은 파일대로, 폴더는 폴더대로 각 클래스가 필요한 역할을 담당하게 된다.

다음으로 개방-폐쇄 원칙(Open-Closed Principle; OCP)를 살펴보자. 'Entity는 확장에는 열려있고, 수정에는 닫혀있어야 한다'는 원칙인데,

**잘못된 예:**
```python
class GraphicEditor:
    def draw_shape(self, shape):
        if shape.type == "circle":
            self.draw_circle(shape)
        elif shape.type == "rectangle":
            self.draw_rectangle(shape)
        elif shape.type == "triangle":
            self.draw_triangle(shape)
```
-> 이렇게 하면 오각형은 어쩌려고? 입체도형은?? 매번 `GraphicEditor`를 수정해야 하는 구조이다. (확장에 대해 개방성이 없다)

**잘된 예:**
```python
class Shape:
    def draw(self): pass

class Circle(Shape):
    def draw(self): return "Drawing circle"

class Rectangle(Shape):
    def draw(self): return "Drawing rectangle"

class ShapeGroup(Shape):  # 새 도형 추가해도 기존 코드 수정 불필요
    def __init__(self):
        self.shapes = []
    def add(self, shape): self.shapes.append(shape)
    def draw(self): return [s.draw() for s in self.shapes]
```
이제, 새로운 도형을 다루고자 할 때엔 `Shape` 클래스를 상속하여 쉽게 기존 기능들을 확장할 수 있으며(확장에는 개방), `ShapeGroup` 클래스에 별도의 코드를 추가할 필요가 없다. (수정에는 닫혀있다.)  
**각 클래스가 명확한 단일 책임, 각 컴포넌트들이 인터페이스(`Component`, `Shape` 등)를 통해서만 상호작용!**


Composite Pattern의 가장 큰 특징은 재귀적 구조이다. 복합 객체는 자식으로 다른 복합 객체나 단일 객체를 포함할 수 있으며, 이러한 구조가 재귀적으로 반복된다.
- 트리의 깊이와 관계없이 일관된 처리 방식
- 새로운 구성 요소 추가가 용이
- 복잡한 구조를 단순한 재귀 호출로 순회 가능


## Composite Pattern은 다음과 같은 상황에서 유용하다:
1. 계층적 구조를 표현해야 할 때.
ex.)
- 파일 시스템 (폴더-파일 구조)
- UI 컴포넌트 (컨테이너-위젯 구조)
- 조직도 (부서-팀-직원 구조)

2. 부분과 전체를 동일하게 처리해야 할 때(재귀적 특성!)
ex.)
- 그래픽 편집기의 도형 그룹화
- 메뉴와 서브메뉴 구조


## 용어 정리
Component (추상 인터페이스): Leaf와 Composite 모두가 구현해야 하는 공통 인터페이스  
Leaf (단일 객체): 트리 구조의 말단 노드로, 더 이상 자식을 가지지 않는 기본 구성 요소  
Composite (복합 객체): Leaf 객체나 다른 Composite 객체를 자식으로 가지는 객체  

1. Python 파일 시스템 예시:
- Component (추상 인터페이스) → Component
- Leaf (단일 객체) → File
- Composite (복합 객체) → Folder

2. 그래픽 에디터 예시:
- Component (추상 인터페이스) → Shape
- Leaf (단일 객체) → Circle, Rectangle
- Composite (복합 객체) → ShapeGroup