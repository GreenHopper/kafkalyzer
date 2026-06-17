// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'script.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScriptVariable {

 String get name; ScriptVariableType get type;
/// Create a copy of ScriptVariable
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScriptVariableCopyWith<ScriptVariable> get copyWith => _$ScriptVariableCopyWithImpl<ScriptVariable>(this as ScriptVariable, _$identity);

  /// Serializes this ScriptVariable to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScriptVariable&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,type);

@override
String toString() {
  return 'ScriptVariable(name: $name, type: $type)';
}


}

/// @nodoc
abstract mixin class $ScriptVariableCopyWith<$Res>  {
  factory $ScriptVariableCopyWith(ScriptVariable value, $Res Function(ScriptVariable) _then) = _$ScriptVariableCopyWithImpl;
@useResult
$Res call({
 String name, ScriptVariableType type
});




}
/// @nodoc
class _$ScriptVariableCopyWithImpl<$Res>
    implements $ScriptVariableCopyWith<$Res> {
  _$ScriptVariableCopyWithImpl(this._self, this._then);

  final ScriptVariable _self;
  final $Res Function(ScriptVariable) _then;

/// Create a copy of ScriptVariable
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? type = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ScriptVariableType,
  ));
}

}


/// Adds pattern-matching-related methods to [ScriptVariable].
extension ScriptVariablePatterns on ScriptVariable {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScriptVariable value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScriptVariable() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScriptVariable value)  $default,){
final _that = this;
switch (_that) {
case _ScriptVariable():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScriptVariable value)?  $default,){
final _that = this;
switch (_that) {
case _ScriptVariable() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  ScriptVariableType type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScriptVariable() when $default != null:
return $default(_that.name,_that.type);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  ScriptVariableType type)  $default,) {final _that = this;
switch (_that) {
case _ScriptVariable():
return $default(_that.name,_that.type);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  ScriptVariableType type)?  $default,) {final _that = this;
switch (_that) {
case _ScriptVariable() when $default != null:
return $default(_that.name,_that.type);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScriptVariable implements ScriptVariable {
  const _ScriptVariable({required this.name, this.type = ScriptVariableType.string});
  factory _ScriptVariable.fromJson(Map<String, dynamic> json) => _$ScriptVariableFromJson(json);

@override final  String name;
@override@JsonKey() final  ScriptVariableType type;

/// Create a copy of ScriptVariable
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScriptVariableCopyWith<_ScriptVariable> get copyWith => __$ScriptVariableCopyWithImpl<_ScriptVariable>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScriptVariableToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScriptVariable&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,type);

@override
String toString() {
  return 'ScriptVariable(name: $name, type: $type)';
}


}

/// @nodoc
abstract mixin class _$ScriptVariableCopyWith<$Res> implements $ScriptVariableCopyWith<$Res> {
  factory _$ScriptVariableCopyWith(_ScriptVariable value, $Res Function(_ScriptVariable) _then) = __$ScriptVariableCopyWithImpl;
@override @useResult
$Res call({
 String name, ScriptVariableType type
});




}
/// @nodoc
class __$ScriptVariableCopyWithImpl<$Res>
    implements _$ScriptVariableCopyWith<$Res> {
  __$ScriptVariableCopyWithImpl(this._self, this._then);

  final _ScriptVariable _self;
  final $Res Function(_ScriptVariable) _then;

/// Create a copy of ScriptVariable
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? type = null,}) {
  return _then(_ScriptVariable(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ScriptVariableType,
  ));
}


}


