---
title: "Vibe Coding을 위한 디자인 패턴 - 추상 팩토리(Abstract Factory)"
date: 2026-05-08T15:44:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "추상팩토리", "Abstract Factory", "팩토리","Factory"]
---

Abstract Factory Pattern은 **관련 있는 객체들의 묶음(제품군)을 생성하는 인터페이스를 제공하되, 구체적인 클래스는 클라이언트가 알지 못하게 하는** 생성 디자인 패턴이다.

Factory Method가 "객체 하나를 어떻게 만들지"에 집중한다면, Abstract Factory는 "서로 어울리는 객체 세트를 어떤 계열로 만들지"에 집중한다.

예를 들어 GUI를 만든다고 해보자.

- Windows 환경에서는 `WindowsButton`, `WindowsCheckbox`, `WindowsTextbox`
- Mac 환경에서는 `MacButton`, `MacCheckbox`, `MacTextbox`

이렇게 버튼, 체크박스, 텍스트박스가 각각 따로 존재하지만, 실제로는 **같은 운영체제 스타일끼리 함께 생성되어야 한다.**

이때 `WindowsButton`과 `MacCheckbox`가 섞여버리면 UI 스타일이 깨진다. Abstract Factory는 이런 문제를 막고, 관련 객체들을 하나의 제품군으로 일관되게 생성하게 해준다.

## Factory Method와의 차이

먼저 헷갈리기 쉬운 Factory Method와 비교해보자.

### Factory Method

Factory Method는 보통 **하나의 제품(Product)** 을 만든다.

```python
class DocumentFactory(ABC):
    @abstractmethod
    def create_document(self) -> Document:
        pass

class PDFFactory(DocumentFactory):
    def create_document(self) -> Document:
        return PDFDocument()
```

여기서 팩토리는 `Document` 계열 객체 하나를 생성한다.

즉 관심사는:

> "PDF 문서를 만들까? Word 문서를 만들까?"

이다.

### Abstract Factory

Abstract Factory는 **서로 관련 있는 여러 제품을 함께 만든다.**

```python
class GUIFactory(ABC):
    @abstractmethod
    def create_button(self) -> Button:
        pass

    @abstractmethod
    def create_checkbox(self) -> Checkbox:
        pass

    @abstractmethod
    def create_textbox(self) -> Textbox:
        pass
```

여기서 팩토리는 `Button`, `Checkbox`, `Textbox`를 함께 생성한다.

즉 관심사는:

> "Windows 스타일 제품군을 만들까? Mac 스타일 제품군을 만들까?"

이다.

간단히 말하면:

- **Factory Method**: 객체 하나의 생성 방식 캡슐화
- **Abstract Factory**: 관련 객체 묶음의 생성 방식 캡슐화

Abstract Factory 안에는 여러 개의 Factory Method가 들어 있다고 생각해도 된다.

## 문제가 있는 예시

Abstract Factory가 필요한 상황을 코드로 보자.

```python
class WindowsButton:
    def render(self):
        return "Render Windows button"

class MacButton:
    def render(self):
        return "Render Mac button"

class WindowsCheckbox:
    def render(self):
        return "Render Windows checkbox"

class MacCheckbox:
    def render(self):
        return "Render Mac checkbox"

class Application:
    def __init__(self, os_type):
        self.os_type = os_type

    def render_ui(self):
        if self.os_type == "windows":
            button = WindowsButton()
            checkbox = WindowsCheckbox()
        elif self.os_type == "mac":
            button = MacButton()
            checkbox = MacCheckbox()

        print(button.render())
        print(checkbox.render())
```

위 코드의 문제점:

1. `Application`이 모든 구체 클래스를 알고 있어야 한다.
2. 새로운 OS 스타일이 추가되면 `Application`을 수정해야 한다.
3. 버튼과 체크박스 생성 로직이 여기저기 섞이기 쉽다.
4. 실수로 `WindowsButton`과 `MacCheckbox` 같은 조합을 만들 수도 있다.

즉, 클라이언트 코드가 구체적인 UI 제품들에 너무 강하게 의존하고 있다.

## Abstract Factory 적용

이제 Button, Checkbox를 각각 추상화하고, 이들을 생성하는 Factory도 추상화해보자.

