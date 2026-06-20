---
title: "Vibe Coding을 위한 디자인 패턴 - 플라이웨이트(Flyweight)"
date: 2026-06-20T17:54:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "플라이웨이트", "Flyweight"]
---

Flyweight Pattern(플라이웨이트 패턴)은 **대량의 유사한 객체들을 효율적으로 공유**함으로써 메모리 사용량을 줄이는 구조 디자인 패턴이다.

핵심 아이디어는 **공유 가능한 상태(intrinsic state)** 와 **공유 불가능한 상태(extrinsic state)** 를 분리하는 것이다.

예를 들어 텍스트 편집기에서 문자 `'A'`가 10만 번 등장한다고 해보자. 각 `'A'`마다 글꼴, 색상, 폰트 크기 객체를 따로 만들면 메모리 낭비가 심하다. 하지만 `'A'`의 글꼴 정보는 어느 위치에 있든 동일하다. Flyweight는 이 **공통 부분을 하나만 만들어 재사용**하고, 위치처럼 각 `'A'`마다 달라지는 정보만 외부에서 주입한다.

## Intrinsic vs Extrinsic

Flyweight 패턴을 이해하는 데 가장 중요한 개념이다.

| 구분 | 이름 | 특징 | 예시 |
|------|------|------|------|
| 내부 상태 | Intrinsic State | 객체 간 공유 가능, 불변 | 글꼴, 색상, 스프라이트 이미지 |
| 외부 상태 | Extrinsic State | 객체마다 다름, 외부에서 주입 | 문자 위치, 나무의 X/Y 좌표 |

Flyweight 객체는 **intrinsic state만 내부에 저장**한다. extrinsic state는 필요할 때마다 매개변수로 전달받는다.

## 문제가 있는 예시

숲 시뮬레이션 게임을 만든다고 해보자. 나무 10만 그루를 화면에 그려야 한다.

```python
class Tree:
    def __init__(self, x, y, tree_type, color, texture):
        self.x = x
        self.y = y
        self.tree_type = tree_type   # "Oak", "Pine", "Birch" 중 하나
        self.color = color           # 색상 데이터 (수 MB)
        self.texture = texture       # 텍스처 이미지 (수십 MB)

    def draw(self):
        print(f"Draw {self.tree_type} at ({self.x}, {self.y})")


# 10만 그루 생성
trees = []
for i in range(100_000):
    trees.append(Tree(i, i * 2, "Oak", large_color_data, large_texture_data))
```

위 코드의 문제점:

1. 나무 10만 그루 각각이 `color`와 `texture`를 따로 들고 있다.
2. "Oak" 나무의 색상과 텍스처는 모두 동일한데, 10만 번 복사된다.
3. 메모리 사용량이 폭발적으로 증가한다.

실제로 `tree_type`, `color`, `texture`는 나무 종류가 같으면 동일하다. 반면 `x`, `y`는 나무마다 다르다.

## Flyweight 적용

공유 가능한 부분(`tree_type`, `color`, `texture`)을 별도 객체로 분리하자.

```python
class TreeType:
    """Flyweight: intrinsic state만 보관"""
    def __init__(self, tree_type, color, texture):
        self.tree_type = tree_type
        self.color = color
        self.texture = texture

    def draw(self, x, y):
        # extrinsic state(x, y)는 매개변수로 받음
        print(f"Draw {self.tree_type}(color={self.color}) at ({x}, {y})")


class Tree:
    """extrinsic state(좌표)와 Flyweight 참조만 보관"""
    def __init__(self, x, y, tree_type: TreeType):
        self.x = x
        self.y = y
        self.tree_type = tree_type  # Flyweight 객체 참조

    def draw(self):
        self.tree_type.draw(self.x, self.y)
```

이제 `TreeType` 객체는 나무 종류별로 딱 하나만 존재한다. 나무 10만 그루가 같은 `TreeType` 객체를 공유한다.

## Flyweight Factory

Flyweight 객체를 직접 생성하면 중복이 생길 수 있다. 보통 **팩토리**로 관리한다.