/// @nodoc
mixin _$Script {

 String get id; String get name; int get concurrencyLimit; String? get outputDirectory; List<ScriptVariable> get variables; List<ScriptStep> get steps;
/// Create a copy of Script
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScriptCopyWith<Script> get copyWith => _$ScriptCopyWithImpl<Script>(this as Script, _$identity);

  /// Serializes this Script to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Script&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.concurrencyLimit, concurrencyLimit) || other.concurrencyLimit == concurrencyLimit)&&(identical(other.outputDirectory, outputDirectory) || other.outputDirectory == outputDirectory)&&const DeepCollectionEquality().equals(other.variables, variables)&&const DeepCollectionEquality().equals(other.steps, steps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,concurrencyLimit,outputDirectory,const DeepCollectionEquality().hash(variables),const DeepCollectionEquality().hash(steps));

@override
String toString() {
  return 'Script(id: $id, name: $name, concurrencyLimit: $concurrencyLimit, outputDirectory: $outputDirectory, variables: $variables, steps: $steps)';
}


}

/// @nodoc
abstract mixin class $ScriptCopyWith<$Res>  {
  factory $ScriptCopyWith(Script value, $Res Function(Script) _then) = _$ScriptCopyWithImpl;
@useResult
$Res call({
 String id, String name, int concurrencyLimit, String? outputDirectory, List<ScriptVariable> variables, List<ScriptStep> steps
});




}
/// @nodoc
class _$ScriptCopyWithImpl<$Res>
    implements $ScriptCopyWith<$Res> {
  _$ScriptCopyWithImpl(this._self, this._then);

  final Script _self;
  final $Res Function(Script) _then;

/// Create a copy of Script
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? concurrencyLimit = null,Object? outputDirectory = freezed,Object? variables = null,Object? steps = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,concurrencyLimit: null == concurrencyLimit ? _self.concurrencyLimit : concurrencyLimit // ignore: cast_nullable_to_non_nullable
as int,outputDirectory: freezed == outputDirectory ? _self.outputDirectory : outputDirectory // ignore: cast_nullable_to_non_nullable
as String?,variables: null == variables ? _self.variables : variables // ignore: cast_nullable_to_non_nullable
as List<ScriptVariable>,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as List<ScriptStep>,
  ));
}

}


/// Adds pattern-matching-related methods to [Script].
extension ScriptPatterns on Script {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Script value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Script() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Script value)  $default,){
final _that = this;
switch (_that) {
case _Script():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Script value)?  $default,){
final _that = this;
switch (_that) {
case _Script() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int concurrencyLimit,  String? outputDirectory,  List<ScriptVariable> variables,  List<ScriptStep> steps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Script() when $default != null:
return $default(_that.id,_that.name,_that.concurrencyLimit,_that.outputDirectory,_that.variables,_that.steps);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int concurrencyLimit,  String? outputDirectory,  List<ScriptVariable> variables,  List<ScriptStep> steps)  $default,) {final _that = this;
switch (_that) {
case _Script():
return $default(_that.id,_that.name,_that.concurrencyLimit,_that.outputDirectory,_that.variables,_that.steps);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int concurrencyLimit,  String? outputDirectory,  List<ScriptVariable> variables,  List<ScriptStep> steps)?  $default,) {final _that = this;
switch (_that) {
case _Script() when $default != null:
return $default(_that.id,_that.name,_that.concurrencyLimit,_that.outputDirectory,_that.variables,_that.steps);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Script implements Script {
  const _Script({required this.id, required this.name, this.concurrencyLimit = 2, this.outputDirectory, final  List<ScriptVariable> variables = const [], final  List<ScriptStep> steps = const []}): _variables = variables,_steps = steps;
  factory _Script.fromJson(Map<String, dynamic> json) => _$ScriptFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  int concurrencyLimit;
@override final  String? outputDirectory;
 final  List<ScriptVariable> _variables;
@override@JsonKey() List<ScriptVariable> get variables {
  if (_variables is EqualUnmodifiableListView) return _variables;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_variables);
}

 final  List<ScriptStep> _steps;
@override@JsonKey() List<ScriptStep> get steps {
  if (_steps is EqualUnmodifiableListView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_steps);
}


/// Create a copy of Script
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScriptCopyWith<_Script> get copyWith => __$ScriptCopyWithImpl<_Script>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScriptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Script&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.concurrencyLimit, concurrencyLimit) || other.concurrencyLimit == concurrencyLimit)&&(identical(other.outputDirectory, outputDirectory) || other.outputDirectory == outputDirectory)&&const DeepCollectionEquality().equals(other._variables, _variables)&&const DeepCollectionEquality().equals(other._steps, _steps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,concurrencyLimit,outputDirectory,const DeepCollectionEquality().hash(_variables),const DeepCollectionEquality().hash(_steps));

