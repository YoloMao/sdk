// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Data produced by dart2js when run with the `--dump-info` flag.
library dart2js_info.info;

/// Common interface to many pieces of information generated by the dart2js
/// compiler that are directly associated with an element (compilation unit,
/// library, class, function, or field).
abstract class Info {
  /// An identifier for the kind of information.
  InfoKind get kind;

  /// Name of the element associated with this info.
  String name;

  /// Id used by the compiler when instrumenting code for code coverage.
  // TODO(sigmund): It would be nice if we could use the same id for
  // serialization and for coverage. Could we unify them?
  String coverageId;

  /// Bytes used in the generated code for the corresponding element.
  int size;

  /// Info of the enclosing element.
  Info parent;

  /// At which stage of the compiler this component was treeshaken.
  TreeShakenStatus treeShakenStatus;

  T accept<T>(InfoVisitor<T> visitor);
}

/// Indicates at what stage of compilation the [Info] element was treeshaken.
enum TreeShakenStatus { Dead, Live }

/// Common information used for most kind of elements.
// TODO(sigmund): add more:
//  - inputSize: bytes used in the Dart source program
abstract class BasicInfo implements Info {
  @override
  final InfoKind kind;

  @override
  String coverageId;
  @override
  int size;
  @override
  Info parent;
  @override
  TreeShakenStatus treeShakenStatus = TreeShakenStatus.Dead;

  @override
  String name;

  /// If using deferred libraries, where the element associated with this info
  /// is generated.
  OutputUnitInfo outputUnit;

  BasicInfo(this.kind, this.name, this.outputUnit, this.size, this.coverageId);

  BasicInfo.internal(this.kind);

  @override
  String toString() => '$kind $name [$size]';
}

/// Info associated with elements containing executable code (like fields and
/// methods)
abstract class CodeInfo implements Info {
  /// How does this function or field depend on others.
  List<DependencyInfo> uses = [];
}

/// The entire information produced while compiling a program.
class AllInfo {
  /// Summary information about the program.
  ProgramInfo program;

  /// Information about each library processed by the compiler.
  List<LibraryInfo> libraries = <LibraryInfo>[];

  /// Information about each function (includes methods and getters in any
  /// library)
  List<FunctionInfo> functions = <FunctionInfo>[];

  /// Information about type defs in the program.
  List<TypedefInfo> typedefs = <TypedefInfo>[];

  /// Information about each class (in any library).
  List<ClassInfo> classes = <ClassInfo>[];

  /// Information about each class type (in any library).
  List<ClassTypeInfo> classTypes = <ClassTypeInfo>[];

  /// Information about fields (in any class).
  List<FieldInfo> fields = <FieldInfo>[];

  /// Information about constants anywhere in the program.
  // TODO(sigmund): expand docs about canonicalization. We don't put these
  // inside library because a single constant can be used in more than one lib,
  // and we'll include it only once in the output.
  List<ConstantInfo> constants = <ConstantInfo>[];

  /// Information about closures anywhere in the program.
  List<ClosureInfo> closures = <ClosureInfo>[];

  /// Information about output units (should be just one entry if not using
  /// deferred loading).
  List<OutputUnitInfo> outputUnits = <OutputUnitInfo>[];

  /// Details about all deferred imports and what files would be loaded when the
  /// import is resolved.
  // TODO(sigmund): use a different format for dump-info. This currently emits
  // the same map that is created for the `--deferred-map` flag.
  Map<String, Map<String, dynamic>> deferredFiles;

  /// A new representation of dependencies from one info to another. An entry in
  /// this map indicates that an [Info] depends on another (e.g. a function
  /// invokes another). Please note that the data in this field might not be
  /// accurate yet (this is work in progress).
  Map<Info, List<Info>> dependencies = {};

  /// Major version indicating breaking changes in the format. A new version
  /// means that an old deserialization algorithm will not work with the new
  /// format.
  final int version = 6;

  /// Minor version indicating non-breaking changes in the format. A change in
  /// this version number means that the json parsing in this library from a
  /// previous will continue to work after the change. This is typically
  /// increased when adding new entries to the file format.
  // Note: the dump-info.viewer app was written using a json parser version 3.2.
  final int minorVersion = 1;

  AllInfo();

  T accept<T>(InfoVisitor<T> visitor) => visitor.visitAll(this);
}

