/*
 * Copyright (c) 2012 the original author or authors
 *
 * Permission is hereby granted to use, modify, and distribute this file
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders.typedescriptions;

import org.swiftsuspenders.Injector;

class TypeDescription {
	//----------------------              Public Properties             ----------------------//
	public var ctor:ConstructorInjectionPoint;
	public var injectionMethods:Array<Dynamic->Injector->Void>;
	public var preDestroyMethods:Array<Dynamic->Void>;
	public var postConstructionMethods:Array<Dynamic->Void>;

	//----------------------               Public Methods               ----------------------//
	public function new()
	{
		ctor = NoParamsConstructorInjectionPoint.instance;
	}

	public function addPostConstructMethod(func:Dynamic->Void)
	{
		if (postConstructionMethods == null)
			postConstructionMethods = [func];
		else
			postConstructionMethods.push(func);
	}

	public function addPreDestroyMethod(func:Dynamic->Void)
	{
		if (preDestroyMethods == null)
			preDestroyMethods = [func];
		else
			preDestroyMethods.push(func);
	}

	public function addInjectionMethod(func:Dynamic->Injector->Void)
	{
		if (injectionMethods == null)
			injectionMethods = [func];
		else
			injectionMethods.push(func);
	}
}
