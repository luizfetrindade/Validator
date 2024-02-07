import UIKit
//MARK: - Contract
protocol RuleValidationProtocol {
    associatedtype Value
    associatedtype Rule
    
    var priority: Int { get set }
    var errorMessage: String { get }
    func isValid(value: Value, rule: Rule) -> Bool
}

protocol AnyRuleValidation {
    var priority: Int { get }
    var errorMessage: String { get }
    func validate(value: Any) -> RuleCompletion
}

enum RuleCompletion {
    case success
    case failure(String?)
}

//MARK: - Rules
struct NonEmptyValidation: RuleValidationProtocol {
    typealias Value = String
    typealias Rule = Void
    
    var errorMessage: String
    var priority: Int
    
    func isValid(value: String, rule: ()) -> Bool {
        return !value.isEmpty
    }
}

struct RegexValidation: RuleValidationProtocol {
    typealias Value = String
    typealias Rule = String

    var errorMessage: String
    var priority: Int
    
    func isValid(value: String, rule: String) -> Bool {
        let regex = try! NSRegularExpression(pattern: rule)
        let range = NSRange(location: 0, length: value.utf16.count)
        return regex.firstMatch(in: value, options: [], range: range) != nil
    }
}


//MARK: - Validator
struct AnyRuleValidator<Validator: RuleValidationProtocol>: AnyRuleValidation {
    private let _validate: (Validator.Value) -> RuleCompletion
    let priority: Int
    let errorMessage: String
    
    init(_ validator: Validator, rule: Validator.Rule) {
        self.priority = validator.priority
        self.errorMessage = validator.errorMessage
        self._validate = { value in
            return validator.isValid(value: value, rule: rule) ? .success : .failure(validator.errorMessage)
        }
    }
    
    func validate(value: Any) -> RuleCompletion {
        guard let value = value as? Validator.Value else {
            return .failure(errorMessage)
        }
        return _validate(value)
    }
}


func validateField(value: Any, rules: [AnyRuleValidation], completion: @escaping (RuleCompletion) -> Void) {
    DispatchQueue.main.async {
        let sortedRules = rules.sorted { $0.priority < $1.priority }
        
        for rule in sortedRules {
            let result = rule.validate(value: value)
            if case .failure(_) = result {
                DispatchQueue.main.async {
                    completion(result)
                }
                return
            }
            completion(.success)
        }
    }
}

let nonEmptyRule = AnyRuleValidator(NonEmptyValidation(errorMessage: "Vazio", priority: 2), rule: ())
let regexRule = AnyRuleValidator(RegexValidation(errorMessage: "Regex inválido", priority: 1), rule: "^[A-Za-z]+$")
let fieldRules: [any AnyRuleValidation] = [nonEmptyRule, regexRule]

validateField(value: "", rules: fieldRules) { result in
    print("result")
    switch result {
    case .success:
        print("Validação bem-sucedida!")
    case .failure(let errorMessage):
        print(errorMessage ?? "Erro desconhecido")
    }
}