```python
from abc import ABC, abstractmethod

# 제품 인터페이스 1
class Button(ABC):
    @abstractmethod
    def render(self):
        pass

# 제품 인터페이스 2
class Checkbox(ABC):
    @abstractmethod
    def render(self):
        pass

# Windows를 위한 Concrete Products
class WindowsButton(Button):
    def render(self):
        return "Render Windows button"

class WindowsCheckbox(Checkbox):
    def render(self):
        return "Render Windows checkbox"

# Mac을 위한 Concrete Products
class MacButton(Button):
    def render(self):
        return "Render Mac button"

class MacCheckbox(Checkbox):
    def render(self):
        return "Render Mac checkbox"

# 추상 팩토리
class GUIFactory(ABC):
    @abstractmethod
    def create_button(self) -> Button:
        pass

    @abstractmethod
    def create_checkbox(self) -> Checkbox:
        pass

# Concrete Factory: Windows 제품군 생성
class WindowsFactory(GUIFactory):
    def create_button(self) -> Button:
        return WindowsButton()

    def create_checkbox(self) -> Checkbox:
        return WindowsCheckbox()

# Concrete Factory: Mac 제품군 생성
class MacFactory(GUIFactory):
    def create_button(self) -> Button:
        return MacButton()

    def create_checkbox(self) -> Checkbox:
        return MacCheckbox()
```

이제 `Application`은 구체적인 제품을 몰라도 된다.

```python
class Application:
    def __init__(self, factory: GUIFactory):
        self.factory = factory

    def render_ui(self):
        button = self.factory.create_button()
        checkbox = self.factory.create_checkbox()

        print(button.render())
        print(checkbox.render())

# 사용
def create_factory(os_type: str) -> GUIFactory:
    if os_type == "windows":
        return WindowsFactory()
    elif os_type == "mac":
        return MacFactory()
    else:
        raise ValueError(f"Unknown OS type: {os_type}")

factory = create_factory("windows")
app = Application(factory)
app.render_ui()
```

`Application`은 `WindowsButton`, `MacButton`, `WindowsCheckbox`, `MacCheckbox`를 직접 알지 않는다.
오직 `GUIFactory`, `Button`, `Checkbox`라는 추상화에만 의존한다.

## 제품군 일관성 보장

Abstract Factory의 중요한 장점은 **서로 어울리는 객체들이 함께 생성되도록 강제한다는 것**이다.

위 예시에서 `WindowsFactory`는 항상 Windows 스타일 제품만 만든다.

```python
class WindowsFactory(GUIFactory):
    def create_button(self) -> Button:
        return WindowsButton()

    def create_checkbox(self) -> Checkbox:
        return WindowsCheckbox()
```

반대로 `MacFactory`는 항상 Mac 스타일 제품만 만든다.

```python
class MacFactory(GUIFactory):
    def create_button(self) -> Button:
        return MacButton()

    def create_checkbox(self) -> Checkbox:
        return MacCheckbox()
```

클라이언트가 팩토리 하나만 선택하면, 그 뒤에 생성되는 객체들은 자연스럽게 같은 계열로 맞춰진다.

이 구조는 다음과 같은 상황에서 유용하다.

- 다크 테마 / 라이트 테마 UI 컴포넌트
- Windows / Mac / Linux용 위젯
- MySQL / PostgreSQL / SQLite용 저장소 객체들
- AWS / GCP / Azure용 클라우드 리소스 객체들
- 테스트 환경 / 운영 환경용 서비스 객체들

## 데이터베이스 예시

GUI 예시가 너무 UI에 치우쳐 있으니, 데이터베이스 예시도 보자.

애플리케이션에서 데이터베이스마다 여러 객체가 필요하다고 가정하자.

- 연결 객체
- 쿼리 빌더
- 마이그레이션 러너

이 객체들은 서로 같은 DB 계열이어야 한다.

```python
from abc import ABC, abstractmethod

# 어떤 DB를 쓰던 제공하는 기능들 (Abstract Product)
class Connection(ABC):
    @abstractmethod
    def connect(self):
        pass

class QueryBuilder(ABC):
    @abstractmethod
    def select_users(self):
        pass

class MigrationRunner(ABC):
    @abstractmethod
    def migrate(self):
        pass

# 그 기능들의 실제 구현 (Concrete Product)
class MySQLConnection(Connection):
    def connect(self):
        return "Connect to MySQL"

class MySQLQueryBuilder(QueryBuilder):
    def select_users(self):
        return "SELECT * FROM users LIMIT 10"

class MySQLMigrationRunner(MigrationRunner):
    def migrate(self):
        return "Run MySQL migration"

class PostgreSQLConnection(Connection):
    def connect(self):
        return "Connect to PostgreSQL"

class PostgreSQLQueryBuilder(QueryBuilder):
    def select_users(self):
        return "SELECT * FROM users LIMIT 10"

class PostgreSQLMigrationRunner(MigrationRunner):
    def migrate(self):
        return "Run PostgreSQL migration"

# Abstract Factory: Product를 생성함
class DatabaseFactory(ABC):
    @abstractmethod
    def create_connection(self) -> Connection:
        pass

    @abstractmethod
    def create_query_builder(self) -> QueryBuilder:
        pass

    @abstractmethod
    def create_migration_runner(self) -> MigrationRunner:
        pass

# Concrete Factory: 각 DB에 맞춰진 Concrete Product를 생성함
class MySQLFactory(DatabaseFactory):
    def create_connection(self) -> Connection:
        return MySQLConnection()

    def create_query_builder(self) -> QueryBuilder:
        return MySQLQueryBuilder()

    def create_migration_runner(self) -> MigrationRunner:
        return MySQLMigrationRunner()

class PostgreSQLFactory(DatabaseFactory):
    def create_connection(self) -> Connection:
        return PostgreSQLConnection()

    def create_query_builder(self) -> QueryBuilder:
        return PostgreSQLQueryBuilder()

    def create_migration_runner(self) -> MigrationRunner:
        return PostgreSQLMigrationRunner()
```

