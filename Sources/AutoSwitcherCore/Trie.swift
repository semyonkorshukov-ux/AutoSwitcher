import Foundation

/// Префиксное дерево для быстрой проверки «существует ли слово с таким началом».
public final class Trie {
    private final class Node {
        var children: [Character: Node] = [:]
        var isWord = false
    }

    private let root = Node()

    public init(words: [String]) {
        for word in words {
            insert(word.lowercased())
        }
    }

    private func insert(_ word: String) {
        var node = root
        for ch in word {
            if let next = node.children[ch] {
                node = next
            } else {
                let fresh = Node()
                node.children[ch] = fresh
                node = fresh
            }
        }
        node.isWord = true
    }

    /// true, если существует слово, начинающееся с данной строки.
    public func hasPrefix(_ s: String) -> Bool {
        var node = root
        for ch in s {
            guard let next = node.children[ch] else { return false }
            node = next
        }
        return true
    }

    /// true, если строка является полным словом словаря.
    public func contains(_ s: String) -> Bool {
        var node = root
        for ch in s {
            guard let next = node.children[ch] else { return false }
            node = next
        }
        return node.isWord
    }
}
