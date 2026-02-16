import FeLangRuntime
import Foundation
import Testing

@Suite("VTable Dispatch E2E Tests", .serialized)
struct VTableDispatchE2ETests {

    // MARK: - Basic Class Method via VTable

    @Test("Basic class method dispatch via vtable")
    func testBasicVTableDispatch() throws {
        let code = """
        class Animal
            name: 文字列
            Animal(n: 文字列)
                self.name ← n
            function speak(): 文字列
                return "..."
            endfunction
        endclass

        変数 a: Animal ← Animal("Tama")
        println(a.speak())
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "...")
    }

    // MARK: - Override Dispatch

    @Test("Subclass override dispatches to overridden method")
    func testOverrideDispatch() throws {
        let code = """
        class Animal
            name: 文字列
            Animal(n: 文字列)
                self.name ← n
            function speak(): 文字列
                return "..."
            endfunction
        endclass

        class Dog: Animal
            Dog(n: 文字列)
                self.name ← n
            override function speak(): 文字列
                return "Woof!"
            endfunction
        endclass

        変数 d: Dog ← Dog("Pochi")
        println(d.speak())
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "Woof!")
    }

    @Test("Superclass method still works when subclass overrides")
    func testSuperclassMethodUnchanged() throws {
        let code = """
        class Animal
            name: 文字列
            Animal(n: 文字列)
                self.name ← n
            function speak(): 文字列
                return "..."
            endfunction
        endclass

        class Dog: Animal
            Dog(n: 文字列)
                self.name ← n
            override function speak(): 文字列
                return "Woof!"
            endfunction
        endclass

        変数 a: Animal ← Animal("Generic")
        変数 d: Dog ← Dog("Pochi")
        println(a.speak())
        println(d.speak())
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(lines == ["...", "Woof!"])
    }

    @Test("Inherited method works without override")
    func testInheritedMethodWithoutOverride() throws {
        let code = """
        class Base
            value: 整数
            Base(v: 整数)
                self.value ← v
            function getValue(): 整数
                return self.value
            endfunction
        endclass

        class Child: Base
            Child(v: 整数)
                self.value ← v
        endclass

        変数 c: Child ← Child(42)
        println(c.getValue())
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "42")
    }

    @Test("Multi-level inheritance override chain")
    func testMultiLevelOverride() throws {
        let code = """
        class A
            A()
            function greet(): 文字列
                return "Hello A"
            endfunction
        endclass

        class B: A
            B()
            override function greet(): 文字列
                return "Hello B"
            endfunction
        endclass

        class C: B
            C()
            override function greet(): 文字列
                return "Hello C"
            endfunction
        endclass

        変数 a: A ← A()
        変数 b: B ← B()
        変数 c: C ← C()
        println(a.greet())
        println(b.greet())
        println(c.greet())
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(lines == ["Hello A", "Hello B", "Hello C"])
    }

    @Test("Subclass inherits parent method and adds new method")
    func testInheritAndAddNewMethod() throws {
        let code = """
        class Shape
            Shape()
            function kind(): 文字列
                return "shape"
            endfunction
        endclass

        class Circle: Shape
            radius: 整数
            Circle(r: 整数)
                self.radius ← r
            function area(): 整数
                return self.radius * self.radius
            endfunction
        endclass

        変数 c: Circle ← Circle(5)
        println(c.kind())
        println(c.area())
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(lines == ["shape", "25"])
    }

    // MARK: - Interface Dispatch

    @Test("Class implementing interface dispatches correctly")
    func testInterfaceImplementation() throws {
        let code = """
        interface Greetable
            function greet(): 文字列
        endinterface

        class Person implements Greetable
            name: 文字列
            Person(n: 文字列)
                self.name ← n
            function greet(): 文字列
                return concat("Hello, I am ", self.name)
            endfunction
        endclass

        変数 p: Person ← Person("Taro")
        println(p.greet())
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "Hello, I am Taro")
    }

    @Test("Class with inheritance and interface")
    func testInheritanceWithInterface() throws {
        let code = """
        interface Describable
            function describe(): 文字列
        endinterface

        class Animal
            name: 文字列
            Animal(n: 文字列)
                self.name ← n
            function describe(): 文字列
                return self.name
            endfunction
        endclass

        class Cat: Animal implements Describable
            Cat(n: 文字列)
                self.name ← n
            override function describe(): 文字列
                return concat("Cat: ", self.name)
            endfunction
        endclass

        変数 c: Cat ← Cat("Tama")
        println(c.describe())
        """
        let output = try InProcessTestHelper.run(code)
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "Cat: Tama")
    }

    @Test("Missing interface method causes error")
    func testMissingInterfaceMethodError() throws {
        let code = """
        interface Speakable
            function speak(): 文字列
        endinterface

        class Rock implements Speakable
            Rock()
        endclass
        """
        let result = InProcessTestHelper.execute(code)
        #expect(!result.succeeded)
    }

    // MARK: - Override with Parameters

    @Test("Override method with parameters")
    func testOverrideWithParameters() throws {
        let code = """
        class Calculator
            Calculator()
            function compute(x: 整数, y: 整数): 整数
                return x + y
            endfunction
        endclass

        class Multiplier: Calculator
            Multiplier()
            override function compute(x: 整数, y: 整数): 整数
                return x * y
            endfunction
        endclass

        変数 calc: Calculator ← Calculator()
        変数 mult: Multiplier ← Multiplier()
        println(calc.compute(3, 4))
        println(mult.compute(3, 4))
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(lines == ["7", "12"])
    }

    // MARK: - Interface with Multiple Methods

    @Test("Interface with multiple method signatures")
    func testInterfaceMultipleMethods() throws {
        let code = """
        interface Shape
            function area(): 整数
            function perimeter(): 整数
        endinterface

        class Square implements Shape
            side: 整数
            Square(s: 整数)
                self.side ← s
            function area(): 整数
                return self.side * self.side
            endfunction
            function perimeter(): 整数
                return self.side * 4
            endfunction
        endclass

        変数 sq: Square ← Square(5)
        println(sq.area())
        println(sq.perimeter())
        """
        let output = try InProcessTestHelper.run(code)
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        #expect(lines == ["25", "20"])
    }
}