class ProgramInfo {
  FunctionInfo entrypoint;
  int size;
  String dart2jsVersion;
  DateTime compilationMoment;
  Duration compilationDuration;
  Duration toJsonDuration;
  Duration dumpInfoDuration;

  /// `true` if `noSuchMethod` is used.
  bool noSuchMethodEnabled;

  /// `true` if `Object.runtimeType` is used.
  bool isRuntimeTypeUsed;

  /// `true` if the `dart:isolate` library is in use.
  bool isIsolateInUse;

  /// `true` if `Function.apply` is used.
  bool isFunctionApplyUsed;

  /// `true` if `dart:mirrors` features are used.
  bool isMirrorsUsed;

  bool minified;

  ProgramInfo(
      {this.entrypoint,
      this.size,
      this.dart2jsVersion,
      this.compilationMoment,
      this.compilationDuration,
      this.toJsonDuration,
      this.dumpInfoDuration,
      this.noSuchMethodEnabled,
      this.isRuntimeTypeUsed,
      this.isIsolateInUse,
      this.isFunctionApplyUsed,
      this.isMirrorsUsed,
      this.minified});

  T accept<T>(InfoVisitor<T> visitor) => visitor.visitProgram(this);
}

/// Info associated with a library element.
class LibraryInfo extends BasicInfo {
  /// Canonical uri that identifies the library.
  Uri uri;

  /// Top level functions defined within the library.
  List<FunctionInfo> topLevelFunctions = <FunctionInfo>[];

  /// Top level fields defined within the library.
  List<FieldInfo> topLevelVariables = <FieldInfo>[];

  /// Classes defined within the library.
  List<ClassInfo> classes = <ClassInfo>[];

  /// Class types defined within the library.
  List<ClassTypeInfo> classTypes = <ClassTypeInfo>[];

  /// Typedefs defined within the library.
  List<TypedefInfo> typedefs = <TypedefInfo>[];

  // TODO(sigmund): add here a list of parts. That can help us improve how we
  // encode source-span information in metrics (rather than include the uri on
  // each function, include an index into this list).

  /// Whether there is any information recorded for this library.
  bool get isEmpty =>
      topLevelFunctions.isEmpty &&
      topLevelVariables.isEmpty &&
      classes.isEmpty &&
      classTypes.isEmpty;

  LibraryInfo(String name, this.uri, OutputUnitInfo outputUnit, int size)
      : super(InfoKind.library, name, outputUnit, size, null);

  LibraryInfo.internal() : super.internal(InfoKind.library);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitLibrary(this);
}

/// Information about an output unit. Normally there is just one for the entire
/// program unless the application uses deferred imports, in which case there
/// would be an additional output unit per deferred chunk.
class OutputUnitInfo extends BasicInfo {
  String filename;

  /// The deferred imports that will load this output unit.
  List<String> imports = <String>[];

  OutputUnitInfo(this.filename, String name, int size)
      : super(InfoKind.outputUnit, name, null, size, null);

  OutputUnitInfo.internal() : super.internal(InfoKind.outputUnit);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitOutput(this);
}

/// Information about a class element.
class ClassInfo extends BasicInfo {
  /// Whether the class is abstract.
  bool isAbstract;

  // TODO(sigmund): split static vs instance vs closures
  /// Functions (static or instance) defined in the class.
  List<FunctionInfo> functions = <FunctionInfo>[];

  /// Fields defined in the class.
  // TODO(sigmund): currently appears to only be populated with instance fields,
  // but this should be fixed.
  List<FieldInfo> fields = <FieldInfo>[];

  ClassInfo(
      {String name, this.isAbstract, OutputUnitInfo outputUnit, int size = 0})
      : super(InfoKind.clazz, name, outputUnit, size, null);

  ClassInfo.internal() : super.internal(InfoKind.clazz);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitClass(this);
}

/// Information about a class type element. [ClassTypeInfo] is distinct from
/// [ClassInfo] because a class and its type may end up in different output
/// units.
class ClassTypeInfo extends BasicInfo {
  ClassTypeInfo({String name, OutputUnitInfo outputUnit, int size = 0})
      : super(InfoKind.classType, name, outputUnit, size, null);

  ClassTypeInfo.internal() : super.internal(InfoKind.classType);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitClassType(this);
}

