//
//  Macros.swift
//  JSON
//
//  Created by Alsey Coleman Miller on 7/19/26.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct Plugins: CompilerPlugin {

    let providingMacros: [Macro.Type] = [
        JSONCodableMacro.self
    ]
}
