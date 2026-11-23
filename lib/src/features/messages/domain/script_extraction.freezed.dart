// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'script_extraction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

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
  final _this = this as ScriptExtraction;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScriptExtraction&&(identical(other.jsonPath, _this.jsonPath) || other.jsonPath == _this.jsonPath)&&(identical(other.variableName, _this.variableName) || other.variableName == _this.variableName)&&(identical(other.topic, _this.topic) || other.topic == _this.topic)&&(identical(other.source, _this.source) || other.source == _this.source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScriptExtraction;
  return Object.hash(runtimeType,_this.jsonPath,_this.variableName,_this.topic,_this.source);
}

@override
String toString() {
  final _this = this as ScriptExtraction;
  return 'ScriptExtraction(jsonPath: ${_this.jsonPath}, variableName: ${_this.variableName}, topic: ${_this.topic}, source: ${_this.source})';
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
  return _then(ScriptExtraction(
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
int get hashCode {
    return Object.hash(runtimeType,jsonPath,variableName,topic,source);
}

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

// dart format on
