---
title: "Vibe Coding을 위한 디자인 패턴 - 팩토리(Factory)"
date: 2025-09-27T16:55:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "팩토리", "Factory"]
---

Factory Method Pattern은 객체 생성을 위한 인터페이스를 정의하되, 어떤 클래스의 인스턴스를 생성할지는 서브클래스가 결정하도록 하는 생성 디자인 패턴이다.
클라이언트 코드가 **구체적인 클래스를 알 필요 없이** 객체를 생성할 수 있다.

## 의존성 역전 원칙 (Dependency Inversion Principle)

DIP는 "고수준 모듈은 저수준 모듈에 의존해서는 안 되며, 둘 다 추상화에 의존해야 한다"는 원칙이다.

**문제가 있는 예시:**
```python
class Application:
    def create_document(self, doc_type):
        if doc_type == "pdf":
            return PDFDocument()
        elif doc_type == "word":
            return WordDocument()
        elif doc_type == "excel":
            return ExcelDocument()
        # 새로운 문서 타입 추가시 이 메서드를 수정해야 함
```

위 코드의 문제점:
1. `Application` 클래스가 모든 문서 타입을 알고 있어야 함
2. 새로운 문서 타입 추가 시 기존 코드 수정 필요 (개방-폐쇄 원칙 위반)
3. 클라이언트가 구체적인 클래스에 의존 (의존관계 역전 원칙 위반; `PDFDocument`, `WordDocument`, ... 에 의존하고 있다.)

**Factory Method를 적용한 예시:**
```python
from abc import ABC, abstractmethod

# 제품 인터페이스
class Document(ABC):
    @abstractmethod
    def open(self): pass
    
    @abstractmethod
    def save(self): pass

# 구체적인 제품들
class PDFDocument(Document):
    def open(self): 
        "... PDF를 위한 구현 ..."
        return "Opening PDF document"
    def save(self): 
        "... PDF를 위한 구현 ..."
        return "Saving PDF document"

class WordDocument(Document):
    def open(self): 
        "... Word를 위한 구현 ..."
        return "Opening Word document"
    def save(self): 
        "... Word를 위한 구현 ..."
        return "Saving Word document"

# Creator 추상 클래스
class Application(ABC):
    @abstractmethod
    def create_document(self) -> Document:
        "PDF이든 Word이든 상관 없이 Document로 접근"
        pass  # Factory Method
    
    def new_document(self):
        # 객체 생성과 사용의 분리
        doc = self.create_document()
        print(doc.open())
        return doc

# Concrete Creator들
class PDFApplication(Application):
    def create_document(self) -> Document:
        return PDFDocument()

class WordApplication(Application):
    def create_document(self) -> Document:
        return WordDocument()
```

이제 클라이언트는 구체적인 문서 타입을 몰라도 된다.(PDF든 Word든 `Document` 클래스를 상속했으니까) :
```python
def client_code(app: Application):
    doc = app.new_document()  # 어떤 타입의 문서인지 몰라도 됨
    doc.save()

# 사용
pdf_app = PDFApplication()
word_app = WordApplication()
client_code(pdf_app)   # PDF 문서 생성
client_code(word_app)  # Word 문서 생성
```

중요하니까 예제를 하나 더 보자..!

**DIP 위반 예시:**
```python
class EmailService:
    def send(self, message): 
        print(f"Sending email: {message}")

class SMSService:
    def send(self, message): 
        print(f"Sending SMS: {message}")

class NotificationManager:
    def __init__(self):
        self.email_service = EmailService()  # 구체 클래스에 직접 의존
        self.sms_service = SMSService()      # 구체 클래스에 직접 의존
    
    def notify(self, channel, message):
        if channel == "email":
            self.email_service.send(message)
        elif channel == "sms":
            self.sms_service.send(message)
```
→ `NotificationManager`가 구체적인 서비스 클래스들을 직접 알고 있어야 한다!

**Factory Method + DIP 적용:**
```python
# 추상화 (인터페이스)
class NotificationService(ABC):
    @abstractmethod
    def send(self, message): pass

# 구체 구현
class EmailService(NotificationService):
    def send(self, message): 
        return f"Email sent: {message}"

class SMSService(NotificationService):
    def send(self, message): 
        return f"SMS sent: {message}"

class PushService(NotificationService):
    def send(self, message): 
        return f"Push notification: {message}"

# Factory Method를 가진 추상 클래스
class NotificationFactory(ABC):
    @abstractmethod
    def create_service(self) -> NotificationService:
        pass
    
    def notify(self, message):
        service = self.create_service()  # 팩토리 메서드 호출
        return service.send(message)

# 구체적인 Factory들
class EmailFactory(NotificationFactory):
    def create_service(self) -> NotificationService:
        return EmailService()

class SMSFactory(NotificationFactory):
    def create_service(self) -> NotificationService:
        return SMSService()

class PushFactory(NotificationFactory):
    def create_service(self) -> NotificationService:
        return PushService()
```

이제 고수준 모듈인 `NotificationFactory`는 저수준 모듈인 구체 서비스들에 의존하지 않고, 모두 `NotificationService` 추상화에 의존한다!

## 객체 생성과 사용의 분리

Factory Method의 핵심은 **객체를 생성하는 코드**와 **객체를 사용하는 코드**를 분리하는 것이다.

**분리되지 않은 예시:**
```python
class GameManager:
    def start_game(self, difficulty):
        # 객체 생성과 사용이 섞여있음
        if difficulty == "easy":
            enemy = Enemy(health=50, damage=10)     # 생성
            enemy.attack()      # 사용
        elif difficulty == "hard":
            enemy = Enemy(health=200, damage=50)    # 생성
            enemy.attack()      # 사용
        elif difficulty == "nightmare":
            enemy = Boss(health=500, damage=100, special_ability="fire")    # 생성
            enemy.attack()      # 사용
            enemy.use_special() # 사용
```