@override
String toString() {
  return 'Script(id: $id, name: $name, concurrencyLimit: $concurrencyLimit, outputDirectory: $outputDirectory, variables: $variables, steps: $steps)';
}


}

/// @nodoc
abstract mixin class _$ScriptCopyWith<$Res> implements $ScriptCopyWith<$Res> {
  factory _$ScriptCopyWith(_Script value, $Res Function(_Script) _then) = __$ScriptCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int concurrencyLimit, String? outputDirectory, List<ScriptVariable> variables, List<ScriptStep> steps
});




}
/// @nodoc
class __$ScriptCopyWithImpl<$Res>
    implements _$ScriptCopyWith<$Res> {
  __$ScriptCopyWithImpl(this._self, this._then);

  final _Script _self;
  final $Res Function(_Script) _then;

/// Create a copy of Script
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? concurrencyLimit = null,Object? outputDirectory = freezed,Object? variables = null,Object? steps = null,}) {
  return _then(_Script(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,concurrencyLimit: null == concurrencyLimit ? _self.concurrencyLimit : concurrencyLimit // ignore: cast_nullable_to_non_nullable
as int,outputDirectory: freezed == outputDirectory ? _self.outputDirectory : outputDirectory // ignore: cast_nullable_to_non_nullable
as String?,variables: null == variables ? _self._variables : variables // ignore: cast_nullable_to_non_nullable
as List<ScriptVariable>,steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as List<ScriptStep>,
  ));
}


}


/// @nodoc
mixin _$ScriptExtraction {

 String get jsonPath; String get variableName; String? get topic; ScriptExtractionSource get source;
/// Create a copy of ScriptExtraction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScriptExtractionCopyWith<ScriptExtraction> get copyWith => _$ScriptExtractionCopyWithImpl<ScriptExtraction>(this as ScriptExtraction, _$identity);

  /// Serializes this ScriptExtraction to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScriptExtraction&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.variableName, variableName) || other.variableName == variableName)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,jsonPath,variableName,topic,source);

@override
String toString() {
  return 'ScriptExtraction(jsonPath: $jsonPath, variableName: $variableName, topic: $topic, source: $source)';
}


}

/// @nodoc
abstract mixin class $ScriptExtractionCopyWith<$Res>  {
  factory $ScriptExtractionCopyWith(ScriptExtraction value, $Res Function(ScriptExtraction) _then) = _$ScriptExtractionCopyWithImpl;
@useResult
$Res call({
 String jsonPath, String variableName, String? topic, ScriptExtractionSource source
});




}
/// @nodoc
class _$ScriptExtractionCopyWithImpl<$Res>
    implements $ScriptExtractionCopyWith<$Res> {
  _$ScriptExtractionCopyWithImpl(this._self, this._then);

  final ScriptExtraction _self;
  final $Res Function(ScriptExtraction) _then;

/// Create a copy of ScriptExtraction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? jsonPath = null,Object? variableName = null,Object? topic = freezed,Object? source = null,}) {
  return _then(_self.copyWith(
jsonPath: null == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String,variableName: null == variableName ? _self.variableName : variableName // ignore: cast_nullable_to_non_nullable
as String,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ScriptExtractionSource,
  ));
}

}