클라이언트 코드는 다음처럼 사용할 수 있다.

```python
class DataApplication:
    def __init__(self, factory: DatabaseFactory):
        self.connection = factory.create_connection()
        self.query_builder = factory.create_query_builder()
        self.migration_runner = factory.create_migration_runner()

    def start(self):
        print(self.connection.connect())
        print(self.migration_runner.migrate())
        print(self.query_builder.select_users())

app = DataApplication(PostgreSQLFactory())
app.start()
```

이제 `DataApplication`은 MySQL인지 PostgreSQL인지 몰라도 된다. `DataApplication`이 직접 의존하는 것은 다음뿐이다.
- `DatabaseFactory`
- `Connection`
- `QueryBuilder`
- `MigrationRunner`

`MySQLConnection`, `PostgreSQLConnection` 같은 구체 클래스에는 의존하지 않는다.  

DB를 바꾸고 싶으면 팩토리만 바꾸면 된다.
```python
app = DataApplication(MySQLFactory())
```
DB 구현체가 바뀌어도 `DataApplication`의 핵심 로직은 그대로 유지된다.

## 장점

1. **제품군 일관성 보장**
   - 같은 계열의 객체들이 함께 생성되므로 잘못된 조합을 줄일 수 있다.

2. **구체 클래스와 클라이언트 분리**
   - 클라이언트는 `WindowsButton`, `MacCheckbox` 같은 구체 클래스를 몰라도 된다.

3. **제품군 교체가 쉬움**
   - `WindowsFactory`를 `MacFactory`로 바꾸는 식으로 전체 객체 세트를 교체할 수 있다.

4. **개방-폐쇄 원칙(OCP) 준수**
   - 새로운 제품군을 추가할 때 기존 클라이언트 코드를 크게 수정하지 않아도 된다.

5. **테스트 용이성**
   - 테스트용 팩토리를 만들어 Mock 객체 세트를 주입할 수 있다.

## 단점

1. **구조가 복잡해진다**
   - 제품 인터페이스, 구체 제품, 추상 팩토리, 구체 팩토리가 모두 필요하다.

2. **새로운 제품 종류 추가가 번거롭다**
   - 예를 들어 `create_slider()`를 추가하면 모든 팩토리 구현체를 수정해야 한다.

3. **작은 프로젝트에는 과할 수 있다**
   - 제품군이 명확하지 않다면 단순한 Factory Method나 직접 생성이 더 낫다.

## 언제 사용해야 할까?

1. **관련 객체들을 세트로 생성해야 할 때**
   - 버튼, 체크박스, 텍스트박스처럼 같은 테마나 플랫폼에 속해야 하는 객체들

2. **제품군 전체를 런타임에 교체해야 할 때**
   - 설정에 따라 Windows UI, Mac UI, Web UI를 바꾸는 경우

3. **클라이언트가 구체 클래스를 몰라야 할 때**
   - 프레임워크나 라이브러리처럼 확장 가능성이 중요한 경우

4. **잘못된 객체 조합을 방지하고 싶을 때**
   - PostgreSQL 연결 객체와 MySQL 전용 쿼리 빌더가 섞이면 안 되는 경우

## Factory Method와 Abstract Factory 선택 기준

둘 중 무엇을 써야 할지 헷갈린다면 이렇게 생각하면 된다.

### 객체 하나만 만들면 된다

Factory Method가 적합하다.

```python
factory.create_document()
```

관심사는 하나다.

> 어떤 `Document`를 만들 것인가?

### 관련 객체 여러 개를 함께 만들어야 한다

Abstract Factory가 적합하다.

```python
factory.create_button()
factory.create_checkbox()
factory.create_textbox()
```

관심사는 제품군이다.

> 어떤 스타일의 UI 세트를 만들 것인가?

## 용어 정리

