import Foundation

@Observable
class PostProcessingService {
    static let shared = PostProcessingService()

    private(set) var isProcessing = false

    private static let enabledKey = "postProcessingEnabled"
    private static let promptKey = "postProcessingPrompt"
    private static let baseURLKey = "postProcessingBaseURL"
    private static let modelKey = "postProcessingModel"
    private static let keychainService = "sh.polar.speaktype.postprocessing"
    private static let keychainAccount = "api_key"

    static let defaultPrompt =
        "You are a post-processor for voice dictation. Fix typos, remove filler words, correct grammar, and clean up the text while preserving the original meaning. Output ONLY the corrected text with no explanation."
    static let defaultBaseURL = "http://localhost:11434/v1"
    static let defaultModel = "qwen2.5:0.5b"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var prompt: String {
        get { UserDefaults.standard.string(forKey: Self.promptKey) ?? Self.defaultPrompt }
        set { UserDefaults.standard.set(newValue, forKey: Self.promptKey) }
    }

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: Self.baseURLKey) ?? Self.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: Self.baseURLKey) }
    }

    var model: String {
        get { UserDefaults.standard.string(forKey: Self.modelKey) ?? Self.defaultModel }
        set { UserDefaults.standard.set(newValue, forKey: Self.modelKey) }
    }

    var apiKey: String {
        get {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: Self.keychainService,
                kSecAttrAccount: Self.keychainAccount,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data,
                let key = String(data: data, encoding: .utf8)
            else { return "" }
            return key
        }
        set {
            let deleteQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: Self.keychainService,
                kSecAttrAccount: Self.keychainAccount,
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            guard !newValue.isEmpty, let data = newValue.data(using: .utf8) else { return }
            let addQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: Self.keychainService,
                kSecAttrAccount: Self.keychainAccount,
                kSecValueData: data,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private init() {}

    func process(_ text: String) async throws -> String {
        guard isEnabled else { return text }

        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmedBase)/chat/completions") else { return text }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.3,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = apiKey
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        isProcessing = true
        defer { isProcessing = false }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            return text
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            return text
        }

        let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? text : result
    }
}
