package org.swiftsuspenders.reflection;

@:autoBuild(org.swiftsuspenders.reflection.TypeDescriptionMacro.build())
@:dce @:remove // remove the inteface from output since it's just a marker interface
interface ITypeDescriptionAware {}
