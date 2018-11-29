package org.swiftsuspenders.reflection;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
using haxe.macro.Tools;

// added some comments here because the macro is not really simple and even simpler ones are perceived
// as dark magic by many :)
//
// so this macro works in two phases
// phase 1: build macro that is run per class implementing ITypeDescriptionAware
// phase 2: onAfterTyping callback that processes all the marked classes and generates
//          "factory" functions that fill the TypeDescription instance for this class
//
// initial version of this macro was much simplier: we just generated a static method in a @:build-macro
// but that hangs up haxe 3 compiler. so when we're on haxe 4 we might want to revisit and simplify this
class TypeDescriptionMacro {
	static inline var META = ":TypeDescriptionAware";

	static function build() {
		if (Context.defined("display")) // don't do anything in display-mode (completion, etc.)
			return null;

		switch Context.getLocalType() {
			case TInst(_.get() => cl, _):
				if (!cl.meta.has(META)) // only mark once, because the build-macro can be called multiple times
					cl.meta.add(META, [], cl.pos); // just mark the class with a meta to be processed after typing
				return null;
			case _:
				throw new Error("TypeDescriptionMacro must be only called on classes", Context.currentPos());
		}
	}

	// this is called at the start of compilation (using --macro argument) and registers a one-time onAfterTyping callback
	//
	// we could registering this implicitly on first build-macro call, but this is a bit too complicated wrt compiler cache
	// for me right now, so let's just call it with `--macro` explicitly
	static function use() {
		if (Context.defined("display")) // don't do anything in display-mode (completion, etc.)
			return;

		var called = false; // prevent processing twice, because the callback will be called again because we add a new type
		Context.onAfterTyping(function(types) {
			if (called) return;
			called = true;
			processInjections(types);
		});
	}

	// iterate over all marked classes and create factory function for them
	static function processInjections(types:Array<ModuleType>) {
		var fields = [];

		for (type in types) {
			switch type {
				case TClassDecl(_.get() => c) if (c.meta.has(META)): // only process classes that were marked by our metadata
					var meta = c.meta.extract(META)[0];

					// here we do a fancy trick to prevent processing classes that are not changed:
					// if the metadata contains no arguments, then it's new or changed (and thus
					// the build-macro was run, adding the no-argument meta), so we process it
					// and store the function expression we generated for it as a meta argument.
					// if the meta contains an argument - then the build macro wasn't run and the class
					// was processed before by this macro, so we just extract the function from it

					var expr;
					if (meta.params.length == 0) {
						var exprs = [];

						var moduleName = {
							var parts = c.module.split(".");
							parts[parts.length - 1];
						};
						var classTP:TypePath = {pack: c.pack, name: moduleName, sub: c.name};

						// if there is a type-description-aware superclass - call the parent factory before adding our injection points
						if (c.superClass != null && c.superClass.t.get().meta.has(META)) {
							var superClassKey = c.superClass.t.toString();
							exprs.push(macro org.swiftsuspenders.reflection.MacroReflector.factories[$v{superClassKey}](description));
						}

						var ctorExpr = getCtorExpr(c);
						exprs.push(macro description.ctor = $ctorExpr);

						var classCT = TPath(classTP);
						var injectExprs = [];
						for (field in c.fields.get()) {
							processField(classCT, field, injectExprs, exprs);
						}

						if (injectExprs.length > 0) {
							var funcExpr = macro function(target:$classCT, injector:org.swiftsuspenders.Injector) $b{injectExprs};
							exprs.push(macro description.addInjectionMethod($funcExpr));
						}

						expr = macro function(description:org.swiftsuspenders.typedescriptions.TypeDescription) $b{exprs};
						c.meta.remove(META);
						c.meta.add(META, [expr], c.pos);
					} else {
						expr = meta.params[0];
					}

					// add the function using the qualified class name as the field name
					var dotPath = if (c.pack.length > 0) c.pack.join(".") + "." + c.name else c.name;
					fields.push({field: dotPath, expr: expr});
				case _:
			}
		}

		// create an object literal expression
		var objectExpr = {pos: Context.currentPos(), expr: EObjectDecl(fields)};

		// create a class with the sole purpose of calling its `__init__` magic
		// that will initialize `MacroReflector.factories` with the factories mapping
		var typeDefinition = macro class TypeDescriptionAwareInit {
			static function __init__() {
				@:privateAccess org.swiftsuspenders.reflection.MacroReflector.factories = $objectExpr;
			}
		};
		typeDefinition.meta.push({pos: typeDefinition.pos, name: ":keep"}); // prevent it to be removed by DCE, since it's never used directly
		Context.defineType(typeDefinition); // add the type to the compilation
	}

	static function getCtorExpr(c:ClassType):Expr {
		var ctorField = getCtorField(c);
		if (ctorField == null) {
			return macro null;
		}

		switch ctorField.type {
			case TFun([], _):
				return macro org.swiftsuspenders.typedescriptions.NoParamsConstructorInjectionPoint.instance;
			case TFun(args, _):
				var params = [];
				var requiredParams = 0;
				for (arg in args) {
					var name = arg.t.follow().toString();
					params.push(name + "|");
					if (!arg.opt) {
						requiredParams++;
					}
				}
				return macro new org.swiftsuspenders.typedescriptions.ConstructorInjectionPoint($v{params}, $v{requiredParams});
			case _:
				throw "assert"; // can't happen
		}
	}

	static function getCtorField(c:ClassType):ClassField {
		if (c.isInterface) {
			return null;
		}
		if (c.constructor == null) {
			if (c.superClass != null) {
				return getCtorField(c.superClass.t.get());
			} else {
				return null;
			}
		}
		return c.constructor.get();
	}

	static function processField(classCT:ComplexType, field:ClassField, injectExprs:Array<Expr>, exprs:Array<Expr>) {
		var fieldName = field.name;

		if (field.meta.has("inject")) {
			switch field.kind {
				case FVar(_, _):
					var injectMeta = field.meta.extract("inject");
					var optional;
					switch injectMeta[0].params {
						case []:
							optional = false;
						case [{expr: EConst(CString("optional=true"))}]:
							optional = true;
						case _:
							throw new Error("@inject with parameters other than `optional=true` are not yet supported", injectMeta[0].pos);
					}

					var mappingId = field.type.follow().toString();
					var typeExpr = macro $p{mappingId.split(".")};
					var instanceExpr = macro injector.getInstanceForMapping($v{mappingId + "|"}, $typeExpr, null);
					if (optional) {
						injectExprs.push(macro {
							var instance = $instanceExpr;
							if (instance != null) {
								target.$fieldName = instance;
							}
						});
					} else {
						injectExprs.push(macro target.$fieldName = $instanceExpr);
					}
				case FMethod(_):
					throw new Error("@inject can only be applied to var fields", field.pos);
			}
		}

		inline function checkNoArgs() {
			switch field.type {
				case TFun([], _): // no-args function, ok
				case _:
					throw new Error("@PostConstruct/@PreDestroy function arguments are not yet supported", field.pos);
			}
		}

		if (field.meta.has("PostConstruct")) {
			checkNoArgs();
			exprs.push(macro description.addPostConstructMethod(function(o:$classCT) o.$fieldName()));
		}

		if (field.meta.has("PreDestroy")) {
			checkNoArgs();
			exprs.push(macro description.addPreDestroyMethod(function(o:$classCT) o.$fieldName()));
		}
	}
}
#end
