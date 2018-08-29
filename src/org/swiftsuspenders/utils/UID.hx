package org.swiftsuspenders.utils;

import haxe.ds.ObjectMap;

@:keepSub
class UID
{
	private static var _i:UInt;
	
	/**
	 * Generates a UID for a given source object or class
	 * @param source The source object or class
	 * @return Generated UID
	 */
	public static function create(source:Dynamic = null):String
	{
		var className = UID.classID(source);
		var random:Int = Math.floor(Math.random() * 255);
		var returnVal:String = "";// (source ? source + '-':'');
		if (source != null) returnVal = className;
		returnVal += '-';
		returnVal += random;
		
		return returnVal;
	}
	
	public static function classID(source:Dynamic):String
	{
		var className = "";
		if (Std.is(source, Class)) {
			className = Type.getClassName(source); 
		}
		else if (Type.getClass(source) != null) {
			className = Type.getClassName(Type.getClass(source)); 
		}
		return className;
	}
}