- **AbstractFactory (추상 팩토리)**: 관련 제품들을 생성하는 메서드들을 선언한 인터페이스
- **ConcreteFactory (구체 팩토리)**: 특정 제품군을 실제로 생성하는 클래스
- **AbstractProduct (추상 제품)**: 제품들이 따라야 하는 공통 인터페이스
- **ConcreteProduct (구체 제품)**: 특정 제품군에 속하는 실제 객체
- **Product Family (제품군)**: 서로 함께 사용되어야 하는 관련 객체들의 묶음

## 한 줄 요약

Factory Method가 **객체 하나의 생성을 캡슐화**한다면, Abstract Factory는 **관련 객체들의 세트 생성을 캡슐화**한다.

즉:

> Factory Method는 "무엇 하나를 만들까?"이고, Abstract Factory는 "어떤 계열의 세트를 만들까?"이다.

---

## 혼동하기 쉬운 팩토리 관련 용어 비교

### 1. 팩토리 (Factory)

가장 넓은 의미의 모호한 용어다. 함수, 메서드, 클래스 등 **무언가를 생성하는 모든 것**을 통칭한다. "팩토리"라는 단어만 봐서는 구체적인 의미를 알 수 없으니, 문맥을 파악해야 한다.

### 2. 생성 메서드 (Creation Method)

**객체를 생성해 반환하는 메서드**다. 생성자 호출을 감싸는 래퍼로, 의도를 더 명확히 표현하는 이름을 가질 수 있다.

```python
class Number:
    def __init__(self, value):
        self.value = value

    def next(self):          # 생성 메서드
        return Number(self.value + 1)
```

많은 사람이 이것을 "팩토리 메서드"라고 부르지만, 팩토리 메서드 패턴과는 다르다.

### 3. 정적 생성 메서드 (Static Creation Method)

**정적(static)으로 선언된 생성 메서드**다. 객체 없이 클래스에서 직접 호출할 수 있어 대체 생성자 역할을 한다.

```python
class User:
    def __init__(self, id, name, email):
        self.id = id
        self.name = name
        self.email = email

    @staticmethod
    def load(id):            # 정적 생성 메서드
        id, name, email = DB.load_data('users', id)
        return User(id, name, email)
```

"정적 팩토리 메서드"라고 부르는 사람도 있지만, `static`으로 선언되면 자식 클래스에서 오버라이드할 수 없으므로 팩토리 메서드 패턴이라고 부르기에는 적합하지 않다.

### 4. 단순 팩토리 (Simple Factory)

**하나의 메서드 안에 조건문을 두고 어떤 클래스를 인스턴스화할지 결정하는 패턴**이다.

```python
class UserFactory:
    @staticmethod
    def create(type_):
        if type_ == 'user':     return User()
        elif type_ == 'admin':  return Admin()
        else: raise ValueError(f"Unknown type: {type_}")
```

공식 GoF 패턴은 아니다. 팩토리 메서드나 추상 팩토리 패턴을 도입하기 전의 중간 단계로 자주 등장한다. 클래스에 `abstract`를 붙인다고 추상 팩토리 패턴이 되지는 않는다.

### 5. 팩토리 메서드 패턴 (Factory Method Pattern)

**객체 생성을 위한 인터페이스를 정의하되, 어떤 클래스를 만들지는 자식 클래스가 결정하도록 위임하는 패턴**이다. 상속을 기반으로 동작한다.

```python
class Department(ABC):
    @abstractmethod
    def create_employee(self, id): ...   # 팩토리 메서드

class ITDepartment(Department):
    def create_employee(self, id):
        return Programmer(id)

class AccountingDepartment(Department):
    def create_employee(self, id):
        return Accountant(id)
```

부모 클래스에 생성 메서드가 있고, 자식 클래스가 이를 오버라이드한다면 팩토리 메서드 패턴일 가능성이 높다.

### 6. 추상 팩토리 패턴 (Abstract Factory Pattern)

**서로 관련된 객체들의 제품군을 일관되게 생성하는 인터페이스를 제공하는 패턴**이다. 구체 클래스를 지정하지 않고 제품군 전체를 교체할 수 있다.

단 하나의 객체가 아닌 **여러 객체의 집합**을 생성해야 할 때 사용한다. 이 글의 본 내용이다.

---

### 요약 비교표

| 용어 | 형태 | 핵심 |
|---|---|---|
| 팩토리 | 모호한 통칭 | 무언가를 생성하는 것 |
| 생성 메서드 | 일반 메서드 | 객체를 만들어 반환 |
| 정적 생성 메서드 | static 메서드 | 객체 없이 호출, 대체 생성자 역할 |
| 단순 팩토리 | 조건문이 있는 static 메서드 | 타입에 따라 다른 객체 반환 |
| 팩토리 메서드 패턴 | 추상 메서드 + 상속 | 자식 클래스가 생성 타입 결정 |
| 추상 팩토리 패턴 | 인터페이스 + 제품군 | 관련 객체 세트를 일관되게 생성 |
