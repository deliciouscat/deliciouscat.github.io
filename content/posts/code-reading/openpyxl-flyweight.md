---
title: "Flyweight는 실전에서 이렇게 쓰인다 — openpyxl 스타일 시스템"
date: 2026-06-20T20:25:00+09:00
draft: false
categories: ["Code Reading"]
tags: ["openpyxl", "Flyweight", "플라이웨이트", "디자인패턴"]
---

> 이전 글 [Vibe Coding을 위한 디자인 패턴 - 플라이웨이트(Flyweight)](/posts/design-pattern/designpattern-flyweight/)를 읽었다는 가정 하에 쓴다.

## openpyxl이 뭔지 3줄

openpyxl은 Python에서 `.xlsx` 파일을 읽고 쓰는 라이브러리다.  
엑셀 파일의 셀 값, 수식, 스타일(글꼴·색상·테두리)을 코드로 다룰 수 있다.  
오늘 볼 코드는 그중에서도 **"셀이 수십만 개여도 스타일 객체를 어떻게 메모리 효율적으로 관리하는가"** 이다.

---

## 문제: 셀은 많지만 스타일 조합은 반복된다

엑셀 파일을 생각해보자. A1부터 Z10000까지 26만 개의 셀이 있다고 하자. 이 중 헤더 행은 굵은 파란 글씨, 짝수 행은 회색 배경, 나머지는 기본 스타일이다.

실제 스타일 **조합의 종류**는 3가지뿐이지만, 셀은 26만 개다.

만약 각 셀이 `Font`, `Fill`, `Border`, `Alignment` 객체를 직접 들고 있으면:

```python
# 이렇게 하면 Font 객체만 26만 개
class Cell:
    def __init__(self):
        self.font = Font(bold=True, color="0000FF")   # 각자 들고 있음
        self.fill = Fill(...)
        self.border = Border(...)
```

`Font` 하나가 수십 바이트라도, 26만 개면 수십 MB가 스타일에만 쓰인다.

Flyweight 패턴 글에서 본 숲 예시와 상황이 같다. **스타일 종류(intrinsic)는 적고, 그걸 쓰는 셀(context)은 많다.**

---

## 해법: 셀은 인덱스만 들고, 실제 객체는 workbook이 관리한다

openpyxl의 핵심 아이디어는 단순하다.

- `Font`, `Fill`, `Border` 같은 스타일 객체는 **workbook 수준의 IndexedList**에 딱 하나씩만 저장한다.
- 각 셀은 스타일 객체를 직접 보관하지 않고, **그 객체의 인덱스(정수)만 보관한다.**

```
Workbook
 ├── _fonts    = IndexedList([Font(bold=True), Font(italic=True), ...])   # 2개
 ├── _fills    = IndexedList([PatternFill(), PatternFill(bgColor=...), ...])
 ├── _borders  = IndexedList([Border(), Border(left=...)])
 └── _cell_styles = IndexedList(...)

Cell A1 ─── _style = StyleArray([fontId=0, fillId=0, borderId=1, ...])  # 인덱스만!
Cell A2 ─── _style = StyleArray([fontId=0, fillId=1, borderId=0, ...])  # 인덱스만!
Cell A3 ─── _style = StyleArray([fontId=0, fillId=0, borderId=1, ...])  # A1과 같은 스타일
```

A1과 A3의 `fontId=0`이 가리키는 건 **동일한 `Font` 객체 하나**다. 복사가 아니라 참조다.

---

## `StyleArray` — 셀이 실제로 들고 있는 것

`Cell`이 보관하는 `_style` 필드의 타입은 `StyleArray`다.

```python
# openpyxl/styles/cell_style.py

class StyleArray(array):
    """
    Simplified named tuple with an array
    """
    fontId       = ArrayDescriptor(0)   # _fonts 의 인덱스
    fillId       = ArrayDescriptor(1)   # _fills 의 인덱스
    borderId     = ArrayDescriptor(2)   # _borders 의 인덱스
    numFmtId     = ArrayDescriptor(3)   # 숫자 형식 인덱스
    protectionId = ArrayDescriptor(4)   # _protections 의 인덱스
    alignmentId  = ArrayDescriptor(5)   # _alignments 의 인덱스
    ...

    def __new__(cls, args=[0]*9):
        return array.__new__(cls, 'i', args)   # 정수 배열 9개
```

`StyleArray`는 `array('i', ...)` — 즉 **정수 9개짜리 배열**이다.

`Font`, `Fill`, `Border` 객체를 들고 있는 게 아니라 **그 객체들의 인덱스**만 들고 있다. 셀 하나가 스타일을 위해 쓰는 메모리는 정수 9개(36바이트)가 전부다. `Font` 객체 자체는 workbook이 한 번만 만들어서 관리한다.

