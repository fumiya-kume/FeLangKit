/// Groups the components of a callable (function/procedure) declaration for printing.
struct CallableDeclarationInfo {
    let name: String
    let parameters: [Parameter]
    let returnType: DataType?
    let localVariables: [VariableDeclaration]
    let body: [Statement]
    let keyword: String
    let endKeyword: String
}