/// Adds pattern-matching-related methods to [ScriptExtraction].
extension ScriptExtractionPatterns on ScriptExtraction {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScriptExtraction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScriptExtraction() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScriptExtraction value)  $default,){
final _that = this;
switch (_that) {
case _ScriptExtraction():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScriptExtraction value)?  $default,){
final _that = this;
switch (_that) {
case _ScriptExtraction() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String jsonPath,  String variableName,  String? topic,  ScriptExtractionSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScriptExtraction() when $default != null:
return $default(_that.jsonPath,_that.variableName,_that.topic,_that.source);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String jsonPath,  String variableName,  String? topic,  ScriptExtractionSource source)  $default,) {final _that = this;
switch (_that) {
case _ScriptExtraction():
return $default(_that.jsonPath,_that.variableName,_that.topic,_that.source);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String jsonPath,  String variableName,  String? topic,  ScriptExtractionSource source)?  $default,) {final _that = this;
switch (_that) {
case _ScriptExtraction() when $default != null:
return $default(_that.jsonPath,_that.variableName,_that.topic,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScriptExtraction implements ScriptExtraction {
  const _ScriptExtraction({required this.jsonPath, required this.variableName, this.topic, this.source = ScriptExtractionSource.value});
  factory _ScriptExtraction.fromJson(Map<String, dynamic> json) => _$ScriptExtractionFromJson(json);

@override final  String jsonPath;
@override final  String variableName;
@override final  String? topic;
@override@JsonKey() final  ScriptExtractionSource source;

/// Create a copy of ScriptExtraction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScriptExtractionCopyWith<_ScriptExtraction> get copyWith => __$ScriptExtractionCopyWithImpl<_ScriptExtraction>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScriptExtractionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScriptExtraction&&(identical(other.jsonPath, jsonPath) || other.jsonPath == jsonPath)&&(identical(other.variableName, variableName) || other.variableName == variableName)&&(identical(other.topic, topic) || other.topic == topic)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,jsonPath,variableName,topic,source);

@override
String toString() {
  return 'ScriptExtraction(jsonPath: $jsonPath, variableName: $variableName, topic: $topic, source: $source)';
}


}

/// @nodoc
abstract mixin class _$ScriptExtractionCopyWith<$Res> implements $ScriptExtractionCopyWith<$Res> {
  factory _$ScriptExtractionCopyWith(_ScriptExtraction value, $Res Function(_ScriptExtraction) _then) = __$ScriptExtractionCopyWithImpl;
@override @useResult
$Res call({
 String jsonPath, String variableName, String? topic, ScriptExtractionSource source
});




}
/// @nodoc
class __$ScriptExtractionCopyWithImpl<$Res>
    implements _$ScriptExtractionCopyWith<$Res> {
  __$ScriptExtractionCopyWithImpl(this._self, this._then);

  final _ScriptExtraction _self;
  final $Res Function(_ScriptExtraction) _then;

/// Create a copy of ScriptExtraction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? jsonPath = null,Object? variableName = null,Object? topic = freezed,Object? source = null,}) {
  return _then(_ScriptExtraction(
jsonPath: null == jsonPath ? _self.jsonPath : jsonPath // ignore: cast_nullable_to_non_nullable
as String,variableName: null == variableName ? _self.variableName : variableName // ignore: cast_nullable_to_non_nullable
as String,topic: freezed == topic ? _self.topic : topic // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as ScriptExtractionSource,
  ));
}


}


/// @nodoc
mixin _$ScriptStep {

 String get id; String get name; String get clusterName;// Reference by name for persistence
 List<String> get topicNames;// Reference by name for persistence
 String? get filterTemplate; FilterType get filterType; SearchScope get scope;// Configuration strategies
 MultiSearchStartStrategy get startStrategy; MultiSearchEndStrategy get endStrategy;// Stringified for variable support
 String? get startOffset; String? get startTimestamp; String? get startPartition; bool get fastTraceEnabled; String? get endOffset; String? get endTimestamp; String? get maxResults; List<ScriptExtraction> get extractions;
/// Create a copy of ScriptStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScriptStepCopyWith<ScriptStep> get copyWith => _$ScriptStepCopyWithImpl<ScriptStep>(this as ScriptStep, _$identity);

  /// Serializes this ScriptStep to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScriptStep&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.clusterName, clusterName) || other.clusterName == clusterName)&&const DeepCollectionEquality().equals(other.topicNames, topicNames)&&(identical(other.filterTemplate, filterTemplate) || other.filterTemplate == filterTemplate)&&(identical(other.filterType, filterType) || other.filterType == filterType)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.startStrategy, startStrategy) || other.startStrategy == startStrategy)&&(identical(other.endStrategy, endStrategy) || other.endStrategy == endStrategy)&&(identical(other.startOffset, startOffset) || other.startOffset == startOffset)&&(identical(other.startTimestamp, startTimestamp) || other.startTimestamp == startTimestamp)&&(identical(other.startPartition, startPartition) || other.startPartition == startPartition)&&(identical(other.fastTraceEnabled, fastTraceEnabled) || other.fastTraceEnabled == fastTraceEnabled)&&(identical(other.endOffset, endOffset) || other.endOffset == endOffset)&&(identical(other.endTimestamp, endTimestamp) || other.endTimestamp == endTimestamp)&&(identical(other.maxResults, maxResults) || other.maxResults == maxResults)&&const DeepCollectionEquality().equals(other.extractions, extractions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,clusterName,const DeepCollectionEquality().hash(topicNames),filterTemplate,filterType,scope,startStrategy,endStrategy,startOffset,startTimestamp,startPartition,fastTraceEnabled,endOffset,endTimestamp,maxResults,const DeepCollectionEquality().hash(extractions));

@override
String toString() {
  return 'ScriptStep(id: $id, name: $name, clusterName: $clusterName, topicNames: $topicNames, filterTemplate: $filterTemplate, filterType: $filterType, scope: $scope, startStrategy: $startStrategy, endStrategy: $endStrategy, startOffset: $startOffset, startTimestamp: $startTimestamp, startPartition: $startPartition, fastTraceEnabled: $fastTraceEnabled, endOffset: $endOffset, endTimestamp: $endTimestamp, maxResults: $maxResults, extractions: $extractions)';
}


}

/// @nodoc
abstract mixin class $ScriptStepCopyWith<$Res>  {
  factory $ScriptStepCopyWith(ScriptStep value, $Res Function(ScriptStep) _then) = _$ScriptStepCopyWithImpl;
@useResult
$Res call({
 String id, String name, String clusterName, List<String> topicNames, String? filterTemplate, FilterType filterType, SearchScope scope, MultiSearchStartStrategy startStrategy, MultiSearchEndStrategy endStrategy, String? startOffset, String? startTimestamp, String? startPartition, bool fastTraceEnabled, String? endOffset, String? endTimestamp, String? maxResults, List<ScriptExtraction> extractions
});




}
/// @nodoc
class _$ScriptStepCopyWithImpl<$Res>
    implements $ScriptStepCopyWith<$Res> {
  _$ScriptStepCopyWithImpl(this._self, this._then);

  final ScriptStep _self;
  final $Res Function(ScriptStep) _then;

/// Create a copy of ScriptStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? clusterName = null,Object? topicNames = null,Object? filterTemplate = freezed,Object? filterType = null,Object? scope = null,Object? startStrategy = null,Object? endStrategy = null,Object? startOffset = freezed,Object? startTimestamp = freezed,Object? startPartition = freezed,Object? fastTraceEnabled = null,Object? endOffset = freezed,Object? endTimestamp = freezed,Object? maxResults = freezed,Object? extractions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,clusterName: null == clusterName ? _self.clusterName : clusterName // ignore: cast_nullable_to_non_nullable
as String,topicNames: null == topicNames ? _self.topicNames : topicNames // ignore: cast_nullable_to_non_nullable
as List<String>,filterTemplate: freezed == filterTemplate ? _self.filterTemplate : filterTemplate // ignore: cast_nullable_to_non_nullable
as String?,filterType: null == filterType ? _self.filterType : filterType // ignore: cast_nullable_to_non_nullable
as FilterType,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as SearchScope,startStrategy: null == startStrategy ? _self.startStrategy : startStrategy // ignore: cast_nullable_to_non_nullable
as MultiSearchStartStrategy,endStrategy: null == endStrategy ? _self.endStrategy : endStrategy // ignore: cast_nullable_to_non_nullable
as MultiSearchEndStrategy,startOffset: freezed == startOffset ? _self.startOffset : startOffset // ignore: cast_nullable_to_non_nullable
as String?,startTimestamp: freezed == startTimestamp ? _self.startTimestamp : startTimestamp // ignore: cast_nullable_to_non_nullable
as String?,startPartition: freezed == startPartition ? _self.startPartition : startPartition // ignore: cast_nullable_to_non_nullable
as String?,fastTraceEnabled: null == fastTraceEnabled ? _self.fastTraceEnabled : fastTraceEnabled // ignore: cast_nullable_to_non_nullable
as bool,endOffset: freezed == endOffset ? _self.endOffset : endOffset // ignore: cast_nullable_to_non_nullable
as String?,endTimestamp: freezed == endTimestamp ? _self.endTimestamp : endTimestamp // ignore: cast_nullable_to_non_nullable
as String?,maxResults: freezed == maxResults ? _self.maxResults : maxResults // ignore: cast_nullable_to_non_nullable
as String?,extractions: null == extractions ? _self.extractions : extractions // ignore: cast_nullable_to_non_nullable
as List<ScriptExtraction>,
  ));
}

}