---

## `IndexedList` — Flyweight Factory이자 캐시

`IndexedList`는 openpyxl에서 **스타일 객체를 dedupe(중복 제거)하는 핵심 자료구조**다.

```python
# openpyxl/utils/indexed_list.py

class IndexedList(list):
    """
    List with optimised access by value
    """

    def __init__(self, iterable=None):
        self.clean = True
        self._dict = {}          # value → index 역방향 매핑
        if iterable is not None:
            for idx, val in enumerate(iterable):
                self._dict[val] = idx
                list.append(self, val)

    def append(self, value):
        if value not in self._dict:          # 이미 있으면 추가 안 함
            self._dict[value] = len(self)
            list.append(self, value)

    def add(self, value):
        self.append(value)
        return self._dict[value]             # 인덱스 반환
```

`add(value)`가 핵심이다.

- 이미 동일한 값이 있으면 **추가하지 않고** 기존 인덱스를 반환한다.
- 새로운 값이면 추가하고 새 인덱스를 반환한다.

Flyweight 패턴 글의 `TreeTypeFactory.get_tree_type()`과 역할이 같다.

```python
# 패턴 글의 팩토리
def get_tree_type(cls, tree_type, color, texture) -> TreeType:
    key = f"{tree_type}_{color}"
    if key not in cls._cache:
        cls._cache[key] = TreeType(...)
    return cls._cache[key]

# openpyxl의 IndexedList.add
def add(self, value):
    self.append(value)        # 내부에서 중복 체크
    return self._dict[value]  # 기존이든 신규든 인덱스 반환
```

차이가 있다면 패턴 글의 팩토리는 **객체 자체**를 돌려주고, `IndexedList.add`는 **인덱스(정수)**를 돌려준다는 점이다.

---

## `StyleDescriptor` — 셀에서 스타일을 읽고 쓸 때

셀에서 `cell.font = Font(bold=True)`를 쓰면 내부에서 무슨 일이 일어나는지 보자.

```python
# openpyxl/styles/styleable.py

class StyleDescriptor:

    def __init__(self, collection, key):
        self.collection = collection   # "_fonts", "_fills", "_borders" 등
        self.key = key                 # "fontId", "fillId", "borderId" 등

    def __set__(self, instance, value):
        coll = getattr(instance.parent.parent, self.collection)  # wb._fonts
        setattr(instance._style, self.key, coll.add(value))      # 인덱스 저장

    def __get__(self, instance, cls):
        coll = getattr(instance.parent.parent, self.collection)   # wb._fonts
        idx = getattr(instance._style, self.key)                  # 인덱스 조회
        return StyleProxy(coll[idx])                              # 객체 반환
```

`cell.font = Font(bold=True)`가 실행되는 흐름:

```
cell.font = Font(bold=True)
    └─ StyleDescriptor.__set__ 호출
         ├─ wb._fonts.add(Font(bold=True))   # IndexedList에 추가
         │    └─ 이미 동일한 Font가 있으면 기존 인덱스 반환
         │       없으면 추가 후 새 인덱스 반환
         └─ cell._style.fontId = 반환된_인덱스  # 정수 저장
```

`cell.font`를 읽을 때는:

```
cell.font
    └─ StyleDescriptor.__get__ 호출
         ├─ idx = cell._style.fontId          # 정수 꺼냄
         └─ return wb._fonts[idx]             # 실제 Font 객체 조회
```

셀은 인덱스만 저장하고, 실제 객체는 workbook에서 꺼내온다. Flyweight 패턴의 구조 그대로다.

```
Cell.font 접근
            ↓
     _style.fontId (정수)
            ↓
     wb._fonts[idx] (공유 Font 객체)
```

---

## 전체 흐름 한 번에 보기

```python
import openpyxl
from openpyxl.styles import Font, PatternFill

wb = openpyxl.Workbook()
ws = wb.active

bold_blue = Font(bold=True, color="0000FF")

# 셀 1만 개에 같은 스타일 적용
for row in range(1, 10001):
    cell = ws.cell(row=row, column=1)
    cell.font = bold_blue
```

내부에서 일어나는 일:

```
첫 번째 셀: wb._fonts.add(Font(bold=True, color="0000FF"))
              → 새 Font 객체 저장, index=2 반환
              → cell._style.fontId = 2

두 번째 셀: wb._fonts.add(Font(bold=True, color="0000FF"))
              → 이미 동일한 Font 존재 → index=2 반환
              → cell._style.fontId = 2   (같은 인덱스)

...

1만 번째 셀: wb._fonts.add(Font(bold=True, color="0000FF"))
               → 여전히 index=2 반환
               → cell._style.fontId = 2
```

