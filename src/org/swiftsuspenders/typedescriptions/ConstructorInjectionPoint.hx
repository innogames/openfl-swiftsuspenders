/*
 * Copyright (c) 2012 the original author or authors
 *
 * Permission is hereby granted to use, modify, and distribute this file
 * in accordance with the terms of the license agreement accompanying it.
 */

package org.swiftsuspenders.typedescriptions;

import org.swiftsuspenders.Injector;
import org.swiftsuspenders.errors.InjectorError;
import org.swiftsuspenders.errors.InjectorMissingMappingError;

class ConstructorInjectionPoint
{
	//----------------------       Private / Protected Properties       ----------------------//
	private var _parameterMappingIDs:Array<Dynamic>;
	private var _requiredParameters:Int;

	//----------------------               Public Methods               ----------------------//
	public function new(parameters:Array<Dynamic>, requiredParameters:UInt)
	{
		_parameterMappingIDs = parameters;
		_requiredParameters = requiredParameters;
	}

	public function createInstance(type:Class<Dynamic>, injector:Injector):Dynamic
	{
		return Type.createInstance(type, gatherParameterValues(type, injector));
	}

	//----------------------         Private / Protected Methods        ----------------------//
	private function gatherParameterValues(targetType:Class<Dynamic>, injector:Injector):Array<Dynamic>
	{
		var length:Int = _parameterMappingIDs.length;
		var parameters:Array<Dynamic> = [];
		// CHECK
		//parameters.length = length;

		for (i in 0...length)
		{
			var parameterMappingId:String = _parameterMappingIDs[i];
			var provider = injector.getProvider(parameterMappingId);
			if (provider == null)
			{
				if (i >= _requiredParameters)
				{
					break;
				}

				var errorMsg:String = 'Injector is missing a mapping to handle injection into target "';
				errorMsg += Type.getClassName(targetType);
				errorMsg += '". Target dependency: ';
				errorMsg += parameterMappingId;
				errorMsg += ', parameter: ';
				errorMsg += (i + 1);

				throw(new InjectorMissingMappingError(errorMsg));
			}

			parameters[i] = provider.apply(targetType, injector, null);
		}
		return parameters;
	}
}