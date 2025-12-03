---
title: "Vibe Coding을 위한 디자인 패턴 - 전략패턴(Strategy)"
date: 2025-11-20T18:00:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "전략패턴", "Strategy"]
---
# Strategy Pattern (전략 패턴)

Strategy Pattern은 **알고리즘군을 정의하고 각각을 캡슐화하여 교환 가능하게 만드는** 디자인 패턴이다.
클라이언트는 알고리즘의 구체적인 구현과 독립적으로 **런타임에 알고리즘을 선택**할 수 있다.

예를 들어:
```python
class PaymentStrategy:
    def pay(self, amount): pass

class CreditCard(PaymentStrategy):
    def pay(self, amount): return f"Paid {amount} with Credit Card"

class PayPal(PaymentStrategy):
    def pay(self, amount): return f"Paid {amount} with PayPal"

class ShoppingCart:
    def __init__(self, strategy: PaymentStrategy):
        self.strategy = strategy
    
    def set_strategy(self, strategy: PaymentStrategy):
        self.strategy = strategy
    
    def checkout(self, amount):
        return self.strategy.pay(amount)

# 런타임에 전략 변경
cart = ShoppingCart(CreditCard())
print(cart.checkout(100))  # Paid 100 with Credit Card

cart.set_strategy(PayPal())
print(cart.checkout(200))  # Paid 200 with PayPal
```
→ `ShoppingCart`는 구체적인 결제 방식을 알 필요 없이, `PaymentStrategy` 인터페이스만 알면 된다.

## 의존성 역전 원칙 (Dependency Inversion Principle; DIP)

Strategy Pattern의 핵심은 **"구체적인 구현이 아닌 추상화에 의존"**하는 것이다.

**잘못된 예:**
```python
class ShoppingCart:
    def __init__(self, payment_type):
        self.payment_type = payment_type
    
    def checkout(self, amount):
        if self.payment_type == "credit":
            return f"Credit card: {amount}"
        elif self.payment_type == "paypal":
            return f"PayPal: {amount}"
        elif self.payment_type == "crypto":
            return f"Crypto: {amount}"
        # 새 결제 수단 추가시 이 메서드를 계속 수정해야 함!
```
→ 구체적인 결제 로직이 `ShoppingCart`에 강하게 결합되어 있어, 새로운 결제 수단 추가 시 기존 코드를 수정해야 한다.

**잘된 예:**
```python
class PaymentStrategy:
    def pay(self, amount): pass

class CreditCard(PaymentStrategy):
    def __init__(self, number, cvv):
        self.number, self.cvv = number, cvv
    def pay(self, amount): 
        return f"Credit {self.number}: {amount}"

class PayPal(PaymentStrategy):
    def __init__(self, email):
        self.email = email
    def pay(self, amount):
        return f"PayPal {self.email}: {amount}"

class ShoppingCart:
    def __init__(self, strategy: PaymentStrategy):
        self.strategy = strategy
    
    def checkout(self, amount):
        return self.strategy.pay(amount)  # 추상화에만 의존
```
→ `ShoppingCart`는 `PaymentStrategy` 추상 인터페이스에만 의존하고, 구체적인 결제 수단(`CreditCard`, `PayPal`)의 구현 세부사항을 알지 못한다.

## 컨텍스트-전략 분리 (Context-Strategy Decoupling)

Strategy Pattern의 중요한 특징은 **알고리즘의 사용(Context)과 구현(Strategy)을 분리**하는 것이다.

```python
# 컨텍스트: 알고리즘을 "사용"하는 객체
class DataCompressor:
    def __init__(self, strategy):
        self.strategy = strategy
    
    def compress_file(self, file):
        data = self.read_file(file)
        compressed = self.strategy.compress(data)  # 전략에 위임
        return compressed
    
    def read_file(self, file):
        return f"data from {file}"

# 전략: 알고리즘을 "구현"하는 객체들
class ZipStrategy:
    def compress(self, data): return f"Zipped: {data}"

class RarStrategy:
    def compress(self, data): return f"Rared: {data}"

class LzmaStrategy:
    def compress(self, data): return f"Lzma: {data}"

# 사용
compressor = DataCompressor(ZipStrategy())
result = compressor.compress_file("test.txt")

# 전략 교체
compressor.strategy = RarStrategy()
result = compressor.compress_file("test.txt")
```
→ `DataCompressor`는 파일 읽기 등의 공통 로직을 처리하고, 압축 알고리즘은 전략 객체에 위임한다.

