package partials;

import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.rtti.Meta;
import haxe.ds.StringMap;

using Lambda;

/**
 * Utility macros for defining multiple parts of a class in different files. To define a class
 * as a partial, simply implement the partials.Partial interface. To indicate the "host" class
 * for a series of partials, use the `@:partials()` metadata on the class, like so:
 *
 * ```haxe
 * package my.package;
 *
 * @:partials(my.package.PartialDefinitionA, my.package.partials.PartialDefinitionB)
 * class MyClassThatWouldBeReallyLongWithoutPartials implements partials.Partial {
 *     public function new() {
 *         trace("My partials are here!");
 *         foo();
 *         bar();
 *     }
 * }
 * ```
 *
 * ```haxe
 * package my.package;
 *
 * class PartialDefinitionA implements partials.Partial {
 *     public function foo() {
 *         trace("FOO!");
 *     }
 * }
 * ```
 *
 * ```haxe
 * package my.package.partials;
 *
 * class PartialDefinitionB implements partials.Partial {
 *     public function bar() {
 *         trace("BAR!");
 *     }
 * }
 * ```
 *
 * This would output:
 *
 * ```
 * My partials are here!
 * FOO!
 * BAR!
 * ```
 */
class Partials {

    /**
        Caches class fields, keyed by the module name.
    **/
    @:persistent
    private static var cache: Map<String, Array<Field>> = new StringMap();

    private static function getModuleName(e: Expr): Null<String> {
        return switch (e.expr) {
            case EConst(c):
                switch (c) {
                    case CIdent(s): s;
                    default: null;
                }
            case EField(e, field):
                getModuleName(e) + "." + field;
            default: null;
        };
    }

    macro public static function process(): Array<Field> {

        final localClass = Context.getLocalClass().get();
        final localFields = Context.getBuildFields();

        // Is it a partial "host"?
        final meta = localClass.meta;
        if (meta.has(":partials")) {

            // If so, get the modules it is referencing
            final currentPos = Context.currentPos();
            for (candidate in meta.extract(":partials").flatMap(e -> e.params)) {

                // Force-import them
                final moduleName = getModuleName(candidate);
                for (module in Context.getModule(moduleName)) {
                    switch (module) {
                        case TInst(classType, _):
                            final _ = classType.get();
                        case _:
                    }
                }

                // Bring in all of their fields
                final moduleFields = cache.get(moduleName);
                if (moduleFields == null) {
                    Context.info('No cached fields for module $moduleName', currentPos);
                    Context.info("(Try restarting your language server?)", currentPos, 1);
                } else {
                    for (field in moduleFields) {
                        field.pos = currentPos;
                        localFields.push(field);
                    }
                }
            }
        } else {
            // No, this is a "guest".
            // Save its fields and trash the class
            cache.set(Context.getLocalModule(), localFields);
            localClass.exclude();
            return [];
        }

        return localFields;
    }
}