`Font` 객체는 **딱 1개**, `wb._fonts` 안에만 존재한다. 1만 개의 셀은 모두 인덱스 `2`를 들고 공유한다.

실제로 확인해볼 수 있다:

```python
import openpyxl
from openpyxl.styles import Font

wb = openpyxl.Workbook()
ws = wb.active

bold = Font(bold=True)

for row in range(1, 10001):
    ws.cell(row=row, column=1).font = bold

print(len(wb._fonts))       # 2 (기본 폰트 + bold)
print(len(ws._cells))       # 10000
```

셀 1만 개, `Font` 객체 2개.

---

## xlsx 파일로 저장될 때도 마찬가지다

openpyxl이 파일을 저장할 때, Excel의 `.xlsx` 포맷도 같은 구조를 쓴다. `.xlsx` 파일의 내부에는 `styles.xml`이 있는데:

```xml
<!-- xl/styles.xml -->
<fonts>
  <font><!-- 기본 폰트 --></font>
  <font><b/><color rgb="0000FF"/></font>  <!-- index=1: bold blue -->
</fonts>

<cellXfs>
  <!-- 각 스타일 조합. fontId로 위 fonts를 참조 -->
  <xf fontId="1" fillId="0" borderId="0" .../>
</cellXfs>
```

그리고 각 셀은 `s="0"` 같이 **스타일 인덱스만 XML에 기록**한다.

```xml
<row r="1">
  <c r="A1" s="0"><v>100</v></c>
  <c r="A2" s="0"><v>200</v></c>  <!-- 같은 스타일 인덱스 -->
</row>
```

**Python 코드 레벨의 Flyweight 구조가 파일 포맷 레벨에서도 그대로 반영**된다. Excel 포맷 자체가 이 설계를 요구하기 때문이다.

---

## Flyweight 패턴 용어로 매핑하면

| 패턴 용어 | openpyxl 구현 |
|-----------|--------------|
| **Flyweight** | `Font`, `Fill`, `Border`, `Alignment`, `Protection` |
| **Intrinsic state** | 글꼴 이름·크기·색상, 테두리 스타일 등 — 공유 가능한 불변 스타일 정보 |
| **Flyweight Factory/Cache** | `IndexedList` (`wb._fonts`, `wb._fills`, `wb._borders`, ...) |
| **Extrinsic state** | 셀 좌표(`row`, `column`), 셀 값(`_value`) |
| **Context** | `Cell` — `StyleArray`(인덱스들)와 좌표를 함께 보관 |
| **Client** | `Worksheet`, `Workbook` |

---

## 패턴 글의 교훈 — 실전에서 달랐던 점

| | 패턴 글의 교과서 예시 | openpyxl |
|---|---|---|
| Factory | 딕셔너리 캐시, 객체 반환 | `IndexedList`, **인덱스 반환** |
| Flyweight 저장 방식 | 팩토리 딕셔너리 | workbook 필드(`_fonts` 등) |
| Context가 보관하는 것 | Flyweight 객체 **참조** | Flyweight의 **인덱스(정수)** |
| 파일 저장과의 연계 | 없음 | Excel 포맷 자체가 인덱스 구조 |

openpyxl의 한 걸음 더 나아간 점은, **객체 참조 대신 정수 인덱스**를 extrinsic state로 쓴다는 것이다. 참조(포인터)도 메모리를 쓰지만, 정수는 더 작다. 게다가 Excel 파일 포맷이 원래 인덱스 기반이라 저장/로드 시 변환 없이 그대로 쓸 수 있다.

---

## 한 줄 정리

> openpyxl은 `IndexedList`로 스타일 객체를 dedupe하고, 각 셀에는 객체 대신 **정수 인덱스만 남겨** — 셀 수십만 개가 있어도 실제 `Font`·`Fill`·`Border` 객체는 종류만큼만 존재하는 Flyweight 패턴의 정석 사례다.

원본 코드:
- [`openpyxl/utils/indexed_list.py`](https://foss.heptapod.net/openpyxl/openpyxl/-/blob/branch/default/openpyxl/utils/indexed_list.py)
- [`openpyxl/styles/styleable.py`](https://foss.heptapod.net/openpyxl/openpyxl/-/blob/branch/default/openpyxl/styles/styleable.py)
- [`openpyxl/styles/cell_style.py`](https://foss.heptapod.net/openpyxl/openpyxl/-/blob/branch/default/openpyxl/styles/cell_style.py)