## 상속 vs 구성 (Inheritance vs Composition)

Strategy Pattern은 **"상속보다 구성(Composition over Inheritance)"** 원칙의 좋은 예시다.

**상속을 사용한 잘못된 예:**
```python
class Sorter:
    def sort(self, data): pass

class BubbleSorter(Sorter):
    def sort(self, data): return "bubble sorted"

class QuickSorter(Sorter):
    def sort(self, data): return "quick sorted"

# 문제: 런타임에 정렬 방식을 변경할 수 없음
sorter = BubbleSorter()
sorter.sort([3, 1, 2])
# QuickSort로 바꾸려면? 새 객체를 생성해야 함!
```

**구성을 사용한 잘된 예:**
```python
class SortStrategy:
    def sort(self, data): pass

class BubbleSort(SortStrategy):
    def sort(self, data): return sorted(data)  # 간단 예시

class QuickSort(SortStrategy):
    def sort(self, data): return sorted(data, reverse=False)

class DataProcessor:
    def __init__(self, strategy: SortStrategy):
        self.strategy = strategy
    
    def set_strategy(self, strategy: SortStrategy):
        self.strategy = strategy
    
    def process(self, data):
        # 전처리
        cleaned = [x for x in data if x > 0]
        # 전략 실행
        sorted_data = self.strategy.sort(cleaned)
        # 후처리
        return sorted_data

# 런타임에 전략 교체 가능!
processor = DataProcessor(BubbleSort())
result = processor.process([3, -1, 2, 5])

processor.set_strategy(QuickSort())  # 같은 객체로 전략만 변경
result = processor.process([7, 2, 9])
```

## Strategy Pattern의 재귀적 특성?

Composite Pattern과 달리, Strategy Pattern은 **재귀적 구조를 가지지 않는다**. 대신:

- **단일 책임**: 각 전략은 하나의 알고리즘만 구현
- **수평적 관계**: 전략들은 계층 구조가 아닌 대등한 관계
- **교환 가능성**: 같은 인터페이스를 구현하므로 서로 교체 가능

```python
# Strategy는 서로를 포함하지 않음 (재귀 X)
class EncryptionStrategy:
    def encrypt(self, text): pass

class AES(EncryptionStrategy):
    def encrypt(self, text): return f"AES({text})"

class RSA(EncryptionStrategy):
    def encrypt(self, text): return f"RSA({text})"

# 전략들은 독립적이고 수평적
strategies = [AES(), RSA()]  # 서로를 포함하지 않음
```

**단, 전략을 조합하는 패턴은 가능:**
```python
class CompositeStrategy(EncryptionStrategy):
    def __init__(self, *strategies):
        self.strategies = strategies
    
    def encrypt(self, text):
        result = text
        for strategy in self.strategies:
            result = strategy.encrypt(result)
        return result

# 여러 전략을 순차적으로 적용
multi_encrypt = CompositeStrategy(AES(), RSA())
encrypted = multi_encrypt.encrypt("secret")  # RSA(AES(secret))
```

## Strategy Pattern은 다음과 같은 상황에서 유용하다:

1. **같은 작업을 다양한 방식으로 수행해야 할 때**
   - 정렬 알고리즘 (버블, 퀵, 머지 등)
   - 압축 방식 (ZIP, RAR, 7z 등)
   - 결제 수단 (카드, 페이팔, 암호화폐 등)

2. **런타임에 알고리즘을 선택/변경해야 할 때**
   - 사용자 설정에 따른 동작 변경
   - 데이터 크기에 따른 최적 알고리즘 선택
   - A/B 테스트

3. **복잡한 조건문을 제거하고 싶을 때**
   - 많은 `if-elif-else` 분기를 전략 객체로 대체
   - 코드 가독성과 유지보수성 향상

## 용어 정리

**Strategy (전략 인터페이스)**: 모든 구체적 전략이 구현해야 하는 공통 인터페이스  
**ConcreteStrategy (구체적 전략)**: 실제 알고리즘을 구현하는 클래스들  
**Context (컨텍스트)**: 전략을 사용하는 객체, 전략 객체를 참조하고 필요시 교체

1. 결제 시스템 예시:
   - Strategy → PaymentStrategy
   - ConcreteStrategy → CreditCard, PayPal, Crypto
   - Context → ShoppingCart

2. 압축 시스템 예시:
   - Strategy → CompressionStrategy
   - ConcreteStrategy → ZipStrategy, RarStrategy, LzmaStrategy
   - Context → DataCompressor