```python
class TreeTypeFactory:
    _cache: dict[str, TreeType] = {}

    @classmethod
    def get_tree_type(cls, tree_type, color, texture) -> TreeType:
        key = f"{tree_type}_{color}"
        if key not in cls._cache:
            cls._cache[key] = TreeType(tree_type, color, texture)
            print(f"[Factory] 새 TreeType 생성: {key}")
        return cls._cache[key]
```

팩토리가 캐시를 관리하므로, 같은 종류의 `TreeType`은 항상 동일한 객체를 반환한다.  
이렇게 짜야 메모리를 같은 캐시에서 공유함.

## 전체 코드

```python
from __future__ import annotations


class TreeType:
    def __init__(self, tree_type: str, color: str, texture: str):
        self.tree_type = tree_type
        self.color = color
        self.texture = texture

    def draw(self, x: int, y: int):
        print(f"Draw {self.tree_type}(color={self.color}) at ({x}, {y})")


class TreeTypeFactory:
    _cache: dict[str, TreeType] = {}

    @classmethod
    def get_tree_type(cls, tree_type: str, color: str, texture: str) -> TreeType:
        key = f"{tree_type}_{color}"
        if key not in cls._cache:
            cls._cache[key] = TreeType(tree_type, color, texture)
        return cls._cache[key]


class Tree:
    def __init__(self, x: int, y: int, tree_type: TreeType):
        self.x = x
        self.y = y
        self.tree_type = tree_type

    def draw(self):
        self.tree_type.draw(self.x, self.y)


class Forest:
    def __init__(self):
        self.trees: list[Tree] = []

    def plant_tree(self, x: int, y: int, type_name: str, color: str, texture: str):
        tree_type = TreeTypeFactory.get_tree_type(type_name, color, texture)
        self.trees.append(Tree(x, y, tree_type))

    def draw(self):
        for tree in self.trees:
            tree.draw()


# 사용
forest = Forest()
for i in range(5):
    forest.plant_tree(i * 10, i * 20, "Oak", "green", "oak_texture.png")
for i in range(5):
    forest.plant_tree(i * 15, i * 30, "Pine", "dark_green", "pine_texture.png")

forest.draw()
print(f"\nTreeType 캐시 수: {len(TreeTypeFactory._cache)}")  # 2 (Oak, Pine)
print(f"Tree 총 수: {len(forest.trees)}")  # 10
```

실행 결과:

```
Draw Oak(color=green) at (0, 0)
Draw Oak(color=green) at (10, 20)
...
Draw Pine(color=dark_green) at (0, 0)
...

TreeType 캐시 수: 2
Tree 총 수: 10
```

`TreeType`은 두 종류뿐이고, 나무가 몇 그루가 되든 `TreeType` 수는 늘어나지 않는다.

## 텍스트 편집기 예시

또 다른 전형적인 예시로 텍스트 편집기에서 문자 렌더링을 보자.

```python
from __future__ import annotations


class CharacterStyle:
    """Flyweight: 폰트, 크기, 색상 — 공유 가능한 스타일 정보"""
    def __init__(self, font: str, size: int, color: str):
        self.font = font
        self.size = size
        self.color = color

    def render(self, char: str, position: int):
        print(f"[pos={position}] '{char}' font={self.font} size={self.size} color={self.color}")


class StyleFactory:
    _styles: dict[tuple, CharacterStyle] = {}

    @classmethod
    def get_style(cls, font: str, size: int, color: str) -> CharacterStyle:
        key = (font, size, color)
        if key not in cls._styles:
            cls._styles[key] = CharacterStyle(font, size, color)
        return cls._styles[key]


class Character:
    """extrinsic state: 문자 값과 위치"""
    def __init__(self, char: str, position: int, style: CharacterStyle):
        self.char = char
        self.position = position
        self.style = style

    def render(self):
        self.style.render(self.char, self.position)


# 사용
factory = StyleFactory()
normal = factory.get_style("Arial", 12, "black")
bold   = factory.get_style("Arial-Bold", 12, "black")

document = [
    Character("H", 0, normal),
    Character("e", 1, normal),
    Character("l", 2, normal),
    Character("l", 3, normal),
    Character("o", 4, normal),
    Character("!", 5, bold),
]

for ch in document:
    ch.render()

print(f"\n스타일 객체 수: {len(StyleFactory._styles)}")  # 2 (normal, bold)
print(f"문자 객체 수: {len(document)}")               # 6
```