/// A code span of generated code. A [CodeSpan] object is associated with a
/// single [BasicInfo]. The offsets in the span corresponds to offsets on the
/// file of [BasicInfo.outputUnit].
class CodeSpan {
  /// Start offset in the generated file.
  int start;

  /// end offset in the generated file.
  int end;

  /// The actual code (optional, blank when using a compact representation of
  /// the encoding).
  String text;

  CodeSpan({this.start, this.end, this.text});
}

/// Information about a constant value.
// TODO(sigmund): add dependency data for ConstantInfo
class ConstantInfo extends BasicInfo {
  /// The actual generated code for the constant.
  List<CodeSpan> code;

  // TODO(sigmund): Add coverage support to constants?
  ConstantInfo({int size = 0, this.code, OutputUnitInfo outputUnit})
      : super(InfoKind.constant, null, outputUnit, size, null);

  ConstantInfo.internal() : super.internal(InfoKind.constant);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitConstant(this);
}

/// Information about a field element.
class FieldInfo extends BasicInfo with CodeInfo {
  /// The type of the field.
  String type;

  /// The type inferred by dart2js's whole program analysis
  String inferredType;

  /// Nested closures seen in the field initializer.
  List<ClosureInfo> closures;

  /// The actual generated code for the field.
  List<CodeSpan> code;

  /// Whether this corresponds to a const field declaration.
  bool isConst;

  /// When [isConst] is true, the constant initializer expression.
  ConstantInfo initializer;

  FieldInfo(
      {String name,
      String coverageId,
      int size = 0,
      this.type,
      this.inferredType,
      this.closures,
      this.code,
      OutputUnitInfo outputUnit,
      this.isConst})
      : super(InfoKind.field, name, outputUnit, size, coverageId);

  FieldInfo.internal() : super.internal(InfoKind.field);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitField(this);
}

/// Information about a typedef declaration.
class TypedefInfo extends BasicInfo {
  /// The declared type.
  String type;

  TypedefInfo(String name, this.type, OutputUnitInfo outputUnit)
      : super(InfoKind.typedef, name, outputUnit, 0, null);

  TypedefInfo.internal() : super.internal(InfoKind.typedef);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitTypedef(this);
}

/// Information about a function or method.
class FunctionInfo extends BasicInfo with CodeInfo {
  static const int TOP_LEVEL_FUNCTION_KIND = 0;
  static const int CLOSURE_FUNCTION_KIND = 1;
  static const int METHOD_FUNCTION_KIND = 2;
  static const int CONSTRUCTOR_FUNCTION_KIND = 3;

  /// Kind of function (top-level function, closure, method, or constructor).
  int functionKind;

  /// Modifiers applied to this function.
  FunctionModifiers modifiers;

  /// Nested closures that appear within the body of this function.
  List<ClosureInfo> closures;

  /// The type of this function.
  String type;

  /// The declared return type.
  String returnType;

  /// The inferred return type.
  String inferredReturnType;

  /// Name and type information for each parameter.
  List<ParameterInfo> parameters;

  /// Side-effects.
  // TODO(sigmund): serialize more precisely, not just a string representation.
  String sideEffects;

  /// How many function calls were inlined into this function.
  int inlinedCount;

  /// The actual generated code.
  List<CodeSpan> code;

  FunctionInfo(
      {String name,
      String coverageId,
      OutputUnitInfo outputUnit,
      int size = 0,
      this.functionKind,
      this.modifiers,
      this.closures,
      this.type,
      this.returnType,
      this.inferredReturnType,
      this.parameters,
      this.sideEffects,
      this.inlinedCount,
      this.code})
      : super(InfoKind.function, name, outputUnit, size, coverageId);

  FunctionInfo.internal() : super.internal(InfoKind.function);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitFunction(this);
}

/// Information about a closure, also known as a local function.
class ClosureInfo extends BasicInfo {
  /// The function that is wrapped by this closure.
  FunctionInfo function;

  ClosureInfo(
      {String name, OutputUnitInfo outputUnit, int size = 0, this.function})
      : super(InfoKind.closure, name, outputUnit, size, null);

  ClosureInfo.internal() : super.internal(InfoKind.closure);

  @override
  T accept<T>(InfoVisitor<T> visitor) => visitor.visitClosure(this);
}

/// Information about how a dependency is used.
class DependencyInfo {
  /// The dependency, either a FunctionInfo or FieldInfo.
  final Info target;