/// Adds pattern-matching-related methods to [ScriptStep].
extension ScriptStepPatterns on ScriptStep {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScriptStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScriptStep() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScriptStep value)  $default,){
final _that = this;
switch (_that) {
case _ScriptStep():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScriptStep value)?  $default,){
final _that = this;
switch (_that) {
case _ScriptStep() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String clusterName,  List<String> topicNames,  String? filterTemplate,  FilterType filterType,  SearchScope scope,  MultiSearchStartStrategy startStrategy,  MultiSearchEndStrategy endStrategy,  String? startOffset,  String? startTimestamp,  String? startPartition,  bool fastTraceEnabled,  String? endOffset,  String? endTimestamp,  String? maxResults,  List<ScriptExtraction> extractions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScriptStep() when $default != null:
return $default(_that.id,_that.name,_that.clusterName,_that.topicNames,_that.filterTemplate,_that.filterType,_that.scope,_that.startStrategy,_that.endStrategy,_that.startOffset,_that.startTimestamp,_that.startPartition,_that.fastTraceEnabled,_that.endOffset,_that.endTimestamp,_that.maxResults,_that.extractions);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String clusterName,  List<String> topicNames,  String? filterTemplate,  FilterType filterType,  SearchScope scope,  MultiSearchStartStrategy startStrategy,  MultiSearchEndStrategy endStrategy,  String? startOffset,  String? startTimestamp,  String? startPartition,  bool fastTraceEnabled,  String? endOffset,  String? endTimestamp,  String? maxResults,  List<ScriptExtraction> extractions)  $default,) {final _that = this;
switch (_that) {
case _ScriptStep():
return $default(_that.id,_that.name,_that.clusterName,_that.topicNames,_that.filterTemplate,_that.filterType,_that.scope,_that.startStrategy,_that.endStrategy,_that.startOffset,_that.startTimestamp,_that.startPartition,_that.fastTraceEnabled,_that.endOffset,_that.endTimestamp,_that.maxResults,_that.extractions);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String clusterName,  List<String> topicNames,  String? filterTemplate,  FilterType filterType,  SearchScope scope,  MultiSearchStartStrategy startStrategy,  MultiSearchEndStrategy endStrategy,  String? startOffset,  String? startTimestamp,  String? startPartition,  bool fastTraceEnabled,  String? endOffset,  String? endTimestamp,  String? maxResults,  List<ScriptExtraction> extractions)?  $default,) {final _that = this;
switch (_that) {
case _ScriptStep() when $default != null:
return $default(_that.id,_that.name,_that.clusterName,_that.topicNames,_that.filterTemplate,_that.filterType,_that.scope,_that.startStrategy,_that.endStrategy,_that.startOffset,_that.startTimestamp,_that.startPartition,_that.fastTraceEnabled,_that.endOffset,_that.endTimestamp,_that.maxResults,_that.extractions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScriptStep implements ScriptStep {
  const _ScriptStep({required this.id, required this.name, required this.clusterName, final  List<String> topicNames = const [], this.filterTemplate, this.filterType = FilterType.contains, this.scope = SearchScope.both, this.startStrategy = MultiSearchStartStrategy.earliest, this.endStrategy = MultiSearchEndStrategy.latest, this.startOffset, this.startTimestamp, this.startPartition, this.fastTraceEnabled = false, this.endOffset, this.endTimestamp, this.maxResults, final  List<ScriptExtraction> extractions = const []}): _topicNames = topicNames,_extractions = extractions;
  factory _ScriptStep.fromJson(Map<String, dynamic> json) => _$ScriptStepFromJson(json);

@override final  String id;
@override final  String name;
@override final  String clusterName;
// Reference by name for persistence
 final  List<String> _topicNames;
// Reference by name for persistence
@override@JsonKey() List<String> get topicNames {
  if (_topicNames is EqualUnmodifiableListView) return _topicNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topicNames);
}

// Reference by name for persistence
@override final  String? filterTemplate;
@override@JsonKey() final  FilterType filterType;
@override@JsonKey() final  SearchScope scope;
// Configuration strategies
@override@JsonKey() final  MultiSearchStartStrategy startStrategy;
@override@JsonKey() final  MultiSearchEndStrategy endStrategy;
// Stringified for variable support
@override final  String? startOffset;
@override final  String? startTimestamp;
@override final  String? startPartition;
@override@JsonKey() final  bool fastTraceEnabled;
@override final  String? endOffset;
@override final  String? endTimestamp;
@override final  String? maxResults;
 final  List<ScriptExtraction> _extractions;
@override@JsonKey() List<ScriptExtraction> get extractions {
  if (_extractions is EqualUnmodifiableListView) return _extractions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extractions);
}


/// Create a copy of ScriptStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScriptStepCopyWith<_ScriptStep> get copyWith => __$ScriptStepCopyWithImpl<_ScriptStep>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScriptStepToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScriptStep&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.clusterName, clusterName) || other.clusterName == clusterName)&&const DeepCollectionEquality().equals(other._topicNames, _topicNames)&&(identical(other.filterTemplate, filterTemplate) || other.filterTemplate == filterTemplate)&&(identical(other.filterType, filterType) || other.filterType == filterType)&&(identical(other.scope, scope) || other.scope == scope)&&(identical(other.startStrategy, startStrategy) || other.startStrategy == startStrategy)&&(identical(other.endStrategy, endStrategy) || other.endStrategy == endStrategy)&&(identical(other.startOffset, startOffset) || other.startOffset == startOffset)&&(identical(other.startTimestamp, startTimestamp) || other.startTimestamp == startTimestamp)&&(identical(other.startPartition, startPartition) || other.startPartition == startPartition)&&(identical(other.fastTraceEnabled, fastTraceEnabled) || other.fastTraceEnabled == fastTraceEnabled)&&(identical(other.endOffset, endOffset) || other.endOffset == endOffset)&&(identical(other.endTimestamp, endTimestamp) || other.endTimestamp == endTimestamp)&&(identical(other.maxResults, maxResults) || other.maxResults == maxResults)&&const DeepCollectionEquality().equals(other._extractions, _extractions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,clusterName,const DeepCollectionEquality().hash(_topicNames),filterTemplate,filterType,scope,startStrategy,endStrategy,startOffset,startTimestamp,startPartition,fastTraceEnabled,endOffset,endTimestamp,maxResults,const DeepCollectionEquality().hash(_extractions));

@override
String toString() {
  return 'ScriptStep(id: $id, name: $name, clusterName: $clusterName, topicNames: $topicNames, filterTemplate: $filterTemplate, filterType: $filterType, scope: $scope, startStrategy: $startStrategy, endStrategy: $endStrategy, startOffset: $startOffset, startTimestamp: $startTimestamp, startPartition: $startPartition, fastTraceEnabled: $fastTraceEnabled, endOffset: $endOffset, endTimestamp: $endTimestamp, maxResults: $maxResults, extractions: $extractions)';
}


}

/// @nodoc
abstract mixin class _$ScriptStepCopyWith<$Res> implements $ScriptStepCopyWith<$Res> {
  factory _$ScriptStepCopyWith(_ScriptStep value, $Res Function(_ScriptStep) _then) = __$ScriptStepCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String clusterName, List<String> topicNames, String? filterTemplate, FilterType filterType, SearchScope scope, MultiSearchStartStrategy startStrategy, MultiSearchEndStrategy endStrategy, String? startOffset, String? startTimestamp, String? startPartition, bool fastTraceEnabled, String? endOffset, String? endTimestamp, String? maxResults, List<ScriptExtraction> extractions
});




}
/// @nodoc
class __$ScriptStepCopyWithImpl<$Res>
    implements _$ScriptStepCopyWith<$Res> {
  __$ScriptStepCopyWithImpl(this._self, this._then);

  final _ScriptStep _self;
  final $Res Function(_ScriptStep) _then;

/// Create a copy of ScriptStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? clusterName = null,Object? topicNames = null,Object? filterTemplate = freezed,Object? filterType = null,Object? scope = null,Object? startStrategy = null,Object? endStrategy = null,Object? startOffset = freezed,Object? startTimestamp = freezed,Object? startPartition = freezed,Object? fastTraceEnabled = null,Object? endOffset = freezed,Object? endTimestamp = freezed,Object? maxResults = freezed,Object? extractions = null,}) {
  return _then(_ScriptStep(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,clusterName: null == clusterName ? _self.clusterName : clusterName // ignore: cast_nullable_to_non_nullable
as String,topicNames: null == topicNames ? _self._topicNames : topicNames // ignore: cast_nullable_to_non_nullable
as List<String>,filterTemplate: freezed == filterTemplate ? _self.filterTemplate : filterTemplate // ignore: cast_nullable_to_non_nullable
as String?,filterType: null == filterType ? _self.filterType : filterType // ignore: cast_nullable_to_non_nullable
as FilterType,scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as SearchScope,startStrategy: null == startStrategy ? _self.startStrategy : startStrategy // ignore: cast_nullable_to_non_nullable
as MultiSearchStartStrategy,endStrategy: null == endStrategy ? _self.endStrategy : endStrategy // ignore: cast_nullable_to_non_nullable
as MultiSearchEndStrategy,startOffset: freezed == startOffset ? _self.startOffset : startOffset // ignore: cast_nullable_to_non_nullable
as String?,startTimestamp: freezed == startTimestamp ? _self.startTimestamp : startTimestamp // ignore: cast_nullable_to_non_nullable
as String?,startPartition: freezed == startPartition ? _self.startPartition : startPartition // ignore: cast_nullable_to_non_nullable
as String?,fastTraceEnabled: null == fastTraceEnabled ? _self.fastTraceEnabled : fastTraceEnabled // ignore: cast_nullable_to_non_nullable
as bool,endOffset: freezed == endOffset ? _self.endOffset : endOffset // ignore: cast_nullable_to_non_nullable
as String?,endTimestamp: freezed == endTimestamp ? _self.endTimestamp : endTimestamp // ignore: cast_nullable_to_non_nullable
as String?,maxResults: freezed == maxResults ? _self.maxResults : maxResults // ignore: cast_nullable_to_non_nullable
as String?,extractions: null == extractions ? _self._extractions : extractions // ignore: cast_nullable_to_non_nullable
as List<ScriptExtraction>,
  ));
}


}

// dart format on
