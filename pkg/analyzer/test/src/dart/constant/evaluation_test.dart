// Copyright (c) 2016, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/error/syntactic_errors.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../generated/test_support.dart';
import '../resolution/context_collection_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ConstantVisitorTest);
    defineReflectiveTests(ConstantVisitorWithoutNullSafetyTest);
    defineReflectiveTests(InstanceCreationEvaluatorTest);
    defineReflectiveTests(InstanceCreationEvaluatorWithoutNullSafetyTest);
  });
}

@reflectiveTest
class ConstantVisitorTest extends ConstantVisitorTestSupport
    with ConstantVisitorTestCases {
  test_declaration_staticError_notAssignable() async {
    await assertErrorsInCode('''
const int x = 'foo';
''', [
      error(CompileTimeErrorCode.INVALID_ASSIGNMENT, 14, 5),
    ]);
  }

  test_equalEqual_double_object() async {
    await assertNoErrorsInCode('''
const v = 1.2 == Object();
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_int_int_false() async {
    await assertNoErrorsInCode('''
const v = 1 == 2;
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_int_int_true() async {
    await assertNoErrorsInCode('''
const v = 1 == 1;
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool true
''');
  }

  test_equalEqual_int_null() async {
    await assertNoErrorsInCode('''
const int? a = 1;
const v = a == null;
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_int_object() async {
    await assertNoErrorsInCode('''
const v = 1 == Object();
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_int_userClass() async {
    await assertNoErrorsInCode('''
class A {
  const A();
}

const v = 1 == A();
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_null_object() async {
    await assertNoErrorsInCode('''
const Object? a = null;
const v = a == Object();
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_string_object() async {
    await assertNoErrorsInCode('''
const v = 'foo' == Object();
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_userClass_hasEqEq() async {
    await assertErrorsInCode('''
class A {
  const A();
  bool operator ==(other) => false;
}

const v = A() == 0;
''', [
      error(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING, 72, 8),
    ]);
    // TODO(scheglov) check the invalid value
  }

  test_equalEqual_userClass_hasHashCode() async {
    await assertErrorsInCode('''
class A {
  const A();
  int get hashCode => 0;
}

const v = A() == 0;
''', [
      error(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING, 61, 8),
    ]);
    // TODO(scheglov) check the invalid value
  }

  test_equalEqual_userClass_hasPrimitiveEquality_false() async {
    await assertNoErrorsInCode('''
class A {
  final int f;
  const A(this.f);
}

const v = A(0) == 0;
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool false
''');
  }

  test_equalEqual_userClass_hasPrimitiveEquality_language219() async {
    await assertErrorsInCode('''
// @dart = 2.19
class A {
  const A();
}

const v = A() == 0;
''', [
      error(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING, 52, 8),
    ]);
    _evaluateConstantOrNull('v', errorCodes: [
      CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING,
    ]);
  }

  test_equalEqual_userClass_hasPrimitiveEquality_true() async {
    await assertNoErrorsInCode('''
class A {
  final int f;
  const A(this.f);
}

const v = A(0) == A(0);
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
bool true
''');
  }

  test_hasPrimitiveEquality_bool() async {
    await assertNoErrorsInCode('''
const v = true;
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_class_hasEqEq() async {
    await assertNoErrorsInCode('''
const v = const A();

class A {
  const A();
  bool operator ==(other) => false;
}
''');
    _assertHasPrimitiveEqualityFalse('v');
  }

  test_hasPrimitiveEquality_class_hasEqEq_language219() async {
    await assertNoErrorsInCode('''
// @dart = 2.19
const v = const A();

class A {
  const A();
  bool operator ==(other) => false;
}
''');
    _assertHasPrimitiveEqualityFalse('v');
  }

  test_hasPrimitiveEquality_class_hasHashCode() async {
    await assertNoErrorsInCode('''
const v = const A();

class A {
  const A();
  int get hashCode => 0;
}
''');
    _assertHasPrimitiveEqualityFalse('v');
  }

  test_hasPrimitiveEquality_class_hasHashCode_language219() async {
    await assertNoErrorsInCode('''
// @dart = 2.19
const v = const A();

class A {
  const A();
  int get hashCode => 0;
}
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_class_hasNone() async {
    await assertNoErrorsInCode('''
const v = const A();

class A {
  const A();
}
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_double() async {
    await assertNoErrorsInCode('''
const v = 1.2;
''');
    _assertHasPrimitiveEqualityFalse('v');
  }

  test_hasPrimitiveEquality_functionReference_staticMethod() async {
    await assertNoErrorsInCode('''
const v = A.foo;

class A {
  static void foo() {}
}
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_functionReference_topLevelFunction() async {
    await assertNoErrorsInCode('''
const v = foo;

void foo() {}
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_int() async {
    await assertNoErrorsInCode('''
const v = 0;
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_list() async {
    await assertNoErrorsInCode('''
const v = const [0];
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_map() async {
    await assertNoErrorsInCode('''
const v = const <int, String>{0: ''};
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_null() async {
    await assertNoErrorsInCode('''
const v = null;
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_record_named_false() async {
    await assertNoErrorsInCode('''
const v = (f1: true, f2: 1.2);
''');
    _assertHasPrimitiveEqualityFalse('v');
  }

  test_hasPrimitiveEquality_record_named_true() async {
    await assertNoErrorsInCode('''
const v = (f1: true, f2: 0);
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_record_positional_false() async {
    await assertNoErrorsInCode('''
const v = (true, 1.2);
''');
    _assertHasPrimitiveEqualityFalse('v');
  }

  test_hasPrimitiveEquality_record_positional_true() async {
    await assertNoErrorsInCode('''
const v = (true, 0);
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_set() async {
    await assertNoErrorsInCode('''
const v = const {0};
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_symbol() async {
    await assertNoErrorsInCode('''
const v = #foo.bar;
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_hasPrimitiveEquality_type() async {
    await assertNoErrorsInCode('''
const v = int;
''');
    _assertHasPrimitiveEqualityTrue('v');
  }

  test_identical_typeLiteral_explicitTypeArgs_differentTypeArgs() async {
    await resolveTestCode('''
class C<T> {}
const c = identical(C<int>, C<String>);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(false),
    );
  }

  test_identical_typeLiteral_explicitTypeArgs_differentTypes() async {
    await resolveTestCode('''
class C<T> {}
class D<T> {}
const c = identical(C<int>, D<int>);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(false),
    );
  }

  test_identical_typeLiteral_explicitTypeArgs_sameType() async {
    await resolveTestCode('''
class C<T> {}
const c = identical(C<int>, C<int>);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(true),
    );
  }

  test_identical_typeLiteral_explicitTypeArgs_simpleTypeAlias() async {
    await resolveTestCode('''
class C<T> {}
typedef TC = C<int>;
const c = identical(C<int>, TC);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(true),
    );
  }

  test_identical_typeLiteral_explicitTypeArgs_typeAlias() async {
    await resolveTestCode('''
class C<T> {}
typedef TC<T> = C<T>;
const c = identical(C<int>, TC<int>);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(true),
    );
  }

  test_identical_typeLiteral_explicitTypeArgs_typeAlias_differentTypeArgs() async {
    await resolveTestCode('''
class C<T> {}
typedef TC<T> = C<T>;
const c = identical(C<int>, TC<String>);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(false),
    );
  }

  test_identical_typeLiteral_explicitTypeArgs_typeAlias_implicitTypeArgs() async {
    await resolveTestCode('''
class C<T> {}
typedef TC<T> = C<T>;
const c = identical(C<dynamic>, TC);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(true),
    );
  }

  test_identical_typeLiteral_explicitTypeArgs_typeAlias_implicitTypeArgs_bound() async {
    await resolveTestCode('''
class C<T extends num> {}
typedef TC<T extends num> = C<T>;
const c = identical(C<num>, TC);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(true),
    );
  }

  test_identical_typeLiteral_simple_differentTypes() async {
    await resolveTestCode('''
const c = identical(int, String);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(false),
    );
  }

  test_identical_typeLiteral_simple_sameType() async {
    await resolveTestCode('''
const c = identical(int, int);
''');
    expect(
      _evaluateConstant('c'),
      _boolValue(true),
    );
  }

  test_visitBinaryExpression_extensionMethod() async {
    await assertErrorsInCode('''
extension on Object {
  int operator +(Object other) => 0;
}

const Object v1 = 0;
const v2 = v1 + v1;
''', [
      error(CompileTimeErrorCode.CONST_EVAL_EXTENSION_METHOD, 94, 7),
    ]);
    _assertNull('v2');
  }

  test_visitBinaryExpression_gtGtGt_negative_fewerBits() async {
    await resolveTestCode('''
const c = 0xFFFFFFFF >>> 8;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0xFFFFFF);
  }

  test_visitBinaryExpression_gtGtGt_negative_moreBits() async {
    await resolveTestCode('''
const c = 0xFFFFFFFF >>> 33;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0);
  }

  test_visitBinaryExpression_gtGtGt_negative_moreThan64Bits() async {
    await resolveTestCode('''
const c = 0xFFFFFFFF >>> 65;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0);
  }

  test_visitBinaryExpression_gtGtGt_negative_negativeBits() async {
    await resolveTestCode('''
const c = 0xFFFFFFFF >>> -2;
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION]);
  }

  test_visitBinaryExpression_gtGtGt_negative_zeroBits() async {
    await resolveTestCode('''
const c = 0xFFFFFFFF >>> 0;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0xFFFFFFFF);
  }

  test_visitBinaryExpression_gtGtGt_positive_fewerBits() async {
    await resolveTestCode('''
const c = 0xFF >>> 3;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0x1F);
  }

  test_visitBinaryExpression_gtGtGt_positive_moreBits() async {
    await resolveTestCode('''
const c = 0xFF >>> 9;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0);
  }

  test_visitBinaryExpression_gtGtGt_positive_moreThan64Bits() async {
    await resolveTestCode('''
const c = 0xFF >>> 65;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0);
  }

  test_visitBinaryExpression_gtGtGt_positive_negativeBits() async {
    await resolveTestCode('''
const c = 0xFF >>> -2;
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION]);
  }

  test_visitBinaryExpression_gtGtGt_positive_zeroBits() async {
    await resolveTestCode('''
const c = 0xFF >>> 0;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0xFF);
  }

  test_visitConditionalExpression_instantiatedFunctionType_variable() async {
    await resolveTestCode('''
void f<T>(T p, {T? q}) {}

const void Function<T>(T p) g = f;

const bool b = false;
const void Function(int p) h = b ? g : g;
''');
    var result = _evaluateConstant('h');
    assertType(result.type, 'void Function(int, {int? q})');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitConditionalExpression_unknownCondition() async {
    await assertNoErrorsInCode('''
const bool kIsWeb = identical(0, 0.0);
const x = kIsWeb ? 0 : 1;
''');
    _assertValue('x', r'''
int <unknown>
  variable: self::@variable::x
''');
  }

  test_visitConditionalExpression_unknownCondition_errorInConstructor() async {
    await assertErrorsInCode(r'''
const bool kIsWeb = identical(0, 0.0);

var a = 2;
const x = A(kIsWeb ? 0 : a);

class A {
  const A(int _);
}
''', [
      error(CompileTimeErrorCode.CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH, 63, 14),
      error(CompileTimeErrorCode.INVALID_CONSTANT, 76, 1),
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 76,
          1),
    ]);
    _assertValue('x', r'''
A
  variable: self::@variable::x
''');
  }

  test_visitConditionalExpression_unknownCondition_undefinedIdentifier() async {
    await assertErrorsInCode(r'''
const bool kIsWeb = identical(0, 0.0);
const x = kIsWeb ? a : b;
''', [
      error(CompileTimeErrorCode.UNDEFINED_IDENTIFIER, 58, 1),
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 58,
          1),
      error(CompileTimeErrorCode.UNDEFINED_IDENTIFIER, 62, 1),
    ]);
    _assertNull('x');
  }

  test_visitConstructorDeclaration_field_asExpression_nonConst() async {
    await assertErrorsInCode(r'''
dynamic y = 2;
class A {
  const A();
  final x = y as num;
}
''', [
      error(
          CompileTimeErrorCode
              .CONST_CONSTRUCTOR_WITH_FIELD_INITIALIZED_BY_NON_CONST,
          27,
          5),
    ]);
  }

  test_visitConstructorReference_identical_aliasIsNotGeneric() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC = C<int>;
const a = identical(MyC.new, C<int>.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsNotProperRename_differentBound() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC<T extends num> = C<T>;
const a = identical(MyC.new, C.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsNotProperRename_differentCount() async {
    await assertNoErrorsInCode('''
class C<T, U> {}
typedef MyC<T> = C<T, int>;
const a = identical(MyC.new, C.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsNotProperRename_differentCount2() async {
    await assertNoErrorsInCode('''
class C<T, U> {}
typedef MyC<T> = C;
const a = identical(MyC.new, C.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsNotProperRename_differentOrder() async {
    await assertNoErrorsInCode('''
class C<T, U> {}
typedef MyC<T, U> = C<U, T>;
const a = identical(MyC.new, C.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsNotProperRename_instantiated() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC<T extends num> = C<T>;
const a = identical(MyC<int>.new, C<int>.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsNotProperRename_mixedInstantiations() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC<T extends num> = C<T>;
const a = identical(MyC<int>.new, (MyC.new)<int>);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsProperRename_instantiated() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC<T> = C<T>;
const a = identical(MyC<int>.new, MyC<int>.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsProperRename_mixedInstantiations() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC<T> = C<T>;
const a = identical(MyC<int>.new, (MyC.new)<int>);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsProperRename_mutualSubtypes_dynamic() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC<T extends Object?> = C<T>;
const a = identical(MyC<int>.new, MyC<int>.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsProperRename_mutualSubtypes_futureOr() async {
    await assertNoErrorsInCode('''
import 'dart:async';
class C<T extends FutureOr<num>> {}
typedef MyC<T extends num> = C<T>;
const a = identical(MyC<int>.new, MyC<int>.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_aliasIsProperRename_uninstantiated() async {
    await assertNoErrorsInCode('''
class C<T> {}
typedef MyC<T> = C<T>;
const a = identical(MyC.new, MyC.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_explicitTypeArgs_differentClasses() async {
    await assertNoErrorsInCode('''
class C<T> {}
class D<T> {}
const a = identical(C<int>.new, D<int>.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_explicitTypeArgs_differentConstructors() async {
    await assertNoErrorsInCode('''
class C<T> {
  C();
  C.named();
}
const a = identical(C<int>.new, C<int>.named);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_explicitTypeArgs_differentTypeArgs() async {
    await assertNoErrorsInCode('''
class C<T> {}
const a = identical(C<int>.new, C<String>.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_explicitTypeArgs_sameElement() async {
    await assertNoErrorsInCode('''
class C<T> {}
const a = identical(C<int>.new, C<int>.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_inferredTypeArgs_sameElement() async {
    await assertNoErrorsInCode('''
class C<T> {}
const C<int> Function() c1 = C.new;
const c2 = C<int>.new;
const a = identical(c1, c2);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_notInstantiated_differentClasses() async {
    await assertNoErrorsInCode('''
class C<T> {}
class D<T> {}
const a = identical(C.new, D.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_notInstantiated_differentConstructors() async {
    await assertNoErrorsInCode('''
class C<T> {
  C();
  C.named();
}
const a = identical(C.new, C.named);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_notInstantiated_sameElement() async {
    await assertNoErrorsInCode('''
class C<T> {}
const a = identical(C.new, C.new);
''');
    _assertValue('a', r'''
bool true
  variable: self::@variable::a
''');
  }

  test_visitConstructorReference_identical_onlyOneHasTypeArgs() async {
    await assertNoErrorsInCode('''
class C<T> {}
const a = identical(C<int>.new, C.new);
''');
    _assertValue('a', r'''
bool false
  variable: self::@variable::a
''');
  }

  test_visitFunctionReference_defaultConstructorValue() async {
    await assertErrorsInCode(r'''
void f<T>(T t) => t;

class C<T> {
  final void Function(T) p;
  const C({this.p = f});
}
''', [
      error(CompileTimeErrorCode.NON_CONSTANT_DEFAULT_VALUE, 83, 1),
    ]);
  }

  test_visitFunctionReference_explicitTypeArgs_complexExpression() async {
    await assertNoErrorsInCode(r'''
const b = true;
void foo<T>(T a) {}
void bar<T>(T a) {}
const g = (b ? foo : bar)<int>;
''');
    _assertValue('g', r'''
void Function(int)
  element: self::@function::foo
  typeArguments
    int
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_complexExpression_differentTypes() async {
    await assertNoErrorsInCode(r'''
const b = true;
void foo<T>(String a, T b) {}
void bar<T>(T a, String b) {}
const g = (b ? foo : bar)<int>;
''');
    _assertValue('g', r'''
void Function(String, int)
  element: self::@function::foo
  typeArguments
    int
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_functionName_constantType() async {
    await assertNoErrorsInCode(r'''
void f<T>(T a) {}
const g = f<int>;
''');
    _assertValue('g', r'''
void Function(int)
  element: self::@function::f
  typeArguments
    int
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_functionName_notMatchingBound() async {
    await assertErrorsInCode(r'''
void f<T extends num>(T a) {}
const g = f<String>;
''', [
      error(CompileTimeErrorCode.TYPE_ARGUMENT_NOT_MATCHING_BOUNDS, 42, 6),
    ]);
    _assertValue('g', r'''
void Function(String)
  element: self::@function::f
  typeArguments
    String
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_functionName_notType() async {
    await assertErrorsInCode(r'''
void foo<T>(T a) {}
const g = foo<true>;
''', [
      error(CompileTimeErrorCode.CONST_EVAL_TYPE_NUM, 30, 8),
      error(CompileTimeErrorCode.UNDEFINED_OPERATOR, 33, 1),
      error(ParserErrorCode.EQUALITY_CANNOT_BE_EQUALITY_OPERAND, 38, 1),
      error(ParserErrorCode.MISSING_IDENTIFIER, 39, 1),
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 39,
          0),
    ]);
    _assertNull('g');
  }

  test_visitFunctionReference_explicitTypeArgs_functionName_tooFew() async {
    await assertErrorsInCode(r'''
void foo<T, U>(T a, U b) {}
const g = foo<int>;
''', [
      error(
          CompileTimeErrorCode.WRONG_NUMBER_OF_TYPE_ARGUMENTS_FUNCTION, 41, 5),
    ]);
    _assertNull('g');
  }

  test_visitFunctionReference_explicitTypeArgs_functionName_tooMany() async {
    await assertErrorsInCode(r'''
void foo<T>(T a) {}
const g = foo<int, String>;
''', [
      error(
          CompileTimeErrorCode.WRONG_NUMBER_OF_TYPE_ARGUMENTS_FUNCTION, 33, 13),
    ]);
    _assertNull('g');
  }

  test_visitFunctionReference_explicitTypeArgs_functionName_typeParameter() async {
    await assertErrorsInCode(r'''
void f<T>(T a) {}

class C<U> {
  void m() {
    const g = f<U>;
  }
}
''', [
      error(WarningCode.UNUSED_LOCAL_VARIABLE, 55, 1),
      error(CompileTimeErrorCode.CONST_WITH_TYPE_PARAMETERS_FUNCTION_TEAROFF,
          61, 1),
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 61,
          1),
    ]);
  }

  test_visitFunctionReference_explicitTypeArgs_identical_differentElements() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
void bar<T>(T a) {}
const g = identical(foo<int>, bar<int>);
''');
    _assertValue('g', r'''
bool false
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_identical_differentTypeArgs() async {
    await resolveTestCode(r'''
void foo<T>(T a) {}
const g = identical(foo<int>, foo<String>);
''');
    _assertValue('g', r'''
bool false
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_identical_onlyOneHasTypeArgs() async {
    await resolveTestCode(r'''
void foo<T>(T a) {}
const g = identical(foo<int>, foo);
''');
    _assertValue('g', r'''
bool false
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_identical_sameElement() async {
    await resolveTestCode(r'''
void foo<T>(T a) {}
const g = identical(foo<int>, foo<int>);
''');
    _assertValue('g', r'''
bool true
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_explicitTypeArgs_identical_sameElement_runtimeTypeEquality() async {
    await resolveTestCode(r'''
import 'dart:async';
void foo<T>(T a) {}
const g = identical(foo<Object>, foo<FutureOr<Object>>);
''');
    _assertValue('g', r'''
bool true
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_identical_explicitTypeArgs_differentElements() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
void bar<T>(T a) {}
const g = identical(foo<int>, bar<int>);
''');
    _assertValue('g', r'''
bool false
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_identical_explicitTypeArgs_differentTypeArgs() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
const g = identical(foo<int>, foo<String>);
''');
    _assertValue('g', r'''
bool false
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_identical_explicitTypeArgs_onlyOneHasTypeArgs() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
const g = identical(foo<int>, foo);
''');
    _assertValue('g', r'''
bool false
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_identical_explicitTypeArgs_sameElement() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
const g = identical(foo<int>, foo<int>);
''');
    _assertValue('g', r'''
bool true
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_identical_explicitTypeArgs_sameElement_runtimeTypeEquality() async {
    await assertNoErrorsInCode(r'''
import 'dart:async';
void foo<T>(T a) {}
const g = identical(foo<Object>, foo<FutureOr<Object>>);
''');
    _assertValue('g', r'''
bool true
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_identical_implicitTypeArgs_differentTypes() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
const void Function(int) f = foo;
const void Function(String) g = foo;
const c = identical(f, g);
''');
    _assertValue('c', r'''
bool false
  variable: self::@variable::c
''');
  }

  test_visitFunctionReference_identical_implicitTypeArgs_sameTypes() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
const void Function(int) f = foo;
const void Function(int) g = foo;
const c = identical(f, g);
''');
    _assertValue('c', r'''
bool true
  variable: self::@variable::c
''');
  }

  test_visitFunctionReference_identical_uninstantiated_sameElement() async {
    await assertNoErrorsInCode(r'''
void foo<T>(T a) {}
const g = identical(foo, foo);
''');
    _assertValue('g', r'''
bool true
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_implicitTypeArgs_identical_differentTypes() async {
    await resolveTestCode(r'''
void foo<T>(T a) {}
const void Function(int) f = foo;
const void Function(String) g = foo;
const c = identical(f, g);
''');
    _assertValue('c', r'''
bool false
  variable: self::@variable::c
''');
  }

  test_visitFunctionReference_implicitTypeArgs_identical_sameTypes() async {
    await resolveTestCode(r'''
void foo<T>(T a) {}
const void Function(int) f = foo;
const void Function(int) g = foo;
const c = identical(f, g);
''');
    _assertValue('c', r'''
bool true
  variable: self::@variable::c
''');
  }

  test_visitFunctionReference_uninstantiated_complexExpression() async {
    await assertNoErrorsInCode(r'''
const b = true;
void foo<T>(T a) {}
void bar<T>(T a) {}
const g = b ? foo : bar;
''');
    _assertValue('g', r'''
void Function<T>(T)
  element: self::@function::foo
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_uninstantiated_functionName() async {
    await assertNoErrorsInCode(r'''
void f<T>(T a) {}
const g = f;
''');
    _assertValue('g', r'''
void Function<T>(T)
  element: self::@function::f
  variable: self::@variable::g
''');
  }

  test_visitFunctionReference_uninstantiated_identical_sameElement() async {
    await resolveTestCode(r'''
void foo<T>(T a) {}
const g = identical(foo, foo);
''');
    _assertValue('g', r'''
bool true
  variable: self::@variable::g
''');
  }

  test_visitInterpolationExpression_list() async {
    await assertErrorsInCode(r'''
const x = '${const [2]}';
''', [
      error(CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_NUM_STRING, 11, 12),
    ]);
  }

  test_visitIsExpression_is_null() async {
    await resolveTestCode('''
const a = null;
const b = a is A;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_is_null_nullable() async {
    await resolveTestCode('''
const a = null;
const b = a is A?;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_is_null_object() async {
    await resolveTestCode('''
const a = null;
const b = a is Object;
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_isNot_null() async {
    await resolveTestCode('''
const a = null;
const b = a is! A;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitListLiteral_forElement() async {
    await assertErrorsInCode(r'''
const x = [for (int i = 0; i < 3; i++) i];
''', [
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 10,
          31),
      error(CompileTimeErrorCode.CONST_EVAL_FOR_ELEMENT, 11, 29),
    ]);
    _assertNull('x');
  }

  test_visitListLiteral_ifElement_nonBoolCondition() async {
    await assertErrorsInCode(r'''
const dynamic c = 2;
const x = [1, if (c) 2 else 3, 4];
''', [
      error(CompileTimeErrorCode.NON_BOOL_CONDITION, 39, 1),
    ]);
    _assertNull('x');
  }

  test_visitListLiteral_ifElement_nonBoolCondition_static() async {
    await assertErrorsInCode(r'''
const x = [1, if (1) 2 else 3, 4];
''', [
      error(CompileTimeErrorCode.NON_BOOL_CONDITION, 18, 1),
    ]);
    _assertNull('x');
  }

  test_visitListLiteral_spreadElement() async {
    await assertErrorsInCode(r'''
const dynamic a = 5;
const x = <int>[...a];
''', [
      error(CompileTimeErrorCode.CONST_SPREAD_EXPECTED_LIST_OR_SET, 40, 1),
    ]);
    _assertNull('x');
  }

  test_visitMethodInvocation_notIdentical() async {
    await assertErrorsInCode(r'''
int f() {
  return 3;
}
const a = f();
''', [
      error(CompileTimeErrorCode.CONST_EVAL_METHOD_INVOCATION, 34, 3),
    ]);
  }

  test_visitNamedType_typeLiteral_typeParameter_nested() async {
    await assertErrorsInCode(r'''
void f<T>(Object? x) {
  if (x case const (T)) {}
}
''', [
      error(CompileTimeErrorCode.CONSTANT_PATTERN_WITH_NON_CONSTANT_EXPRESSION,
          43, 1),
    ]);
  }

  test_visitNamedType_typeLiteral_typeParameter_nested2() async {
    await assertErrorsInCode(r'''
void f<T>(Object? x) {
  if (x case const (List<T>)) {}
}
''', [
      error(CompileTimeErrorCode.CONSTANT_PATTERN_WITH_NON_CONSTANT_EXPRESSION,
          43, 7),
    ]);
  }

  test_visitPrefixedIdentifier_genericFunction_instantiated() async {
    await resolveTestCode('''
import '' as self;
void f<T>(T a) {}
const void Function(int) g = self.f;
''');
    var result = _evaluateConstant('g');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitPrefixedIdentifier_genericFunction_instantiatedNonIdentifier() async {
    await resolveTestCode('''
void f<T>(T a) {}
const b = false;
const g1 = f;
const g2 = f;
const void Function(int) h = b ? g1 : g2;
''');
    var result = _evaluateConstant('h');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitPrefixedIdentifier_genericFunction_instantiatedPrefixed() async {
    await resolveTestCode('''
import '' as self;
void f<T>(T a) {}
const g = f;
const void Function(int) h = self.g;
''');
    var result = _evaluateConstant('h');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitPrefixExpression_extensionMethod() async {
    await assertErrorsInCode('''
extension on Object {
  int operator -() => 0;
}

const Object v1 = 1;
const v2 = -v1;
''', [
      error(CompileTimeErrorCode.CONST_EVAL_EXTENSION_METHOD, 82, 3),
    ]);
    _assertNull('v2');
  }

  test_visitPropertyAccess_genericFunction_instantiated() async {
    await resolveTestCode('''
import '' as self;
class C {
  static void f<T>(T a) {}
}
const void Function(int) g = self.C.f;
''');
    var result = _evaluateConstant('g');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.method('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitRecordLiteral_objectField_generic() async {
    await assertNoErrorsInCode(r'''
class A<T> {
  final (T, T) record;
  const A(T a) : record = (a, a);
}

const a = A(42);
''');
    final value = _evaluateConstant('a');
    assertDartObjectText(value, r'''
A<int>
  record: Record(int, int)
    positionalFields
      $1: int 42
      $2: int 42
''');
  }

  test_visitRecordLiteral_withoutEnvironment() async {
    await assertNoErrorsInCode(r'''
const a = (1, 'b', c: false);
''');
    final value = _evaluateConstant('a');
    assertDartObjectText(value, r'''
Record(int, String, {bool c})
  positionalFields
    $1: int 1
    $2: String b
  namedFields
    c: bool false
''');
  }

  test_visitSetOrMapLiteral_map_forElement() async {
    await assertErrorsInCode(r'''
const x = {1: null, for (final i in const []) i: null};
''', [
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 10,
          44),
      error(CompileTimeErrorCode.CONST_EVAL_FOR_ELEMENT, 20, 33),
    ]);
    _assertNull('x');
  }

  test_visitSetOrMapLiteral_map_forElement_nested() async {
    await assertErrorsInCode(r'''
const x = {1: null, if (true) for (final i in const []) i: null};
''', [
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 10,
          54),
      error(CompileTimeErrorCode.CONST_EVAL_FOR_ELEMENT, 30, 33),
    ]);
    _assertNull('x');
  }

  test_visitSetOrMapLiteral_set_forElement() async {
    await assertErrorsInCode(r'''
const Set set = {};
const x = {for (final i in set) i};
''', [
      error(CompileTimeErrorCode.CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE, 30,
          24),
      error(CompileTimeErrorCode.CONST_EVAL_FOR_ELEMENT, 31, 22),
    ]);
    _assertNull('x');
  }

  test_visitSimpleIdentifier_className() async {
    await resolveTestCode('''
const a = C;
class C {}
''');
    DartObjectImpl result = _evaluateConstant('a');
    expect(result.type, typeProvider.typeType);
    assertType(result.toTypeValue(), 'C*');
  }

  test_visitSimpleIdentifier_genericFunction_instantiated() async {
    await resolveTestCode('''
void f<T>(T a) {}
const void Function(int) g = f;
''');
    var result = _evaluateConstant('g');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitSimpleIdentifier_genericFunction_nonGeneric() async {
    await resolveTestCode('''
void f(int a) {}
const void Function(int) g = f;
''');
    var result = _evaluateConstant('g');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, null);
  }

  test_visitSimpleIdentifier_genericVariable_instantiated() async {
    await resolveTestCode('''
void f<T>(T a) {}
const g = f;
const void Function(int) h = g;
''');
    var result = _evaluateConstant('h');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitSimpleIdentifier_instantiatedFunctionType_field() async {
    await resolveTestCode('''
void f<T>(T a, {T? b}) {}

class C {
  static const void Function<T>(T a) g = f;
  static const void Function(int a) h = g;
}
''');
    var result = _evaluateConstantLocal('h')!;
    assertType(result.type, 'void Function(int, {int? b})');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  test_visitSimpleIdentifier_instantiatedFunctionType_parameter() async {
    await resolveTestCode('''
void f<T>(T a, {T? b}) {}

class C {
  const C(void Function<T>(T a) g) : h = g;
  final void Function(int a) h;
}

const c = C(f);
''');
    var result = _evaluateConstant('c');
    var field = result.fields!['h']!;
    assertType(field.type, 'void Function(int, {int? b})');
    assertElement(field.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(field, ['int']);
  }

  test_visitSimpleIdentifier_instantiatedFunctionType_variable() async {
    await resolveTestCode('''
void f<T>(T a, {T? b}) {}

const void Function<T>(T a) g = f;

const void Function(int a) h = g;
''');
    var result = _evaluateConstant('h');
    assertType(result.type, 'void Function(int, {int? b})');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, ['int']);
  }

  void _assertHasPrimitiveEqualityFalse(String name) {
    final value = _evaluateConstant(name);
    final featureSet = result.libraryElement.featureSet;
    final has = value.hasPrimitiveEquality(featureSet);
    expect(has, isFalse);
  }

  void _assertHasPrimitiveEqualityTrue(String name) {
    final value = _evaluateConstant(name);
    final featureSet = result.libraryElement.featureSet;
    final has = value.hasPrimitiveEquality(featureSet);
    expect(has, isTrue);
  }

  void _assertNull(String variableName) {
    final variable = findElement.topVar(variableName) as ConstVariableElement;
    final evaluationResult = variable.evaluationResult;
    if (evaluationResult == null) {
      fail('Not evaluated: $this');
    }
    expect(evaluationResult.value, isNull);
  }

  void _assertValue(String variableName, String expectedText) {
    final variable = findElement.topVar(variableName) as ConstVariableElement;
    final evaluationResult = variable.evaluationResult;
    if (evaluationResult == null) {
      fail('Not evaluated: $this');
    }
    assertDartObjectText(evaluationResult.value, expectedText);
  }
}

@reflectiveTest
mixin ConstantVisitorTestCases on ConstantVisitorTestSupport {
  test_listLiteral_ifElement_false_withElse() async {
    await resolveTestCode('''
const c = [1, if (1 < 0) 2 else 3, 4];
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.listType(typeProvider.intType));
    expect(result.toListValue()!.map((e) => e.toIntValue()), [1, 3, 4]);
  }

  test_listLiteral_ifElement_false_withoutElse() async {
    await resolveTestCode('''
const c = [1, if (1 < 0) 2, 3];
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.listType(typeProvider.intType));
    expect(result.toListValue()!.map((e) => e.toIntValue()), [1, 3]);
  }

  test_listLiteral_ifElement_true_withElse() async {
    await resolveTestCode('''
const c = [1, if (1 > 0) 2 else 3, 4];
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.listType(typeProvider.intType));
    expect(result.toListValue()!.map((e) => e.toIntValue()), [1, 2, 4]);
  }

  test_listLiteral_ifElement_true_withoutElse() async {
    await resolveTestCode('''
const c = [1, if (1 > 0) 2, 3];
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.listType(typeProvider.intType));
    expect(result.toListValue()!.map((e) => e.toIntValue()), [1, 2, 3]);
  }

  test_listLiteral_nested() async {
    await resolveTestCode('''
const c = [1, if (1 > 0) if (2 > 1) 2, 3];
''');
    DartObjectImpl result = _evaluateConstant('c');
    // The expected type ought to be `List<int>`, but type inference isn't yet
    // implemented.
    expect(result.type, typeProvider.listType(typeProvider.intType));
    expect(result.toListValue()!.map((e) => e.toIntValue()), [1, 2, 3]);
  }

  test_listLiteral_spreadElement() async {
    await resolveTestCode('''
const c = [1, ...[2, 3], 4];
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.listType(typeProvider.intType));
    expect(result.toListValue()!.map((e) => e.toIntValue()), [1, 2, 3, 4]);
  }

  test_mapLiteral_ifElement_false_withElse() async {
    await resolveTestCode('''
const c = {'a' : 1, if (1 < 0) 'b' : 2 else 'c' : 3, 'd' : 4};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type,
        typeProvider.mapType(typeProvider.stringType, typeProvider.intType));
    Map<DartObject, DartObject> value = result.toMapValue()!;
    expect(value.keys.map((e) => e.toStringValue()),
        unorderedEquals(['a', 'c', 'd']));
    expect(value.values.map((e) => e.toIntValue()), unorderedEquals([1, 3, 4]));
  }

  test_mapLiteral_ifElement_false_withoutElse() async {
    await resolveTestCode('''
const c = {'a' : 1, if (1 < 0) 'b' : 2, 'c' : 3};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type,
        typeProvider.mapType(typeProvider.stringType, typeProvider.intType));
    Map<DartObject, DartObject> value = result.toMapValue()!;
    expect(
        value.keys.map((e) => e.toStringValue()), unorderedEquals(['a', 'c']));
    expect(value.values.map((e) => e.toIntValue()), unorderedEquals([1, 3]));
  }

  test_mapLiteral_ifElement_true_withElse() async {
    await resolveTestCode('''
const c = {'a' : 1, if (1 > 0) 'b' : 2 else 'c' : 3, 'd' : 4};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type,
        typeProvider.mapType(typeProvider.stringType, typeProvider.intType));
    Map<DartObject, DartObject> value = result.toMapValue()!;
    expect(value.keys.map((e) => e.toStringValue()),
        unorderedEquals(['a', 'b', 'd']));
    expect(value.values.map((e) => e.toIntValue()), unorderedEquals([1, 2, 4]));
  }

  test_mapLiteral_ifElement_true_withoutElse() async {
    await resolveTestCode('''
const c = {'a' : 1, if (1 > 0) 'b' : 2, 'c' : 3};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type,
        typeProvider.mapType(typeProvider.stringType, typeProvider.intType));
    Map<DartObject, DartObject> value = result.toMapValue()!;
    expect(value.keys.map((e) => e.toStringValue()),
        unorderedEquals(['a', 'b', 'c']));
    expect(value.values.map((e) => e.toIntValue()), unorderedEquals([1, 2, 3]));
  }

  @failingTest
  test_mapLiteral_nested() async {
    // Fails because we're not yet parsing nested elements.
    await resolveTestCode('''
const c = {'a' : 1, if (1 > 0) if (2 > 1) {'b' : 2}, 'c' : 3};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type,
        typeProvider.mapType(typeProvider.intType, typeProvider.intType));
    Map<DartObject, DartObject> value = result.toMapValue()!;
    expect(value.keys.map((e) => e.toStringValue()),
        unorderedEquals(['a', 'b', 'c']));
    expect(value.values.map((e) => e.toIntValue()), unorderedEquals([1, 2, 3]));
  }

  test_mapLiteral_spreadElement() async {
    await resolveTestCode('''
const c = {'a' : 1, ...{'b' : 2, 'c' : 3}, 'd' : 4};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type,
        typeProvider.mapType(typeProvider.stringType, typeProvider.intType));
    Map<DartObject, DartObject> value = result.toMapValue()!;
    expect(value.keys.map((e) => e.toStringValue()),
        unorderedEquals(['a', 'b', 'c', 'd']));
    expect(
        value.values.map((e) => e.toIntValue()), unorderedEquals([1, 2, 3, 4]));
  }

  test_setLiteral_ifElement_false_withElse() async {
    await resolveTestCode('''
const c = {1, if (1 < 0) 2 else 3, 4};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.setType(typeProvider.intType));
    expect(result.toSetValue()!.map((e) => e.toIntValue()), [1, 3, 4]);
  }

  test_setLiteral_ifElement_false_withoutElse() async {
    await resolveTestCode('''
const c = {1, if (1 < 0) 2, 3};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.setType(typeProvider.intType));
    expect(result.toSetValue()!.map((e) => e.toIntValue()), [1, 3]);
  }

  test_setLiteral_ifElement_true_withElse() async {
    await resolveTestCode('''
const c = {1, if (1 > 0) 2 else 3, 4};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.setType(typeProvider.intType));
    expect(result.toSetValue()!.map((e) => e.toIntValue()), [1, 2, 4]);
  }

  test_setLiteral_ifElement_true_withoutElse() async {
    await resolveTestCode('''
const c = {1, if (1 > 0) 2, 3};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.setType(typeProvider.intType));
    expect(result.toSetValue()!.map((e) => e.toIntValue()), [1, 2, 3]);
  }

  test_setLiteral_nested() async {
    await resolveTestCode('''
const c = {1, if (1 > 0) if (2 > 1) 2, 3};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.setType(typeProvider.intType));
    expect(result.toSetValue()!.map((e) => e.toIntValue()), [1, 2, 3]);
  }

  test_setLiteral_spreadElement() async {
    await resolveTestCode('''
const c = {1, ...{2, 3}, 4};
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.setType(typeProvider.intType));
    expect(result.toSetValue()!.map((e) => e.toIntValue()), [1, 2, 3, 4]);
  }

  test_typeParameter() async {
    await resolveTestCode('''
class A<X> {
  const A();
  void m() {
    const x = X;
  }
}
''');
    var result = _evaluateConstantLocal('x', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitAsExpression_instanceOfSameClass() async {
    await resolveTestCode('''
const a = const A();
const b = a as A;
class A {
  const A();
}
''');
    DartObjectImpl resultA = _evaluateConstant('a');
    DartObjectImpl resultB = _evaluateConstant('b');
    expect(resultB, resultA);
  }

  test_visitAsExpression_instanceOfSubclass() async {
    await resolveTestCode('''
const a = const B();
const b = a as A;
class A {
  const A();
}
class B extends A {
  const B();
}
''');
    DartObjectImpl resultA = _evaluateConstant('a');
    DartObjectImpl resultB = _evaluateConstant('b');
    expect(resultB, resultA);
  }

  test_visitAsExpression_instanceOfSuperclass() async {
    await resolveTestCode('''
const a = const A();
const b = a as B;
class A {
  const A();
}
class B extends A {
  const B();
}
''');
    var result = _evaluateConstantOrNull('b',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION]);
    expect(result, isNull);
  }

  test_visitAsExpression_instanceOfUnrelatedClass() async {
    await resolveTestCode('''
const a = const A();
const b = a as B;
class A {
  const A();
}
class B {
  const B();
}
''');
    var result = _evaluateConstantOrNull('b',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION]);
    expect(result, isNull);
  }

  test_visitAsExpression_potentialConst() async {
    await assertNoErrorsInCode('''
class A {
  const A();
}

class MyClass {
  final A a;
  const MyClass(Object o) : a = o as A;
}
''');
  }

  test_visitBinaryExpression_and_bool_false_invalid() async {
    await resolveTestCode('''
final a = false;
const c = false && a;
''');
    DartObjectImpl result = _evaluateConstant('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    _assertBoolValue(result, false);
  }

  test_visitBinaryExpression_and_bool_invalid_false() async {
    await resolveTestCode('''
final a = false;
const c = a && false;
''');
    var result = _evaluateConstantOrNull('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitBinaryExpression_and_bool_invalid_true() async {
    await resolveTestCode('''
final a = false;
const c = a && true;
''');
    var result = _evaluateConstantOrNull('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitBinaryExpression_and_bool_known_known() async {
    await resolveTestCode('''
const c = false & true;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_and_bool_known_unknown() async {
    await resolveTestCode('''
const b = bool.fromEnvironment('y');
const c = false & b;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_and_bool_true_invalid() async {
    await resolveTestCode('''
final a = false;
const c = true && a;
''');
    var result = _evaluateConstantOrNull('c', errorCodes: [
      CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL,
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitBinaryExpression_and_bool_unknown_known() async {
    await resolveTestCode('''
const a = bool.fromEnvironment('x');
const c = a & true;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_and_bool_unknown_unknown() async {
    await resolveTestCode('''
const a = bool.fromEnvironment('x');
const b = bool.fromEnvironment('y');
const c = a & b;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_and_int() async {
    await resolveTestCode('''
const c = 3 & 5;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
  }

  test_visitBinaryExpression_and_mixed() async {
    await resolveTestCode('''
const c = 3 & false;
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_INT]);
  }

  test_visitBinaryExpression_or_bool_false_invalid() async {
    await resolveTestCode('''
final a = false;
const c = false || a;
''');
    var result = _evaluateConstantOrNull('c', errorCodes: [
      CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL,
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitBinaryExpression_or_bool_invalid_false() async {
    await resolveTestCode('''
final a = false;
const c = a || false;
''');
    var result = _evaluateConstantOrNull('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitBinaryExpression_or_bool_invalid_true() async {
    await resolveTestCode('''
final a = false;
const c = a || true;
''');
    var result = _evaluateConstantOrNull('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitBinaryExpression_or_bool_known_known() async {
    await resolveTestCode('''
const c = false | true;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_or_bool_known_unknown() async {
    await resolveTestCode('''
const b = bool.fromEnvironment('y');
const c = false | b;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_or_bool_true_invalid() async {
    await resolveTestCode('''
final a = false;
const c = true || a;
''');
    var result = _evaluateConstant('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    _assertBoolValue(result, true);
  }

  test_visitBinaryExpression_or_bool_unknown_known() async {
    await resolveTestCode('''
const a = bool.fromEnvironment('x');
const c = a | true;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_or_bool_unknown_unknown() async {
    await resolveTestCode('''
const a = bool.fromEnvironment('x');
const b = bool.fromEnvironment('y');
const c = a | b;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_or_int() async {
    await resolveTestCode('''
const c = 3 | 5;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
  }

  test_visitBinaryExpression_or_mixed() async {
    await resolveTestCode('''
const c = 3 | false;
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_INT]);
  }

  test_visitBinaryExpression_questionQuestion_invalid_notNull() async {
    await resolveTestCode('''
final x = 0;
const c = x ?? 1;
''');
    var result = _evaluateConstantOrNull('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    expect(result, isNull);
  }

  test_visitBinaryExpression_questionQuestion_notNull_invalid() async {
    await resolveTestCode('''
final x = 1;
const c = 0 ?? x;
''');
    var result = _evaluateConstant('c', errorCodes: [
      CompileTimeErrorCode.INVALID_CONSTANT,
    ]);
    _assertIntValue(result, 0);
  }

  test_visitBinaryExpression_questionQuestion_notNull_notNull() async {
    await resolveTestCode('''
const c = 'a' ?? 'b';
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.stringType);
    expect(result.toStringValue(), 'a');
  }

  test_visitBinaryExpression_questionQuestion_null_invalid() async {
    await resolveTestCode('''
const c = null ?? new C();
class C {}
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT]);
  }

  test_visitBinaryExpression_questionQuestion_null_notNull() async {
    await resolveTestCode('''
const c = null ?? 'b';
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.stringType);
    expect(result.toStringValue(), 'b');
  }

  test_visitBinaryExpression_questionQuestion_null_null() async {
    await resolveTestCode('''
const c = null ?? null;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.isNull, isTrue);
  }

  test_visitBinaryExpression_xor_bool_known_known() async {
    await resolveTestCode('''
const c = false ^ true;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_xor_bool_known_unknown() async {
    await resolveTestCode('''
const b = bool.fromEnvironment('y');
const c = false ^ b;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_xor_bool_unknown_known() async {
    await resolveTestCode('''
const a = bool.fromEnvironment('x');
const c = a ^ true;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_xor_bool_unknown_unknown() async {
    await resolveTestCode('''
const a = bool.fromEnvironment('x');
const b = bool.fromEnvironment('y');
const c = a ^ b;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
  }

  test_visitBinaryExpression_xor_int() async {
    await resolveTestCode('''
const c = 3 ^ 5;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
  }

  test_visitBinaryExpression_xor_mixed() async {
    await resolveTestCode('''
const c = 3 ^ false;
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL_INT]);
  }

  test_visitConditionalExpression_eager_false_int_int() async {
    await resolveTestCode('''
const c = false ? 1 : 0;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0);
  }

  test_visitConditionalExpression_eager_invalid_int_int() async {
    await resolveTestCode('''
const c = null ? 1 : 0;
''');
    var result = _evaluateConstantOrNull(
      'c',
      errorCodes: [CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL],
    );
    expect(result, isNull);
  }

  test_visitConditionalExpression_eager_true_int_int() async {
    await resolveTestCode('''
const c = true ? 1 : 0;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 1);
  }

  test_visitConditionalExpression_eager_true_int_invalid() async {
    await resolveTestCode('''
const c = true ? 1 : x;
''');
    DartObjectImpl result = _evaluateConstant(
      'c',
      errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT],
    );
    expect(result.toIntValue(), 1);
  }

  test_visitConditionalExpression_eager_true_invalid_int() async {
    await resolveTestCode('''
const c = true ? x : 0;
''');
    var result = _evaluateConstantOrNull(
      'c',
      errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT],
    );
    expect(result, isNull);
  }

  test_visitConditionalExpression_lazy_false_int_int() async {
    await resolveTestCode('''
const c = false ? 1 : 0;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0);
  }

  test_visitConditionalExpression_lazy_false_int_invalid() async {
    await resolveTestCode('''
const c = false ? 1 : new C();
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT]);
  }

  test_visitConditionalExpression_lazy_false_invalid_int() async {
    await resolveTestCode('''
const c = false ? new C() : 0;
''');
    DartObjectImpl result = _evaluateConstant('c',
        errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT]);
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 0);
  }

  test_visitConditionalExpression_lazy_invalid_int_int() async {
    await resolveTestCode('''
const c = 3 ? 1 : 0;
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.CONST_EVAL_TYPE_BOOL]);
  }

  test_visitConditionalExpression_lazy_true_int_int() async {
    await resolveTestCode('''
const c = true ? 1 : 0;
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 1);
  }

  test_visitConditionalExpression_lazy_true_int_invalid() async {
    await resolveTestCode('''
const c = true ? 1: new C();
''');
    DartObjectImpl result = _evaluateConstant('c',
        errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT]);
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 1);
  }

  test_visitConditionalExpression_lazy_true_invalid_int() async {
    await resolveTestCode('''
const c = true ? new C() : 0;
class C {}
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT]);
  }

  test_visitConditionalExpression_lazy_unknown_int_invalid() async {
    await resolveTestCode('''
const c = identical(0, 0.0) ? 1 : new Object();
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT]);
  }

  test_visitConditionalExpression_lazy_unknown_invalid_int() async {
    await resolveTestCode('''
const c = identical(0, 0.0) ? 1 : new Object();
''');
    _evaluateConstantOrNull('c',
        errorCodes: [CompileTimeErrorCode.INVALID_CONSTANT]);
  }

  test_visitIntegerLiteral() async {
    await resolveTestCode('''
const double d = 3;
''');
    DartObjectImpl result = _evaluateConstant('d');
    expect(result.type, typeProvider.doubleType);
    expect(result.toDoubleValue(), 3.0);
  }

  test_visitIsExpression_is_functionType_badTypes() async {
    await resolveTestCode('''
void foo(int a) {}
const c = foo is void Function(String);
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_is_functionType_correctTypes() async {
    await resolveTestCode('''
void foo(int a) {}
const c = foo is void Function(int);
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_is_functionType_nonFunction() async {
    await resolveTestCode('''
const c = false is void Function();
''');
    DartObjectImpl result = _evaluateConstant('c');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_is_instanceOfSameClass() async {
    await resolveTestCode('''
const a = const A();
const b = a is A;
class A {
  const A();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_is_instanceOfSubclass() async {
    await resolveTestCode('''
const a = const B();
const b = a is A;
class A {
  const A();
}
class B extends A {
  const B();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_is_instanceOfSuperclass() async {
    await resolveTestCode('''
const a = const A();
const b = a is B;
class A {
  const A();
}
class B extends A {
  const B();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_is_instanceOfUnrelatedClass() async {
    await resolveTestCode('''
const a = const A();
const b = a is B;
class A {
  const A();
}
class B {
  const B();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_is_null_dynamic() async {
    await resolveTestCode('''
const a = null;
const b = a is dynamic;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_is_null_null() async {
    await resolveTestCode('''
const a = null;
const b = a is Null;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_isNot_instanceOfSameClass() async {
    await resolveTestCode('''
const a = const A();
const b = a is! A;
class A {
  const A();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_isNot_instanceOfSubclass() async {
    await resolveTestCode('''
const a = const B();
const b = a is! A;
class A {
  const A();
}
class B extends A {
  const B();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }

  test_visitIsExpression_isNot_instanceOfSuperclass() async {
    await resolveTestCode('''
const a = const A();
const b = a is! B;
class A {
  const A();
}
class B extends A {
  const B();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_isNot_instanceOfUnrelatedClass() async {
    await resolveTestCode('''
const a = const A();
const b = a is! B;
class A {
  const A();
}
class B {
  const B();
}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitPrefixedIdentifier_function() async {
    await resolveTestCode('''
import '' as self;
void f(int a) {}
const g = self.f;
''');
    var result = _evaluateConstant('g');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, null);
  }

  test_visitPrefixedIdentifier_genericVariable_uninstantiated() async {
    await resolveTestCode('''
import '' as self;
void f<T>(T a) {}
const g = f;
const h = self.g;
''');
    var result = _evaluateConstant('h');
    assertType(result.type, 'void Function<T>(T)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, null);
  }

  test_visitPropertyAccess_fromExtension() async {
    await resolveTestCode('''
extension ExtObject on Object {
  int get length => 4;
}

class B {
  final l;
  const B(Object o) : l = o.length;
}

const b = B('');
''');
    _evaluateConstant('b', errorCodes: [
      CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION,
      CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION
    ]);
  }

  test_visitSimpleIdentifier_dynamic() async {
    await resolveTestCode('''
const a = dynamic;
''');
    DartObjectImpl result = _evaluateConstant('a');
    expect(result.type, typeProvider.typeType);
    expect(result.toTypeValue(), typeProvider.dynamicType);
  }

  test_visitSimpleIdentifier_function() async {
    await resolveTestCode('''
void f(int a) {}
const g = f;
''');
    var result = _evaluateConstant('g');
    assertType(result.type, 'void Function(int)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, null);
  }

  test_visitSimpleIdentifier_genericVariable_uninstantiated() async {
    await resolveTestCode('''
void f<T>(T a) {}
const g = f;
const h = g;
''');
    var result = _evaluateConstant('h');
    assertType(result.type, 'void Function<T>(T)');
    assertElement(result.toFunctionValue(), findElement.topFunction('f'));
    _assertTypeArguments(result, null);
  }

  test_visitSimpleIdentifier_inEnvironment() async {
    await resolveTestCode(r'''
const a = b;
const b = 3;''');
    var environment = <String, DartObjectImpl>{
      'b': DartObjectImpl(typeSystem, typeProvider.intType, IntState(6)),
    };
    var result = _evaluateConstant('a', lexicalEnvironment: environment);
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 6);
  }

  test_visitSimpleIdentifier_notInEnvironment() async {
    await resolveTestCode(r'''
const a = b;
const b = 3;''');
    var environment = <String, DartObjectImpl>{
      'c': DartObjectImpl(typeSystem, typeProvider.intType, IntState(6)),
    };
    var result = _evaluateConstant('a', lexicalEnvironment: environment);
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 3);
  }

  test_visitSimpleIdentifier_withoutEnvironment() async {
    await resolveTestCode(r'''
const a = b;
const b = 3;''');
    var result = _evaluateConstant('a');
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), 3);
  }
}

class ConstantVisitorTestSupport extends PubPackageResolutionTest {
  void _assertBoolValue(DartObjectImpl result, bool value) {
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), value);
  }

  void _assertIntValue(DartObjectImpl result, int value) {
    expect(result.type, typeProvider.intType);
    expect(result.toIntValue(), value);
  }

  void _assertTypeArguments(DartObject value, List<String>? typeArgumentNames) {
    var typeArguments = (value as DartObjectImpl).typeArguments;
    if (typeArguments == null) {
      expect(typeArguments, typeArgumentNames);
      return;
    }
    expect(
      typeArguments.map((arg) => arg.getDisplayString(withNullability: true)),
      equals(typeArgumentNames),
    );
  }

  /// Asserts that evaluation of [name] results in no errors, and a non-null
  /// [DartObject].
  void _assertValidConstant(String name) {
    _evaluateConstant(name);
  }

  DartObjectImpl _boolValue(bool value) {
    if (identical(value, false)) {
      return DartObjectImpl(
        typeSystem,
        typeProvider.boolType,
        BoolState.FALSE_STATE,
      );
    } else if (identical(value, true)) {
      return DartObjectImpl(
        typeSystem,
        typeProvider.boolType,
        BoolState.TRUE_STATE,
      );
    }
    fail("Invalid boolean value used in test");
  }

  DartObjectImpl _evaluateConstant(
    String name, {
    List<ErrorCode>? errorCodes,
    Map<String, String> declaredVariables = const {},
    Map<String, DartObjectImpl>? lexicalEnvironment,
  }) {
    return _evaluateConstantOrNull(
      name,
      errorCodes: errorCodes,
      declaredVariables: declaredVariables,
      lexicalEnvironment: lexicalEnvironment,
    )!;
  }

  DartObjectImpl? _evaluateConstantLocal(
    String name, {
    List<ErrorCode>? errorCodes,
    Map<String, String> declaredVariables = const {},
    Map<String, DartObjectImpl>? lexicalEnvironment,
  }) {
    var expression = findNode.variableDeclaration(name).initializer!;
    return _evaluateExpression(
      expression,
      errorCodes: errorCodes,
      declaredVariables: declaredVariables,
      lexicalEnvironment: lexicalEnvironment,
    );
  }

  DartObjectImpl? _evaluateConstantOrNull(
    String name, {
    List<ErrorCode>? errorCodes,
    Map<String, String> declaredVariables = const {},
    Map<String, DartObjectImpl>? lexicalEnvironment,
  }) {
    var expression = findNode.topVariableDeclarationByName(name).initializer!;
    return _evaluateExpression(
      expression,
      errorCodes: errorCodes,
      declaredVariables: declaredVariables,
      lexicalEnvironment: lexicalEnvironment,
    );
  }

  DartObjectImpl? _evaluateExpression(
    Expression expression, {
    List<ErrorCode>? errorCodes,
    Map<String, String> declaredVariables = const {},
    Map<String, DartObjectImpl>? lexicalEnvironment,
  }) {
    var unit = this.result.unit;
    var source = unit.declaredElement!.source;
    var errorListener = GatheringErrorListener();
    var errorReporter = ErrorReporter(
      errorListener,
      source,
      isNonNullableByDefault: false,
    );

    // TODO(kallentu): Remove unwrapping of Constant.
    var expressionConstant = expression.accept(
      ConstantVisitor(
        ConstantEvaluationEngine(
          declaredVariables: DeclaredVariables.fromMap(declaredVariables),
          isNonNullableByDefault:
              unit.featureSet.isEnabled(Feature.non_nullable),
          configuration: ConstantEvaluationConfiguration(),
        ),
        this.result.libraryElement as LibraryElementImpl,
        errorReporter,
        lexicalEnvironment: lexicalEnvironment,
      ),
    );
    var result =
        expressionConstant is DartObjectImpl ? expressionConstant : null;
    if (errorCodes == null) {
      errorListener.assertNoErrors();
    } else {
      errorListener.assertErrorsWithCodes(errorCodes);
    }
    return result;
  }

  DartObjectImpl _intValue(int value) {
    return DartObjectImpl(
      typeSystem,
      typeProvider.intType,
      IntState(value),
    );
  }
}

@reflectiveTest
class ConstantVisitorWithoutNullSafetyTest extends ConstantVisitorTestSupport
    with ConstantVisitorTestCases, WithoutNullSafetyMixin {
  test_visitAsExpression_null() async {
    await resolveTestCode('''
const a = null;
const b = a as A;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.nullType);
  }

  test_visitIsExpression_is_null() async {
    await resolveTestCode('''
const a = null;
const b = a is A;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_is_null_object() async {
    await resolveTestCode('''
const a = null;
const b = a is Object;
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), true);
  }

  test_visitIsExpression_isNot_null() async {
    await resolveTestCode('''
const a = null;
const b = a is! A;
class A {}
''');
    DartObjectImpl result = _evaluateConstant('b');
    expect(result.type, typeProvider.boolType);
    expect(result.toBoolValue(), false);
  }
}

@reflectiveTest
class InstanceCreationEvaluatorTest extends ConstantVisitorTestSupport
    with InstanceCreationEvaluatorTestCases {
  test_assertInitializer_assertIsNot_null_nullableType() async {
    await resolveTestCode('''
class A<T> {
  const A() : assert(null is! T);
}

const a = const A<int?>();
''');

    _evaluateConstantOrNull(
      'a',
      errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION],
    );
  }

  test_assertInitializer_intInDoubleContext_true() async {
    await assertNoErrorsInCode('''
class A {
  const A(double x): assert((x + 3) / 2 == 1.5);
}
const v = const A(0);
''');
    final value = _evaluateConstant('v');
    assertDartObjectText(value, r'''
A
''');
  }

  test_fieldInitializer_functionReference_withTypeParameter() async {
    await resolveTestCode('''
void g<U>(U a) {}
class A<T> {
  final void Function(T) f;
  const A(): f = g;
}
const a = const A<int>();
''');
    var result = _evaluateConstant('a');
    var aElement = findElement.class_('A');
    var expectedType = aElement.instantiate(
        typeArguments: [typeProvider.intType],
        nullabilitySuffix: NullabilitySuffix.none);
    expect(result.type, expectedType);

    var fField = result.fields!['f']!;
    var gElement = findElement.topFunction('g');
    var expectedFunctionType =
        gElement.type.instantiate([typeProvider.intType]);
    expect(fField.type, expectedFunctionType);
  }

  test_fieldInitializer_typeParameter() async {
    await resolveTestCode('''
class A<T> {
  final Object f;
  const A(): f = T;
}
const a = const A<int>();
''');
    var result = _evaluateConstant('a');
    var aElement = findElement.class_('A');
    var expectedType = aElement.instantiate(
        typeArguments: [typeProvider.intType],
        nullabilitySuffix: NullabilitySuffix.none);
    expect(result.type, expectedType);
  }

  test_fieldInitializer_typeParameter_implicitTypeArgs() async {
    await resolveTestCode('''
class A<T> {
  final Object f;
  const A(): f = T;
}
const a = const A();
''');
    var result = _evaluateConstant('a');
    var aElement = findElement.class_('A');
    var expectedType = aElement.instantiate(
        typeArguments: [typeProvider.dynamicType],
        nullabilitySuffix: NullabilitySuffix.none);
    expect(result.type, expectedType);
  }

  test_fieldInitializer_typeParameter_typeAlias() async {
    await resolveTestCode('''
class A<T, U> {
  final Object f, g;
  const A(): f = T, g = U;
}
typedef B<S> = A<int, S>;
const a = const B<String>();
''');
    var result = _evaluateConstant('a');
    var aElement = findElement.class_('A');
    var expectedType = aElement.instantiate(
        typeArguments: [typeProvider.intType, typeProvider.stringType],
        nullabilitySuffix: NullabilitySuffix.none);
    expect(result.type, expectedType);
  }

  test_fieldInitializer_typeParameter_withoutConstructorTearoffs() async {
    await resolveTestCode('''
// @dart=2.12
class A<T> {
  final Object f;
  const A(): f = T;
}
const a = const A<int>();
''');
    var result = _evaluateConstant('a', errorCodes: [
      CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION,
      CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION,
    ]);
    var aElement = findElement.class_('A');
    var expectedType = aElement.instantiate(
        typeArguments: [typeProvider.intType],
        nullabilitySuffix: NullabilitySuffix.none);
    expect(result.type, expectedType);
  }

  test_fieldInitializer_visitAsExpression_potentialConstType() async {
    await assertNoErrorsInCode('''
const num three = 3;

class C<T extends num> {
  final T w;
  const C() : w = three as T;
}

void main() {
  const C<int>().w;
}
''');
  }

  test_redirectingConstructor_typeParameter() async {
    await resolveTestCode('''
class A<T> {
  final Object f;
  const A(): this.named(T);
  const A.named(Object t): f = t;
}
const a = const A<int>();
''');
    var result = _evaluateConstant('a');
    expect(result, isNotNull);
  }

  test_superInitializer_typeParameter() async {
    await resolveTestCode('''
class A<T> {
  final Object f;
  const A(Object t): f = t;
}
class B<T> extends A<T> {
  const B(): super(T);
}
const a = const B<int>();
''');
    var result = _evaluateConstant('a');
    var bElement = findElement.class_('B');
    var expectedType = bElement.instantiate(
        typeArguments: [typeProvider.intType],
        nullabilitySuffix: NullabilitySuffix.none);
    expect(result.type, expectedType);
  }

  test_superInitializer_typeParameter_superNonGeneric() async {
    await resolveTestCode('''
class A {
  final Object f;
  const A(Object t): f = t;
}
class B<T> extends A {
  const B(): super(T);
}
const a = const B<int>();
''');
    var result = _evaluateConstant('a');
    expect(result, isNotNull);
  }
}

@reflectiveTest
mixin InstanceCreationEvaluatorTestCases on ConstantVisitorTestSupport {
  test_assertInitializer_assertIsNot_false() async {
    await resolveTestCode('''
class A {
  const A() : assert(0 is! int);
}

const a = const A(null);
''');
    _evaluateConstantOrNull(
      'a',
      errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION],
    );
  }

  test_assertInitializer_assertIsNot_true() async {
    await resolveTestCode('''
class A {
  const A() : assert(0 is! String);
}

const a = const A(null);
''');
    _assertValidConstant('a');
  }

  test_assertInitializer_intInDoubleContext_assertIsDouble_true() async {
    await resolveTestCode('''
class A {
  const A(double x): assert(x is double);
}
const a = const A(0);
''');
    _assertValidConstant('a');
  }

  test_assertInitializer_intInDoubleContext_false() async {
    await resolveTestCode('''
class A {
  const A(double x): assert((x + 3) / 2 == 1.5);
}
const a = const A(1);
''');
    _evaluateConstantOrNull(
      'a',
      errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION],
    );
  }

  test_assertInitializer_simple_false() async {
    await resolveTestCode('''
class A {
  const A(): assert(1 is String);
}
const a = const A();
''');
    _evaluateConstantOrNull(
      'a',
      errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION],
    );
  }

  test_assertInitializer_simple_true() async {
    await resolveTestCode('''
class A {
  const A(): assert(1 is int);
}
const a = const A();
''');
    _assertValidConstant('a');
  }

  test_assertInitializer_simpleInSuperInitializer_false() async {
    await resolveTestCode('''
class A {
  const A(): assert(1 is String);
}
class B extends A {
  const B() : super();
}
const b = const B();
''');
    _evaluateConstantOrNull(
      'b',
      errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION],
    );
  }

  test_assertInitializer_simpleInSuperInitializer_true() async {
    await resolveTestCode('''
class A {
  const A(): assert(1 is int);
}
class B extends A {
  const B() : super();
}
const b = const B();
''');
    _assertValidConstant('b');
  }

  test_assertInitializer_usingArgument_false() async {
    await resolveTestCode('''
class A {
  const A(int x): assert(x > 0);
}
const a = const A(0);
''');
    _evaluateConstantOrNull(
      'a',
      errorCodes: [CompileTimeErrorCode.CONST_EVAL_THROWS_EXCEPTION],
    );
  }

  test_assertInitializer_usingArgument_true() async {
    await resolveTestCode('''
class A {
  const A(int x): assert(x > 0);
}
const a = const A(1);
''');
    _assertValidConstant('a');
  }

  test_bool_fromEnvironment() async {
    await resolveTestCode('''
const a = bool.fromEnvironment('a');
const b = bool.fromEnvironment('b', defaultValue: true);
''');
    expect(
      _evaluateConstant('a'),
      _boolValue(false),
    );
    expect(
      _evaluateConstant('a', declaredVariables: {'a': 'true'}),
      _boolValue(true),
    );

    expect(
      _evaluateConstant(
        'b',
        declaredVariables: {'b': 'bbb'},
        lexicalEnvironment: {'defaultValue': _boolValue(true)},
      ),
      _boolValue(true),
    );
  }

  test_bool_hasEnvironment() async {
    await resolveTestCode('''
const a = bool.hasEnvironment('a');
''');
    expect(
      _evaluateConstant('a'),
      _boolValue(false),
    );

    expect(
      _evaluateConstant('a', declaredVariables: {'a': '42'}),
      _boolValue(true),
    );
  }

  test_int_fromEnvironment() async {
    await resolveTestCode('''
const a = int.fromEnvironment('a');
const b = int.fromEnvironment('b', defaultValue: 42);
''');
    expect(
      _evaluateConstant('a'),
      _intValue(0),
    );
    expect(
      _evaluateConstant('a', declaredVariables: {'a': '5'}),
      _intValue(5),
    );

    expect(
      _evaluateConstant(
        'b',
        declaredVariables: {'b': 'bbb'},
        lexicalEnvironment: {'defaultValue': _intValue(42)},
      ),
      _intValue(42),
    );
  }

  test_string_fromEnvironment() async {
    await resolveTestCode('''
const a = String.fromEnvironment('a');
''');
    expect(
      _evaluateConstant('a'),
      DartObjectImpl(
        typeSystem,
        typeProvider.stringType,
        StringState(''),
      ),
    );
    expect(
      _evaluateConstant('a', declaredVariables: {'a': 'test'}),
      DartObjectImpl(
        typeSystem,
        typeProvider.stringType,
        StringState('test'),
      ),
    );
  }
}

@reflectiveTest
class InstanceCreationEvaluatorWithoutNullSafetyTest
    extends ConstantVisitorTestSupport
    with InstanceCreationEvaluatorTestCases, WithoutNullSafetyMixin {}
