/*
 * Copyright (c) 2012 the original author or authors
 *
 * Permission is hereby granted to use, modify, and distribute this file
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders.typedescriptions;

import org.swiftsuspenders.Injector;

class NoParamsConstructorInjectionPoint extends ConstructorInjectionPoint
{
	public static var instance(default,null) = new NoParamsConstructorInjectionPoint();

	public function new()
	{
		super([], 0);
	}

	override public function createInstance(type:Class<Dynamic>, injector:Injector):Dynamic
	{
		return Type.createInstance(type, []);
	}
}