  /// Either a selector mask indicating how this is used, or 'inlined'.
  // TODO(sigmund): split mask into an enum or something more precise to really
  // describe the dependencies in detail.
  final String mask;

  DependencyInfo(this.target, this.mask);
}

/// Name and type information about a function parameter.
class ParameterInfo {
  final String name;
  final String type;
  final String declaredType;

  ParameterInfo(this.name, this.type, this.declaredType);
}

/// Modifiers that may apply to methods.
class FunctionModifiers {
  final bool isStatic;
  final bool isConst;
  final bool isFactory;
  final bool isExternal;
  final bool isGetter;
  final bool isSetter;

  FunctionModifiers({
    this.isStatic = false,
    this.isConst = false,
    this.isFactory = false,
    this.isExternal = false,
    this.isGetter,
    this.isSetter,
  });
}

/// Possible values of the `kind` field in the serialized infos.
enum InfoKind {
  library,
  clazz,
  classType,
  function,
  field,
  constant,
  outputUnit,
  typedef,
  closure,
}

String kindToString(InfoKind kind) {
  switch (kind) {
    case InfoKind.library:
      return 'library';
    case InfoKind.clazz:
      return 'class';
    case InfoKind.classType:
      return 'classType';
    case InfoKind.function:
      return 'function';
    case InfoKind.field:
      return 'field';
    case InfoKind.constant:
      return 'constant';
    case InfoKind.outputUnit:
      return 'outputUnit';
    case InfoKind.typedef:
      return 'typedef';
    case InfoKind.closure:
      return 'closure';
    default:
      return null;
  }
}

InfoKind kindFromString(String kind) {
  switch (kind) {
    case 'library':
      return InfoKind.library;
    case 'class':
      return InfoKind.clazz;
    case 'classType':
      return InfoKind.classType;
    case 'function':
      return InfoKind.function;
    case 'field':
      return InfoKind.field;
    case 'constant':
      return InfoKind.constant;
    case 'outputUnit':
      return InfoKind.outputUnit;
    case 'typedef':
      return InfoKind.typedef;
    case 'closure':
      return InfoKind.closure;
    default:
      return null;
  }
}

/// A simple visitor for information produced by the dart2js compiler.
abstract class InfoVisitor<T> {
  T visitAll(AllInfo info);
  T visitProgram(ProgramInfo info);
  T visitLibrary(LibraryInfo info);
  T visitClass(ClassInfo info);
  T visitClassType(ClassTypeInfo info);
  T visitField(FieldInfo info);
  T visitConstant(ConstantInfo info);
  T visitFunction(FunctionInfo info);
  T visitTypedef(TypedefInfo info);
  T visitClosure(ClosureInfo info);
  T visitOutput(OutputUnitInfo info);
}

/// A visitor that recursively walks each portion of the program. Because the
/// info representation is redundant, this visitor only walks the structure of
/// the program and skips some redundant links. For example, even though
/// visitAll contains references to functions, this visitor only recurses to
/// visit libraries, then from each library we visit functions and classes, and
/// so on.
class RecursiveInfoVisitor extends InfoVisitor<void> {
  @override
  visitAll(AllInfo info) {
    // Note: we don't visit functions, fields, classes, and typedefs because
    // they are reachable from the library info.
    info.libraries.forEach(visitLibrary);
    info.constants.forEach(visitConstant);
  }

  @override
  visitProgram(ProgramInfo info) {}

  @override
  visitLibrary(LibraryInfo info) {
    info.topLevelFunctions.forEach(visitFunction);
    info.topLevelVariables.forEach(visitField);
    info.classes.forEach(visitClass);
    info.classTypes.forEach(visitClassType);
    info.typedefs.forEach(visitTypedef);
  }

  @override
  visitClass(ClassInfo info) {
    info.functions.forEach(visitFunction);
    info.fields.forEach(visitField);
  }

  @override
  visitClassType(ClassTypeInfo info) {}

  @override
  visitField(FieldInfo info) {
    info.closures.forEach(visitClosure);
  }

  @override
  visitConstant(ConstantInfo info) {}

  @override
  visitFunction(FunctionInfo info) {
    info.closures.forEach(visitClosure);
  }

  @override
  visitTypedef(TypedefInfo info) {}
  @override
  visitOutput(OutputUnitInfo info) {}
  @override
  visitClosure(ClosureInfo info) {
    visitFunction(info.function);
  }
}