**Factory Method로 분리한 예시:**
```python
class Character(ABC):
    @abstractmethod
    def attack(self): pass

class Enemy(Character):
    def __init__(self, health, damage):
        self.health, self.damage = health, damage
    def attack(self): 
        return f"Enemy attacks for {self.damage} damage"

class Boss(Character):
    def __init__(self, health, damage, ability):
        self.health, self.damage, self.ability = health, damage, ability
    def attack(self): 
        return f"Boss attacks for {self.damage} damage"
    def special_attack(self): 
        return f"Boss uses {self.ability}!"

# 생성 로직 분리
class GameLevel(ABC):
    @abstractmethod
    def create_enemy(self) -> Character:
        pass  # Factory Method
    
    def start_battle(self):  # <- `사용` 로직
        enemy = self.create_enemy()
        print(f"Battle started!")
        print(enemy.attack())
        if hasattr(enemy, 'special_attack'):
            print(enemy.special_attack())

class EasyLevel(GameLevel):     # <- `생성` 로직
    def create_enemy(self) -> Character:
        return Enemy(health=50, damage=10)

class HardLevel(GameLevel):     # <- `생성` 로직
    def create_enemy(self) -> Character:
        return Enemy(health=200, damage=50)

class NightmareLevel(GameLevel):# <- `생성` 로직
    def create_enemy(self) -> Character:
        return Boss(health=500, damage=100, ability="fire breath")
```

## 다형성 (Polymorphism) 활용

"같은 인터페이스로 다른 구현체들을 동일하게 다룰 수 있는 능력"을 다형성이라고 한다.  
Factory Method는 다형성을 최대한 활용하여 코드의 유연성을 높인다.

```python
# 데이터베이스 연결 예시
class DatabaseConnection(ABC):      # 같은 인터페이스
    @abstractmethod
    def connect(self): pass
    
    @abstractmethod
    def execute(self, query): pass

class MySQLConnection(DatabaseConnection):      # 다른 구현체 1
    def connect(self): 
        return "Connected to MySQL"
    def execute(self, query): 
        return f"MySQL executing: {query}"

class PostgreSQLConnection(DatabaseConnection): # 다른 구현체 2
    def connect(self): 
        return "Connected to PostgreSQL"
    def execute(self, query): 
        return f"PostgreSQL executing: {query}"

class MongoDBConnection(DatabaseConnection):    # 다른 구현체 3
    def connect(self): 
        return "Connected to MongoDB"
    def execute(self, query): 
        return f"MongoDB executing: {query}"

# Factory Method 패턴
class DatabaseFactory(ABC):
    @abstractmethod
    def create_connection(self) -> DatabaseConnection:
        pass
    
    def run_query(self, query):
        # 다형성 활용: 어떤 DB인지 몰라도 동일한 인터페이스 사용
        db = self.create_connection()
        print(db.connect())
        return db.execute(query)

class MySQLFactory(DatabaseFactory):
    def create_connection(self) -> DatabaseConnection:
        return MySQLConnection()

class PostgreSQLFactory(DatabaseFactory):
    def create_connection(self) -> DatabaseConnection:
        return PostgreSQLConnection()

class MongoDBFactory(DatabaseFactory):
    def create_connection(self) -> DatabaseConnection:
        return MongoDBConnection()

# 클라이언트 코드
def process_data(factory: DatabaseFactory):
    # 다형성: factory가 어떤 구체 타입인지 몰라도 됨
    result = factory.run_query("SELECT * FROM users")
    print(result)

# 런타임에 결정
config = {"db_type": "mysql"}  # 설정 파일에서 읽어온다고 가정

if config["db_type"] == "mysql":
    factory = MySQLFactory()
elif config["db_type"] == "postgres":
    factory = PostgreSQLFactory()
else:
    factory = MongoDBFactory()

process_data(factory)  # 동일한 인터페이스로 처리
```

## Factory Method Pattern의 장점

1. **단일 책임 원칙(SRP) 준수**: 객체 생성 코드를 한 곳으로 분리
2. **개방-폐쇄 원칙(OCP) 준수**: 새로운 제품 타입 추가 시 기존 코드 수정 불필요
3. **의존성 역전 원칙(DIP) 준수**: 구체 클래스가 아닌 추상화에 의존
4. **유연성**: 런타임에 객체 타입 결정 가능
5. **테스트 용이성**: Mock 객체 생성이 쉬워짐

## 언제 사용해야 할까?

1. **객체 생성 로직이 복잡할 때**
   - 설정이 많거나 초기화 과정이 복잡한 경우
   
2. **제품군이 확장 가능해야 할 때**
   - 새로운 타입의 객체가 추가될 가능성이 있는 경우
   
3. **객체 생성을 서브클래스에 위임하고 싶을 때**
   - 프레임워크 설계 시 유용

4. **테스트를 위한 Mock 객체가 필요할 때**
   - 실제 객체 대신 테스트용 객체를 쉽게 주입 가능

## 용어 정리

- **Product (제품)**: Factory Method가 생성하는 객체들의 공통 인터페이스
- **ConcreteProduct (구체 제품)**: Product 인터페이스를 구현한 실제 객체
- **Creator (생성자)**: Factory Method를 선언한 추상 클래스
- **ConcreteCreator (구체 생성자)**: Factory Method를 구현하여 실제 객체를 생성하는 클래스