문자 6개지만 `CharacterStyle` 객체는 2개뿐이다. 문서가 수천 글자로 늘어나도 스타일 종류가 늘지 않으면 `CharacterStyle` 객체 수는 그대로다.

## Singleton과의 차이

Flyweight와 Singleton은 둘 다 "하나만 만든다"는 점에서 혼동하기 쉽지만 다르다.

| 구분 | Singleton | Flyweight |
|------|-----------|-----------|
| 목적 | 전역 접근점 제공, 인스턴스 하나 보장 | 메모리 절약, 유사 객체 공유 |
| 인스턴스 수 | 클래스당 정확히 1개 | **종류별로** 1개 (여러 개일 수 있음) |
| 상태 | 가변 상태를 가질 수 있음 | 내부 상태는 불변(공유 안전을 위해) |
| 관리 주체 | 클래스 자신 | Factory가 관리 |

Flyweight는 "전역에 딱 하나"가 아니라 "같은 내용이면 하나"다.

## 장점

1. **메모리 절약**
   - 대량의 유사 객체를 생성할 때 메모리 사용량을 극적으로 줄인다.

2. **성능 향상**
   - 객체 생성 비용이 큰 경우(이미지 로딩, DB 연결 등) 재사용으로 성능이 올라간다.

3. **캐시 역할**
   - Flyweight Factory가 자연스럽게 객체 캐시 역할을 한다.

## 단점

1. **코드 복잡도 증가**
   - intrinsic/extrinsic 상태를 분리해야 하므로 설계가 복잡해진다.

2. **extrinsic state 관리 부담**
   - 외부 상태를 호출할 때마다 넘겨줘야 하므로 코드가 장황해질 수 있다.

3. **공유 객체는 불변이어야 함**
   - 한 곳에서 수정하면 해당 Flyweight를 공유하는 모든 객체에 영향이 간다.

4. **CPU와 메모리의 트레이드오프**
   - 매번 extrinsic state를 계산하거나 조합하는 경우 CPU 사용이 늘 수 있다.

## 언제 사용해야 할까?

1. **비슷한 객체가 대량으로 필요할 때**
   - 파티클 시스템, 텍스트 렌더링, 지도 타일, 게임 스프라이트 등

2. **공유 가능한 상태가 명확히 분리될 때**
   - 모든 객체가 공통으로 가지는 불변 데이터가 있을 때

3. **메모리 부족이 실제 문제일 때**
   - 프로파일링으로 메모리 과다 사용을 확인한 뒤에 적용하는 것이 좋다.

단순히 "객체가 많다"는 이유만으로 무조건 적용하면 오히려 복잡도만 높아진다. 객체의 공유 가능한 부분이 명확하고, 메모리 절약이 실질적으로 필요한 경우에 사용한다.

## 용어 정리

- **Flyweight**: 공유되는 객체. intrinsic state만 보관한다.
- **Intrinsic State (내부 상태)**: Flyweight 내부에 저장되는 불변 데이터. 여러 문맥에서 공유된다.
- **Extrinsic State (외부 상태)**: 문맥마다 달라지는 데이터. Flyweight에 저장하지 않고, 메서드 호출 시 전달한다.
- **Flyweight Factory**: Flyweight 객체를 생성하고 캐시로 관리하는 팩토리. 동일한 intrinsic state를 가진 Flyweight를 재사용한다.
- **Context (문맥 객체)**: extrinsic state와 Flyweight 참조를 함께 보관하는 객체. 위 예시에서 `Tree`, `Character`가 해당한다.

## 한 줄 요약

> 공유 가능한 상태(intrinsic)를 하나의 객체로 뽑아내고, 문맥마다 달라지는 상태(extrinsic)는 외부에서 주입함으로써 **대량의 유사 객체를 메모리 효율적으로 처리**하는 패턴이다.
